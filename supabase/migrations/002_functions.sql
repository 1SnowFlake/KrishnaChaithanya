-- ============================================================
-- School Attendance App – Helper Functions & Triggers
-- Run AFTER 001_schema.sql
-- ============================================================

-- ============================================================
-- A. SECURITY-DEFINER HELPERS
-- These run as the DB owner, so they bypass RLS.
-- We call them *inside* RLS policies to avoid infinite loops
-- (a policy on `profiles` that reads `profiles` = recursion).
-- ============================================================

-- Returns the school's "today" in its configured timezone.
-- We use this instead of CURRENT_DATE so the app respects the
-- school timezone regardless of the Supabase server timezone.
CREATE OR REPLACE FUNCTION school_today()
RETURNS DATE
LANGUAGE sql SECURITY DEFINER STABLE
SET search_path = public
AS $$
  SELECT (now() AT TIME ZONE
            (SELECT timezone FROM settings LIMIT 1))::DATE;
$$;

-- Is the current JWT user an active admin?
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN
LANGUAGE sql SECURITY DEFINER STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
      AND role = 'admin'
      AND is_active = true
  );
$$;

-- Is the current JWT user active (any role)?
CREATE OR REPLACE FUNCTION is_active_user()
RETURNS BOOLEAN
LANGUAGE sql SECURITY DEFINER STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND is_active = true
  );
$$;

-- Does the current teacher have access to a class on a given date?
-- Access = primary teacher OR active substitute assignment.
CREATE OR REPLACE FUNCTION teacher_has_class_access(
  p_class_id UUID,
  p_date     DATE DEFAULT NULL  -- defaults to school_today()
)
RETURNS BOOLEAN
LANGUAGE sql SECURITY DEFINER STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    -- Primary teacher for this class
    SELECT 1 FROM classes
    WHERE id = p_class_id AND primary_teacher_id = auth.uid()
  )
  OR EXISTS (
    -- Active substitute assignment covering p_date
    SELECT 1 FROM substitute_assignments
    WHERE class_id   = p_class_id
      AND teacher_id = auth.uid()
      AND COALESCE(p_date, school_today())
            BETWEEN start_date AND end_date
  );
$$;

-- Is a date a gazetted / custom holiday?
CREATE OR REPLACE FUNCTION is_holiday(p_date DATE)
RETURNS BOOLEAN
LANGUAGE sql SECURITY DEFINER STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM holidays
    WHERE p_date BETWEEN start_date AND end_date
  );
$$;

-- Is a date a weekly off day (e.g., Sunday)?
CREATE OR REPLACE FUNCTION is_weekly_off(p_date DATE)
RETURNS BOOLEAN
LANGUAGE sql SECURITY DEFINER STABLE
SET search_path = public
AS $$
  SELECT COALESCE(
    EXTRACT(DOW FROM p_date)::INTEGER = ANY(s.weekly_off_days),
    false
  )
  FROM (SELECT weekly_off_days FROM settings LIMIT 1) AS s;
$$;

-- Is the current school-timezone time before the cutoff
-- for the given session?
CREATE OR REPLACE FUNCTION is_before_cutoff(p_session TEXT)
RETURNS BOOLEAN
LANGUAGE sql SECURITY DEFINER STABLE
SET search_path = public
AS $$
  SELECT CASE p_session
    WHEN 'morning' THEN
      (now() AT TIME ZONE (SELECT timezone FROM settings LIMIT 1))::TIME
        < (SELECT morning_cutoff FROM settings LIMIT 1)
    WHEN 'afternoon' THEN
      (now() AT TIME ZONE (SELECT timezone FROM settings LIMIT 1))::TIME
        < (SELECT afternoon_cutoff FROM settings LIMIT 1)
    ELSE false
  END;
$$;


-- ============================================================
-- B. TRIGGER: Auto-create a profile when a new auth user signs up
-- The Edge Function passes name & role via raw_user_meta_data.
-- ============================================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO profiles (id, email, name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data ->> 'name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data ->> 'role', 'teacher')
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();


-- ============================================================
-- C. TRIGGER: Audit log for attendance changes
-- Fires AFTER INSERT (old_status = NULL) and AFTER UPDATE when status
-- actually changed. MUST be AFTER so attendance row exists for foreign key.
-- ============================================================
CREATE OR REPLACE FUNCTION log_attendance_change()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO attendance_log (attendance_id, old_status, new_status, changed_by)
    VALUES (NEW.id, NULL, NEW.status, NEW.marked_by);
  ELSIF TG_OP = 'UPDATE'
        AND OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO attendance_log (attendance_id, old_status, new_status, changed_by)
    VALUES (NEW.id, OLD.status, NEW.status, NEW.marked_by);
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_attendance_audit ON attendance;
CREATE TRIGGER trg_attendance_audit
  AFTER INSERT OR UPDATE ON attendance
  FOR EACH ROW
  EXECUTE FUNCTION log_attendance_change();

-- Attendance updated_at trigger (BEFORE UPDATE)
CREATE TRIGGER trg_attendance_updated
  BEFORE UPDATE ON attendance
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();


-- ============================================================
-- D. TRIGGER: Auto-update updated_at on other tables
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_profiles_updated
  BEFORE UPDATE ON profiles   FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_classes_updated
  BEFORE UPDATE ON classes    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_students_updated
  BEFORE UPDATE ON students   FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_settings_updated
  BEFORE UPDATE ON settings   FOR EACH ROW EXECUTE FUNCTION update_updated_at();


-- ============================================================
-- E. REPORT HELPERS (Postgres, not Dart)
-- Calculate attendance percentage excluding holidays & off days.
-- ============================================================

-- Per-student percentage for a date range.
CREATE OR REPLACE FUNCTION get_attendance_percentage(
  p_student_id UUID,
  p_start_date DATE,
  p_end_date   DATE,
  p_session    TEXT DEFAULT NULL   -- NULL = both sessions
)
RETURNS NUMERIC
LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public
AS $$
DECLARE
  v_working_days  INTEGER;
  v_total_slots   INTEGER;
  v_present_count INTEGER;
  v_weekly_offs   INTEGER[];
BEGIN
  SELECT weekly_off_days INTO v_weekly_offs FROM settings LIMIT 1;

  -- Count working days (not a holiday, not a weekly off)
  SELECT COUNT(*)::INTEGER INTO v_working_days
  FROM generate_series(p_start_date, p_end_date, '1 day'::INTERVAL) AS d(day)
  WHERE EXTRACT(DOW FROM d.day)::INTEGER != ALL(COALESCE(v_weekly_offs, '{}'))
    AND NOT EXISTS (
      SELECT 1 FROM holidays h WHERE d.day BETWEEN h.start_date AND h.end_date
    );

  -- Slots = working_days × sessions_per_day
  IF p_session IS NOT NULL THEN
    v_total_slots := v_working_days;           -- 1 session
  ELSE
    v_total_slots := v_working_days * 2;       -- both sessions
  END IF;

  IF v_total_slots = 0 THEN RETURN 0; END IF;

  -- Count present records on working days only
  SELECT COUNT(*) INTO v_present_count
  FROM attendance a
  WHERE a.student_id = p_student_id
    AND a.date BETWEEN p_start_date AND p_end_date
    AND a.status = 'present'
    AND (p_session IS NULL OR a.session = p_session)
    AND EXTRACT(DOW FROM a.date)::INTEGER != ALL(COALESCE(v_weekly_offs, '{}'))
    AND NOT EXISTS (
      SELECT 1 FROM holidays h WHERE a.date BETWEEN h.start_date AND h.end_date
    );

  RETURN ROUND(v_present_count::NUMERIC / v_total_slots * 100, 2);
END;
$$;

-- Class-level attendance summary for one date + session.
CREATE OR REPLACE FUNCTION get_class_attendance_summary(
  p_class_id UUID,
  p_date     DATE,
  p_session  TEXT
)
RETURNS TABLE (
  total_students BIGINT,
  present_count  BIGINT,
  absent_count   BIGINT,
  not_marked     BIGINT
)
LANGUAGE sql SECURITY DEFINER STABLE
SET search_path = public
AS $$
  WITH counts AS (
    SELECT
      (SELECT COUNT(*) FROM students
        WHERE class_id = p_class_id AND is_active = true) AS total,
      COUNT(*) FILTER (WHERE a.status = 'present') AS present_cnt,
      COUNT(*) FILTER (WHERE a.status = 'absent')  AS absent_cnt
    FROM attendance a
    WHERE a.class_id = p_class_id
      AND a.date     = p_date
      AND a.session  = p_session
  )
  SELECT
    total,
    present_cnt,
    absent_cnt,
    total - present_cnt - absent_cnt
  FROM counts;
$$;


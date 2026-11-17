-- ============================================================
-- School Attendance App – COMPLETE RESTART & SETUP SCRIPT
-- Paste this entire file into your Supabase SQL Editor and click RUN.
--
-- This script will:
--   1. Cleanly tear down existing app tables, triggers, and seed users
--   2. Create the complete schema (all tables + teacher_attendance)
--   3. Create all helper functions & triggers
--   4. Enable Row Level Security (RLS) & apply all policies
--   5. Seed initial data (admin, teachers, classes, students, settings)
-- ============================================================

-- ============================================================
-- STEP 1: TEARDOWN (CLEAN WIPE)
-- ============================================================
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS log_attendance_change() CASCADE;
DROP FUNCTION IF EXISTS is_admin() CASCADE;
DROP FUNCTION IF EXISTS is_active_user() CASCADE;
DROP FUNCTION IF EXISTS school_today() CASCADE;
DROP FUNCTION IF EXISTS teacher_has_class_access(UUID, DATE) CASCADE;

DROP TABLE IF EXISTS teacher_attendance CASCADE;
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS substitute_assignments CASCADE;
DROP TABLE IF EXISTS settings CASCADE;
DROP TABLE IF EXISTS holidays CASCADE;
DROP TABLE IF EXISTS attendance_log CASCADE;
DROP TABLE IF EXISTS attendance CASCADE;
DROP TABLE IF EXISTS students CASCADE;
DROP TABLE IF EXISTS classes CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;

-- Remove seed auth users if already present
DELETE FROM auth.identities WHERE user_id IN (
  'a0000000-0000-0000-0000-000000000001',
  'a0000000-0000-0000-0000-000000000002',
  'a0000000-0000-0000-0000-000000000003'
);
DELETE FROM auth.users WHERE id IN (
  'a0000000-0000-0000-0000-000000000001',
  'a0000000-0000-0000-0000-000000000002',
  'a0000000-0000-0000-0000-000000000003'
);

-- ============================================================
-- STEP 2: SCHEMA DEFINITION
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. PROFILES
CREATE TABLE profiles (
  id         UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name       TEXT        NOT NULL,
  email      TEXT        NOT NULL UNIQUE,
  role       TEXT        NOT NULL DEFAULT 'teacher',
  is_active  BOOLEAN     NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. CLASSES
CREATE TABLE classes (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name               TEXT NOT NULL UNIQUE,
  primary_teacher_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. STUDENTS
CREATE TABLE students (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name       TEXT    NOT NULL,
  roll_no    TEXT    NOT NULL,
  class_id   UUID    NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
  is_active  BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (roll_no, class_id)
);

-- 4. ATTENDANCE
CREATE TABLE attendance (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id    UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  class_id      UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
  date          DATE NOT NULL,
  session       TEXT NOT NULL CHECK (session IN ('morning', 'afternoon')),
  status        TEXT NOT NULL CHECK (status IN ('present', 'absent')),
  marked_by     UUID NOT NULL REFERENCES profiles(id),
  is_substitute BOOLEAN NOT NULL DEFAULT false,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (student_id, date, session)
);

-- 5. ATTENDANCE_LOG (audit trail)
CREATE TABLE attendance_log (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  attendance_id UUID NOT NULL REFERENCES attendance(id) ON DELETE CASCADE,
  old_status    TEXT,
  new_status    TEXT NOT NULL CHECK (new_status IN ('present', 'absent')),
  changed_by    UUID NOT NULL REFERENCES profiles(id),
  changed_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. HOLIDAYS
CREATE TABLE holidays (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name       TEXT NOT NULL,
  start_date DATE NOT NULL,
  end_date   DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (end_date >= start_date)
);

-- 7. SETTINGS (single-row table)
CREATE TABLE settings (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  morning_cutoff           TIME         NOT NULL DEFAULT '10:30:00',
  afternoon_cutoff         TIME         NOT NULL DEFAULT '14:30:00',
  weekly_off_days          INTEGER[]    NOT NULL DEFAULT '{0}',
  low_attendance_threshold NUMERIC(5,2) NOT NULL DEFAULT 75.00,
  timezone                 TEXT         NOT NULL DEFAULT 'Asia/Kolkata',
  allow_holiday_attendance BOOLEAN      NOT NULL DEFAULT true,
  allow_past_cutoff        BOOLEAN      NOT NULL DEFAULT true,
  updated_at               TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX settings_singleton ON settings ((true));

-- 8. SUBSTITUTE_ASSIGNMENTS
CREATE TABLE substitute_assignments (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id   UUID NOT NULL REFERENCES classes(id)   ON DELETE CASCADE,
  teacher_id UUID NOT NULL REFERENCES profiles(id)  ON DELETE CASCADE,
  start_date DATE NOT NULL,
  end_date   DATE NOT NULL,
  created_by UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (end_date >= start_date)
);

-- 9. NOTIFICATIONS
CREATE TABLE notifications (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID REFERENCES profiles(id) ON DELETE CASCADE,
  type       TEXT    NOT NULL,
  message    TEXT    NOT NULL,
  is_read    BOOLEAN NOT NULL DEFAULT false,
  metadata   JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 10. TEACHER_ATTENDANCE
CREATE TABLE teacher_attendance (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  date       DATE NOT NULL,
  session    TEXT NOT NULL CHECK (session IN ('morning', 'afternoon')),
  status     TEXT NOT NULL CHECK (status IN ('present', 'absent')),
  marked_by  UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (teacher_id, date, session)
);

-- INDEXES
CREATE INDEX idx_attendance_date                 ON attendance(date);
CREATE INDEX idx_attendance_class_date           ON attendance(class_id, date);
CREATE INDEX idx_attendance_student_date         ON attendance(student_id, date);
CREATE INDEX idx_students_class                  ON students(class_id);
CREATE INDEX idx_classes_teacher                 ON classes(primary_teacher_id);
CREATE INDEX idx_sub_assign_dates                ON substitute_assignments(start_date, end_date);
CREATE INDEX idx_sub_assign_teacher              ON substitute_assignments(teacher_id);
CREATE INDEX idx_holidays_dates                  ON holidays(start_date, end_date);
CREATE INDEX idx_notifications_user_read         ON notifications(user_id, is_read);
CREATE INDEX idx_attendance_log_att              ON attendance_log(attendance_id);
CREATE INDEX idx_teacher_attendance_date         ON teacher_attendance(date);
CREATE INDEX idx_teacher_attendance_teacher_date ON teacher_attendance(teacher_id, date);

-- ============================================================
-- STEP 3: FUNCTIONS & TRIGGERS
-- ============================================================
CREATE OR REPLACE FUNCTION school_today()
RETURNS DATE
LANGUAGE sql SECURITY DEFINER STABLE
SET search_path = public
AS $$
  SELECT (now() AT TIME ZONE
            (SELECT timezone FROM settings LIMIT 1))::DATE;
$$;

CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN
LANGUAGE sql SECURITY DEFINER STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
      AND lower(role) = 'admin'
      AND is_active = true
  );
$$;

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

CREATE OR REPLACE FUNCTION teacher_has_class_access(
  p_class_id UUID,
  p_date     DATE DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE sql SECURITY DEFINER STABLE
SET search_path = public
AS $$
  SELECT (
    EXISTS (
      SELECT 1 FROM classes
      WHERE id = p_class_id
        AND primary_teacher_id = auth.uid()
    )
    OR
    EXISTS (
      SELECT 1 FROM substitute_assignments
      WHERE class_id   = p_class_id
        AND teacher_id = auth.uid()
        AND COALESCE(p_date, school_today()) BETWEEN start_date AND end_date
    )
  );
$$;

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

CREATE TRIGGER on_attendance_change
  AFTER INSERT OR UPDATE ON attendance
  FOR EACH ROW
  EXECUTE FUNCTION log_attendance_change();

-- ============================================================
-- STEP 4: ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================
ALTER TABLE profiles                ENABLE ROW LEVEL SECURITY;
ALTER TABLE classes                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE students                ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance              ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_log          ENABLE ROW LEVEL SECURITY;
ALTER TABLE holidays                ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings                ENABLE ROW LEVEL SECURITY;
ALTER TABLE substitute_assignments   ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications           ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_attendance      ENABLE ROW LEVEL SECURITY;

-- PROFILES
CREATE POLICY "admin_all_profiles"
  ON profiles FOR ALL
  USING  (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "teacher_read_own_profile"
  ON profiles FOR SELECT
  USING (id = auth.uid() AND is_active = true);

-- CLASSES
CREATE POLICY "admin_all_classes"
  ON classes FOR ALL
  USING  (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "teacher_read_classes"
  ON classes FOR SELECT
  USING (
    is_active_user()
    AND (
      primary_teacher_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM substitute_assignments
        WHERE class_id   = classes.id
          AND teacher_id = auth.uid()
          AND school_today() BETWEEN start_date AND end_date
      )
    )
  );

-- STUDENTS
CREATE POLICY "admin_all_students"
  ON students FOR ALL
  USING  (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "teacher_read_students"
  ON students FOR SELECT
  USING (
    is_active_user()
    AND teacher_has_class_access(class_id)
  );

-- ATTENDANCE
CREATE POLICY "admin_all_attendance"
  ON attendance FOR ALL
  USING  (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "teacher_select_attendance"
  ON attendance FOR SELECT
  USING (
    is_active_user()
    AND teacher_has_class_access(class_id, date)
  );

CREATE POLICY "teacher_insert_attendance"
  ON attendance FOR INSERT
  WITH CHECK (
    is_active_user()
    AND teacher_has_class_access(class_id, date)
    AND marked_by = auth.uid()
  );

CREATE POLICY "teacher_update_attendance"
  ON attendance FOR UPDATE
  USING (
    is_active_user()
    AND teacher_has_class_access(class_id, date)
  )
  WITH CHECK (
    is_active_user()
    AND teacher_has_class_access(class_id, date)
    AND marked_by = auth.uid()
  );

-- ATTENDANCE_LOG
CREATE POLICY "admin_select_attendance_log"
  ON attendance_log FOR SELECT
  USING (is_admin());

CREATE POLICY "teacher_select_attendance_log"
  ON attendance_log FOR SELECT
  USING (
    is_active_user()
    AND EXISTS (
      SELECT 1 FROM attendance a
      WHERE a.id = attendance_log.attendance_id
        AND teacher_has_class_access(a.class_id, a.date)
    )
  );

-- HOLIDAYS
CREATE POLICY "admin_all_holidays"
  ON holidays FOR ALL
  USING  (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "everyone_read_holidays"
  ON holidays FOR SELECT
  USING (is_active_user());

-- SETTINGS
CREATE POLICY "admin_all_settings"
  ON settings FOR ALL
  USING  (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "everyone_read_settings"
  ON settings FOR SELECT
  USING (is_active_user());

-- SUBSTITUTE_ASSIGNMENTS
CREATE POLICY "admin_all_substitutes"
  ON substitute_assignments FOR ALL
  USING  (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "teacher_read_own_substitutes"
  ON substitute_assignments FOR SELECT
  USING (
    is_active_user()
    AND teacher_id = auth.uid()
  );

-- NOTIFICATIONS
CREATE POLICY "admin_all_notifications"
  ON notifications FOR ALL
  USING  (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "user_read_own_notifications"
  ON notifications FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "user_update_own_notifications"
  ON notifications FOR UPDATE
  USING  (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- TEACHER_ATTENDANCE
CREATE POLICY "admin_all_teacher_attendance"
  ON teacher_attendance FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "teacher_read_own_attendance"
  ON teacher_attendance FOR SELECT
  USING (teacher_id = auth.uid() AND is_active_user());

-- ============================================================
-- STEP 5: SEED DATA
-- ============================================================
INSERT INTO auth.users (
  instance_id, id, aud, role, email,
  encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data,
  is_super_admin, created_at, updated_at,
  confirmation_token, recovery_token,
  email_change, email_change_token_new,
  email_change_token_current, phone_change,
  phone_change_token, reauthentication_token
)
VALUES
  -- Admin (admin@school.com / Test@123)
  (
    '00000000-0000-0000-0000-000000000000',
    'a0000000-0000-0000-0000-000000000001',
    'authenticated', 'authenticated',
    'admin@school.com',
    crypt('Test@123', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"name":"Admin User","role":"admin"}',
    false, now(), now(),
    '', '', '', '', '', '', '', ''
  ),
  -- Teacher 1 (teacher1@school.com / Test@123)
  (
    '00000000-0000-0000-0000-000000000000',
    'a0000000-0000-0000-0000-000000000002',
    'authenticated', 'authenticated',
    'teacher1@school.com',
    crypt('Test@123', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"name":"Rahul Sharma","role":"teacher"}',
    false, now(), now(),
    '', '', '', '', '', '', '', ''
  ),
  -- Teacher 2 (teacher2@school.com / Test@123)
  (
    '00000000-0000-0000-0000-000000000003',
    'authenticated', 'authenticated',
    'teacher2@school.com',
    crypt('Test@123', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"name":"Priya Patel","role":"teacher"}',
    false, now(), now(),
    '', '', '', '', '', '', '', ''
  );

INSERT INTO auth.identities (
  id, user_id, provider_id, provider,
  identity_data, last_sign_in_at,
  created_at, updated_at
)
VALUES
  (
    gen_random_uuid(),
    'a0000000-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000001',
    'email',
    jsonb_build_object(
      'sub', 'a0000000-0000-0000-0000-000000000001',
      'email', 'admin@school.com',
      'email_verified', true
    ),
    now(), now(), now()
  ),
  (
    gen_random_uuid(),
    'a0000000-0000-0000-0000-000000000002',
    'a0000000-0000-0000-0000-000000000002',
    'email',
    jsonb_build_object(
      'sub', 'a0000000-0000-0000-0000-000000000002',
      'email', 'teacher1@school.com',
      'email_verified', true
    ),
    now(), now(), now()
  ),
  (
    gen_random_uuid(),
    'a0000000-0000-0000-0000-000000000003',
    'a0000000-0000-0000-0000-000000000003',
    'email',
    jsonb_build_object(
      'sub', 'a0000000-0000-0000-0000-000000000003',
      'email', 'teacher2@school.com',
      'email_verified', true
    ),
    now(), now(), now()
  );

-- Classes
INSERT INTO classes (id, name, primary_teacher_id) VALUES
  ('c0000000-0000-0000-0000-000000000001', 'Class 1-A',
   'a0000000-0000-0000-0000-000000000002'),
  ('c0000000-0000-0000-0000-000000000002', 'Class 2-B',
   'a0000000-0000-0000-0000-000000000003');

-- Students (5 per class = 10 total)
INSERT INTO students (name, roll_no, class_id) VALUES
  ('Aarav Kumar',  '1', 'c0000000-0000-0000-0000-000000000001'),
  ('Diya Singh',   '2', 'c0000000-0000-0000-0000-000000000001'),
  ('Ishaan Gupta', '3', 'c0000000-0000-0000-0000-000000000001'),
  ('Meera Reddy',  '4', 'c0000000-0000-0000-0000-000000000001'),
  ('Rohan Verma',  '5', 'c0000000-0000-0000-0000-000000000001'),
  ('Ananya Joshi', '1', 'c0000000-0000-0000-0000-000000000002'),
  ('Kabir Mehta',  '2', 'c0000000-0000-0000-0000-000000000002'),
  ('Priya Nair',   '3', 'c0000000-0000-0000-0000-000000000002'),
  ('Arjun Iyer',   '4', 'c0000000-0000-0000-0000-000000000002'),
  ('Saanvi Desai', '5', 'c0000000-0000-0000-0000-000000000002');

-- Holiday
INSERT INTO holidays (name, start_date, end_date) VALUES
  ('Republic Day', '2027-01-26', '2027-01-26');

-- Settings
INSERT INTO settings (
  morning_cutoff, afternoon_cutoff,
  weekly_off_days, low_attendance_threshold, timezone
) VALUES (
  '10:30:00', '14:30:00',
  '{0}',
  75.00,
  'Asia/Kolkata'
);

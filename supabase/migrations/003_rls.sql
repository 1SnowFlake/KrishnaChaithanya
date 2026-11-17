-- ============================================================
-- School Attendance App – Row Level Security Policies
-- Run AFTER 002_functions.sql
--
-- STRATEGY:
-- • Every table has RLS enabled.
-- • Admin gets a single FOR ALL policy (read + write everything).
-- • Teachers get granular policies per operation.
-- • Security-definer helpers (is_admin, is_active_user, etc.)
--   avoid the "policy reads the same table it protects" recursion.
-- ============================================================

-- ── Enable RLS on every table ──────────────────────────────
ALTER TABLE profiles              ENABLE ROW LEVEL SECURITY;
ALTER TABLE classes               ENABLE ROW LEVEL SECURITY;
ALTER TABLE students              ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance            ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_log        ENABLE ROW LEVEL SECURITY;
ALTER TABLE holidays              ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings              ENABLE ROW LEVEL SECURITY;
ALTER TABLE substitute_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications         ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_attendance    ENABLE ROW LEVEL SECURITY;


-- ============================================================
-- PROFILES
-- ============================================================

-- Admin: full access to all profiles
CREATE POLICY "admin_all_profiles"
  ON profiles FOR ALL
  USING  (is_admin())
  WITH CHECK (is_admin());

-- Teacher: can only read their OWN profile row
CREATE POLICY "teacher_read_own_profile"
  ON profiles FOR SELECT
  USING (id = auth.uid() AND is_active = true);


-- ============================================================
-- CLASSES
-- ============================================================

-- Admin: full CRUD
CREATE POLICY "admin_all_classes"
  ON classes FOR ALL
  USING  (is_admin())
  WITH CHECK (is_admin());

-- Teacher: can read classes where they are primary OR active substitute
CREATE POLICY "teacher_read_assigned_classes"
  ON classes FOR SELECT
  USING (
    is_active_user()
    AND (
      primary_teacher_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM substitute_assignments sa
        WHERE sa.class_id   = classes.id
          AND sa.teacher_id = auth.uid()
          AND school_today() BETWEEN sa.start_date AND sa.end_date
      )
    )
  );


-- ============================================================
-- STUDENTS
-- ============================================================

-- Admin: full CRUD
CREATE POLICY "admin_all_students"
  ON students FOR ALL
  USING  (is_admin())
  WITH CHECK (is_admin());

-- Teacher: read students in classes they can access
CREATE POLICY "teacher_read_class_students"
  ON students FOR SELECT
  USING (
    is_active_user()
    AND teacher_has_class_access(class_id)
  );


-- ============================================================
-- ATTENDANCE
-- This is the most complex table for RLS.
-- ============================================================

-- Admin: full access to any record, any date
CREATE POLICY "admin_all_attendance"
  ON attendance FOR ALL
  USING  (is_admin())
  WITH CHECK (is_admin());

-- Teacher: can READ attendance for their classes (any date)
CREATE POLICY "teacher_read_attendance"
  ON attendance FOR SELECT
  USING (
    is_active_user()
    AND teacher_has_class_access(class_id)
  );

-- Teacher: can INSERT attendance for their assigned classes for today
CREATE POLICY "teacher_insert_attendance"
  ON attendance FOR INSERT
  WITH CHECK (
    is_active_user()
    AND teacher_has_class_access(class_id, date)
    AND date = school_today()
    AND marked_by = auth.uid()
  );

-- Teacher: can UPDATE attendance for their assigned classes for today
CREATE POLICY "teacher_update_attendance"
  ON attendance FOR UPDATE
  USING (
    is_active_user()
    AND teacher_has_class_access(class_id, date)
    AND date = school_today()
  )
  WITH CHECK (
    marked_by = auth.uid()
    AND date = school_today()
  );


-- ============================================================
-- ATTENDANCE_LOG
-- Insert happens via a SECURITY DEFINER trigger (bypasses RLS).
-- ============================================================

-- Admin: read everything
CREATE POLICY "admin_read_all_logs"
  ON attendance_log FOR SELECT
  USING (is_admin());

-- Teacher: read audit entries for attendance they submitted
CREATE POLICY "teacher_read_own_logs"
  ON attendance_log FOR SELECT
  USING (
    is_active_user()
    AND EXISTS (
      SELECT 1 FROM attendance a
      WHERE a.id = attendance_log.attendance_id
        AND teacher_has_class_access(a.class_id)
    )
  );


-- ============================================================
-- HOLIDAYS  (everyone reads, only admin writes)
-- ============================================================

CREATE POLICY "admin_all_holidays"
  ON holidays FOR ALL
  USING  (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "active_users_read_holidays"
  ON holidays FOR SELECT
  USING (is_active_user());


-- ============================================================
-- SETTINGS  (everyone reads, only admin writes)
-- ============================================================

CREATE POLICY "admin_all_settings"
  ON settings FOR ALL
  USING  (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "active_users_read_settings"
  ON settings FOR SELECT
  USING (is_active_user());


-- ============================================================
-- SUBSTITUTE_ASSIGNMENTS
-- ============================================================

CREATE POLICY "admin_all_substitutes"
  ON substitute_assignments FOR ALL
  USING  (is_admin())
  WITH CHECK (is_admin());

-- Teacher: read only their own substitute assignments
CREATE POLICY "teacher_read_own_substitutes"
  ON substitute_assignments FOR SELECT
  USING (
    is_active_user()
    AND teacher_id = auth.uid()
  );


-- ============================================================
-- NOTIFICATIONS
-- ============================================================

-- Admin: full access (can create and manage all notifications)
CREATE POLICY "admin_all_notifications"
  ON notifications FOR ALL
  USING  (is_admin())
  WITH CHECK (is_admin());

-- Users: read their own notifications
CREATE POLICY "user_read_own_notifications"
  ON notifications FOR SELECT
  USING (user_id = auth.uid());

-- Users: mark their own notifications as read
CREATE POLICY "user_update_own_notifications"
  ON notifications FOR UPDATE
  USING  (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());


-- ============================================================
-- TEACHER_ATTENDANCE
-- ============================================================

-- Admin: full access (create, read, update, delete)
CREATE POLICY "admin_all_teacher_attendance"
  ON teacher_attendance FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- Teachers: read their own attendance records
CREATE POLICY "teacher_read_own_attendance"
  ON teacher_attendance FOR SELECT
  USING (teacher_id = auth.uid() AND is_active_user());



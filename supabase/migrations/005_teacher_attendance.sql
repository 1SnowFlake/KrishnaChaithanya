-- ============================================================
-- School Attendance App – Teacher Attendance Schema & Policies
-- ============================================================

CREATE TABLE IF NOT EXISTS teacher_attendance (
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

ALTER TABLE teacher_attendance ENABLE ROW LEVEL SECURITY;

-- Admins can read, insert, update, and delete teacher attendance
CREATE POLICY "admin_all_teacher_attendance"
  ON teacher_attendance FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- Teachers can view their own attendance records
CREATE POLICY "teacher_read_own_attendance"
  ON teacher_attendance FOR SELECT
  USING (teacher_id = auth.uid() AND is_active_user());

CREATE INDEX IF NOT EXISTS idx_teacher_attendance_date ON teacher_attendance(date);
CREATE INDEX IF NOT EXISTS idx_teacher_attendance_teacher_date ON teacher_attendance(teacher_id, date);

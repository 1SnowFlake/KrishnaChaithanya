-- ============================================================
-- School Attendance App – Full Database Schema
-- Run this FIRST in your Supabase SQL Editor.
-- ============================================================

-- Enable pgcrypto for password hashing (usually already enabled)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- 1. PROFILES
-- Links to auth.users via id. Stores role and active status.
-- ============================================================
CREATE TABLE profiles (
  id         UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name       TEXT        NOT NULL,
  email      TEXT        NOT NULL UNIQUE,
  role       TEXT        NOT NULL DEFAULT 'teacher'
                          CHECK (role IN ('admin', 'teacher')),
  is_active  BOOLEAN     NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE profiles IS
  'One row per user. id = auth.users.id. Role decides routing.';

-- ============================================================
-- 2. CLASSES
-- Each class has exactly one primary teacher.
-- ============================================================
CREATE TABLE classes (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name               TEXT NOT NULL UNIQUE,
  primary_teacher_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- 3. STUDENTS
-- Roll number is unique within a class.
-- ============================================================
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

-- ============================================================
-- 4. ATTENDANCE
-- One row per student per session (morning / afternoon) per day.
-- The UNIQUE constraint also prevents duplicate submissions
-- (important for idempotent offline retries with client UUIDs).
-- ============================================================
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

-- ============================================================
-- 5. ATTENDANCE_LOG (audit trail)
-- Filled automatically by a trigger – never written by the app.
-- ============================================================
CREATE TABLE attendance_log (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  attendance_id UUID NOT NULL REFERENCES attendance(id) ON DELETE CASCADE,
  old_status    TEXT,                                     -- NULL on first insert
  new_status    TEXT NOT NULL CHECK (new_status IN ('present', 'absent')),
  changed_by    UUID NOT NULL REFERENCES profiles(id),
  changed_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- 6. HOLIDAYS
-- A single day has start_date = end_date.
-- ============================================================
CREATE TABLE holidays (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name       TEXT NOT NULL,
  start_date DATE NOT NULL,
  end_date   DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (end_date >= start_date)
);

-- ============================================================
-- 7. SETTINGS (single-row table)
-- The unique index on (true) ensures only one row can exist.
-- ============================================================
CREATE TABLE settings (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  morning_cutoff           TIME         NOT NULL DEFAULT '10:30:00',
  afternoon_cutoff         TIME         NOT NULL DEFAULT '14:30:00',
  weekly_off_days          INTEGER[]    NOT NULL DEFAULT '{0}',
  -- ^ 0 = Sunday, 1 = Monday … 6 = Saturday (PostgreSQL DOW convention)
  low_attendance_threshold NUMERIC(5,2) NOT NULL DEFAULT 75.00,
  timezone                 TEXT         NOT NULL DEFAULT 'Asia/Kolkata',
  allow_holiday_attendance BOOLEAN      NOT NULL DEFAULT true,
  allow_past_cutoff        BOOLEAN      NOT NULL DEFAULT true,
  updated_at               TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- Only one row ever:
CREATE UNIQUE INDEX settings_singleton ON settings ((true));

-- ============================================================
-- 8. SUBSTITUTE_ASSIGNMENTS
-- Gives a teacher temporary access to a class for a date range.
-- ============================================================
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

-- ============================================================
-- 9. NOTIFICATIONS
-- In-app notifications (e.g. "missing attendance" alerts).
-- user_id = NULL means "broadcast to all admins."
-- ============================================================
CREATE TABLE notifications (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID REFERENCES profiles(id) ON DELETE CASCADE,
  type       TEXT    NOT NULL,          -- 'missing_attendance', 'general', …
  message    TEXT    NOT NULL,
  is_read    BOOLEAN NOT NULL DEFAULT false,
  metadata   JSONB,                     -- optional extra payload
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- INDEXES – speed up the queries we know we'll run often
-- ============================================================
CREATE INDEX idx_attendance_date          ON attendance(date);
CREATE INDEX idx_attendance_class_date    ON attendance(class_id, date);
CREATE INDEX idx_attendance_student_date  ON attendance(student_id, date);
CREATE INDEX idx_students_class           ON students(class_id);
CREATE INDEX idx_classes_teacher          ON classes(primary_teacher_id);
CREATE INDEX idx_sub_assign_dates         ON substitute_assignments(start_date, end_date);
CREATE INDEX idx_sub_assign_teacher       ON substitute_assignments(teacher_id);
CREATE INDEX idx_holidays_dates           ON holidays(start_date, end_date);
CREATE INDEX idx_notifications_user_read  ON notifications(user_id, is_read);
CREATE INDEX idx_attendance_log_att       ON attendance_log(attendance_id);


-- ============================================================
-- School Attendance App – Seed Data
-- Run AFTER 003_rls.sql
--
-- Creates: 1 admin, 2 teachers, 2 classes, 10 students,
--          1 holiday, and the default settings row.
--
-- All seed users have password:  Test@123
-- ============================================================

-- ── Fixed UUIDs so foreign keys are predictable ─────────────
-- Admin:     a0000000-0000-0000-0000-000000000001
-- Teacher 1: a0000000-0000-0000-0000-000000000002
-- Teacher 2: a0000000-0000-0000-0000-000000000003
-- Class 1-A: c0000000-0000-0000-0000-000000000001
-- Class 2-B: c0000000-0000-0000-0000-000000000002

-- ============================================================
-- 1. Create auth users
--    The trigger on auth.users (handle_new_user) will auto-
--    create a row in profiles for each user.
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
  -- Admin
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
  -- Teacher 1
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
  -- Teacher 2
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

-- Identity rows (required for email/password login to work)
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

-- ============================================================
-- 2. Classes  (the profiles already exist thanks to the trigger)
-- ============================================================
INSERT INTO classes (id, name, primary_teacher_id) VALUES
  ('c0000000-0000-0000-0000-000000000001', 'Class 1-A',
   'a0000000-0000-0000-0000-000000000002'),
  ('c0000000-0000-0000-0000-000000000002', 'Class 2-B',
   'a0000000-0000-0000-0000-000000000003');

-- ============================================================
-- 3. Students  (5 per class = 10 total)
-- ============================================================
INSERT INTO students (name, roll_no, class_id) VALUES
  -- Class 1-A
  ('Aarav Kumar',    '1', 'c0000000-0000-0000-0000-000000000001'),
  ('Diya Singh',     '2', 'c0000000-0000-0000-0000-000000000001'),
  ('Ishaan Gupta',   '3', 'c0000000-0000-0000-0000-000000000001'),
  ('Meera Reddy',    '4', 'c0000000-0000-0000-0000-000000000001'),
  ('Rohan Verma',    '5', 'c0000000-0000-0000-0000-000000000001'),
  -- Class 2-B
  ('Ananya Joshi',   '1', 'c0000000-0000-0000-0000-000000000002'),
  ('Kabir Mehta',    '2', 'c0000000-0000-0000-0000-000000000002'),
  ('Priya Nair',     '3', 'c0000000-0000-0000-0000-000000000002'),
  ('Arjun Iyer',     '4', 'c0000000-0000-0000-0000-000000000002'),
  ('Saanvi Desai',   '5', 'c0000000-0000-0000-0000-000000000002');

-- ============================================================
-- 4. One holiday (Republic Day 2027)
-- ============================================================
INSERT INTO holidays (name, start_date, end_date) VALUES
  ('Republic Day', '2027-01-26', '2027-01-26');

-- ============================================================
-- 5. Default settings row
-- ============================================================
INSERT INTO settings (
  morning_cutoff, afternoon_cutoff,
  weekly_off_days, low_attendance_threshold, timezone
) VALUES (
  '10:30:00', '14:30:00',
  '{0}',       -- Sunday off
  75.00,
  'Asia/Kolkata'
);


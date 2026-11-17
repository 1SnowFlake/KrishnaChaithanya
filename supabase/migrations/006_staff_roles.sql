-- ============================================================
-- School Attendance App – Expanded Staff Roles
-- Run this to allow any staff role in the profiles table
-- (e.g., Assistant Teacher, Warden, Cook, Aya, Watchman,
--  Psychologist, Dance Master, Doctor, Psychotherapist, etc.)
-- ============================================================

-- Drop the restrictive check constraint on profiles.role
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;

-- Ensure default is 'teacher'
ALTER TABLE profiles ALTER COLUMN role SET DEFAULT 'teacher';

-- ============================================================
-- School Attendance App – Fix "Database error saving new user"
--
-- WHY THIS FILE EXISTS
--   Creating a staff account failed with a GoTrue 500
--   "Database error saving new user". The create-teacher Edge
--   Function is not deployed, so the app falls back to a direct
--   signUp() that passes the app's display role ("Teacher",
--   "Warden", "Admin", …) in user metadata. The handle_new_user
--   trigger copies that value into profiles.role, which still
--   carried the original CHECK (role IN ('admin','teacher')).
--   The violation aborted the whole signup transaction.
--
--   This migration is idempotent: running it on a database that
--   already applied 006 is a no-op apart from the function
--   replacement below, which is the part 006 was missing.
-- ============================================================

-- 1. Allow any staff role string (Teacher, Warden, Cook, Aya, …).
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;

-- 2. Keep the default for rows created without an explicit role.
ALTER TABLE profiles ALTER COLUMN role SET DEFAULT 'teacher';

-- 3. is_admin() compared role case-sensitively. The app writes
--    "Admin", so an admin promoted through the UI would have been
--    treated as a non-admin by every RLS policy and by the
--    create-teacher Edge Function. Compare case-insensitively.
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

-- 4. Verify: should return no rows for profiles_role_check.
--    SELECT conname, pg_get_constraintdef(oid)
--    FROM pg_constraint
--    WHERE conrelid = 'profiles'::regclass;

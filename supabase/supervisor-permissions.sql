-- ============================================================================
-- Supervisor Management Permissions
-- ============================================================================
-- This migration adds INSERT, UPDATE, DELETE policies for supervisors to manage
-- branches and user profiles
-- ============================================================================

-- Branches policies for supervisors
DROP POLICY IF EXISTS "branches_insert_supervisor" ON branches;
CREATE POLICY "branches_insert_supervisor" ON branches
FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);

DROP POLICY IF EXISTS "branches_update_supervisor" ON branches;
CREATE POLICY "branches_update_supervisor" ON branches
FOR UPDATE USING (
  EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
) WITH CHECK (
  EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);

DROP POLICY IF EXISTS "branches_delete_supervisor" ON branches;
CREATE POLICY "branches_delete_supervisor" ON branches
FOR DELETE USING (
  EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);

-- User profiles policies for supervisors
DROP POLICY IF EXISTS "user_profiles_insert_supervisor" ON user_profiles;
CREATE POLICY "user_profiles_insert_supervisor" ON user_profiles
FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);

DROP POLICY IF EXISTS "user_profiles_update_supervisor" ON user_profiles;
CREATE POLICY "user_profiles_update_supervisor" ON user_profiles
FOR UPDATE USING (
  EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
) WITH CHECK (
  EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);

DROP POLICY IF EXISTS "user_profiles_delete_supervisor" ON user_profiles;
CREATE POLICY "user_profiles_delete_supervisor" ON user_profiles
FOR DELETE USING (
  EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);

-- Allow supervisors to view all user profiles
DROP POLICY IF EXISTS "user_profiles_select_supervisor" ON user_profiles;
CREATE POLICY "user_profiles_select_supervisor" ON user_profiles
FOR SELECT USING (
  EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);

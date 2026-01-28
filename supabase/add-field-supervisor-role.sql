-- ============================================================================
-- Add field_supervisor Role to Database
-- ============================================================================
-- This migration updates the user_profiles table to allow the field_supervisor
-- role in addition to branch_user, supervisor, and admin
-- ============================================================================

-- First, add field_supervisor to the app_role enum
ALTER TYPE app_role ADD VALUE 'field_supervisor';

-- Drop the existing role constraint
ALTER TABLE user_profiles
DROP CONSTRAINT IF EXISTS user_profiles_role_check;

-- Drop the branch_required_for_branch_user constraint if it exists
ALTER TABLE user_profiles
DROP CONSTRAINT IF EXISTS branch_required_for_branch_user;

-- Add new constraint with field_supervisor included
-- Note: branch_user requires branch_id, field_supervisor and supervisor/admin do not
ALTER TABLE user_profiles
ADD CONSTRAINT user_profiles_role_check 
CHECK (
  (role = 'branch_user' AND branch_id IS NOT NULL) OR
  (role = 'field_supervisor' AND branch_id IS NULL) OR
  (role = 'supervisor' AND branch_id IS NULL) OR
  (role = 'admin' AND branch_id IS NULL)
);

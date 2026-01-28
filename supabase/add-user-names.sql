-- ============================================================================
-- Add Name Fields to User Profiles
-- ============================================================================
-- This migration adds first_name and last_name columns to user_profiles table
-- ============================================================================

-- Add name columns to user_profiles
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS first_name TEXT,
ADD COLUMN IF NOT EXISTS last_name TEXT;

-- Create index for searching by name
CREATE INDEX IF NOT EXISTS idx_user_profiles_name ON user_profiles(first_name, last_name);

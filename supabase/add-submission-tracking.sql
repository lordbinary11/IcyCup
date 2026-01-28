-- ============================================================================
-- Add Submission Tracking to Daily Sheets
-- ============================================================================
-- This migration adds fields to track who submitted/locked each sheet
-- and their role at the time of submission
-- ============================================================================

-- Add columns to track submission
ALTER TABLE daily_sheets
ADD COLUMN IF NOT EXISTS submitted_by uuid REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS submitted_at timestamptz,
ADD COLUMN IF NOT EXISTS submitted_by_role app_role,
ADD COLUMN IF NOT EXISTS submitted_by_name text;

-- Create an index for querying by submitter
CREATE INDEX IF NOT EXISTS idx_daily_sheets_submitted_by ON daily_sheets(submitted_by);

-- Update the finalize_daily_sheet function to capture submission info
-- Note: This function marks the sheet as submitted but does NOT prevent future edits
-- Edit permissions are controlled by time-based rules in the application:
-- - Branch users can edit same-day sheets until 11:59 PM
-- - Supervisors can edit sheets from 12:00 AM onwards (next day)
-- - Field supervisors follow same rules as branch users
CREATE OR REPLACE FUNCTION finalize_daily_sheet(p_sheet_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  prof user_profiles;
  sheet daily_sheets;
BEGIN
  -- Get current user profile
  SELECT * INTO prof FROM user_profiles WHERE user_id = auth.uid();
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User profile not found';
  END IF;

  -- Get the sheet
  SELECT * INTO sheet FROM daily_sheets WHERE id = p_sheet_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Sheet not found';
  END IF;

  -- Record submission info (but don't lock - locking is handled by time-based rules)
  -- The "locked" field is kept for backward compatibility but edit access is controlled
  -- by the canEditSheet function based on role and time
  UPDATE daily_sheets
  SET 
    locked = true,
    submitted_by = auth.uid(),
    submitted_at = now(),
    submitted_by_role = prof.role,
    submitted_by_name = COALESCE(prof.first_name || ' ' || prof.last_name, 'Unknown User')
  WHERE id = p_sheet_id;
END;
$$;

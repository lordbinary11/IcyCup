-- ============================================================================
-- Test Yoghurt Headers Access
-- ============================================================================
-- Run this to check if RLS policies are working correctly
-- ============================================================================

-- Check current user and role
SELECT 
  auth.uid() as current_user_id,
  up.role as current_role,
  up.first_name,
  up.last_name,
  up.branch_id
FROM user_profiles up
WHERE up.user_id = auth.uid();

-- Check if current_profile view works
SELECT * FROM current_profile;

-- Check existing yoghurt headers
SELECT 
  yh.*,
  ds.branch_id,
  b.name as branch_name
FROM yoghurt_headers yh
JOIN daily_sheets ds ON ds.id = yh.sheet_id
JOIN branches b ON b.id = ds.branch_id
LIMIT 5;

-- Check RLS policies on yoghurt_headers
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'yoghurt_headers'
ORDER BY policyname;

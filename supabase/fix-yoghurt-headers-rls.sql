-- ============================================================================
-- Fix Yoghurt Headers RLS Policies
-- ============================================================================
-- Add field_supervisor and admin roles to yoghurt_headers policies
-- ============================================================================

-- Drop existing policies
DROP POLICY IF EXISTS "yh_select" ON yoghurt_headers;
DROP POLICY IF EXISTS "yh_insert" ON yoghurt_headers;
DROP POLICY IF EXISTS "yh_update" ON yoghurt_headers;
DROP POLICY IF EXISTS "yoghurt_headers_update" ON yoghurt_headers;

-- SELECT: All roles can view yoghurt headers for sheets they have access to
CREATE POLICY "yoghurt_headers_select" ON yoghurt_headers
FOR SELECT USING (
  -- Supervisors, field supervisors, and admins can see all sheets
  EXISTS (SELECT 1 FROM current_profile WHERE role IN ('supervisor', 'field_supervisor', 'admin'))
  OR
  -- Branch users can see their own branch's sheets
  EXISTS (
    SELECT 1 FROM daily_sheets ds
    JOIN current_profile cp ON cp.role = 'branch_user' AND cp.branch_id = ds.branch_id
    WHERE ds.id = yoghurt_headers.sheet_id
  )
);

-- INSERT: All roles can create yoghurt headers for sheets they can access
CREATE POLICY "yoghurt_headers_insert" ON yoghurt_headers
FOR INSERT WITH CHECK (
  -- Supervisors, field supervisors, and admins can insert for all sheets
  EXISTS (SELECT 1 FROM current_profile WHERE role IN ('supervisor', 'field_supervisor', 'admin'))
  OR
  -- Branch users can add to their own branch's sheets
  EXISTS (
    SELECT 1 FROM daily_sheets ds
    JOIN current_profile cp ON cp.role = 'branch_user' AND cp.branch_id = ds.branch_id
    WHERE ds.id = yoghurt_headers.sheet_id
  )
);

-- UPDATE: All roles can update yoghurt headers for sheets they can access
CREATE POLICY "yoghurt_headers_update" ON yoghurt_headers
FOR UPDATE USING (
  -- Supervisors, field supervisors, and admins can update all sheets
  EXISTS (SELECT 1 FROM current_profile WHERE role IN ('supervisor', 'field_supervisor', 'admin'))
  OR
  -- Branch users can update their own branch's sheets
  EXISTS (
    SELECT 1 FROM daily_sheets ds
    JOIN current_profile cp ON cp.role = 'branch_user' AND cp.branch_id = ds.branch_id
    WHERE ds.id = yoghurt_headers.sheet_id
  )
);

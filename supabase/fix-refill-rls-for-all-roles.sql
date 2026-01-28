-- ============================================================================
-- Fix Yoghurt Refill RLS for All Roles
-- ============================================================================
-- This ensures that if a user can see a sheet, they can see its refill lines
-- ============================================================================

-- Drop all existing refill line policies
DROP POLICY IF EXISTS "yr_select" ON yoghurt_refill_lines;
DROP POLICY IF EXISTS "yr_insert" ON yoghurt_refill_lines;
DROP POLICY IF EXISTS "yr_update" ON yoghurt_refill_lines;
DROP POLICY IF EXISTS "yr_delete" ON yoghurt_refill_lines;
DROP POLICY IF EXISTS "yoghurt_refill_select_field_supervisor" ON yoghurt_refill_lines;
DROP POLICY IF EXISTS "yoghurt_refill_write_field_supervisor" ON yoghurt_refill_lines;
DROP POLICY IF EXISTS "yoghurt_refill_lines_update" ON yoghurt_refill_lines;

-- Create new comprehensive policies that work for all roles
-- SELECT: If you can see the sheet, you can see its refill lines
CREATE POLICY "yoghurt_refill_select_all" ON yoghurt_refill_lines
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM daily_sheets ds
    WHERE ds.id = yoghurt_refill_lines.sheet_id
    AND (
      -- Branch users can see their own branch's sheets
      (ds.branch_id = (SELECT branch_id FROM current_profile WHERE role = 'branch_user'))
      -- Supervisors and field supervisors can see all sheets
      OR EXISTS (SELECT 1 FROM current_profile WHERE role IN ('supervisor', 'field_supervisor', 'admin'))
    )
  )
);

-- INSERT: Can insert if you can access the sheet
CREATE POLICY "yoghurt_refill_insert_all" ON yoghurt_refill_lines
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM daily_sheets ds
    WHERE ds.id = yoghurt_refill_lines.sheet_id
    AND (
      (ds.branch_id = (SELECT branch_id FROM current_profile WHERE role = 'branch_user'))
      OR EXISTS (SELECT 1 FROM current_profile WHERE role IN ('supervisor', 'field_supervisor', 'admin'))
    )
  )
);

-- UPDATE: Can update if sheet is not locked and you have access
CREATE POLICY "yoghurt_refill_update_all" ON yoghurt_refill_lines
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM daily_sheets ds
    WHERE ds.id = yoghurt_refill_lines.sheet_id
    AND NOT ds.locked
    AND (
      (ds.branch_id = (SELECT branch_id FROM current_profile WHERE role = 'branch_user'))
      OR EXISTS (SELECT 1 FROM current_profile WHERE role IN ('supervisor', 'field_supervisor', 'admin'))
    )
  )
);

-- DELETE: Can delete if sheet is not locked and you have access
CREATE POLICY "yoghurt_refill_delete_all" ON yoghurt_refill_lines
FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM daily_sheets ds
    WHERE ds.id = yoghurt_refill_lines.sheet_id
    AND NOT ds.locked
    AND (
      (ds.branch_id = (SELECT branch_id FROM current_profile WHERE role = 'branch_user'))
      OR EXISTS (SELECT 1 FROM current_profile WHERE role IN ('supervisor', 'field_supervisor', 'admin'))
    )
  )
);

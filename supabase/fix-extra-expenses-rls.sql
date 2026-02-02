-- ============================================================================
-- Fix Extra Expenses RLS Policies
-- ============================================================================
-- Add field_supervisor and admin roles to extra_expenses policies
-- ============================================================================

-- Drop existing policies
DROP POLICY IF EXISTS "exp_select" ON extra_expenses;
DROP POLICY IF EXISTS "exp_insert" ON extra_expenses;
DROP POLICY IF EXISTS "exp_delete" ON extra_expenses;
DROP POLICY IF EXISTS "extra_expenses_update" ON extra_expenses;

-- SELECT: All roles can view extra expenses for sheets they have access to
CREATE POLICY "extra_expenses_select" ON extra_expenses
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM daily_sheets ds
    WHERE ds.id = extra_expenses.sheet_id
    AND (
      -- Branch users can see their own branch's sheets
      (ds.branch_id = (SELECT branch_id FROM current_profile WHERE role = 'branch_user'))
      -- Supervisors, field supervisors, and admins can see all sheets
      OR EXISTS (SELECT 1 FROM current_profile WHERE role IN ('supervisor', 'field_supervisor', 'admin'))
    )
  )
);

-- INSERT: All roles can add extra expenses to sheets they can access
CREATE POLICY "extra_expenses_insert" ON extra_expenses
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM daily_sheets ds
    WHERE ds.id = extra_expenses.sheet_id
    AND (
      -- Branch users can add to their own branch's sheets
      (ds.branch_id = (SELECT branch_id FROM current_profile WHERE role = 'branch_user'))
      -- Supervisors, field supervisors, and admins can add to all sheets
      OR EXISTS (SELECT 1 FROM current_profile WHERE role IN ('supervisor', 'field_supervisor', 'admin'))
    )
  )
);

-- UPDATE: All roles can update extra expenses for sheets they can access
CREATE POLICY "extra_expenses_update" ON extra_expenses
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM daily_sheets ds
    WHERE ds.id = extra_expenses.sheet_id
    AND (
      -- Branch users can update their own branch's sheets
      (ds.branch_id = (SELECT branch_id FROM current_profile WHERE role = 'branch_user'))
      -- Supervisors, field supervisors, and admins can update all sheets
      OR EXISTS (SELECT 1 FROM current_profile WHERE role IN ('supervisor', 'field_supervisor', 'admin'))
    )
  )
);

-- DELETE: All roles can delete extra expenses from sheets they can access
CREATE POLICY "extra_expenses_delete" ON extra_expenses
FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM daily_sheets ds
    WHERE ds.id = extra_expenses.sheet_id
    AND (
      -- Branch users can delete from their own branch's sheets
      (ds.branch_id = (SELECT branch_id FROM current_profile WHERE role = 'branch_user'))
      -- Supervisors, field supervisors, and admins can delete from all sheets
      OR EXISTS (SELECT 1 FROM current_profile WHERE role IN ('supervisor', 'field_supervisor', 'admin'))
    )
  )
);

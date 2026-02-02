-- ============================================================================
-- Fix Staff Attendance RLS Policies
-- ============================================================================
-- Add field_supervisor and admin roles to staff_attendance policies
-- ============================================================================

-- Drop existing policies
DROP POLICY IF EXISTS "staff_select" ON staff_attendance;
DROP POLICY IF EXISTS "staff_insert" ON staff_attendance;
DROP POLICY IF EXISTS "staff_delete" ON staff_attendance;
DROP POLICY IF EXISTS "staff_attendance_update" ON staff_attendance;

-- SELECT: All roles can view staff attendance for sheets they have access to
CREATE POLICY "staff_attendance_select" ON staff_attendance
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM daily_sheets ds
    WHERE ds.id = staff_attendance.sheet_id
    AND (
      -- Branch users can see their own branch's sheets
      (ds.branch_id = (SELECT branch_id FROM current_profile WHERE role = 'branch_user'))
      -- Supervisors, field supervisors, and admins can see all sheets
      OR EXISTS (SELECT 1 FROM current_profile WHERE role IN ('supervisor', 'field_supervisor', 'admin'))
    )
  )
);

-- INSERT: All roles can add staff attendance to sheets they can access
CREATE POLICY "staff_attendance_insert" ON staff_attendance
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM daily_sheets ds
    WHERE ds.id = staff_attendance.sheet_id
    AND (
      -- Branch users can add to their own branch's sheets
      (ds.branch_id = (SELECT branch_id FROM current_profile WHERE role = 'branch_user'))
      -- Supervisors, field supervisors, and admins can add to all sheets
      OR EXISTS (SELECT 1 FROM current_profile WHERE role IN ('supervisor', 'field_supervisor', 'admin'))
    )
  )
);

-- UPDATE: All roles can update staff attendance for sheets they can access
CREATE POLICY "staff_attendance_update" ON staff_attendance
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM daily_sheets ds
    WHERE ds.id = staff_attendance.sheet_id
    AND (
      -- Branch users can update their own branch's sheets
      (ds.branch_id = (SELECT branch_id FROM current_profile WHERE role = 'branch_user'))
      -- Supervisors, field supervisors, and admins can update all sheets
      OR EXISTS (SELECT 1 FROM current_profile WHERE role IN ('supervisor', 'field_supervisor', 'admin'))
    )
  )
);

-- DELETE: All roles can delete staff attendance from sheets they can access
CREATE POLICY "staff_attendance_delete" ON staff_attendance
FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM daily_sheets ds
    WHERE ds.id = staff_attendance.sheet_id
    AND (
      -- Branch users can delete from their own branch's sheets
      (ds.branch_id = (SELECT branch_id FROM current_profile WHERE role = 'branch_user'))
      -- Supervisors, field supervisors, and admins can delete from all sheets
      OR EXISTS (SELECT 1 FROM current_profile WHERE role IN ('supervisor', 'field_supervisor', 'admin'))
    )
  )
);

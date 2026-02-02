-- ============================================================================
-- Add Field Supervisor Policies for Yoghurt Headers
-- ============================================================================
-- This was missing from the original field_supervisor RLS policies
-- ============================================================================

-- Yoghurt headers - SELECT policy for field supervisors
CREATE POLICY "yoghurt_headers_select_field_supervisor" ON yoghurt_headers
FOR SELECT USING (EXISTS (SELECT 1 FROM current_profile WHERE role = 'field_supervisor'));

-- Yoghurt headers - WRITE policy for field supervisors (INSERT, UPDATE, DELETE)
CREATE POLICY "yoghurt_headers_write_field_supervisor" ON yoghurt_headers
FOR ALL USING (EXISTS (SELECT 1 FROM current_profile WHERE role = 'field_supervisor'));

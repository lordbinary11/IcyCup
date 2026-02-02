-- ============================================================================
-- Add Supervisor Policies for Yoghurt Headers
-- ============================================================================
-- Supervisors need access to yoghurt headers to view sheets
-- ============================================================================

-- Yoghurt headers - SELECT policy for supervisors
CREATE POLICY "yoghurt_headers_select_supervisor" ON yoghurt_headers
FOR SELECT USING (EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor'));

-- Yoghurt headers - WRITE policy for supervisors (INSERT, UPDATE, DELETE)
CREATE POLICY "yoghurt_headers_write_supervisor" ON yoghurt_headers
FOR ALL USING (EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor'));

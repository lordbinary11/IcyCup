-- ============================================================================
-- Add Field Supervisor RLS Policies
-- ============================================================================
-- This migration adds Row Level Security policies for field_supervisor role
-- to allow them to read, insert, and update sheets for any branch
-- ============================================================================

-- Add SELECT policy for field supervisors (can read all sheets)
CREATE POLICY "sheets_select_field_supervisor" ON daily_sheets
FOR SELECT USING (EXISTS (SELECT 1 FROM current_profile WHERE role = 'field_supervisor'));

-- Add INSERT policy for field supervisors (can create sheets for any branch)
CREATE POLICY "sheets_insert_field_supervisor" ON daily_sheets
FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM current_profile WHERE role = 'field_supervisor'));

-- Add UPDATE policy for field supervisors (can edit sheets on same day)
CREATE POLICY "sheets_update_field_supervisor" ON daily_sheets
FOR UPDATE USING (
  EXISTS (SELECT 1 FROM current_profile WHERE role = 'field_supervisor')
  AND (
    -- Can edit same-day sheets (until midnight)
    (daily_sheets.sheet_date = current_date AND NOT daily_sheets.locked)
    -- Or can edit past sheets if they have supervisor permissions
    OR (daily_sheets.sheet_date < current_date)
  )
);

-- Also need to add policies for all the line tables that field supervisors will access

-- Pastry lines
CREATE POLICY "pastry_select_field_supervisor" ON pastry_lines
FOR SELECT USING (EXISTS (SELECT 1 FROM current_profile WHERE role = 'field_supervisor'));

CREATE POLICY "pastry_write_field_supervisor" ON pastry_lines
FOR ALL USING (EXISTS (SELECT 1 FROM current_profile WHERE role = 'field_supervisor'));

-- Yoghurt container lines
CREATE POLICY "yoghurt_container_select_field_supervisor" ON yoghurt_container_lines
FOR SELECT USING (EXISTS (SELECT 1 FROM current_profile WHERE role = 'field_supervisor'));

CREATE POLICY "yoghurt_container_write_field_supervisor" ON yoghurt_container_lines
FOR ALL USING (EXISTS (SELECT 1 FROM current_profile WHERE role = 'field_supervisor'));

-- Yoghurt refill lines
CREATE POLICY "yoghurt_refill_select_field_supervisor" ON yoghurt_refill_lines
FOR SELECT USING (EXISTS (SELECT 1 FROM current_profile WHERE role = 'field_supervisor'));

CREATE POLICY "yoghurt_refill_write_field_supervisor" ON yoghurt_refill_lines
FOR ALL USING (EXISTS (SELECT 1 FROM current_profile WHERE role = 'field_supervisor'));

-- Yoghurt non-container
CREATE POLICY "yoghurt_non_container_select_field_supervisor" ON yoghurt_non_container
FOR SELECT USING (EXISTS (SELECT 1 FROM current_profile WHERE role = 'field_supervisor'));

CREATE POLICY "yoghurt_non_container_write_field_supervisor" ON yoghurt_non_container
FOR ALL USING (EXISTS (SELECT 1 FROM current_profile WHERE role = 'field_supervisor'));

-- Yoghurt section B income
CREATE POLICY "yoghurt_section_b_select_field_supervisor" ON yoghurt_section_b_income
FOR SELECT USING (EXISTS (SELECT 1 FROM current_profile WHERE role = 'field_supervisor'));

CREATE POLICY "yoghurt_section_b_write_field_supervisor" ON yoghurt_section_b_income
FOR ALL USING (EXISTS (SELECT 1 FROM current_profile WHERE role = 'field_supervisor'));

-- Material lines
CREATE POLICY "material_select_field_supervisor" ON material_lines
FOR SELECT USING (EXISTS (SELECT 1 FROM current_profile WHERE role = 'field_supervisor'));

CREATE POLICY "material_write_field_supervisor" ON material_lines
FOR ALL USING (EXISTS (SELECT 1 FROM current_profile WHERE role = 'field_supervisor'));

-- Currency notes
CREATE POLICY "currency_notes_select_field_supervisor" ON currency_notes
FOR SELECT USING (EXISTS (SELECT 1 FROM current_profile WHERE role = 'field_supervisor'));

CREATE POLICY "currency_notes_write_field_supervisor" ON currency_notes
FOR ALL USING (EXISTS (SELECT 1 FROM current_profile WHERE role = 'field_supervisor'));

-- Branches (for reading branch info)
CREATE POLICY "branches_field_supervisor" ON branches
FOR SELECT USING (EXISTS (SELECT 1 FROM current_profile WHERE role = 'field_supervisor'));

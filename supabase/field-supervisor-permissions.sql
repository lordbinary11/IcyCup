-- Field Supervisor RLS Policies for Line Items
-- This script adds the missing RLS policies to allow field supervisors to edit all sheet data

-- Add policy for field supervisors to update sheets
create policy "sheets_update_field_supervisor" on daily_sheets
for update using (exists (select 1 from current_profile where role = 'field_supervisor'));

-- Add policies for field supervisors to edit line items
create policy "pastry_lines_field_supervisor" on pastry_lines
for all using (exists (select 1 from current_profile where role = 'field_supervisor')) with check (true);

create policy "yoghurt_container_lines_field_supervisor" on yoghurt_container_lines
for all using (exists (select 1 from current_profile where role = 'field_supervisor')) with check (true);

create policy "yoghurt_refill_lines_field_supervisor" on yoghurt_refill_lines
for all using (exists (select 1 from current_profile where role = 'field_supervisor')) with check (true);

create policy "yoghurt_non_container_field_supervisor" on yoghurt_non_container
for all using (exists (select 1 from current_profile where role = 'field_supervisor')) with check (true);

create policy "yoghurt_section_b_income_field_supervisor" on yoghurt_section_b_income
for all using (exists (select 1 from current_profile where role = 'field_supervisor')) with check (true);

create policy "yoghurt_headers_field_supervisor" on yoghurt_headers
for all using (exists (select 1 from current_profile where role = 'field_supervisor')) with check (true);

create policy "material_lines_field_supervisor" on material_lines
for all using (exists (select 1 from current_profile where role = 'field_supervisor')) with check (true);

create policy "currency_notes_field_supervisor" on currency_notes
for all using (exists (select 1 from current_profile where role = 'field_supervisor')) with check (true);

create policy "expenses_field_supervisor" on expenses
for all using (exists (select 1 from current_profile where role = 'field_supervisor')) with check (true);

create policy "staff_attendance_field_supervisor" on staff_attendance
for all using (exists (select 1 from current_profile where role = 'field_supervisor')) with check (true);

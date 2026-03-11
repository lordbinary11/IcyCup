-- Field Supervisor Sheet Creation Business Logic
-- Allows field supervisors to select branch and date for sheet recording
-- Prevents duplicate sheets for same branch/date combination
-- Allows back dating

-- Create or replace function for field supervisor to get or create sheet for specific date
create or replace function get_or_create_sheet_for_date(
    p_branch_id uuid,
    p_sheet_date date
)
returns uuid
language plpgsql
security definer
as $$
declare
    prof user_profiles;
    existing_sheet_id uuid;
    new_sheet_id uuid;
    sup_id uuid;
begin
    -- Get current user profile
    select * into prof from user_profiles where user_id = auth.uid();
    
    -- Allow both supervisor and field_supervisor roles to use this function
    if prof.role not in ('supervisor', 'field_supervisor') then
        raise exception 'Only supervisors can create sheets for specific dates';
    end if;
    
    -- Check if sheet already exists for this branch and date
    select id into existing_sheet_id
    from daily_sheets
    where branch_id = p_branch_id
      and sheet_date = p_sheet_date
    limit 1;
    
    if existing_sheet_id is not null then
        return existing_sheet_id;
    end if;
    
    -- Get supervisor ID for the branch
    select supervisor_id into sup_id from branches where id = p_branch_id;
    
    -- Create new sheet
    insert into daily_sheets (branch_id, sheet_date, supervisor_id, created_by)
    values (p_branch_id, p_sheet_date, sup_id, auth.uid())
    returning id into new_sheet_id;
    
    -- Seed all standard line items for this new sheet
    perform seed_sheet_lines(new_sheet_id);
    
    return new_sheet_id;
end;
$$;

-- Update RLS policies to allow field supervisors to create sheets for any branch/date
create policy "sheets_insert_supervisor" on daily_sheets
for insert with check (exists (select 1 from current_profile where role in ('supervisor', 'field_supervisor')));

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

create policy "material_lines_field_supervisor" on material_lines
for all using (exists (select 1 from current_profile where role = 'field_supervisor')) with check (true);

create policy "currency_notes_field_supervisor" on currency_notes
for all using (exists (select 1 from current_profile where role = 'field_supervisor')) with check (true);

create policy "expenses_field_supervisor" on expenses
for all using (exists (select 1 from current_profile where role = 'field_supervisor')) with check (true);

create policy "staff_attendance_field_supervisor" on staff_attendance
for all using (exists (select 1 from current_profile where role = 'field_supervisor')) with check (true);

create policy "yoghurt_headers_field_supervisor" on yoghurt_headers
for all using (exists (select 1 from current_profile where role = 'field_supervisor')) with check (true);

-- Ensure all sheets remain editable for supervisors (remove date restrictions)
create or replace function can_edit_sheet(p_sheet daily_sheets)
returns boolean as $$
declare
  prof user_profiles;
begin
  select * into prof from current_profile;
  
  -- Supervisors and field supervisors can edit any sheet regardless of date
  if prof.role in ('supervisor', 'field_supervisor') then
    return true;
  end if;
  
  -- Branch users can only edit same-day sheets for their branch
  if prof.role = 'branch_user'
     and prof.branch_id = p_sheet.branch_id
     and p_sheet.sheet_date = current_date
     and localtime < time '23:59:59'
     and not p_sheet.locked then
    return true;
  end if;
  
  return false;
end;
$$ language plpgsql security definer;

-- Add unique constraint to prevent duplicate sheets (already exists in schema)
-- This is enforced by: constraint unique_sheet_per_day unique (branch_id, sheet_date)

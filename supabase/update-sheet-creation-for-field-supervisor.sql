-- ============================================================================
-- Update Sheet Creation Function for Field Supervisor
-- ============================================================================
-- This migration updates the get_or_create_today_sheet function to handle
-- field_supervisor role, which can create sheets for any branch
-- ============================================================================

-- Drop and recreate the function with field_supervisor support
CREATE OR REPLACE FUNCTION get_or_create_today_sheet(p_branch_id uuid default null)
returns uuid
language plpgsql
security definer
as $$
declare
  prof user_profiles;
  target_branch uuid;
  sheet_id uuid;
  sup_id uuid;
begin
  select * into prof from user_profiles where user_id = auth.uid();

  if prof.role = 'branch_user' then
    target_branch := prof.branch_id;
  elsif prof.role = 'supervisor' then
    target_branch := coalesce(p_branch_id, prof.branch_id);
  elsif prof.role = 'field_supervisor' then
    -- Field supervisors must specify a branch_id parameter
    target_branch := p_branch_id;
  elsif prof.role = 'admin' then
    -- Admins can specify a branch or use their assigned branch
    target_branch := coalesce(p_branch_id, prof.branch_id);
  end if;

  if target_branch is null then
    raise exception 'Branch could not be resolved for current user';
  end if;

  select id into sheet_id
  from daily_sheets
  where branch_id = target_branch
    and sheet_date = current_date;

  if sheet_id is null then
    select supervisor_id into sup_id from branches where id = target_branch;
    insert into daily_sheets (branch_id, sheet_date, supervisor_id, created_by)
    values (target_branch, current_date, sup_id, auth.uid())
    returning id into sheet_id;
    
    -- Seed all standard line items for this new sheet
    perform seed_sheet_lines(sheet_id);
  end if;

  return sheet_id;
end;
$$;

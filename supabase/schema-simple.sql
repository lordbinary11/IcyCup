-- Simplified schema for IcyCup digital Daily Sales Analysis Sheets
-- Frontend handles all calculations. On submit, complete sheet is saved to database.
-- No triggers for computed fields - all values are stored as submitted.

-- === Auth & Roles ===========================================================
create type if not exists app_role as enum ('branch_user', 'supervisor');

create table if not exists branches (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  supervisor_id uuid references auth.users(id)
);

create table if not exists user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  branch_id uuid references branches(id),
  role app_role not null,
  constraint branch_required_for_branch_user check (
    (role = 'branch_user' and branch_id is not null) or role = 'supervisor'
  )
);

-- === Items (for reference/pricing) ==========================================
create table if not exists items (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  category text not null check (
    category in (
      'pastry',
      'yoghurt_container',
      'yoghurt_non_container',
      'yoghurt_refill',
      'smoothie',
      'water',
      'material'
    )
  ),
  unit_price numeric(12,2) not null default 0,
  volume_factor numeric(12,4) not null default 1,
  created_at timestamptz not null default now()
);

-- === Sheet Header ============================================================
create table if not exists daily_sheets (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references branches(id),
  sheet_date date not null,
  supervisor_id uuid references auth.users(id),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  locked boolean not null default false,
  -- All totals are computed by frontend and stored on submit
  total_pastries_income numeric(14,2) not null default 0,
  yoghurt_section_a_total_volume numeric(14,3) not null default 0,
  yoghurt_section_a_total_income numeric(14,2) not null default 0,
  yoghurt_section_b_total numeric(14,2) not null default 0,
  grand_total numeric(14,2) not null default 0,
  currency_total_cash numeric(14,2) not null default 0,
  cash_on_hand numeric(14,2) not null default 0,
  momo_amount numeric(14,2) not null default 0,
  cash_balance_delta numeric(14,2) not null default 0,
  constraint unique_sheet_per_day unique (branch_id, sheet_date)
);

-- Simple updated_at trigger (keep this one)
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger trg_daily_sheets_ts
before update on daily_sheets
for each row execute procedure set_updated_at();

-- === Pastries ===============================================================
create table if not exists pastry_lines (
  id uuid primary key default gen_random_uuid(),
  sheet_id uuid not null references daily_sheets(id) on delete cascade,
  item_id uuid not null references items(id),
  item_name text not null,
  qty_received numeric(14,3) not null default 0,
  received_from_other_qty numeric(14,3) not null default 0,
  received_from_branch_id uuid references branches(id),
  transfer_to_other_qty numeric(14,3) not null default 0,
  transfer_to_branch_id uuid references branches(id),
  qty_sold numeric(14,3) not null default 0,
  unit_price numeric(12,2) not null default 0,
  leftovers numeric(14,3) not null default 0,
  amount numeric(14,2) not null default 0
);

-- === Yoghurt ================================================================
create table if not exists yoghurt_headers (
  sheet_id uuid primary key references daily_sheets(id) on delete cascade,
  opening_stock numeric(14,3) not null default 0,
  stock_received numeric(14,3) not null default 0,
  total_stock numeric(14,3) not null default 0,
  closing_stock numeric(14,3) not null default 0
);

create table if not exists yoghurt_container_lines (
  id uuid primary key default gen_random_uuid(),
  sheet_id uuid not null references daily_sheets(id) on delete cascade,
  item_id uuid not null references items(id),
  item_name text not null,
  volume_factor numeric(12,4) not null default 1,
  unit_price numeric(12,2) not null default 0,
  qty_sold numeric(14,3) not null default 0,
  volume_sold numeric(14,3) not null default 0,
  income numeric(14,2) not null default 0
);

create table if not exists yoghurt_refill_lines (
  id uuid primary key default gen_random_uuid(),
  sheet_id uuid not null references daily_sheets(id) on delete cascade,
  item_id uuid not null references items(id),
  item_name text not null,
  volume_factor numeric(12,4) not null default 1,
  unit_price numeric(12,2) not null default 0,
  qty_sold numeric(14,3) not null default 0,
  volume_sold numeric(14,3) not null default 0,
  income numeric(14,2) not null default 0
);

create table if not exists yoghurt_non_container (
  id uuid primary key default gen_random_uuid(),
  sheet_id uuid not null references daily_sheets(id) on delete cascade,
  item_id uuid not null references items(id),
  item_name text not null,
  unit_price numeric(12,2) not null default 0,
  volume_sold numeric(14,3) not null default 0,
  income numeric(14,2) not null default 0
);

create table if not exists yoghurt_section_b_income (
  id uuid primary key default gen_random_uuid(),
  sheet_id uuid not null references daily_sheets(id) on delete cascade,
  source text not null check (source in ('pastries','smoothies','water')),
  item_id uuid references items(id),
  unit_price numeric(12,2),
  qty_sold numeric(14,3),
  income numeric(14,2) not null default 0
);

-- === Materials ==============================================================
create table if not exists material_lines (
  id uuid primary key default gen_random_uuid(),
  sheet_id uuid not null references daily_sheets(id) on delete cascade,
  item_id uuid not null references items(id),
  item_name text not null,
  opening numeric(14,3) not null default 0,
  received numeric(14,3) not null default 0,
  used_normal numeric(14,3) not null default 0,
  used_spoilt numeric(14,3) not null default 0,
  transferred_out numeric(14,3) not null default 0,
  transfer_to_branch_id uuid references branches(id),
  total_used numeric(14,3) not null default 0,
  closing numeric(14,3) not null default 0
);

-- === Currency Notes =========================================================
create table if not exists currency_notes (
  id uuid primary key default gen_random_uuid(),
  sheet_id uuid not null references daily_sheets(id) on delete cascade,
  denomination numeric(14,2) not null,
  quantity integer not null default 0,
  amount numeric(14,2) not null default 0
);

-- === Staff & Expenses =======================================================
create table if not exists staff_attendance (
  id uuid primary key default gen_random_uuid(),
  sheet_id uuid not null references daily_sheets(id) on delete cascade,
  staff_name text not null
);

create table if not exists extra_expenses (
  id uuid primary key default gen_random_uuid(),
  sheet_id uuid not null references daily_sheets(id) on delete cascade,
  description text not null,
  amount numeric(14,2) not null,
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id)
);

-- === RLS ====================================================================
alter table branches enable row level security;
alter table user_profiles enable row level security;
alter table items enable row level security;
alter table daily_sheets enable row level security;
alter table pastry_lines enable row level security;
alter table yoghurt_headers enable row level security;
alter table yoghurt_container_lines enable row level security;
alter table yoghurt_refill_lines enable row level security;
alter table yoghurt_non_container enable row level security;
alter table yoghurt_section_b_income enable row level security;
alter table material_lines enable row level security;
alter table currency_notes enable row level security;
alter table staff_attendance enable row level security;
alter table extra_expenses enable row level security;

-- View for current user profile
create or replace view current_profile as
select * from user_profiles where user_id = auth.uid();

-- Branches policies
create policy "branches_select_all" on branches
for select using (true);

-- Items policies (everyone can read)
create policy "items_select_all" on items
for select using (true);

-- User profile access (self)
create policy "user_profile_self" on user_profiles
for select using (user_id = auth.uid());

-- Daily sheets policies
create policy "sheets_select_branch" on daily_sheets
for select using (branch_id = (select branch_id from current_profile where role = 'branch_user'));

create policy "sheets_select_supervisor" on daily_sheets
for select using (exists (select 1 from current_profile where role = 'supervisor'));

create policy "sheets_insert" on daily_sheets
for insert with check (
  branch_id = (select branch_id from current_profile) 
  or exists (select 1 from current_profile where role = 'supervisor')
);

create policy "sheets_update" on daily_sheets
for update using (
  (branch_id = (select branch_id from current_profile where role = 'branch_user') and not locked)
  or exists (select 1 from current_profile where role = 'supervisor')
);

-- Line tables: allow all operations for own branch sheets or supervisors
-- Pastry lines
create policy "pastry_select" on pastry_lines
for select using (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile))
  or exists (select 1 from current_profile where role = 'supervisor')
);

create policy "pastry_insert" on pastry_lines
for insert with check (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile) and not locked)
  or exists (select 1 from current_profile where role = 'supervisor')
);

create policy "pastry_update" on pastry_lines
for update using (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile) and not locked)
  or exists (select 1 from current_profile where role = 'supervisor')
);

create policy "pastry_delete" on pastry_lines
for delete using (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile) and not locked)
  or exists (select 1 from current_profile where role = 'supervisor')
);

-- Similar policies for other line tables (yoghurt, materials, currency, staff, expenses)
-- Yoghurt headers
create policy "yh_select" on yoghurt_headers for select using (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile))
  or exists (select 1 from current_profile where role = 'supervisor')
);
create policy "yh_insert" on yoghurt_headers for insert with check (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile))
  or exists (select 1 from current_profile where role = 'supervisor')
);
create policy "yh_update" on yoghurt_headers for update using (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile) and not locked)
  or exists (select 1 from current_profile where role = 'supervisor')
);

-- Yoghurt container lines
create policy "yc_select" on yoghurt_container_lines for select using (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile))
  or exists (select 1 from current_profile where role = 'supervisor')
);
create policy "yc_insert" on yoghurt_container_lines for insert with check (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile))
  or exists (select 1 from current_profile where role = 'supervisor')
);
create policy "yc_update" on yoghurt_container_lines for update using (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile) and not locked)
  or exists (select 1 from current_profile where role = 'supervisor')
);
create policy "yc_delete" on yoghurt_container_lines for delete using (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile) and not locked)
  or exists (select 1 from current_profile where role = 'supervisor')
);

-- Yoghurt refill lines
create policy "yr_select" on yoghurt_refill_lines for select using (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile))
  or exists (select 1 from current_profile where role = 'supervisor')
);
create policy "yr_insert" on yoghurt_refill_lines for insert with check (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile))
  or exists (select 1 from current_profile where role = 'supervisor')
);
create policy "yr_update" on yoghurt_refill_lines for update using (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile) and not locked)
  or exists (select 1 from current_profile where role = 'supervisor')
);
create policy "yr_delete" on yoghurt_refill_lines for delete using (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile) and not locked)
  or exists (select 1 from current_profile where role = 'supervisor')
);

-- Yoghurt non-container
create policy "ync_select" on yoghurt_non_container for select using (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile))
  or exists (select 1 from current_profile where role = 'supervisor')
);
create policy "ync_insert" on yoghurt_non_container for insert with check (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile))
  or exists (select 1 from current_profile where role = 'supervisor')
);
create policy "ync_update" on yoghurt_non_container for update using (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile) and not locked)
  or exists (select 1 from current_profile where role = 'supervisor')
);
create policy "ync_delete" on yoghurt_non_container for delete using (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile) and not locked)
  or exists (select 1 from current_profile where role = 'supervisor')
);

-- Yoghurt section B
create policy "yb_select" on yoghurt_section_b_income for select using (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile))
  or exists (select 1 from current_profile where role = 'supervisor')
);
create policy "yb_insert" on yoghurt_section_b_income for insert with check (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile))
  or exists (select 1 from current_profile where role = 'supervisor')
);
create policy "yb_update" on yoghurt_section_b_income for update using (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile) and not locked)
  or exists (select 1 from current_profile where role = 'supervisor')
);
create policy "yb_delete" on yoghurt_section_b_income for delete using (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile) and not locked)
  or exists (select 1 from current_profile where role = 'supervisor')
);

-- Material lines
create policy "mat_select" on material_lines for select using (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile))
  or exists (select 1 from current_profile where role = 'supervisor')
);
create policy "mat_insert" on material_lines for insert with check (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile))
  or exists (select 1 from current_profile where role = 'supervisor')
);
create policy "mat_update" on material_lines for update using (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile) and not locked)
  or exists (select 1 from current_profile where role = 'supervisor')
);
create policy "mat_delete" on material_lines for delete using (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile) and not locked)
  or exists (select 1 from current_profile where role = 'supervisor')
);

-- Currency notes
create policy "cn_select" on currency_notes for select using (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile))
  or exists (select 1 from current_profile where role = 'supervisor')
);
create policy "cn_insert" on currency_notes for insert with check (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile))
  or exists (select 1 from current_profile where role = 'supervisor')
);
create policy "cn_update" on currency_notes for update using (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile) and not locked)
  or exists (select 1 from current_profile where role = 'supervisor')
);
create policy "cn_delete" on currency_notes for delete using (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile) and not locked)
  or exists (select 1 from current_profile where role = 'supervisor')
);

-- Staff attendance
create policy "staff_select" on staff_attendance for select using (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile))
  or exists (select 1 from current_profile where role = 'supervisor')
);
create policy "staff_insert" on staff_attendance for insert with check (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile))
  or exists (select 1 from current_profile where role = 'supervisor')
);
create policy "staff_delete" on staff_attendance for delete using (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile) and not locked)
  or exists (select 1 from current_profile where role = 'supervisor')
);

-- Extra expenses
create policy "exp_select" on extra_expenses for select using (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile))
  or exists (select 1 from current_profile where role = 'supervisor')
);
create policy "exp_insert" on extra_expenses for insert with check (
  sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile))
  or exists (select 1 from current_profile where role = 'supervisor')
);

-- === Helper RPC: get or create today's sheet ================================
create or replace function get_or_create_today_sheet(p_branch_id uuid default null)
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
  end if;

  if target_branch is null then
    raise exception 'Branch could not be resolved for current user';
  end if;

  select id into sheet_id
  from daily_sheets
  where branch_id = target_branch
    and sheet_date = current_date
  limit 1;

  if not found then
    select supervisor_id into sup_id from branches where id = target_branch;
    insert into daily_sheets (branch_id, sheet_date, supervisor_id, created_by)
    values (target_branch, current_date, sup_id, auth.uid())
    returning id into sheet_id;
  end if;

  return sheet_id;
end;
$$;

-- === RPC: finalize/submit sheet =============================================
create or replace function finalize_daily_sheet(p_sheet_id uuid)
returns void
language plpgsql
security definer
as $$
declare
  s daily_sheets;
  prof user_profiles;
  staff_count int;
begin
  select * into s from daily_sheets where id = p_sheet_id;
  if not found then
    raise exception 'Sheet not found';
  end if;

  select * into prof from user_profiles where user_id = auth.uid();

  -- Require at least one staff entry before submission
  select count(*) into staff_count from staff_attendance where sheet_id = p_sheet_id;
  if staff_count = 0 then
    raise exception 'Staff attendance is required before submission';
  end if;

  -- Branch users: only same day and same branch
  if prof.role = 'branch_user' then
    if prof.branch_id <> s.branch_id then
      raise exception 'Not allowed';
    end if;
    if s.sheet_date <> current_date then
      raise exception 'Cannot submit past/future sheets';
    end if;
  end if;

  update daily_sheets set locked = true where id = p_sheet_id;
end;
$$;

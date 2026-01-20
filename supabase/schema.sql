-- Core schema for IcyCup digital Daily Sales Analysis Sheets
-- Backend remains the single source of truth. All derived fields are enforced
-- with triggers; the frontend only renders and edits raw inputs.

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

-- === Items and Versioning ====================================================
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
  created_at timestamptz not null default now()
);

create table if not exists item_versions (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references items(id) on delete cascade,
  volume_factor numeric(12,4) not null default 1,
  unit_price numeric(12,2) not null,
  effective_from date not null,
  effective_to date,
  constraint version_range check (effective_to is null or effective_to >= effective_from)
);

create or replace function get_active_item_version(p_item uuid, p_date date)
returns item_versions as $$
  select *
  from item_versions
  where item_id = p_item
    and effective_from <= p_date
    and (effective_to is null or effective_to >= p_date)
  order by effective_from desc
  limit 1;
$$ language sql stable;

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
  item_version_id uuid references item_versions(id),
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

create or replace function pastry_lines_biud()
returns trigger as $$
declare
  v item_versions;
  sdate date;
begin
  select sheet_date into sdate from daily_sheets where id = new.sheet_id;

  if tg_op = 'INSERT' and new.item_version_id is null then
    select * into v from get_active_item_version(new.item_id, sdate);
    if not found then
      raise exception 'No active version for item % on %', new.item_id, sdate;
    end if;
    new.item_version_id := v.id;
    new.unit_price := v.unit_price;
  end if;

  if new.received_from_other_qty > 0 and new.received_from_branch_id is null then
    raise exception 'Received-from requires source branch';
  end if;
  if new.transfer_to_other_qty > 0 and new.transfer_to_branch_id is null then
    raise exception 'Transfer-to requires destination branch';
  end if;

  new.leftovers := (coalesce(new.qty_received,0) + coalesce(new.received_from_other_qty,0))
                   - (coalesce(new.qty_sold,0) + coalesce(new.transfer_to_other_qty,0));
  new.amount := coalesce(new.qty_sold,0) * new.unit_price;
  return new;
end;
$$ language plpgsql;

create trigger trg_pastry_lines_biud
before insert or update on pastry_lines
for each row execute procedure pastry_lines_biud();

create or replace function update_pastries_total()
returns trigger as $$
begin
  update daily_sheets s
  set total_pastries_income = coalesce((select sum(amount) from pastry_lines where sheet_id = s.id), 0)
  where s.id = coalesce(new.sheet_id, old.sheet_id);
  return null;
end;
$$ language plpgsql;

create trigger trg_pastry_lines_totals
after insert or update or delete on pastry_lines
for each row execute procedure update_pastries_total();

-- === Yoghurt ================================================================
create table if not exists yoghurt_headers (
  sheet_id uuid primary key references daily_sheets(id) on delete cascade,
  opening_stock numeric(14,3) not null default 0,
  stock_received numeric(14,3) not null default 0,
  total_stock numeric(14,3) not null default 0,
  closing_stock numeric(14,3) not null default 0
);

create or replace function yoghurt_headers_biud()
returns trigger as $$
begin
  new.total_stock := coalesce(new.opening_stock,0) + coalesce(new.stock_received,0);
  new.closing_stock := new.total_stock - coalesce((
    select yoghurt_section_a_total_volume from daily_sheets where id = new.sheet_id
  ),0);
  return new;
end;
$$ language plpgsql;

create trigger trg_yoghurt_headers_biud
before insert or update on yoghurt_headers
for each row execute procedure yoghurt_headers_biud();

create table if not exists yoghurt_container_lines (
  id uuid primary key default gen_random_uuid(),
  sheet_id uuid not null references daily_sheets(id) on delete cascade,
  item_id uuid not null references items(id),
  item_version_id uuid references item_versions(id),
  volume_factor numeric(12,4) not null default 1,
  unit_price numeric(12,2) not null default 0,
  qty_sold numeric(14,3) not null default 0,
  volume_sold numeric(14,3) not null default 0,
  income numeric(14,2) not null default 0
);

create table if not exists yoghurt_refill_lines (like yoghurt_container_lines including all);

create table if not exists yoghurt_non_container (
  id uuid primary key default gen_random_uuid(),
  sheet_id uuid not null references daily_sheets(id) on delete cascade,
  item_id uuid not null references items(id),
  item_version_id uuid references item_versions(id),
  unit_price numeric(12,2) not null default 0,
  volume_sold numeric(14,3) not null default 0,
  income numeric(14,2) not null default 0
);

create table if not exists yoghurt_section_b_income (
  id uuid primary key default gen_random_uuid(),
  sheet_id uuid not null references daily_sheets(id) on delete cascade,
  source text not null check (source in ('pastries','smoothies','water')),
  item_id uuid references items(id),
  item_version_id uuid references item_versions(id),
  unit_price numeric(12,2),
  qty_sold numeric(14,3),
  income numeric(14,2) not null default 0
);

create or replace function yoghurt_lines_biud()
returns trigger as $$
declare
  v item_versions;
  sdate date;
begin
  select sheet_date into sdate from daily_sheets where id = new.sheet_id;

  if tg_op = 'INSERT' and new.item_version_id is null then
    select * into v from get_active_item_version(new.item_id, sdate);
    if not found then
      raise exception 'No active version for item % on %', new.item_id, sdate;
    end if;
    new.item_version_id := v.id;
    new.unit_price := v.unit_price;
    if exists(select 1 from information_schema.columns where table_name = tg_table_name and column_name = 'volume_factor') then
      new.volume_factor := v.volume_factor;
    end if;
  end if;

  if exists(select 1 from information_schema.columns where table_name = tg_table_name and column_name = 'volume_factor') then
    new.volume_sold := coalesce(new.volume_factor,0) * coalesce(new.qty_sold,0);
  end if;
  new.income := coalesce(new.qty_sold,0) * coalesce(new.unit_price,0);
  return new;
end;
$$ language plpgsql;

create trigger trg_yoghurt_container_biud
before insert or update on yoghurt_container_lines
for each row execute procedure yoghurt_lines_biud();

create trigger trg_yoghurt_refill_biud
before insert or update on yoghurt_refill_lines
for each row execute procedure yoghurt_lines_biud();

create or replace function yoghurt_non_container_biud()
returns trigger as $$
declare
  v item_versions;
  sdate date;
begin
  select sheet_date into sdate from daily_sheets where id = new.sheet_id;
  if tg_op = 'INSERT' and new.item_version_id is null then
    select * into v from get_active_item_version(new.item_id, sdate);
    new.item_version_id := v.id;
    new.unit_price := v.unit_price;
  end if;
  new.income := coalesce(new.volume_sold,0) * coalesce(new.unit_price,0);
  return new;
end;
$$ language plpgsql;

create trigger trg_yoghurt_nc_biud
before insert or update on yoghurt_non_container
for each row execute procedure yoghurt_non_container_biud();

create or replace function yoghurt_section_b_biud()
returns trigger as $$
declare
  v item_versions;
  sdate date;
begin
  select sheet_date into sdate from daily_sheets where id = new.sheet_id;
  if new.source = 'pastries' then
    new.income := (select total_pastries_income from daily_sheets where id = new.sheet_id);
    new.unit_price := null;
    new.qty_sold := null;
    return new;
  end if;

  if tg_op = 'INSERT' and new.item_version_id is null then
    select * into v from get_active_item_version(new.item_id, sdate);
    new.item_version_id := v.id;
    new.unit_price := v.unit_price;
  end if;

  new.income := coalesce(new.qty_sold,0) * coalesce(new.unit_price,0);
  return new;
end;
$$ language plpgsql;

create trigger trg_yoghurt_section_b_biud
before insert or update on yoghurt_section_b_income
for each row execute procedure yoghurt_section_b_biud();

create or replace function recompute_sheet_totals()
returns trigger as $$
declare
  sid uuid := coalesce(new.sheet_id, old.sheet_id);
  v_total_volume numeric;
  v_total_income numeric;
  v_b_total numeric;
  v_cash_total numeric;
begin
  select coalesce(sum(volume_sold),0) into v_total_volume
  from (
    select volume_sold from yoghurt_container_lines where sheet_id = sid
    union all
    select volume_sold from yoghurt_refill_lines where sheet_id = sid
    union all
    select coalesce(volume_sold,0) from yoghurt_non_container where sheet_id = sid
  ) t;

  select coalesce(sum(income),0) into v_total_income
  from (
    select income from yoghurt_container_lines where sheet_id = sid
    union all
    select income from yoghurt_refill_lines where sheet_id = sid
    union all
    select income from yoghurt_non_container where sheet_id = sid
  ) t;

  select coalesce(sum(income),0) into v_b_total
  from yoghurt_section_b_income where sheet_id = sid;

  select coalesce(sum(amount),0) into v_cash_total
  from currency_notes where sheet_id = sid;

  update daily_sheets s
  set yoghurt_section_a_total_volume = v_total_volume,
      yoghurt_section_a_total_income = v_total_income,
      yoghurt_section_b_total = v_b_total,
      grand_total = v_total_income + v_b_total + s.total_pastries_income,
      currency_total_cash = v_cash_total,
      cash_balance_delta = (s.cash_on_hand + s.momo_amount) - (v_total_income + v_b_total + s.total_pastries_income)
  where s.id = sid;

  update yoghurt_headers h
  set closing_stock = h.total_stock - v_total_volume
  where h.sheet_id = sid;
  return null;
end;
$$ language plpgsql;

create trigger trg_totals_pastry after insert or update or delete on pastry_lines for each row execute procedure recompute_sheet_totals();
create trigger trg_totals_yc after insert or update or delete on yoghurt_container_lines for each row execute procedure recompute_sheet_totals();
create trigger trg_totals_yrefill after insert or update or delete on yoghurt_refill_lines for each row execute procedure recompute_sheet_totals();
create trigger trg_totals_ync after insert or update or delete on yoghurt_non_container for each row execute procedure recompute_sheet_totals();
create trigger trg_totals_yb after insert or update or delete on yoghurt_section_b_income for each row execute procedure recompute_sheet_totals();
create trigger trg_totals_currency after insert or update or delete on currency_notes for each row execute procedure recompute_sheet_totals();

-- === Materials ============================================================== 
create table if not exists material_lines (
  id uuid primary key default gen_random_uuid(),
  sheet_id uuid not null references daily_sheets(id) on delete cascade,
  item_id uuid not null references items(id),
  opening numeric(14,3) not null default 0,
  received numeric(14,3) not null default 0,
  used_normal numeric(14,3) not null default 0,
  used_spoilt numeric(14,3) not null default 0,
  transferred_out numeric(14,3) not null default 0,
  transfer_to_branch_id uuid references branches(id),
  total_used numeric(14,3) not null default 0,
  closing numeric(14,3) not null default 0,
  supervisor_override_reason text
);

create or replace function material_lines_biud()
returns trigger as $$
declare
  prof user_profiles;
begin
  select * into prof from user_profiles where user_id = auth.uid();
  new.total_used := coalesce(new.used_normal,0) + coalesce(new.used_spoilt,0);
  new.closing := (coalesce(new.opening,0) + coalesce(new.received,0)) - (new.total_used + coalesce(new.transferred_out,0));

  if tg_op = 'UPDATE' and prof.role = 'branch_user' and new.opening <> old.opening then
    raise exception 'Branch users cannot override opening';
  end if;
  if tg_op = 'UPDATE' and prof.role = 'supervisor' and new.opening <> old.opening and (new.supervisor_override_reason is null or length(trim(new.supervisor_override_reason)) = 0) then
    raise exception 'Supervisor override requires reason';
  end if;
  if new.transferred_out > 0 and new.transfer_to_branch_id is null then
    raise exception 'Transfer out requires destination branch';
  end if;
  return new;
end;
$$ language plpgsql;

create trigger trg_material_lines_biud
before insert or update on material_lines
for each row execute procedure material_lines_biud();

-- === Currency Notes =========================================================
create table if not exists currency_notes (
  id uuid primary key default gen_random_uuid(),
  sheet_id uuid not null references daily_sheets(id) on delete cascade,
  denomination numeric(14,2) not null,
  quantity integer not null default 0,
  amount numeric(14,2) not null default 0
);

create or replace function currency_notes_biud()
returns trigger as $$
begin
  new.amount := coalesce(new.denomination,0) * coalesce(new.quantity,0);
  return new;
end;
$$ language plpgsql;

create trigger trg_currency_notes_biud
before insert or update on currency_notes
for each row execute procedure currency_notes_biud();

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

-- === Audit Logging ==========================================================
create type if not exists audit_action as enum ('create','update','reconcile');

create table if not exists audit_logs (
  id bigserial primary key,
  user_id uuid not null,
  role app_role,
  occurred_at timestamptz not null default now(),
  table_name text not null,
  row_id uuid,
  action audit_action not null,
  old_values jsonb,
  new_values jsonb,
  column_names text[]
);

create or replace function audit_trigger()
returns trigger as $$
declare
  prof user_profiles;
  act audit_action;
  v_old jsonb;
  v_new jsonb;
  v_keys text[];
  v_user_id uuid;
begin
  -- Get current user ID, skip audit if no authenticated user (e.g., service role, migrations)
  v_user_id := auth.uid();
  if v_user_id is null then
    return coalesce(new, old); -- Skip audit logging for system operations
  end if;

  -- Try to get user profile, but don't fail if not found
  select * into prof from user_profiles where user_id = v_user_id;

  if tg_op = 'INSERT' then
    act := 'create';
    v_old := null;
    v_new := to_jsonb(new);
  elsif tg_op = 'UPDATE' then
    act := case when prof.role = 'supervisor' then 'reconcile' else 'update' end;
    v_old := to_jsonb(old);
    v_new := to_jsonb(new);
  else
    return coalesce(new, old); -- ignore DELETEs for now
  end if;

  -- Collect all keys from old ∪ new
  select coalesce(array_agg(key), '{}'::text[])
  into v_keys
  from jsonb_object_keys(coalesce(v_old, '{}'::jsonb) || coalesce(v_new, '{}'::jsonb)) as t(key);

  insert into audit_logs (
    user_id,
    role,
    table_name,
    row_id,
    action,
    old_values,
    new_values,
    column_names
  )
  values (
    v_user_id,
    prof.role, -- may be null if user_profile doesn't exist yet
    tg_table_name,
    -- Handle different primary key column names
    case
      when tg_table_name = 'yoghurt_headers' then coalesce((v_new->>'sheet_id')::uuid, (v_old->>'sheet_id')::uuid)
      else coalesce((v_new->>'id')::uuid, (v_old->>'id')::uuid)
    end,
    act,
    v_old,
    v_new,
    v_keys
  );

  return coalesce(new, old);
end;
$$ language plpgsql security definer;

-- Attach audit triggers (repeat as needed)
do $$
declare
  tbl text;
begin
  foreach tbl in array array[
    'daily_sheets',
    'pastry_lines',
    'yoghurt_headers',
    'yoghurt_container_lines',
    'yoghurt_refill_lines',
    'yoghurt_non_container',
    'yoghurt_section_b_income',
    'material_lines',
    'currency_notes',
    'staff_attendance',
    'extra_expenses',
    'item_versions'
  ]
  loop
    execute format('create trigger trg_audit_%I after insert or update on %I for each row execute procedure audit_trigger();', tbl, tbl);
  end loop;
end $$;

-- === RPC: get_daily_sheet_full =============================================
create or replace function get_daily_sheet_full(p_sheet_id uuid)
returns jsonb
language plpgsql
security definer
as $$
declare
  result jsonb;
begin
  with s as (
    select s.*, b.name as branch_name
    from daily_sheets s
    join branches b on b.id = s.branch_id
    where s.id = p_sheet_id
  )
  select jsonb_build_object(
    'header', jsonb_build_object(
      'id', s.id,
      'branch_id', s.branch_id,
      'branch_name', s.branch_name,
      'sheet_date', s.sheet_date,
      'supervisor_name', (select raw_user_meta_data->>'full_name' from auth.users u where u.id = s.supervisor_id),
      'locked', s.locked,
      'total_pastries_income', s.total_pastries_income,
      'yoghurt_section_a_total_volume', s.yoghurt_section_a_total_volume,
      'yoghurt_section_a_total_income', s.yoghurt_section_a_total_income,
      'yoghurt_section_b_total', s.yoghurt_section_b_total,
      'grand_total', s.grand_total,
      'currency_total_cash', s.currency_total_cash,
      'cash_on_hand', s.cash_on_hand,
      'momo_amount', s.momo_amount,
      'cash_balance_delta', s.cash_balance_delta
    ),
    'pastries', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', pl.id,
          'item_name', i.name,
          'qty_received', pl.qty_received,
          'received_from_other_qty', pl.received_from_other_qty,
          'received_from_branch_id', pl.received_from_branch_id,
          'received_from_branch_name', bf.name,
          'transfer_to_other_qty', pl.transfer_to_other_qty,
          'transfer_to_branch_id', pl.transfer_to_branch_id,
          'transfer_to_branch_name', bt.name,
          'qty_sold', pl.qty_sold,
          'unit_price', pl.unit_price,
          'leftovers', pl.leftovers,
          'amount', pl.amount
        )
      )
      from pastry_lines pl
      join items i on i.id = pl.item_id
      left join branches bf on bf.id = pl.received_from_branch_id
      left join branches bt on bt.id = pl.transfer_to_branch_id
      where pl.sheet_id = s.id
    ), '[]'::jsonb),
    'yoghurtHeader', (
      select jsonb_build_object(
        'sheet_id', yh.sheet_id,
        'opening_stock', yh.opening_stock,
        'stock_received', yh.stock_received,
        'total_stock', yh.total_stock,
        'closing_stock', yh.closing_stock
      )
      from yoghurt_headers yh where yh.sheet_id = s.id
    ),
    'yoghurtContainers', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', yc.id,
          'item_name', i.name,
          'volume_factor', yc.volume_factor,
          'qty_sold', yc.qty_sold,
          'volume_sold', yc.volume_sold,
          'unit_price', yc.unit_price,
          'income', yc.income
        )
      )
      from yoghurt_container_lines yc
      join items i on i.id = yc.item_id
      where yc.sheet_id = s.id
    ), '[]'::jsonb),
    'yoghurtRefills', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', yr.id,
          'item_name', i.name,
          'volume_factor', yr.volume_factor,
          'qty_sold', yr.qty_sold,
          'volume_sold', yr.volume_sold,
          'unit_price', yr.unit_price,
          'income', yr.income
        )
      )
      from yoghurt_refill_lines yr
      join items i on i.id = yr.item_id
      where yr.sheet_id = s.id
    ), '[]'::jsonb),
    'yoghurtNonContainer', (
      select jsonb_build_object(
        'id', ync.id,
        'item_name', i.name,
        'unit_price', ync.unit_price,
        'volume_sold', ync.volume_sold,
        'income', ync.income
      )
      from yoghurt_non_container ync
      join items i on i.id = ync.item_id
      where ync.sheet_id = s.id
    ),
    'yoghurtSectionB', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', yb.id,
          'source', yb.source,
          'unit_price', yb.unit_price,
          'qty_sold', yb.qty_sold,
          'income', yb.income
        )
      )
      from yoghurt_section_b_income yb
      where yb.sheet_id = s.id
    ), '[]'::jsonb),
    'materials', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', m.id,
          'item_name', i.name,
          'opening', m.opening,
          'received', m.received,
          'used_normal', m.used_normal,
          'used_spoilt', m.used_spoilt,
          'transferred_out', m.transferred_out,
          'transfer_to_branch_id', m.transfer_to_branch_id,
          'transfer_to_branch_name', bt.name,
          'total_used', m.total_used,
          'closing', m.closing,
          'supervisor_override_reason', m.supervisor_override_reason
        )
      )
      from material_lines m
      join items i on i.id = m.item_id
      left join branches bt on bt.id = m.transfer_to_branch_id
      where m.sheet_id = s.id
    ), '[]'::jsonb),
    'currencyNotes', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', cn.id,
          'denomination', cn.denomination,
          'quantity', cn.quantity,
          'amount', cn.amount
        )
      )
      from currency_notes cn where cn.sheet_id = s.id
    ), '[]'::jsonb),
    'staff', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', st.id,
          'staff_name', st.staff_name
        )
      )
      from staff_attendance st where st.sheet_id = s.id
    ), '[]'::jsonb),
    'expenses', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', ex.id,
          'description', ex.description,
          'amount', ex.amount,
          'created_at', ex.created_at
        )
      )
      from extra_expenses ex where ex.sheet_id = s.id
    ), '[]'::jsonb)
  ) into result
  from s;

  return result;
end;
$$;

-- === RLS ====================================================================
alter table branches enable row level security;
alter table user_profiles enable row level security;
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
alter table audit_logs enable row level security;

create or replace view current_profile as
select * from user_profiles where user_id = auth.uid();

create policy "branches_supervisor_all" on branches
for select using (exists (select 1 from current_profile where role = 'supervisor'));

create policy "branches_branch_user" on branches
for select using (id = (select branch_id from current_profile where role = 'branch_user'));

-- User profile access (self)
create policy "user_profile_self" on user_profiles
for select using (user_id = auth.uid());

create policy "sheets_select_branch" on daily_sheets
for select using (branch_id = (select branch_id from current_profile where role = 'branch_user'));

create policy "sheets_select_supervisor" on daily_sheets
for select using (exists (select 1 from current_profile where role = 'supervisor'));

create or replace function can_edit_sheet(p_sheet daily_sheets)
returns boolean as $$
declare
  prof user_profiles;
begin
  select * into prof from current_profile;
  if prof.role = 'supervisor' then
    return true;
  end if;
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

create policy "sheets_update_branch_user" on daily_sheets
for update using (can_edit_sheet(daily_sheets));

create policy "sheets_update_supervisor" on daily_sheets
for update using (exists (select 1 from current_profile where role = 'supervisor'));

-- Finalize/submit: locks the sheet. Branch users can only submit same-day sheets.
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

-- Helper RPC: get or create today's sheet for the current user/branch
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

    -- Seed all standard line items for this new sheet
    perform seed_sheet_lines(sheet_id);
  end if;

  return sheet_id;
end;
$$;

-- Seed all standard line items for a sheet (pastries, yoghurt, materials, notes)
create or replace function seed_sheet_lines(p_sheet_id uuid)
returns void
language plpgsql
security definer
as $$
declare
  s daily_sheets;
begin
  select * into s from daily_sheets where id = p_sheet_id;
  if not found then
    raise exception 'Sheet % not found', p_sheet_id;
  end if;

  -- Pastries
  insert into pastry_lines (sheet_id, item_id)
  select p_sheet_id, i.id
  from items i
  where i.category = 'pastry'
    and not exists (
      select 1 from pastry_lines pl
      where pl.sheet_id = p_sheet_id and pl.item_id = i.id
    );

  -- Yoghurt containers
  insert into yoghurt_container_lines (sheet_id, item_id)
  select p_sheet_id, i.id
  from items i
  where i.category = 'yoghurt_container'
    and not exists (
      select 1 from yoghurt_container_lines yc
      where yc.sheet_id = p_sheet_id and yc.item_id = i.id
    );

  -- Yoghurt refills
  insert into yoghurt_refill_lines (sheet_id, item_id)
  select p_sheet_id, i.id
  from items i
  where i.category = 'yoghurt_refill'
    and not exists (
      select 1 from yoghurt_refill_lines yr
      where yr.sheet_id = p_sheet_id and yr.item_id = i.id
    );

  -- Yoghurt non-container (one row)
  insert into yoghurt_non_container (sheet_id, item_id)
  select p_sheet_id, i.id
  from items i
  where i.category = 'yoghurt_non_container'
    and not exists (
      select 1 from yoghurt_non_container ync
      where ync.sheet_id = p_sheet_id
    )
  limit 1;

  -- Section B income rows
  insert into yoghurt_section_b_income (sheet_id, source, item_id)
  values (p_sheet_id, 'pastries', null)
  on conflict do nothing;

  insert into yoghurt_section_b_income (sheet_id, source, item_id)
  select p_sheet_id, 'smoothies', i.id
  from items i
  where i.code = 'YOG_SMOOTHIE'
  on conflict do nothing;

  insert into yoghurt_section_b_income (sheet_id, source, item_id)
  select p_sheet_id, 'water', i.id
  from items i
  where i.code = 'YOG_WATER'
  on conflict do nothing;

  -- Materials
  insert into material_lines (sheet_id, item_id)
  select p_sheet_id, i.id
  from items i
  where i.category = 'material'
    and not exists (
      select 1 from material_lines m
      where m.sheet_id = p_sheet_id and m.item_id = i.id
    );

  -- Currency notes
  insert into currency_notes (sheet_id, denomination)
  values
    (p_sheet_id, 200),
    (p_sheet_id, 100),
    (p_sheet_id, 50),
    (p_sheet_id, 20),
    (p_sheet_id, 10),
    (p_sheet_id, 5),
    (p_sheet_id, 1)
  on conflict do nothing;

  -- Yoghurt header
  insert into yoghurt_headers (sheet_id)
  values (p_sheet_id)
  on conflict (sheet_id) do nothing;
end;
$$;

-- Pattern policies for line tables (example pastry_lines)
create policy "pastry_select_branch" on pastry_lines
for select using (sheet_id in (select id from daily_sheets where branch_id = (select branch_id from current_profile where role = 'branch_user')));

create policy "pastry_select_supervisor" on pastry_lines
for select using (exists (select 1 from current_profile where role = 'supervisor'));

create policy "pastry_write_branch" on pastry_lines
for insert with check (sheet_id in (select id from daily_sheets s where can_edit_sheet(s)));

create policy "pastry_write_branch_update" on pastry_lines
for update using (sheet_id in (select id from daily_sheets s where can_edit_sheet(s)));

create policy "pastry_supervisor_all" on pastry_lines
for all using (exists (select 1 from current_profile where role = 'supervisor')) with check (true);

-- Repeat similar policies for other line tables as required.


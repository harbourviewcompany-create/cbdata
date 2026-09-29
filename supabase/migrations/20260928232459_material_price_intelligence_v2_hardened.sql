-- Material Price Intelligence: reusable supplier comparison workflow for estimating.
-- Keeps source evidence, historical observations, and ranked buy plans.

create table if not exists public.material_suppliers (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  supplier_key text not null,
  name text not null,
  region text not null default 'Ottawa, ON',
  website_url text,
  pricing_mode text not null default 'mixed'
    check (pricing_mode in ('live_page','manual_quote','mixed')),
  default_delivery_fee numeric(12,2) check (default_delivery_fee is null or default_delivery_fee >= 0),
  active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(workspace_id,supplier_key)
);

create table if not exists public.material_catalog_items (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  canonical_key text not null,
  category text not null,
  description text not null,
  nominal_size text,
  length_ft numeric(8,2),
  unit text not null default 'each',
  treatment text,
  default_waste_pct numeric(5,2) not null default 5 check (default_waste_pct between 0 and 50),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(workspace_id,canonical_key)
);

create table if not exists public.material_supplier_products (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  material_item_id uuid not null references public.material_catalog_items(id) on delete cascade,
  supplier_id uuid not null references public.material_suppliers(id) on delete cascade,
  supplier_sku text,
  product_name text not null,
  product_url text,
  pricing_mode text not null default 'live_page'
    check (pricing_mode in ('live_page','manual_quote')),
  pack_qty numeric(10,3) not null default 1 check (pack_qty > 0),
  bulk_min_qty numeric(10,3),
  bulk_discount_pct numeric(5,2) check (bulk_discount_pct is null or bulk_discount_pct between 0 and 100),
  active boolean not null default true,
  last_checked_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(workspace_id,material_item_id,supplier_id)
);

create table if not exists public.material_price_observations (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  material_item_id uuid not null references public.material_catalog_items(id) on delete cascade,
  supplier_id uuid not null references public.material_suppliers(id) on delete cascade,
  supplier_product_id uuid references public.material_supplier_products(id) on delete set null,
  price_each numeric(12,4) not null check (price_each >= 0),
  currency text not null default 'CAD',
  stock_status text,
  store_label text,
  bulk_min_qty numeric(10,3),
  bulk_discount_pct numeric(5,2),
  evidence_url text,
  source_type text not null default 'live_page'
    check (source_type in ('live_page','manual_quote','import')),
  confidence text not null default 'medium'
    check (confidence in ('low','medium','high')),
  raw_excerpt text,
  observed_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.material_requests (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  estimate_id uuid references public.estimates(id) on delete set null,
  property_id uuid references public.properties(id) on delete set null,
  name text not null,
  region text not null default 'Ottawa, ON',
  status text not null default 'draft'
    check (status in ('draft','priced','approved','archived')),
  waste_pct numeric(5,2) not null default 5 check (waste_pct between 0 and 50),
  delivery_mode text not null default 'pickup'
    check (delivery_mode in ('pickup','delivery')),
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.material_request_items (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  request_id uuid not null references public.material_requests(id) on delete cascade,
  material_item_id uuid not null references public.material_catalog_items(id) on delete restrict,
  quantity numeric(12,3) not null check (quantity > 0),
  notes text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.material_price_runs (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  request_id uuid not null references public.material_requests(id) on delete cascade,
  status text not null default 'running'
    check (status in ('running','completed','partial','error')),
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  products_checked integer not null default 0,
  fresh_quotes integer not null default 0,
  reused_quotes integer not null default 0,
  errors jsonb not null default '[]'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.material_price_run_results (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  run_id uuid not null references public.material_price_runs(id) on delete cascade,
  request_item_id uuid not null references public.material_request_items(id) on delete cascade,
  supplier_id uuid not null references public.material_suppliers(id) on delete cascade,
  supplier_product_id uuid references public.material_supplier_products(id) on delete set null,
  observation_id uuid references public.material_price_observations(id) on delete set null,
  unit_price numeric(12,4) not null,
  effective_unit_price numeric(12,4) not null,
  quantity_with_waste numeric(12,3) not null,
  extended_price numeric(14,2) not null,
  rank integer,
  stock_status text,
  evidence_url text,
  observed_at timestamptz,
  stale boolean not null default false,
  confidence text not null default 'medium',
  created_at timestamptz not null default now()
);

create table if not exists public.material_price_plans (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  request_id uuid not null references public.material_requests(id) on delete cascade,
  run_id uuid not null references public.material_price_runs(id) on delete cascade,
  plan_type text not null check (plan_type in ('split_cheapest','single_supplier')),
  supplier_id uuid references public.material_suppliers(id) on delete cascade,
  material_subtotal numeric(14,2) not null default 0,
  delivery_total numeric(14,2) not null default 0,
  total numeric(14,2) not null default 0,
  savings_vs_baseline numeric(14,2) not null default 0,
  lines jsonb not null default '[]'::jsonb,
  suppliers jsonb not null default '[]'::jsonb,
  is_selected boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_material_price_observations_lookup
  on public.material_price_observations(workspace_id,material_item_id,supplier_id,observed_at desc);
create index if not exists idx_material_request_items_request
  on public.material_request_items(workspace_id,request_id,sort_order);
create index if not exists idx_material_price_runs_request
  on public.material_price_runs(workspace_id,request_id,started_at desc);
create index if not exists idx_material_price_results_run
  on public.material_price_run_results(workspace_id,run_id,request_item_id,rank);
create index if not exists idx_material_price_plans_run
  on public.material_price_plans(workspace_id,run_id,total);
create unique index if not exists uq_material_price_plans_selected_request
  on public.material_price_plans(request_id) where is_selected;

-- Every FK gets a non-partial covering index so clean replay satisfies the
-- repository-wide performance/security invariant.
create index if not exists idx_fk_material_supplier_products_material_item
  on public.material_supplier_products(material_item_id);
create index if not exists idx_fk_material_supplier_products_supplier
  on public.material_supplier_products(supplier_id);

create index if not exists idx_fk_material_price_observations_material_item
  on public.material_price_observations(material_item_id);
create index if not exists idx_fk_material_price_observations_supplier
  on public.material_price_observations(supplier_id);
create index if not exists idx_fk_material_price_observations_supplier_product
  on public.material_price_observations(supplier_product_id);
create index if not exists idx_fk_material_price_observations_created_by
  on public.material_price_observations(created_by);

create index if not exists idx_fk_material_requests_workspace
  on public.material_requests(workspace_id);
create index if not exists idx_fk_material_requests_estimate
  on public.material_requests(estimate_id);
create index if not exists idx_fk_material_requests_property
  on public.material_requests(property_id);
create index if not exists idx_fk_material_requests_created_by
  on public.material_requests(created_by);

create index if not exists idx_fk_material_request_items_request
  on public.material_request_items(request_id);
create index if not exists idx_fk_material_request_items_material_item
  on public.material_request_items(material_item_id);

create index if not exists idx_fk_material_price_runs_request
  on public.material_price_runs(request_id);
create index if not exists idx_fk_material_price_runs_created_by
  on public.material_price_runs(created_by);

create index if not exists idx_fk_material_price_run_results_run
  on public.material_price_run_results(run_id);
create index if not exists idx_fk_material_price_run_results_request_item
  on public.material_price_run_results(request_item_id);
create index if not exists idx_fk_material_price_run_results_supplier
  on public.material_price_run_results(supplier_id);
create index if not exists idx_fk_material_price_run_results_supplier_product
  on public.material_price_run_results(supplier_product_id);
create index if not exists idx_fk_material_price_run_results_observation
  on public.material_price_run_results(observation_id);

create index if not exists idx_fk_material_price_plans_request
  on public.material_price_plans(request_id);
create index if not exists idx_fk_material_price_plans_run
  on public.material_price_plans(run_id);
create index if not exists idx_fk_material_price_plans_supplier
  on public.material_price_plans(supplier_id);

do $$
declare t text;
begin
  foreach t in array array[
    'material_suppliers','material_catalog_items','material_supplier_products',
    'material_price_observations','material_requests','material_request_items',
    'material_price_runs','material_price_run_results','material_price_plans'
  ]
  loop
    execute format('alter table public.%I enable row level security',t);
    execute format('alter table public.%I force row level security',t);
    execute format('drop policy if exists workspace_member_select on public.%I',t);
    execute format('drop policy if exists workspace_material_operator_insert on public.%I',t);
    execute format('drop policy if exists workspace_material_operator_update on public.%I',t);
    execute format('drop policy if exists workspace_material_operator_delete on public.%I',t);
    execute format('create policy workspace_member_select on public.%I for select to authenticated using (private.is_workspace_member(workspace_id))',t);
    execute format($p$create policy workspace_material_operator_insert on public.%I for insert to authenticated with check (private.has_workspace_role(workspace_id,array['owner','administrator','operations_manager','sales_manager','sales_rep']::public.membership_role[]))$p$,t);
    execute format($p$create policy workspace_material_operator_update on public.%I for update to authenticated using (private.has_workspace_role(workspace_id,array['owner','administrator','operations_manager','sales_manager','sales_rep']::public.membership_role[])) with check (private.has_workspace_role(workspace_id,array['owner','administrator','operations_manager','sales_manager','sales_rep']::public.membership_role[]))$p$,t);
    execute format($p$create policy workspace_material_operator_delete on public.%I for delete to authenticated using (private.has_workspace_role(workspace_id,array['owner','administrator','operations_manager','sales_manager','sales_rep']::public.membership_role[]))$p$,t);
    execute format('revoke all on public.%I from anon',t);
    execute format('grant select,insert,update,delete on public.%I to authenticated',t);
    execute format('grant all on public.%I to service_role',t);
  end loop;
end $$;

create or replace view public.v_material_request_summary
with (security_invoker = true)
as
select
  r.id,
  r.workspace_id,
  r.estimate_id,
  r.property_id,
  r.name,
  r.region,
  r.status,
  r.waste_pct,
  r.delivery_mode,
  r.created_at,
  count(distinct i.id)::integer as item_count,
  lr.id as latest_run_id,
  lr.status as latest_run_status,
  lr.started_at as latest_run_at,
  bp.total as best_total,
  bp.material_subtotal as best_material_subtotal,
  bp.delivery_total as best_delivery_total
from public.material_requests r
left join public.material_request_items i on i.request_id=r.id
left join lateral (
  select pr.id,pr.status,pr.started_at
  from public.material_price_runs pr
  where pr.request_id=r.id
  order by pr.started_at desc
  limit 1
) lr on true
left join lateral (
  select p.total,p.material_subtotal,p.delivery_total
  from public.material_price_plans p
  where p.run_id=lr.id
  order by p.total asc
  limit 1
) bp on true
group by r.id,lr.id,lr.status,lr.started_at,bp.total,bp.material_subtotal,bp.delivery_total;

grant select on public.v_material_request_summary to authenticated;

do $$
declare w uuid;
begin
  select id into w from public.workspaces where slug='cb-contracting' limit 1;
  if w is null then return; end if;

  insert into public.material_suppliers(workspace_id,supplier_key,name,region,website_url,pricing_mode,default_delivery_fee,notes)
  values
    (w,'home-depot','Home Depot','Ottawa, ON','https://www.homedepot.ca','mixed',null,'Live public web price; delivery and Ottawa-store availability require verification.'),
    (w,'rona','RONA','Ottawa, ON','https://www.rona.ca','mixed',null,'Live public web price; delivery and Ottawa-store availability require verification.'),
    (w,'perkins','Perkins Home Building Centre','Ottawa, ON','https://www.homehardware.ca','manual_quote',null,'Contractor desk / manual quote source; capture delivery in the supplier record when verified.'),
    (w,'bmr-richmond','BMR Richmond','Ottawa, ON','https://www.bmr.ca','manual_quote',null,'Contractor desk / manual quote source; capture delivery in the supplier record when verified.')
  on conflict(workspace_id,supplier_key) do update set
    name=excluded.name,region=excluded.region,website_url=excluded.website_url,
    pricing_mode=excluded.pricing_mode,notes=excluded.notes,updated_at=now();

  insert into public.material_catalog_items(workspace_id,canonical_key,category,description,nominal_size,length_ft,unit,treatment,default_waste_pct)
  values
    (w,'pt-5-4x6x8','decking','5/4 × 6 × 8 pressure-treated deck board','5/4 × 6',8,'each','pressure treated',5),
    (w,'pt-5-4x6x10','decking','5/4 × 6 × 10 pressure-treated deck board','5/4 × 6',10,'each','pressure treated',5),
    (w,'pt-5-4x6x12','decking','5/4 × 6 × 12 pressure-treated deck board','5/4 × 6',12,'each','pressure treated',5),
    (w,'pt-5-4x6x16','decking','5/4 × 6 × 16 pressure-treated deck board','5/4 × 6',16,'each','pressure treated',5),
    (w,'pt-2x6x8','framing','2 × 6 × 8 pressure-treated lumber','2 × 6',8,'each','pressure treated',5),
    (w,'pt-2x6x10','framing','2 × 6 × 10 pressure-treated lumber','2 × 6',10,'each','pressure treated',5),
    (w,'pt-2x6x12','framing','2 × 6 × 12 pressure-treated lumber','2 × 6',12,'each','pressure treated',5),
    (w,'pt-2x6x16','framing','2 × 6 × 16 pressure-treated lumber','2 × 6',16,'each','pressure treated',5),
    (w,'pt-2x8x8','framing','2 × 8 × 8 pressure-treated lumber','2 × 8',8,'each','pressure treated',5),
    (w,'pt-2x8x10','framing','2 × 8 × 10 pressure-treated lumber','2 × 8',10,'each','pressure treated',5),
    (w,'pt-2x8x12','framing','2 × 8 × 12 pressure-treated lumber','2 × 8',12,'each','pressure treated',5),
    (w,'pt-2x8x16','framing','2 × 8 × 16 pressure-treated lumber','2 × 8',16,'each','pressure treated',5),
    (w,'pt-4x4x8','posts','4 × 4 × 8 pressure-treated post','4 × 4',8,'each','pressure treated',3),
    (w,'pt-4x4x10','posts','4 × 4 × 10 pressure-treated post','4 × 4',10,'each','pressure treated',3),
    (w,'pt-4x4x12','posts','4 × 4 × 12 pressure-treated post','4 × 4',12,'each','pressure treated',3)
  on conflict(workspace_id,canonical_key) do update set
    category=excluded.category,description=excluded.description,nominal_size=excluded.nominal_size,
    length_ft=excluded.length_ft,treatment=excluded.treatment,default_waste_pct=excluded.default_waste_pct,
    active=true,updated_at=now();

  insert into public.material_supplier_products(
    workspace_id,material_item_id,supplier_id,product_name,product_url,pricing_mode,bulk_min_qty,bulk_discount_pct
  )
  select
    w,c.id,s.id,
    case
      when s.supplier_key='home-depot' then
        case c.canonical_key
          when 'pt-5-4x6x8' then 'Pressure Treated 5/4 x 6 x 8 Premium Wood Decking'
          when 'pt-5-4x6x10' then 'Pressure Treated 5/4 x 6 x 10 Premium Wood Decking'
          when 'pt-5-4x6x12' then 'Pressure Treated 5/4 x 6 x 12 Premium Wood Decking'
          when 'pt-5-4x6x16' then 'Pressure Treated 5/4 x 6 x 16 Premium Wood Decking'
          else replace(c.description,'pressure-treated','Pressure Treated')
        end
      else replace(c.description,'pressure-treated','Brown Pressure Treated')
    end,
    case when s.supplier_key='home-depot'
      then 'https://www.homedepot.ca/s/en/home/categories/building-materials/lumber-and-composites/pressure-treated-material'
      else 'https://www.rona.ca/en/building-supplies-and-materials/lumber-and-composites/pressure-treated-lumber'
    end,
    'manual_quote',
    case
      when s.supplier_key='home-depot' and c.canonical_key like 'pt-5-4x6%' then 128
      when s.supplier_key='home-depot' and c.canonical_key like 'pt-2x6%' then 96
      else null
    end,
    case
      when s.supplier_key='home-depot' and (c.canonical_key like 'pt-5-4x6%' or c.canonical_key like 'pt-2x6%') then 10
      else null
    end
  from public.material_catalog_items c
  join public.material_suppliers s on s.workspace_id=w and s.supplier_key in ('home-depot','rona')
  where c.workspace_id=w and c.canonical_key like 'pt-%'
  on conflict(workspace_id,material_item_id,supplier_id) do update set
    product_name=excluded.product_name,product_url=excluded.product_url,pricing_mode=excluded.pricing_mode,
    bulk_min_qty=excluded.bulk_min_qty,bulk_discount_pct=excluded.bulk_discount_pct,active=true,updated_at=now();
end $$;


-- Hardening: engine-computed artifacts are read-only to authenticated users.
do $$
declare t text;
begin
  foreach t in array array['material_price_runs','material_price_run_results','material_price_plans']
  loop
    execute format('drop policy if exists workspace_material_operator_insert on public.%I',t);
    execute format('drop policy if exists workspace_material_operator_update on public.%I',t);
    execute format('drop policy if exists workspace_material_operator_delete on public.%I',t);
    execute format('revoke insert,update,delete on public.%I from authenticated',t);
  end loop;
end $$;

-- Cross-workspace references are rejected even when the caller has valid access
-- to the row workspace.
create or replace function private.guard_material_workspace_integrity()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_material_item uuid;
begin
  if tg_table_name='material_supplier_products' then
    if not exists (select 1 from public.material_catalog_items x where x.id=new.material_item_id and x.workspace_id=new.workspace_id)
       or not exists (select 1 from public.material_suppliers x where x.id=new.supplier_id and x.workspace_id=new.workspace_id) then
      raise exception 'Material product references must belong to the same workspace';
    end if;

  elsif tg_table_name='material_price_observations' then
    if not exists (select 1 from public.material_catalog_items x where x.id=new.material_item_id and x.workspace_id=new.workspace_id)
       or not exists (select 1 from public.material_suppliers x where x.id=new.supplier_id and x.workspace_id=new.workspace_id) then
      raise exception 'Material observation references must belong to the same workspace';
    end if;
    if new.supplier_product_id is not null and not exists (
      select 1 from public.material_supplier_products x
      where x.id=new.supplier_product_id
        and x.workspace_id=new.workspace_id
        and x.material_item_id=new.material_item_id
        and x.supplier_id=new.supplier_id
    ) then
      raise exception 'Supplier product does not match observation workspace/material/supplier';
    end if;

  elsif tg_table_name='material_requests' then
    if new.estimate_id is not null and not exists (
      select 1 from public.estimates x where x.id=new.estimate_id and x.workspace_id=new.workspace_id
    ) then
      raise exception 'Estimate does not belong to material request workspace';
    end if;
    if new.property_id is not null and not exists (
      select 1 from public.properties x where x.id=new.property_id and x.workspace_id=new.workspace_id
    ) then
      raise exception 'Property does not belong to material request workspace';
    end if;

  elsif tg_table_name='material_request_items' then
    if not exists (
      select 1 from public.material_requests x where x.id=new.request_id and x.workspace_id=new.workspace_id
    ) or not exists (
      select 1 from public.material_catalog_items x where x.id=new.material_item_id and x.workspace_id=new.workspace_id
    ) then
      raise exception 'Request item references must belong to the same workspace';
    end if;

  elsif tg_table_name='material_price_runs' then
    if not exists (
      select 1 from public.material_requests x where x.id=new.request_id and x.workspace_id=new.workspace_id
    ) then
      raise exception 'Price run request does not belong to the same workspace';
    end if;

  elsif tg_table_name='material_price_run_results' then
    select ri.material_item_id into v_material_item
    from public.material_price_runs r
    join public.material_request_items ri
      on ri.request_id=r.request_id and ri.workspace_id=r.workspace_id
    where r.id=new.run_id
      and ri.id=new.request_item_id
      and r.workspace_id=new.workspace_id;

    if v_material_item is null then
      raise exception 'Price result run/request item relationship is invalid';
    end if;
    if not exists (
      select 1 from public.material_suppliers x where x.id=new.supplier_id and x.workspace_id=new.workspace_id
    ) then
      raise exception 'Price result supplier does not belong to the same workspace';
    end if;
    if new.supplier_product_id is not null and not exists (
      select 1 from public.material_supplier_products x
      where x.id=new.supplier_product_id
        and x.workspace_id=new.workspace_id
        and x.material_item_id=v_material_item
        and x.supplier_id=new.supplier_id
    ) then
      raise exception 'Price result supplier product does not match request item';
    end if;
    if new.observation_id is not null and not exists (
      select 1 from public.material_price_observations x
      where x.id=new.observation_id
        and x.workspace_id=new.workspace_id
        and x.material_item_id=v_material_item
        and x.supplier_id=new.supplier_id
    ) then
      raise exception 'Price result observation does not match request item/supplier';
    end if;

  elsif tg_table_name='material_price_plans' then
    if not exists (
      select 1 from public.material_price_runs r
      where r.id=new.run_id
        and r.workspace_id=new.workspace_id
        and r.request_id=new.request_id
    ) then
      raise exception 'Price plan run/request relationship is invalid';
    end if;
    if new.supplier_id is not null and not exists (
      select 1 from public.material_suppliers x where x.id=new.supplier_id and x.workspace_id=new.workspace_id
    ) then
      raise exception 'Price plan supplier does not belong to the same workspace';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function private.guard_material_workspace_integrity() from public, anon, authenticated;

do $$
declare t text;
begin
  foreach t in array array[
    'material_supplier_products','material_price_observations','material_requests',
    'material_request_items','material_price_runs','material_price_run_results','material_price_plans'
  ]
  loop
    execute format('drop trigger if exists guard_material_workspace_integrity on public.%I',t);
    execute format(
      'create trigger guard_material_workspace_integrity before insert or update on public.%I for each row execute function private.guard_material_workspace_integrity()',
      t
    );
  end loop;
end $$;

-- Any takeoff change invalidates the approved/current plan automatically.
create or replace function private.invalidate_material_request_pricing()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_request_id uuid := coalesce(new.request_id,old.request_id);
  v_workspace_id uuid := coalesce(new.workspace_id,old.workspace_id);
begin
  perform set_config('app.material_request_transition','invalidate',true);

  update public.material_price_plans
  set is_selected=false
  where workspace_id=v_workspace_id
    and request_id=v_request_id
    and is_selected;

  update public.material_requests
  set status='draft',updated_at=now()
  where workspace_id=v_workspace_id
    and id=v_request_id
    and status<>'draft';

  return coalesce(new,old);
end;
$$;

revoke all on function private.invalidate_material_request_pricing() from public, anon, authenticated;

drop trigger if exists invalidate_material_request_pricing on public.material_request_items;
create trigger invalidate_material_request_pricing
after insert or update or delete on public.material_request_items
for each row execute function private.invalidate_material_request_pricing();

create or replace function private.guard_material_request_status()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_mode text := coalesce(current_setting('app.material_request_transition',true),'');
begin
  if old.workspace_id is distinct from new.workspace_id
     or old.id is distinct from new.id
     or old.created_by is distinct from new.created_by
     or old.created_at is distinct from new.created_at then
    raise exception 'Material request identity fields are immutable';
  end if;

  if old.status is distinct from new.status then
    if new.status='approved' and v_mode<>'approve' then
      raise exception 'Material plans must be approved through select_material_price_plan';
    elsif new.status='priced' and coalesce(auth.role(),'')<>'service_role' then
      raise exception 'Only the pricing engine can mark a material request priced';
    elsif new.status='draft' and v_mode<>'invalidate' and old.status='approved' then
      raise exception 'Approved material requests return to draft only after a takeoff change';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function private.guard_material_request_status() from public, anon, authenticated;

drop trigger if exists guard_material_request_status on public.material_requests;
create trigger guard_material_request_status
before update on public.material_requests
for each row execute function private.guard_material_request_status();

create or replace function public.select_material_price_plan(
  p_request_id uuid,
  p_plan_id uuid
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_workspace_id uuid;
  v_delivery_mode text;
  v_plan public.material_price_plans%rowtype;
  v_latest_run uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select r.workspace_id,r.delivery_mode
  into v_workspace_id,v_delivery_mode
  from public.material_requests r
  where r.id=p_request_id
  for update;

  if v_workspace_id is null or not private.has_workspace_role(
    v_workspace_id,
    array['owner','administrator','operations_manager','sales_manager','sales_rep']::public.membership_role[]
  ) then
    raise exception 'Material request unavailable';
  end if;

  select pr.id into v_latest_run
  from public.material_price_runs pr
  where pr.workspace_id=v_workspace_id
    and pr.request_id=p_request_id
    and pr.status in ('completed','partial')
  order by pr.started_at desc
  limit 1;

  select p.* into v_plan
  from public.material_price_plans p
  where p.id=p_plan_id
    and p.workspace_id=v_workspace_id
    and p.request_id=p_request_id
    and p.run_id=v_latest_run;

  if not found then
    raise exception 'Plan must belong to the latest completed pricing run';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(v_plan.lines) line
    where coalesce((line->>'stale')::boolean,false)
  ) then
    raise exception 'Stale price evidence must be refreshed before approval';
  end if;

  if v_delivery_mode='delivery' and exists (
    select 1
    from jsonb_array_elements(v_plan.suppliers) supplier
    where coalesce((supplier->>'delivery_verified')::boolean,false)=false
  ) then
    raise exception 'Verify delivery fees before approving a delivery plan';
  end if;

  perform set_config('app.material_request_transition','approve',true);

  update public.material_price_plans
  set is_selected=(id=p_plan_id)
  where workspace_id=v_workspace_id
    and request_id=p_request_id
    and (is_selected or id=p_plan_id);

  update public.material_requests
  set status='approved',updated_at=now()
  where workspace_id=v_workspace_id and id=p_request_id;
end;
$$;

revoke all on function public.select_material_price_plan(uuid,uuid) from public, anon;
grant execute on function public.select_material_price_plan(uuid,uuid) to authenticated;

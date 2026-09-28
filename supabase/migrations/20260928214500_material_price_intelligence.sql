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
  default_delivery_fee numeric(12,2) not null default 0 check (default_delivery_fee >= 0),
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
    (w,'home-depot','Home Depot','Ottawa, ON','https://www.homedepot.ca','mixed',79,'Live public web price plus store quote verification.'),
    (w,'rona','RONA','Ottawa, ON','https://www.rona.ca','mixed',79,'Live public web price plus store quote verification.'),
    (w,'perkins','Perkins Home Building Centre','Ottawa, ON','https://www.homehardware.ca','manual_quote',0,'Contractor desk / manual quote source.'),
    (w,'bmr-richmond','BMR Richmond','Ottawa, ON','https://www.bmr.ca','manual_quote',0,'Contractor desk / manual quote source.')
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
    'live_page',
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

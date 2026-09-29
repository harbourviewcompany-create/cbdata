alter table public.material_price_observations
  add column if not exists valid_until date;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.material_price_observations'::regclass
      and conname='material_price_observations_valid_until_check'
  ) then
    alter table public.material_price_observations
      add constraint material_price_observations_valid_until_check
      check (valid_until is null or valid_until >= observed_at::date);
  end if;
end $$;

create table if not exists public.material_request_supplier_terms (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  request_id uuid not null references public.material_requests(id) on delete cascade,
  supplier_id uuid not null references public.material_suppliers(id) on delete cascade,
  delivery_fee numeric(12,2) check (delivery_fee is null or delivery_fee >= 0),
  delivery_verified boolean not null default false,
  quote_reference text,
  valid_until date,
  evidence_url text,
  notes text,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(workspace_id,request_id,supplier_id)
);

create index if not exists idx_fk_material_request_supplier_terms_workspace
  on public.material_request_supplier_terms(workspace_id);
create index if not exists idx_fk_material_request_supplier_terms_request
  on public.material_request_supplier_terms(request_id);
create index if not exists idx_fk_material_request_supplier_terms_supplier
  on public.material_request_supplier_terms(supplier_id);
create index if not exists idx_fk_material_request_supplier_terms_updated_by
  on public.material_request_supplier_terms(updated_by);

alter table public.material_request_supplier_terms enable row level security;
alter table public.material_request_supplier_terms force row level security;

drop policy if exists workspace_member_select on public.material_request_supplier_terms;
drop policy if exists workspace_material_operator_insert on public.material_request_supplier_terms;
drop policy if exists workspace_material_operator_update on public.material_request_supplier_terms;
drop policy if exists workspace_material_operator_delete on public.material_request_supplier_terms;

create policy workspace_member_select
  on public.material_request_supplier_terms
  for select to authenticated
  using (private.is_workspace_member(workspace_id));

create policy workspace_material_operator_insert
  on public.material_request_supplier_terms
  for insert to authenticated
  with check (
    private.has_workspace_role(
      workspace_id,
      array['owner','administrator','operations_manager','sales_manager','sales_rep']::public.membership_role[]
    )
  );

create policy workspace_material_operator_update
  on public.material_request_supplier_terms
  for update to authenticated
  using (
    private.has_workspace_role(
      workspace_id,
      array['owner','administrator','operations_manager','sales_manager','sales_rep']::public.membership_role[]
    )
  )
  with check (
    private.has_workspace_role(
      workspace_id,
      array['owner','administrator','operations_manager','sales_manager','sales_rep']::public.membership_role[]
    )
  );

create policy workspace_material_operator_delete
  on public.material_request_supplier_terms
  for delete to authenticated
  using (
    private.has_workspace_role(
      workspace_id,
      array['owner','administrator','operations_manager','sales_manager','sales_rep']::public.membership_role[]
    )
  );

revoke all on public.material_request_supplier_terms from anon;
grant select,insert,update,delete on public.material_request_supplier_terms to authenticated;
grant all on public.material_request_supplier_terms to service_role;

create or replace function private.guard_material_request_supplier_terms()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if not exists (
    select 1 from public.material_requests r
    where r.id=new.request_id and r.workspace_id=new.workspace_id
  ) then
    raise exception 'Supplier terms request does not belong to the same workspace';
  end if;
  if not exists (
    select 1 from public.material_suppliers s
    where s.id=new.supplier_id and s.workspace_id=new.workspace_id
  ) then
    raise exception 'Supplier terms supplier does not belong to the same workspace';
  end if;
  if new.delivery_verified and new.delivery_fee is null then
    raise exception 'Verified delivery requires a delivery fee';
  end if;
  if new.valid_until is not null and new.valid_until < current_date then
    new.delivery_verified := false;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

revoke all on function private.guard_material_request_supplier_terms() from public, anon, authenticated;

drop trigger if exists guard_material_request_supplier_terms on public.material_request_supplier_terms;
create trigger guard_material_request_supplier_terms
before insert or update on public.material_request_supplier_terms
for each row execute function private.guard_material_request_supplier_terms();

drop trigger if exists invalidate_material_request_pricing on public.material_request_supplier_terms;
create trigger invalidate_material_request_pricing
after insert or update or delete on public.material_request_supplier_terms
for each row execute function private.invalidate_material_request_pricing();

with w as (
  select id from public.workspaces where slug='cb-contracting' limit 1
), hd as (
  select id from public.material_suppliers
  where workspace_id=(select id from w) and supplier_key='home-depot'
), mapping(canonical_key,sku,url,bulk_min,bulk_pct) as (
  values
    ('pt-5-4x6x8','1000680745','https://www.homedepot.ca/product/1000680745',128::numeric,10::numeric),
    ('pt-5-4x6x10','1000680741','https://www.homedepot.ca/product/1000680741',128,10),
    ('pt-5-4x6x12','1000680736','https://www.homedepot.ca/product/1000680736',128,10),
    ('pt-5-4x6x16','1000680731','https://www.homedepot.ca/product/1000680731',128,10),
    ('pt-2x6x8','1000790084','https://www.homedepot.ca/product/1000790084',96,10),
    ('pt-2x6x10','1000789781','https://www.homedepot.ca/product/1000789781',96,10),
    ('pt-2x6x12','1000790082','https://www.homedepot.ca/product/1000790082',96,10),
    ('pt-2x6x16','1000790085','https://www.homedepot.ca/product/1000790085',96,10),
    ('pt-2x8x8','1000790210','https://www.homedepot.ca/product/1000790210',72,10),
    ('pt-2x8x10','1000790209','https://www.homedepot.ca/product/1000790209',72,10),
    ('pt-2x8x12','1000790208','https://www.homedepot.ca/product/1000790208',72,10),
    ('pt-2x8x16','1000790206','https://www.homedepot.ca/product/1000790206',72,10),
    ('pt-4x4x8','1000790178','https://www.homedepot.ca/product/1000790178',78,10),
    ('pt-4x4x10','1000790080','https://www.homedepot.ca/product/1000790080',78,10),
    ('pt-4x4x12','1000790394','https://www.homedepot.ca/product/1000790394',78,10)
)
update public.material_supplier_products p
set supplier_sku=m.sku,
    product_url=m.url,
    pricing_mode='live_page',
    bulk_min_qty=m.bulk_min,
    bulk_discount_pct=m.bulk_pct,
    last_error=null,
    updated_at=now()
from mapping m
join public.material_catalog_items c
  on c.workspace_id=(select id from w) and c.canonical_key=m.canonical_key
where p.workspace_id=(select id from w)
  and p.supplier_id=(select id from hd)
  and p.material_item_id=c.id;

with w as (
  select id from public.workspaces where slug='cb-contracting' limit 1
), rs as (
  select id from public.material_suppliers
  where workspace_id=(select id from w) and supplier_key='rona'
), mapping(canonical_key,sku,url) as (
  values
    ('pt-5-4x6x8','84895016','https://www.rona.ca/en/product/P84895016'),
    ('pt-5-4x6x10','84895017','https://www.rona.ca/en/product/P84895017'),
    ('pt-5-4x6x12','84895018','https://www.rona.ca/en/product/P84895018'),
    ('pt-5-4x6x16','84895020','https://www.rona.ca/en/product/P84895020'),
    ('pt-2x6x8','84895026','https://www.rona.ca/en/product/P84895026'),
    ('pt-2x6x10','84895027','https://www.rona.ca/en/product/P84895027'),
    ('pt-2x6x12','84895028','https://www.rona.ca/en/product/P84895028'),
    ('pt-2x6x16','84895053','https://www.rona.ca/en/product/P84895053'),
    ('pt-2x8x8','84895030','https://www.rona.ca/en/product/P84895030'),
    ('pt-2x8x10','84895031','https://www.rona.ca/en/product/P84895031'),
    ('pt-2x8x12','84895032','https://www.rona.ca/en/product/P84895032'),
    ('pt-2x8x16','84895034','https://www.rona.ca/en/product/P84895034'),
    ('pt-4x4x8','84895043','https://www.rona.ca/en/product/P84895043'),
    ('pt-4x4x10','84895044','https://www.rona.ca/en/product/P84895044'),
    ('pt-4x4x12','84895054','https://www.rona.ca/en/product/P84895054')
)
update public.material_supplier_products p
set supplier_sku=m.sku,
    product_url=m.url,
    pricing_mode='live_page',
    bulk_min_qty=null,
    bulk_discount_pct=null,
    last_error=null,
    updated_at=now()
from mapping m
join public.material_catalog_items c
  on c.workspace_id=(select id from w) and c.canonical_key=m.canonical_key
where p.workspace_id=(select id from w)
  and p.supplier_id=(select id from rs)
  and p.material_item_id=c.id;

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
  bp.delivery_total as best_delivery_total,
  sp.id as selected_plan_id,
  sp.total as selected_total,
  sp.material_subtotal as selected_material_subtotal,
  sp.delivery_total as selected_delivery_total
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
left join lateral (
  select p.id,p.total,p.material_subtotal,p.delivery_total
  from public.material_price_plans p
  where p.request_id=r.id and p.is_selected
  limit 1
) sp on true
group by r.id,lr.id,lr.status,lr.started_at,bp.total,bp.material_subtotal,bp.delivery_total,
  sp.id,sp.total,sp.material_subtotal,sp.delivery_total;

grant select on public.v_material_request_summary to authenticated;

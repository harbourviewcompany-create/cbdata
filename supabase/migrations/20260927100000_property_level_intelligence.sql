create table if not exists public.property_intelligence (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  property_id uuid not null unique references public.properties(id) on delete cascade,
  building_count integer,
  unit_count integer,
  floor_count integer,
  estimated_sqft numeric,
  lot_area_sqft numeric,
  parking_spaces integer,
  construction_year integer,
  property_class text,
  ownership_type text,
  occupancy_signal text,
  exterior_scope text,
  grounds_scope text,
  snow_scope text,
  janitorial_scope text,
  capital_projects_signal text,
  vendor_signal text,
  procurement_signal text,
  seasonal_priority text,
  access_complexity text,
  liability_signal text,
  intelligence_score numeric,
  intelligence_summary text,
  primary_source_url text,
  primary_source_label text,
  data_confidence text,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (building_count is null or building_count >= 0),
  check (unit_count is null or unit_count >= 0),
  check (floor_count is null or floor_count >= 0),
  check (estimated_sqft is null or estimated_sqft >= 0),
  check (lot_area_sqft is null or lot_area_sqft >= 0),
  check (parking_spaces is null or parking_spaces >= 0),
  check (construction_year is null or construction_year between 1700 and 2200),
  check (intelligence_score is null or intelligence_score between 0 and 100)
);

create table if not exists public.property_intelligence_sources (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  property_id uuid not null references public.properties(id) on delete cascade,
  source_type text not null,
  source_url text,
  source_title text,
  observed_at timestamptz not null default now(),
  published_at date,
  summary text,
  confidence text,
  raw_payload jsonb,
  created_at timestamptz not null default now()
);

create index if not exists property_intelligence_workspace_idx
  on public.property_intelligence(workspace_id);
create index if not exists property_intelligence_sources_property_idx
  on public.property_intelligence_sources(property_id, observed_at desc);

alter table public.property_intelligence enable row level security;
alter table public.property_intelligence_sources enable row level security;

drop policy if exists workspace_member_select on public.property_intelligence;
drop policy if exists workspace_member_insert on public.property_intelligence;
drop policy if exists workspace_member_update on public.property_intelligence;
create policy workspace_member_select on public.property_intelligence for select
  using (private.is_workspace_member(workspace_id));
create policy workspace_member_insert on public.property_intelligence for insert
  with check (private.is_workspace_member(workspace_id));
create policy workspace_member_update on public.property_intelligence for update
  using (private.is_workspace_member(workspace_id))
  with check (private.is_workspace_member(workspace_id));

drop policy if exists workspace_member_select on public.property_intelligence_sources;
drop policy if exists workspace_member_insert on public.property_intelligence_sources;
drop policy if exists workspace_member_update on public.property_intelligence_sources;
create policy workspace_member_select on public.property_intelligence_sources for select
  using (private.is_workspace_member(workspace_id));
create policy workspace_member_insert on public.property_intelligence_sources for insert
  with check (private.is_workspace_member(workspace_id));
create policy workspace_member_update on public.property_intelligence_sources for update
  using (private.is_workspace_member(workspace_id))
  with check (private.is_workspace_member(workspace_id));

create or replace view public.v_property_intelligence
with (security_invoker=true) as
select
  p.id as property_id,p.workspace_id,p.name,p.address_line_1,p.address_line_2,
  p.city,p.province,p.postal_code,p.property_type,p.status,
  p.owner_organization_id,p.management_organization_id,p.primary_customer_organization_id,
  coalesce(pi.building_count,bc.building_count) as building_count,
  pi.unit_count,pi.floor_count,pi.estimated_sqft,pi.lot_area_sqft,pi.parking_spaces,
  pi.construction_year,pi.property_class,pi.ownership_type,pi.occupancy_signal,
  pi.exterior_scope,pi.grounds_scope,pi.snow_scope,pi.janitorial_scope,
  pi.capital_projects_signal,pi.vendor_signal,pi.procurement_signal,
  pi.seasonal_priority,pi.access_complexity,pi.liability_signal,
  pi.intelligence_score,pi.intelligence_summary,pi.primary_source_url,
  pi.primary_source_label,pi.data_confidence,pi.verified_at,
  coalesce(bc.floor_count,0) as known_floor_count,
  coalesce(pc.contact_count,0) as contact_count,
  coalesce(pr.permit_count,0) as permit_count,
  coalesce(pr.recent_permit_count,0) as recent_permit_count,
  coalesce(pr.recent_permit_value,0) as recent_permit_value
from public.properties p
left join public.property_intelligence pi on pi.property_id=p.id
left join (
  select property_id,count(*)::int building_count,max(floors)::int floor_count
  from public.buildings group by property_id
) bc on bc.property_id=p.id
left join (
  select property_id,count(*)::int contact_count
  from public.property_contacts group by property_id
) pc on pc.property_id=p.id
left join (
  select matched_property_id property_id,count(*)::int permit_count,
    count(*) filter (where filed_date >= current_date - interval '730 days')::int recent_permit_count,
    coalesce(sum(estimated_value) filter (where filed_date >= current_date - interval '730 days'),0) recent_permit_value
  from public.permit_records
  where matched_property_id is not null
  group by matched_property_id
) pr on pr.property_id=p.id
where p.archived_at is null;

grant select on public.v_property_intelligence to authenticated;
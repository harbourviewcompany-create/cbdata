-- Add Crown Realty Partners as an event-driven commercial management target.
-- Sources:
-- https://www.crownrealtypartners.com/news/crown-expands-ottawa-property-management-portfolio-with-minto-place
-- https://www.crownrealtypartners.com/news/crown-announces-sale-of-ottawa-office-portfolio-to-brasswater-retaining-property-management-and-leasing-mandate
-- Idempotent against organization name, target/list and property name.

insert into public.organizations(
  workspace_id,legal_name,operating_name,organization_type,status,website,phone,email,
  primary_region,service_regions,hq_city,hq_province,hq_address_line_1,source_notes
)
select
  '431aa13d-3e7c-41e3-9686-e840b8ea5b7c'::uuid,
  'Crown Realty Partners','Crown Realty Partners','property_manager','active',
  'https://www.crownrealtypartners.com','343-572-5488','swatson@crp-cpmi.com',
  'Ottawa',array['Ottawa'],'Ottawa','ON','300 Sparks Street, Suite 320',
  'Official Crown sources identify Scott Watson as Managing Partner leading property management and operations and document the July 2026 Minto Place appointment.'
where not exists(
  select 1 from public.organizations o
  where o.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
    and coalesce(o.operating_name,o.legal_name)='Crown Realty Partners'
);

insert into public.organizations(
  workspace_id,legal_name,operating_name,organization_type,status,website,primary_region,service_regions,source_notes
)
select
  '431aa13d-3e7c-41e3-9686-e840b8ea5b7c'::uuid,
  'Brasswater Inc.','Brasswater Inc.','owner','active',
  'https://brasswater.com','Ottawa',array['Ottawa'],
  'Crown announced May 28, 2026 that Brasswater acquired the 1525/1545/1565 Carling Avenue three-building 290,000 sq ft office portfolio while Crown retained property management and leasing.'
where not exists(
  select 1 from public.organizations o
  where o.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
    and coalesce(o.operating_name,o.legal_name)='Brasswater Inc.'
);

insert into public.outreach_targets(
  workspace_id,outreach_list_id,organization_name,contact_name,phone,email,property_address,status,
  organization_id,region,score,score_reason,next_action,priority,notes,company_phone,company_email,
  company_website,company_address
)
select
  '431aa13d-3e7c-41e3-9686-e840b8ea5b7c'::uuid,
  'a15af411-9b05-4b7b-9e5b-9da4909b1dcf'::uuid,
  'Crown Realty Partners','Scott Watson','343-572-5488','swatson@crp-cpmi.com','Ottawa','queued',
  o.id, 'Ottawa',92,
  'July 2026 management appointment at 950,000 sq ft Minto Place plus retained management of a 290,000 sq ft Carling portfolio after the May 2026 ownership transfer.',
  'Map Minto Place and Carling service scope; identify incumbent grounds, snow and janitorial vendors and renewal windows.',
  'high',
  'Event-driven commercial management target. Official Crown sources document Minto Place modernization and retained Carling management.',
  '343-572-5488','swatson@crp-cpmi.com','https://www.crownrealtypartners.com','300 Sparks Street, Suite 320, Ottawa, ON K1A 0J6'
from public.organizations o
where o.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
  and coalesce(o.operating_name,o.legal_name)='Crown Realty Partners'
  and not exists(
    select 1 from public.outreach_targets t
    where t.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
      and t.organization_id=o.id
      and t.outreach_list_id='a15af411-9b05-4b7b-9e5b-9da4909b1dcf'::uuid
  );

insert into public.properties(
  workspace_id,name,address_line_1,city,province,country,property_type,status,
  owner_organization_id,management_organization_id,site_notes
)
select
  '431aa13d-3e7c-41e3-9686-e840b8ea5b7c'::uuid,
  'Minto Place','180 Kent Street / 427 Laurier Avenue West / 344 Slater Street',
  'Ottawa','ON','Canada','commercial','prospect',
  (select id from public.organizations where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and coalesce(operating_name,legal_name)='Brasswater Inc.' limit 1),
  (select id from public.organizations where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and coalesce(operating_name,legal_name)='Crown Realty Partners' limit 1),
  'Three-building downtown complex; Crown announced July 6, 2026 appointment and modernization/reintroduction of 180 Kent Street.'
where not exists(select 1 from public.properties p where p.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and p.name='Minto Place');

insert into public.properties(
  workspace_id,name,address_line_1,city,province,country,property_type,status,
  owner_organization_id,management_organization_id,site_notes
)
select
  '431aa13d-3e7c-41e3-9686-e840b8ea5b7c'::uuid,
  'Crown — Carling Avenue Office Portfolio','1525, 1545 & 1565 Carling Avenue',
  'Ottawa','ON','Canada','commercial','prospect',
  (select id from public.organizations where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and coalesce(operating_name,legal_name)='Brasswater Inc.' limit 1),
  (select id from public.organizations where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and coalesce(operating_name,legal_name)='Crown Realty Partners' limit 1),
  'Three-building 290,000 sq ft office portfolio acquired by Brasswater in May 2026; Crown retained property management and leasing.'
where not exists(select 1 from public.properties p where p.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and p.name='Crown — Carling Avenue Office Portfolio');

insert into public.property_intelligence(
  workspace_id,property_id,building_count,estimated_sqft,property_class,ownership_type,
  grounds_scope,snow_scope,janitorial_scope,capital_projects_signal,vendor_signal,
  procurement_signal,seasonal_priority,access_complexity,liability_signal,intelligence_score,
  intelligence_summary,primary_source_url,primary_source_label,data_confidence,verified_at
)
select
  p.workspace_id,p.id,3,case when p.name='Minto Place' then 950000 else 290000 end,
  'commercial','institutional_owner_with_professional_manager',
  'large commercial grounds and public-realm/common-area maintenance',
  'large office snow and ice route with pedestrian/tenant exposure',
  'large office common-area janitorial and tenant-facing service scope',
  case when p.name='Minto Place' then '180 Kent Street modernization: lobby/common spaces, amenities and sustainability initiatives' else 'More than $2.3M in capital improvements since 2019; management retained after ownership transfer' end,
  'Crown provides integrated property management, operations, construction and tenant-experience services',
  'professional property-management vendor route; identify incumbent exterior/janitorial contracts and renewal windows',
  'winter',
  case when p.name='Minto Place' then 'three-tower downtown complex with retail, amenities and transit adjacency' else 'three-building office portfolio on Carling corridor' end,
  'downtown/high-traffic office complex or large office corridor exposure',
  case when p.name='Minto Place' then 97 else 93 end,
  case when p.name='Minto Place' then '950,000 sq ft, three-building downtown complex with active modernization mandate and new property manager.' else '290,000 sq ft three-building office portfolio; ownership changed in 2026 while Crown retained property management and leasing.' end,
  case when p.name='Minto Place' then 'https://www.crownrealtypartners.com/news/crown-expands-ottawa-property-management-portfolio-with-minto-place' else 'https://www.crownrealtypartners.com/news/crown-announces-sale-of-ottawa-office-portfolio-to-brasswater-retaining-property-management-and-leasing-mandate' end,
  'Crown Realty Partners official 2026 portfolio announcement','high',now()
from public.properties p
where p.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
  and p.name in ('Minto Place','Crown — Carling Avenue Office Portfolio')
  and not exists(select 1 from public.property_intelligence pi where pi.property_id=p.id);

insert into public.property_intelligence_sources(
  workspace_id,property_id,source_type,source_url,source_title,summary,confidence
)
select
  p.workspace_id,p.id,'official_website',
  case when p.name='Minto Place' then 'https://www.crownrealtypartners.com/news/crown-expands-ottawa-property-management-portfolio-with-minto-place'
       else 'https://www.crownrealtypartners.com/news/crown-announces-sale-of-ottawa-office-portfolio-to-brasswater-retaining-property-management-and-leasing-mandate' end,
  'Crown Realty Partners 2026 official announcement',
  case when p.name='Minto Place' then 'Crown appointed to manage a 950,000 sq ft three-building downtown Ottawa complex; modernization begins with 180 Kent Street.'
       else 'Brasswater acquired the 290,000 sq ft three-building Carling office portfolio and Crown retained property management and leasing.' end,
  'high'
from public.properties p
where p.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
  and p.name in ('Minto Place','Crown — Carling Avenue Office Portfolio')
  and not exists(select 1 from public.property_intelligence_sources s where s.property_id=p.id);

insert into public.outreach_target_properties(
  workspace_id,outreach_target_id,property_id,relationship_type,is_primary
)
select
  p.workspace_id,t.id,p.id,'management_site',false
from public.properties p
join public.outreach_targets t
  on t.workspace_id=p.workspace_id
 and t.organization_id=p.management_organization_id
 and t.outreach_list_id='a15af411-9b05-4b7b-9e5b-9da4909b1dcf'::uuid
where p.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
  and p.name in ('Minto Place','Crown — Carling Avenue Office Portfolio')
  and not exists(select 1 from public.outreach_target_properties x where x.outreach_target_id=t.id and x.property_id=p.id);
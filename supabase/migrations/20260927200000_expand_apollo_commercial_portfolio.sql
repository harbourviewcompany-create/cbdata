-- Expand Apollo's Ottawa commercial portfolio with official portfolio evidence.
-- Source: https://apollomgt.com/portfolio/
-- Safe on a fresh database: production workspace/organization IDs are resolved only when present.

create temporary table tmp_apollo_commercial(
  name text,address text,city text,postal text,sqft integer,score integer,summary text
) on commit drop;

insert into tmp_apollo_commercial values
('Apollo — 1111 Prince of Wales','1111 Prince of Wales Drive','Ottawa',null,70000,90,'70,000 sq ft commercial office property in Apollo’s current official portfolio.'),
('Apollo — 1200 Prince of Wales','1200 Prince of Wales Drive','Ottawa',null,15000,84,'15,000 sq ft retail property in Apollo’s current official portfolio.'),
('Apollo — 430 Hazeldean','430 Hazeldean Road','Ottawa',null,60000,91,'60,000 sq ft industrial and retail property in Apollo’s current official portfolio.'),
('Apollo — 5510 Canotek','5510 Canotek Road','Ottawa',null,40000,89,'40,000 sq ft office and industrial property in Apollo’s current official portfolio.'),
('Apollo — 170 Metcalfe','170 Metcalfe Street','Ottawa',null,40000,91,'40,000 sq ft commercial office and retail property in Apollo’s current official portfolio.'),
('Apollo — 372-382 Rideau','372-382 Rideau Street','Ottawa',null,8000,82,'8,000 sq ft retail property in Apollo’s current official portfolio.'),
('Apollo — 18 Antares','18 Antares Drive','Ottawa',null,20000,86,'20,000 sq ft office property in Apollo’s current official portfolio.'),
('Apollo — 46 Antares','46 Antares Drive','Ottawa',null,25000,87,'25,000 sq ft industrial and retail property in Apollo’s current official portfolio.'),
('Apollo — 330 Gilmour','330 Gilmour Avenue','Ottawa',null,44200,90,'44,200 sq ft office property in Apollo’s current official portfolio.'),
('Apollo — Post Office Plaza','3rd Street & 4th Street','Ottawa',null,31200,89,'31,200 sq ft mixed retail, office and residential property in Apollo’s current official portfolio.'),
('Apollo — Central Park Plaza','1234 Merivale Road','Ottawa',null,13500,84,'13,500 sq ft retail and office property in Apollo’s current official portfolio.'),
('Apollo — 214 Montreal','214 Montreal Road','Ottawa',null,null,80,'Office property in Apollo’s current official portfolio.'),
('Apollo — 2949-2951 Carling','2949-2951 Carling Avenue','Ottawa',null,4800,81,'4,800 sq ft retail property in Apollo’s current official portfolio.'),
('Apollo — 406-408 Bank','406 & 408 Bank Street','Ottawa',null,3000,80,'3,000 sq ft retail and residential property in Apollo’s current official portfolio.'),
('Apollo — 9-11 Florence','9 & 11 Florence Street','Ottawa',null,1900,79,'1,900 sq ft mixed retail, office and residential property in Apollo’s current official portfolio.'),
('Apollo — 340 Catherine','340 Catherine Street','Ottawa',null,9100,82,'9,100 sq ft retail property in Apollo’s current official portfolio.'),
('Apollo — 194-200 Greenbank','194-200 Greenbank Road','Ottawa',null,4500,81,'4,500 sq ft retail property in Apollo’s current official portfolio.'),
('Apollo — Berlin Property','168-170 Rideau Street, 339-409 Dalhousie Street, 133 Besserer Street','Ottawa',null,20000,90,'20,000 sq ft multi-address retail property in Apollo’s current official portfolio.'),
('Apollo — 70 Bentley','70 Bentley Avenue','Ottawa',null,60000,92,'60,000 sq ft retail, office and warehouse property in Apollo’s current official portfolio.'),
('Apollo — 65 Bentley','65 Bentley Avenue','Ottawa',null,55000,92,'55,000 sq ft retail, office and warehouse property in Apollo’s current official portfolio.'),
('Apollo — 88 Jamie','88 Jamie Street','Ottawa',null,30000,87,'30,000 sq ft office property in Apollo’s current official portfolio.'),
('Apollo — 361 Elgin','361 Elgin Street','Ottawa',null,20000,86,'20,000 sq ft retail property in Apollo’s current official portfolio.'),
('Apollo — 220 Elgin','220 Elgin Street','Ottawa',null,10000,84,'10,000 sq ft retail property in Apollo’s current official portfolio.'),
('Apollo — 80 Elgin','80 Elgin Street','Ottawa',null,20000,87,'20,000 sq ft office property in Apollo’s current official portfolio.'),
('Apollo — 54 York','54 York Street','Ottawa',null,null,80,'Retail property in Apollo’s current official portfolio.'),
('Apollo — 261 Centerpointe','261 Centerpointe Drive','Ottawa',null,null,82,'Retail property in Apollo’s current official portfolio.'),
('Apollo — 2555 St Joseph','2555 St. Joseph Blvd.','Ottawa',null,null,83,'Commercial office and retail property in Apollo’s current official portfolio.'),
('Apollo — 570 Industrial','570 Industrial Avenue','Ottawa',null,null,82,'Commercial office and retail property in Apollo’s current official portfolio.'),
('Apollo — Arts Court','10 Daly Avenue','Ottawa',null,null,86,'Commercial property at Arts Court in Apollo’s current official portfolio.'),
('Apollo — 4366 Innes','4366 Innes Road','Ottawa',null,null,82,'Retail property in Apollo’s current official portfolio.'),
('Apollo — Britannia Plaza','1463-1495 Richmond Road, 359-373 Poulin Avenue, 2648-2664 Priscilla Street','Ottawa',null,55000,92,'55,000 sq ft retail portfolio across three connected address groups in Apollo’s current official portfolio.'),
('Apollo — Ottawa Police Association','141 Catherine Street','Ottawa',null,null,85,'Commercial office property for the Ottawa Police Association in Apollo’s current official portfolio.');

insert into public.properties(
  workspace_id,name,address_line_1,city,province,country,property_type,status,
  owner_organization_id,management_organization_id
)
select
  ws.id,s.name,s.address,s.city,'ON','Canada','commercial','prospect'::property_status,
  case when exists (select 1 from public.organizations o where o.id='044a899b-e5ba-4ca7-a7f9-1c78f11ec3e7'::uuid) then '044a899b-e5ba-4ca7-a7f9-1c78f11ec3e7'::uuid end,
  case when exists (select 1 from public.organizations o where o.id='044a899b-e5ba-4ca7-a7f9-1c78f11ec3e7'::uuid) then '044a899b-e5ba-4ca7-a7f9-1c78f11ec3e7'::uuid end
from public.workspaces ws
cross join tmp_apollo_commercial s
where not exists (
  select 1 from public.properties p
  where p.workspace_id=ws.id and p.name=s.name
);

insert into public.property_intelligence(
  workspace_id,property_id,building_count,estimated_sqft,property_class,ownership_type,
  grounds_scope,snow_scope,janitorial_scope,capital_projects_signal,vendor_signal,
  procurement_signal,seasonal_priority,access_complexity,liability_signal,intelligence_score,
  intelligence_summary,primary_source_url,primary_source_label,data_confidence,verified_at
)
select
  p.workspace_id,p.id,1,s.sqft,'commercial','owner_or_management_portfolio',
  'commercial grounds and exterior maintenance',
  'commercial winter snow and ice service route',
  'commercial common-area cleaning',
  'property-level capital/project scope should be confirmed with Apollo',
  'Apollo documents comprehensive maintenance plans and capital-project services',
  'property manager / owner procurement route; confirm current vendor roster',
  'winter',
  'property-specific access requirements to confirm',
  'commercial public-facing premises; confirm loading/parking/traffic exposure',
  s.score,s.summary,
  'https://apollomgt.com/portfolio/','Apollo Property Management official portfolio',
  'high',now()
from public.properties p
join tmp_apollo_commercial s on s.name=p.name
where not exists(select 1 from public.property_intelligence pi where pi.property_id=p.id);

insert into public.property_intelligence_sources(
  workspace_id,property_id,source_type,source_url,source_title,summary,confidence
)
select
  p.workspace_id,p.id,'official_website',
  'https://apollomgt.com/portfolio/',
  'Apollo Property Management official portfolio',
  s.summary,'high'
from public.properties p
join tmp_apollo_commercial s on s.name=p.name
where not exists(
  select 1 from public.property_intelligence_sources x
  where x.property_id=p.id and x.source_url='https://apollomgt.com/portfolio/'
);

insert into public.outreach_target_properties(
  workspace_id,outreach_target_id,property_id,relationship_type,is_primary
)
select
  p.workspace_id,
  'c645cd3f-1d90-4439-a016-b8b5c601a762'::uuid,
  p.id,'management_site',false
from public.properties p
where p.name like 'Apollo — %'
  and exists(select 1 from public.outreach_targets ot where ot.id='c645cd3f-1d90-4439-a016-b8b5c601a762'::uuid)
  and not exists(
    select 1 from public.outreach_target_properties x
    where x.outreach_target_id='c645cd3f-1d90-4439-a016-b8b5c601a762'::uuid
      and x.property_id=p.id
  );
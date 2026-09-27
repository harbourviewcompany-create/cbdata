-- Add Metcalfe Realty's verified Ottawa commercial portfolio and operations contact.
-- Official source: https://metcalfe.ca/
-- Idempotent by organization/target/property canonical names.

insert into public.organizations(workspace_id,legal_name,operating_name,organization_type,status,website,phone,email,primary_region,service_regions,hq_city,hq_province,hq_address_line_1,source_notes)
select '431aa13d-3e7c-41e3-9686-e840b8ea5b7c'::uuid,'Metcalfe Realty Company Limited','Metcalfe Realty','property_manager','active','https://metcalfe.ca','613-563-4442','mshore@metcalferealty.com','Ottawa',array['Ottawa'],'Ottawa','ON','130 Albert St #210','Official Metcalfe sources identify a 20+ property / 1.6M+ sq ft commercial portfolio with integrated Leasing, Construction, Operations and Finance divisions. Mario Martel is Director of Operations; Mike Shore is VP Leasing.';

insert into public.outreach_targets(workspace_id,outreach_list_id,organization_name,contact_name,phone,email,property_address,status,organization_id,region,score,score_reason,next_action,priority,notes,company_phone,company_email,company_website,company_address)
select '431aa13d-3e7c-41e3-9686-e840b8ea5b7c'::uuid,'a15af411-9b05-4b7b-9e5b-9da4909b1dcf'::uuid,'Metcalfe Realty','Mario Martel','613-563-4442',null,'Ottawa','queued',o.id,'Ottawa',91,'20+ property / 1.6M+ sq ft integrated commercial portfolio with dedicated operations, construction and finance functions.','Identify current exterior, snow and janitorial vendors across the portfolio; use Mario Martel for operations routing and Mike Shore for leasing/property context.','high','Official team page identifies Mario Martel as Director of Operations. Mike Shore has public direct email mshore@metcalferealty.com.','613-563-4442','mshore@metcalferealty.com','https://metcalfe.ca','130 Albert St #210, Ottawa, ON K1P 5G4'
from public.organizations o
where o.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and coalesce(o.operating_name,o.legal_name)='Metcalfe Realty'
and not exists(select 1 from public.outreach_targets t where t.organization_id=o.id and t.outreach_list_id='a15af411-9b05-4b7b-9e5b-9da4909b1dcf'::uuid);

create temporary table tmp_metcalfe(name text,address text,score int,summary text) on commit drop;
insert into tmp_metcalfe values
('Metcalfe — Killeany Place','150 Isabella Street',94,'Large downtown office property with 13 floors plus basement levels, underground and surface parking, on-site engineering/maintenance and daily cleaning.'),
('Metcalfe — Varette Building','130 Albert Street',90,'Downtown office property with current leasing activity and transit adjacency.'),
('Metcalfe — MacDonald Building','123 Slater Street',91,'Downtown office property with renovated lobby/common areas and parking operations.'),
('Metcalfe — 7 Hinton Avenue','7 Hinton Avenue North',87,'Commercial office property with 62-space parking operation.'),
('Metcalfe — Fuller Building','75 Albert Street',91,'Downtown office/retail property with parking and active leasing inventory.'),
('Metcalfe — 161 Greenbank Road','161 Greenbank Road',87,'Suburban office property with 77-space indoor parking operation.'),
('Metcalfe — 700 Industrial Avenue','700 Industrial Avenue',90,'Office/warehouse property with active leasing inventory and free parking.'),
('Metcalfe — 151 Slater Street','151 Slater Street',91,'Downtown office/retail property with 149-space garage operation.'),
('Metcalfe — 2680 Queensview Drive','2680 Queensview Drive',88,'Suburban office/warehouse property in Metcalfe portfolio.'),
('Metcalfe — 1523 Laperriere Avenue','1523 Laperriere Avenue',84,'Warehouse property with tenant parking operation.'),
('Metcalfe — Beacon Hill Shopping Centre','2339 Ogilvie Road',90,'Retail property with active tenant parking and leasing operations.'),
('Metcalfe — 2650 Queensview Drive','2650 Queensview Drive',89,'Suburban office property with underground and surface tenant parking and active leasing.');

insert into public.properties(workspace_id,name,address_line_1,city,province,country,property_type,status,management_organization_id,site_notes)
select '431aa13d-3e7c-41e3-9686-e840b8ea5b7c'::uuid,s.name,s.address,'Ottawa','ON','Canada','commercial','prospect',o.id,'Verified against Metcalfe Realty official portfolio/property pages.'
from tmp_metcalfe s cross join (select id from public.organizations where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and coalesce(operating_name,legal_name)='Metcalfe Realty' limit 1) o
where not exists(select 1 from public.properties p where p.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and p.name=s.name);

insert into public.property_intelligence(workspace_id,property_id,building_count,property_class,ownership_type,grounds_scope,snow_scope,janitorial_scope,capital_projects_signal,vendor_signal,procurement_signal,seasonal_priority,access_complexity,liability_signal,intelligence_score,intelligence_summary,primary_source_url,primary_source_label,data_confidence,verified_at)
select p.workspace_id,p.id,1,'commercial','professional_property_manager','commercial grounds and exterior maintenance','commercial snow and ice service','office/retail common-area cleaning','Metcalfe has dedicated construction and operations divisions; property-level capital scope should be confirmed','integrated operations and maintenance model; incumbent vendor roster should be identified','route through Director of Operations / property operations; confirm vendor renewal windows','winter','parking/loading/tenant access varies by property','commercial tenant and pedestrian exposure',s.score,s.summary,'https://metcalfe.ca/properties/','Metcalfe Realty official property portfolio','high',now()
from public.properties p join tmp_metcalfe s on s.name=p.name
where not exists(select 1 from public.property_intelligence pi where pi.property_id=p.id);

insert into public.property_intelligence_sources(workspace_id,property_id,source_type,source_url,source_title,summary,confidence)
select p.workspace_id,p.id,'official_website','https://metcalfe.ca/properties/','Metcalfe Realty official property portfolio',s.summary,'high'
from public.properties p join tmp_metcalfe s on s.name=p.name
where not exists(select 1 from public.property_intelligence_sources x where x.property_id=p.id and x.source_url='https://metcalfe.ca/properties/');

insert into public.outreach_target_properties(workspace_id,outreach_target_id,property_id,relationship_type,is_primary)
select p.workspace_id,t.id,p.id,'management_site',false
from public.properties p join public.outreach_targets t on t.organization_id=p.management_organization_id and t.outreach_list_id='a15af411-9b05-4b7b-9e5b-9da4909b1dcf'::uuid
where p.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and p.name like 'Metcalfe — %'
and not exists(select 1 from public.outreach_target_properties x where x.outreach_target_id=t.id and x.property_id=p.id);
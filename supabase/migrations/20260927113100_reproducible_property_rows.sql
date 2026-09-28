-- Reproducible verified property rows and intelligence.
-- Safe to rerun: each property/intelligence row is resolved by workspace + canonical name/address.
with seed(name,address_line_1,city,province,postal_code,property_type,owner_name,customer_name,manager_name,summary,source_url,source_label) as (
values
('90 George','90 George St','Ottawa','ON','K1N 0A8','condominium','90 George — OCSCC 815','90 George — OCSCC 815',null,'Large condominium property with front desk, extensive amenities and an identified board plus property manager.','https://90georgeliving.com/contact/','90 George official contact page'),
('Gatespark Private — OCCCEC 677','Gatespark Private','Ottawa','ON','K2T 1K9','condominium','Gatespark Private — OCCCEC 677',null,null,'Common-elements condo community with board-managed winter maintenance and shared private-road/parking/infrastructure scope.','https://www.gatesparkpvtkanata.com/general-information/documents','Gatespark mandatory corporation documents'),
('377 Dalhousie Street','377 Dalhousie St','Ottawa','ON',null,'commercial','Golpro Holdings',null,'Golpro Holdings','Owner-managed commercial building with 70,000+ sq ft and mixed retail/office tenant profile.','https://old.golproholdings.com/managed-properties.html','Golpro managed properties'),
('830 Campbell Avenue','830 Campbell Ave','Ottawa','ON',null,'commercial','Golpro Holdings',null,'Golpro Holdings','Owner-managed commercial site with approximately 23,919 sq ft building area on a 36,155 sq ft site.','https://creative.previews.rebel.com/available-spaces.html','Golpro recent properties'),
('Killeany Place','150 Isabella St','Ottawa','ON','K1S 1V7','commercial','Metcalfe Realty',null,'Metcalfe Realty','Large office property with documented daily full-service cleaning, on-site engineering/management, substantial parking and 151,129 rentable sq ft.','https://metcalfe.ca/blog/property/150-isabella-street/','Metcalfe Realty property specification'),
('2181 Ogilvie Road','2181 Ogilvie Rd','Ottawa','ON','K1J 8Y7','commercial','The Properties Group',null,'The Properties Group','Commercial property with documented rear delivery access and active leasing.','https://thepropertiesgroup.ca/property/2181-ogilvie-road/','The Properties Group property page')
), new_props as (
insert into public.properties(workspace_id,name,address_line_1,city,province,postal_code,country,property_type,status,owner_organization_id,primary_customer_organization_id,management_organization_id)
select '431aa13d-3e7c-41e3-9686-e840b8ea5b7c'::uuid,s.name,s.address_line_1,s.city,s.province,s.postal_code,'Canada',s.property_type,'prospect'::property_status,
(select o.id from public.organizations o where o.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and coalesce(o.operating_name,o.legal_name)=s.owner_name limit 1),
(select o.id from public.organizations o where o.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and coalesce(o.operating_name,o.legal_name)=s.customer_name limit 1),
(select o.id from public.organizations o where o.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and coalesce(o.operating_name,o.legal_name)=s.manager_name limit 1)
from seed s cross join public.workspaces ws where ws.id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'::uuid and not exists(select 1 from public.properties p where p.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and p.name=s.name and p.address_line_1=s.address_line_1)
returning id
)
insert into public.property_intelligence(workspace_id,property_id,building_count,estimated_sqft,lot_area_sqft,parking_spaces,property_class,ownership_type,grounds_scope,snow_scope,janitorial_scope,capital_projects_signal,vendor_signal,procurement_signal,seasonal_priority,access_complexity,liability_signal,intelligence_score,intelligence_summary,primary_source_url,primary_source_label,data_confidence,verified_at)
select '431aa13d-3e7c-41e3-9686-e840b8ea5b7c'::uuid,p.id,
case s.name when 'Killeany Place' then 2 else 1 end,
case s.name when '377 Dalhousie Street' then 70000 when '830 Campbell Avenue' then 23919 when 'Killeany Place' then 151129 when '2181 Ogilvie Road' then 1766 end,
case s.name when '830 Campbell Avenue' then 36155 end,
case s.name when 'Killeany Place' then 285 end,s.property_type,
case when s.name in ('90 George','Gatespark Private — OCCCEC 677') then 'condominium_corporation' else 'owner_operator' end,
case when s.name='Gatespark Private — OCCCEC 677' then 'common-element private road / visitor parking / shared infrastructure' end,
case when s.name='Gatespark Private — OCCCEC 677' then 'documented winter maintenance contract' end,
case when s.name='Killeany Place' then 'daily full-service cleaning for all tenancies' end,
case when s.name='Killeany Place' then 'energy-saving lighting and water-conservation retrofits documented' end,
case when s.name in ('377 Dalhousie Street','830 Campbell Avenue') then 'owner-managed property evidence' when s.name='Killeany Place' then 'on-site engineer and building manager' when s.name='Gatespark Private — OCCCEC 677' then 'board-managed winter maintenance' end,
case when s.name='Gatespark Private — OCCCEC 677' then 'board-managed contract' end,
case when s.name='Gatespark Private — OCCCEC 677' then 'winter' end,
case when s.name='2181 Ogilvie Road' then 'rear delivery access' when s.name='Killeany Place' then 'multi-level office/parking complex' end,
case when s.name='90 George' then 'pool/hot tub, terrace, car wash and residential common areas' when s.name='Killeany Place' then 'high-rise office / parking / public-facing amenities' end,
case s.name when 'Killeany Place' then 92 when '377 Dalhousie Street' then 88 when '830 Campbell Avenue' then 84 when 'Gatespark Private — OCCCEC 677' then 82 when '90 George' then 80 when '2181 Ogilvie Road' then 76 end,
s.summary,s.source_url,s.source_label,'high',now()
from public.properties p join seed s on s.name=p.name and s.address_line_1=p.address_line_1
where p.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
and not exists(select 1 from public.property_intelligence pi where pi.property_id=p.id);
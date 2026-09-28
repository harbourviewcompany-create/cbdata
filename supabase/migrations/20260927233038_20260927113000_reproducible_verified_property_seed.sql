-- Reproducible verified property evidence, target links, and test-fixture cleanup.
insert into public.property_intelligence_sources (workspace_id,property_id,source_type,source_url,source_title,summary,confidence)
select p.workspace_id,p.id,'official_website',s.source_url,s.source_title,s.summary,'high'
from (values
('90 George','90 George St','https://90georgeliving.com/contact/','90 George official contact page','Large condominium property with front desk, extensive amenities and an identified board plus property manager.'),
('Gatespark Private — OCCCEC 677','Gatespark Private','https://www.gatesparkpvtkanata.com/general-information/documents','Gatespark mandatory corporation documents','Common-elements condo community with board-managed winter maintenance and shared private-road/parking/infrastructure scope.'),
('377 Dalhousie Street','377 Dalhousie St','https://old.golproholdings.com/managed-properties.html','Golpro managed properties','Owner-managed commercial building with 70,000+ sq ft and mixed retail/office tenant profile.'),
('830 Campbell Avenue','830 Campbell Ave','https://creative.previews.rebel.com/available-spaces.html','Golpro recent properties','Owner-managed commercial site with approximately 23,919 sq ft building area on a 36,155 sq ft site.'),
('Killeany Place','150 Isabella St','https://metcalfe.ca/blog/property/150-isabella-street/','Metcalfe Realty property specification','Large office property with documented daily full-service cleaning, on-site engineering/management, substantial parking and 151,129 rentable sq ft.'),
('2181 Ogilvie Road','2181 Ogilvie Rd','https://thepropertiesgroup.ca/property/2181-ogilvie-road/','The Properties Group property page','Commercial property with documented rear delivery access and active leasing.')
) s(name,address_line_1,source_url,source_title,summary)
join public.properties p on p.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and p.name=s.name and p.address_line_1=s.address_line_1
where not exists (select 1 from public.property_intelligence_sources x where x.property_id=p.id and x.source_url=s.source_url);

insert into public.outreach_target_properties(workspace_id,outreach_target_id,property_id,relationship_type,is_primary)
select t.workspace_id,t.id,p.id,case when p.name in ('90 George','Gatespark Private — OCCCEC 677') then 'board_site' else 'owned_or_managed_site' end,true
from public.outreach_targets t join public.properties p on p.workspace_id=t.workspace_id
where t.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
and t.organization_id=p.owner_organization_id
and p.name in ('90 George','Gatespark Private — OCCCEC 677','377 Dalhousie Street','830 Campbell Avenue','Killeany Place','2181 Ogilvie Road')
and not exists (select 1 from public.outreach_target_properties x where x.outreach_target_id=t.id and x.property_id=p.id);

update public.properties
set status='archived'::property_status,archived_at=coalesce(archived_at,now()),updated_at=now()
where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and name='test' and address_line_1='123 abc st';
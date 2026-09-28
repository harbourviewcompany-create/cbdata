-- Institutional facilities/operations routing from current official sources.
insert into public.contacts(workspace_id,first_name,last_name,job_title,email,phone,status,notes,source_url,source_label,source_confidence,source_verified_at)
select o.workspace_id,'George','Zigoumis','Senior Director, Facilities — Asset Management, Planning, Design and Real Estate',null,'613-562-5700','active',
'University of Ottawa Facilities official page identifies George Zigoumis as director and assigns asset management, planning, design, real estate and large-scale development responsibilities. Direct personal email is not published on the source.',
'https://www.uottawa.ca/about-us/administration-services/facilities/about-us','University of Ottawa Facilities official page','high',now()
from public.organizations o where o.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and coalesce(o.operating_name,o.legal_name)='University of Ottawa'
and not exists(select 1 from public.contacts c where c.workspace_id=o.workspace_id and c.first_name='George' and c.last_name='Zigoumis');

insert into public.contacts(workspace_id,first_name,last_name,job_title,email,phone,status,notes,source_url,source_label,source_confidence,source_verified_at)
select o.workspace_id,'Jacques','Nadeau','Senior Director, Facilities — Integrated Operations Delivery',null,'613-562-5700','active',
'University of Ottawa Facilities/Sustainability governance source identifies Jacques Nadeau as Senior Director for Facilities Integrated Operations Delivery.',
'https://www.uottawa.ca/campus-life/campus-sustainability/governance/suscom-members','University of Ottawa facilities governance page','high',now()
from public.organizations o where o.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and coalesce(o.operating_name,o.legal_name)='University of Ottawa'
and not exists(select 1 from public.contacts c where c.workspace_id=o.workspace_id and c.first_name='Jacques' and c.last_name='Nadeau');

insert into public.contacts(workspace_id,first_name,last_name,job_title,email,phone,status,notes,source_url,source_label,source_confidence,source_verified_at)
select o.workspace_id,'John','Clements','Associate Vice-President, Facilities Management and Planning','John.Clements3@carleton.ca','613-852-0012','active',
'Carleton Facilities Management and Planning official contact page. Oversees a department covering planning/design/construction, energy/sustainability and operations/maintenance.',
'https://carleton.ca/fmp/contact/','Carleton Facilities Management and Planning official contact page','high',now()
from public.organizations o where o.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and coalesce(o.operating_name,o.legal_name)='Carleton University'
and not exists(select 1 from public.contacts c where c.workspace_id=o.workspace_id and c.first_name='John' and c.last_name='Clements');

insert into public.contacts(workspace_id,first_name,last_name,job_title,email,phone,status,notes,source_url,source_label,source_confidence,source_verified_at)
select o.workspace_id,'Chad','McKenzie','Director, Campus Services','Chad.Mckenzie@carleton.ca','613-520-2600 ext. 8400','active',
'Current Carleton Campus Services leadership profile. Campus Services provides facilities/services support; FMP is the more direct property/maintenance route.',
'https://carleton.ca/campus-services/profile/chad-mckenzie/','Carleton Campus Services official profile','high',now()
from public.organizations o where o.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and coalesce(o.operating_name,o.legal_name)='Carleton University'
and not exists(select 1 from public.contacts c where c.workspace_id=o.workspace_id and c.first_name='Chad' and c.last_name='McKenzie');

insert into public.contacts(workspace_id,first_name,last_name,job_title,email,phone,status,notes,source_url,source_label,source_confidence,source_verified_at)
select o.workspace_id,'Joanne','Read','Executive Vice-President and Chief Planning and Development Officer','Joanne.Read@toh.ca','613-798-5555 ext. 10964','active',
'Current Ottawa Hospital leadership page states Joanne Read leads redevelopment, facilities management, emergency operations and strategic master/capital plans.',
'https://www.ottawahospital.on.ca/en/who-we-are/our-leadership-team/joanne-read','The Ottawa Hospital current leadership profile','high',now()
from public.organizations o where o.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and coalesce(o.operating_name,o.legal_name)='The Ottawa Hospital'
and not exists(select 1 from public.contacts c where c.workspace_id=o.workspace_id and c.first_name='Joanne' and c.last_name='Read');

insert into public.contacts(workspace_id,first_name,last_name,job_title,email,phone,status,notes,source_url,source_label,source_confidence,source_verified_at)
select o.workspace_id,'Randy','Gerrior','Associate Director of Education, Business Operations',null,'613-596-8211','active',
'OCDSB official leadership materials identify Randy Gerrior in Business Operations. The Facilities Department separately documents facilities operations, maintenance and construction responsibilities. No direct email was published in the current source.',
'https://www.ocdsb.ca/about-us/senior-leadership','Ottawa-Carleton District School Board senior leadership','high',now()
from public.organizations o where o.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and coalesce(o.operating_name,o.legal_name)='Ottawa-Carleton District School Board'
and not exists(select 1 from public.contacts c where c.workspace_id=o.workspace_id and c.first_name='Randy' and c.last_name='Gerrior');

insert into public.organization_contacts(workspace_id,organization_id,contact_id,relationship_type,is_primary)
select o.workspace_id,o.id,c.id,'facilities_asset_management',true from public.organizations o join public.contacts c on c.workspace_id=o.workspace_id and c.first_name='George' and c.last_name='Zigoumis' where coalesce(o.operating_name,o.legal_name)='University of Ottawa' and not exists(select 1 from public.organization_contacts x where x.organization_id=o.id and x.contact_id=c.id);
insert into public.organization_contacts(workspace_id,organization_id,contact_id,relationship_type,is_primary)
select o.workspace_id,o.id,c.id,'facilities_operations',false from public.organizations o join public.contacts c on c.workspace_id=o.workspace_id and c.first_name='Jacques' and c.last_name='Nadeau' where coalesce(o.operating_name,o.legal_name)='University of Ottawa' and not exists(select 1 from public.organization_contacts x where x.organization_id=o.id and x.contact_id=c.id);
insert into public.organization_contacts(workspace_id,organization_id,contact_id,relationship_type,is_primary)
select o.workspace_id,o.id,c.id,'facilities_management_planning',true from public.organizations o join public.contacts c on c.workspace_id=o.workspace_id and c.first_name='John' and c.last_name='Clements' where coalesce(o.operating_name,o.legal_name)='Carleton University' and not exists(select 1 from public.organization_contacts x where x.organization_id=o.id and x.contact_id=c.id);
insert into public.organization_contacts(workspace_id,organization_id,contact_id,relationship_type,is_primary)
select o.workspace_id,o.id,c.id,'campus_services',false from public.organizations o join public.contacts c on c.workspace_id=o.workspace_id and c.first_name='Chad' and c.last_name='McKenzie' where coalesce(o.operating_name,o.legal_name)='Carleton University' and not exists(select 1 from public.organization_contacts x where x.organization_id=o.id and x.contact_id=c.id);
insert into public.organization_contacts(workspace_id,organization_id,contact_id,relationship_type,is_primary)
select o.workspace_id,o.id,c.id,'redevelopment_facilities_capital',true from public.organizations o join public.contacts c on c.workspace_id=o.workspace_id and c.first_name='Joanne' and c.last_name='Read' where coalesce(o.operating_name,o.legal_name)='The Ottawa Hospital' and not exists(select 1 from public.organization_contacts x where x.organization_id=o.id and x.contact_id=c.id);
insert into public.organization_contacts(workspace_id,organization_id,contact_id,relationship_type,is_primary)
select o.workspace_id,o.id,c.id,'business_operations',true from public.organizations o join public.contacts c on c.workspace_id=o.workspace_id and c.first_name='Randy' and c.last_name='Gerrior' where coalesce(o.operating_name,o.legal_name)='Ottawa-Carleton District School Board' and not exists(select 1 from public.organization_contacts x where x.organization_id=o.id and x.contact_id=c.id);

update public.outreach_targets t set contact_id=c.id,contact_name=c.first_name||' '||c.last_name,phone=coalesce(t.phone,c.phone),email=coalesce(t.email,c.email),updated_at=now()
from public.organizations o join public.contacts c on c.workspace_id=o.workspace_id
where t.workspace_id=o.workspace_id and t.organization_id=o.id and t.contact_id is null and t.status in ('queued','contacted','responded')
and ((coalesce(o.operating_name,o.legal_name)='University of Ottawa' and c.first_name='George' and c.last_name='Zigoumis')
 or (coalesce(o.operating_name,o.legal_name)='Carleton University' and c.first_name='John' and c.last_name='Clements')
 or (coalesce(o.operating_name,o.legal_name)='The Ottawa Hospital' and c.first_name='Joanne' and c.last_name='Read')
 or (coalesce(o.operating_name,o.legal_name)='Ottawa-Carleton District School Board' and c.first_name='Randy' and c.last_name='Gerrior'));

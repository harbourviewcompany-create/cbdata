insert into public.organizations (workspace_id,legal_name,operating_name,organization_type,status,website,phone,email,primary_region,hq_city,hq_province,source_notes)
select '431aa13d-3e7c-41e3-9686-e840b8ea5b7c','Algonquin College','Algonquin College','owner','active','https://www.algonquincollege.com','613-727-4723','purchasing@algonquincollege.com','Ottawa, ON','Ottawa','ON','Official Facilities Management and Procurement sources verified 2026-09-28.'
where not exists (select 1 from public.organizations where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and operating_name='Algonquin College');

insert into public.contacts (workspace_id,first_name,last_name,job_title,email,phone,phone_extension,status,source_url,source_label,source_confidence,source_verified_at)
select '431aa13d-3e7c-41e3-9686-e840b8ea5b7c','Ryan','Southwood','Executive Director, Facilities Management','southwr@algonquincollege.com','613-727-4723','5579','active','https://www.algonquincollege.com/facilities-management/management-team/','Algonquin College Facilities Management management team','high',now()
where not exists (select 1 from public.contacts where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and email='southwr@algonquincollege.com');

insert into public.organization_contacts (workspace_id,organization_id,contact_id,relationship_type,is_primary)
select '431aa13d-3e7c-41e3-9686-e840b8ea5b7c',o.id,c.id,'facilities_management',true
from public.organizations o,public.contacts c
where o.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and o.operating_name='Algonquin College' and c.email='southwr@algonquincollege.com'
and not exists (select 1 from public.organization_contacts oc where oc.organization_id=o.id and oc.contact_id=c.id);

update public.outreach_targets t set organization_id=o.id,contact_id=c.id,contact_name='Ryan Southwood',phone='613-727-4723',email='southwr@algonquincollege.com',company_phone='613-727-4723',company_email='purchasing@algonquincollege.com',company_website='https://www.algonquincollege.com',next_action='Facilities + procurement: grounds, snow, janitorial / contractor onboarding'
from public.organizations o,public.contacts c
where o.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and o.operating_name='Algonquin College' and c.email='southwr@algonquincollege.com' and t.organization_name='Algonquin College' and t.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c';

insert into public.contacts (workspace_id,first_name,last_name,job_title,email,phone,phone_extension,status,source_url,source_label,source_confidence,source_verified_at)
select '431aa13d-3e7c-41e3-9686-e840b8ea5b7c','Miro','Vala','Superintendent of Planning and Facilities','Miro.Vala@ocsb.ca','613-224-4455','2322','active','https://www.ocsb.ca/our-board/executive-council/','OCSB Executive Council','high',now()
where not exists (select 1 from public.contacts where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and email='Miro.Vala@ocsb.ca');

insert into public.organization_contacts (workspace_id,organization_id,contact_id,relationship_type,is_primary)
select '431aa13d-3e7c-41e3-9686-e840b8ea5b7c','ae39bff3-fc51-45b6-a41c-59edc121c6df',(select id from public.contacts where email='Miro.Vala@ocsb.ca' limit 1),'planning_facilities',true
where not exists (select 1 from public.organization_contacts where organization_id='ae39bff3-fc51-45b6-a41c-59edc121c6df' and contact_id=(select id from public.contacts where email='Miro.Vala@ocsb.ca' limit 1));

update public.outreach_targets set contact_id=(select id from public.contacts where email='Miro.Vala@ocsb.ca' limit 1),contact_name='Miro Vala',phone='613-224-4455',email='Miro.Vala@ocsb.ca',company_phone='613-224-2222',company_email='info@ocsb.ca',next_action='Planning + Facilities: maintenance, operations, custodial, renewal'
where organization_name='Ottawa Catholic School Board' and workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c';

update public.outreach_targets set contact_name='Chartwell Ottawa residences administration',company_website='https://chartwell.com',next_action='Route to Ottawa residence operations: grounds, snow, janitorial'
where organization_name='Chartwell Retirement Residences (Ottawa properties)' and workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c';

update public.outreach_targets set contact_name='Extendicare facilities / procurement routing',company_phone='905-470-4000',company_website='https://www.extendicare.com',next_action='Route to facilities/procurement: grounds, snow, janitorial'
where organization_name='Extendicare (Ottawa facilities)' and workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c';
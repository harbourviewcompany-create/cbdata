insert into public.contacts (workspace_id,first_name,last_name,job_title,email,phone,phone_extension,status,source_url,source_label,source_confidence,source_verified_at)
select '431aa13d-3e7c-41e3-9686-e840b8ea5b7c','Jamie','Hopkins','Associate Director, Facilities Operations, Maintenance, and Engineering Services','hopkinj2@algonquincollege.com','613-727-4723','7718','active','https://www.algonquincollege.com/facilities-management/management-team/','Algonquin College Facilities Management management team','high',now()
where not exists (select 1 from public.contacts where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and email='hopkinj2@algonquincollege.com');

insert into public.contacts (workspace_id,first_name,last_name,job_title,email,phone,phone_extension,status,source_url,source_label,source_confidence,source_verified_at)
select '431aa13d-3e7c-41e3-9686-e840b8ea5b7c','Gordon','Warner','Associate Director, Strategic Procurement','warnerg@algonquincollege.com','613-727-4723','3203','active','https://www.algonquincollege.com/purchasing/management-team/','Algonquin College Procurement Team','high',now()
where not exists (select 1 from public.contacts where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and email='warnerg@algonquincollege.com');

insert into public.organization_contacts (workspace_id,organization_id,contact_id,relationship_type,is_primary)
select '431aa13d-3e7c-41e3-9686-e840b8ea5b7c',o.id,c.id,v.rel,v.primary_flag
from public.organizations o
cross join lateral (values ('hopkinj2@algonquincollege.com','facilities_operations',false),('warnerg@algonquincollege.com','strategic_procurement',false)) v(email,rel,primary_flag)
join public.contacts c on c.email=v.email
where o.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and o.operating_name='Algonquin College'
and not exists (select 1 from public.organization_contacts oc where oc.organization_id=o.id and oc.contact_id=c.id);
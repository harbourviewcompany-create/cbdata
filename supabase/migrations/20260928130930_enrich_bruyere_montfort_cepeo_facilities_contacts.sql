insert into public.organizations (workspace_id,legal_name,operating_name,organization_type,status,website,phone,email,primary_region,hq_city,hq_province,source_notes)
select '431aa13d-3e7c-41e3-9686-e840b8ea5b7c','Conseil des écoles publiques de l’Est de l’Ontario','Conseil des écoles publiques de l’Est de l’Ontario','owner','active','https://cepeo.on.ca','613-742-8960',null,'Ottawa, ON','Ottawa','ON','Official CEPEO administrative directory and facilities-service evidence verified 2026-09-28.'
where not exists (select 1 from public.organizations where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and operating_name='Conseil des écoles publiques de l’Est de l’Ontario');

insert into public.contacts (workspace_id,first_name,last_name,job_title,email,phone,status,source_url,source_label,source_confidence,source_verified_at)
select '431aa13d-3e7c-41e3-9686-e840b8ea5b7c','David','Calderisi','Director, Facilities and Security','davidcalderisi@montfort.on.ca','613-746-4621','active','https://hopitalmontfort.com/sites/default/files/2023-11/Montfort%20Hospital%20-%20CDM%20Plan%202024%20to%202028%20v2.pdf','Hôpital Montfort Conservation and Demand Management Plan 2024-2028','high',now()
where not exists (select 1 from public.contacts where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and email='davidcalderisi@montfort.on.ca');

insert into public.contacts (workspace_id,first_name,last_name,job_title,phone,status,source_url,source_label,source_confidence,source_verified_at)
select '431aa13d-3e7c-41e3-9686-e840b8ea5b7c','Mélanie','Dubé','Chief Financial Officer, Vice-President Corporate Services, Planning and Redevelopment','613-562-6262','active','https://www.bruyere.org/en/leadership-team','Bruyère Health Senior Strategy Team','high',now()
where not exists (select 1 from public.contacts where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and first_name='Mélanie' and last_name='Dubé' and job_title like 'Chief Financial Officer%');

insert into public.contacts (workspace_id,first_name,last_name,job_title,phone,status,source_url,source_label,source_confidence,source_verified_at)
select '431aa13d-3e7c-41e3-9686-e840b8ea5b7c','Youssef','Abada','Direction du Service des immobilisations','613-742-8960','active','https://cepeo.on.ca/a-propos/administration/personnel-administratif/','CEPEO personnel administratif','high',now()
where not exists (select 1 from public.contacts where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and first_name='Youssef' and last_name='Abada' and job_title='Direction du Service des immobilisations');

insert into public.organization_contacts (workspace_id,organization_id,contact_id,relationship_type,is_primary)
select '431aa13d-3e7c-41e3-9686-e840b8ea5b7c',o.id,c.id,v.rel,true
from public.organizations o
cross join lateral (values
('Hôpital Montfort','davidcalderisi@montfort.on.ca','facilities_security'),
('Bruyère Health',null,'planning_redevelopment'),
('Conseil des écoles publiques de l’Est de l’Ontario',null,'capital_facilities')
) v(org_name,email,rel)
join public.contacts c on ((v.email is not null and c.email=v.email) or (v.email is null and ((v.rel='planning_redevelopment' and c.first_name='Mélanie' and c.last_name='Dubé') or (v.rel='capital_facilities' and c.first_name='Youssef' and c.last_name='Abada'))))
where o.operating_name=v.org_name
and not exists (select 1 from public.organization_contacts oc where oc.organization_id=o.id and oc.contact_id=c.id);

update public.outreach_targets t set contact_id=(select id from public.contacts where email='davidcalderisi@montfort.on.ca' limit 1),contact_name='David Calderisi',phone='613-746-4621',email='davidcalderisi@montfort.on.ca',next_action='Facilities + security: grounds, snow, janitorial, exterior/site services'
where t.organization_name='Hôpital Montfort' and t.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c';

update public.outreach_targets t set contact_id=(select id from public.contacts where first_name='Mélanie' and last_name='Dubé' limit 1),contact_name='Mélanie Dubé',phone='613-562-6262',company_phone='613-562-6262',company_website='https://www.bruyere.org',next_action='Corporate services + planning/redevelopment: facilities services and capital work'
where t.organization_name='Bruyère Health' and t.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c';

update public.outreach_targets t set organization_id=(select id from public.organizations where operating_name='Conseil des écoles publiques de l’Est de l’Ontario' limit 1),contact_id=(select id from public.contacts where first_name='Youssef' and last_name='Abada' limit 1),contact_name='Youssef Abada',phone='613-742-8960',company_phone='613-742-8960',company_website='https://cepeo.on.ca',next_action='Immobilisations: construction, renovation, maintenance and supplier contracts'
where t.organization_name='Conseil des écoles publiques de l''Est de l''Ontario (CEPEO)' and t.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c';
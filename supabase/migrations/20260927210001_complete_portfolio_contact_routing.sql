-- Complete portfolio-level contact routing for Crown and Apollo and remove a duplicate task index.
insert into public.contacts(workspace_id,first_name,last_name,job_title,email,phone,status,notes)
select '431aa13d-3e7c-41e3-9686-e840b8ea5b7c'::uuid,'Scott','Watson','Managing Partner / Broker of Record','swatson@crp-cpmi.com','343-572-5488','active','Official Crown team page: Managing Partner and Broker of Record; leads Real Estate Services including property management, construction, leasing and tenant experience.'
where not exists (
  select 1 from public.contacts
  where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
    and first_name='Scott' and last_name='Watson'
    and job_title='Managing Partner / Broker of Record'
);

update public.outreach_targets t
set contact_id=c.id, contact_name='Scott Watson', phone='343-572-5488', email='swatson@crp-cpmi.com'
from public.contacts c
where t.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
  and t.organization_name='Crown Realty Partners'
  and c.workspace_id=t.workspace_id
  and c.first_name='Scott' and c.last_name='Watson';

insert into public.property_contacts(workspace_id,property_id,contact_id,relationship_type,is_primary,emergency_contact,notes)
select p.workspace_id,p.id,c.id,'management',false,false,
       'Portfolio-level Crown management contact. Official role covers property management, construction, leasing and tenant experience; verify building-specific operations contact before service outreach.'
from public.properties p
join public.contacts c on c.workspace_id=p.workspace_id
  and c.first_name='Scott' and c.last_name='Watson'
where p.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
  and p.name in ('Minto Place','Crown — Carling Avenue Office Portfolio')
  and not exists(select 1 from public.property_contacts pc where pc.property_id=p.id and pc.contact_id=c.id);

insert into public.property_contacts(workspace_id,property_id,contact_id,relationship_type,is_primary,emergency_contact,notes)
select p.workspace_id,p.id,c.id,'management',false,false,
       'Portfolio-level Apollo management contact. President-level routing only; not a building-specific manager.'
from public.properties p
join public.contacts c on c.workspace_id=p.workspace_id
  and c.first_name='Patrick' and c.last_name='Charbonneau'
where p.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
  and p.name like 'Apollo — %'
  and not exists(select 1 from public.property_contacts pc where pc.property_id=p.id and pc.contact_id=c.id);

drop index if exists public.idx_tasks_due;

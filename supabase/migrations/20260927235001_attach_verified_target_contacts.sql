-- Attach source-backed operational contacts to organizations, properties, and target snapshots.
-- All entities are resolved by workspace + canonical names; rerunnable and does not invent contacts.

insert into public.contacts(workspace_id,first_name,last_name,job_title,email,phone,status,notes)
select o.workspace_id,'Scott','Watson','Managing Partner / Broker of Record','swatson@crp-cpmi.com','343-572-5488','active',
       'Official Crown Realty Partners team/news sources identify Scott Watson as Managing Partner and head of the Real Estate Services platform; he is the named contact for the July 2026 Minto Place management announcement. Source: https://www.crownrealtypartners.com/team/scott-watson'
from public.organizations o
where o.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
  and coalesce(o.operating_name,o.legal_name)='Crown Realty Partners'
  and not exists(select 1 from public.contacts c where c.workspace_id=o.workspace_id and c.first_name='Scott' and c.last_name='Watson');

insert into public.contacts(workspace_id,first_name,last_name,job_title,email,phone,status,notes)
select o.workspace_id,'Anna','Iordanidi','Property Manager','anna@apollomgt.com','613-225-7969','active',
       '570 Laurier official contact page identifies Anna Iordanidi as the Apollo Property Management manager. Source: https://570laurier.com/contact/'
from public.organizations o
where o.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
  and coalesce(o.operating_name,o.legal_name)='Apollo Property Management'
  and not exists(select 1 from public.contacts c where c.workspace_id=o.workspace_id and c.first_name='Anna' and c.last_name='Iordanidi');

insert into public.organization_contacts(workspace_id,organization_id,contact_id,relationship_type,is_primary)
select o.workspace_id,o.id,c.id,'property_manager',true
from public.organizations o
join public.contacts c on c.workspace_id=o.workspace_id and c.first_name='Anna' and c.last_name='Iordanidi'
where coalesce(o.operating_name,o.legal_name)='Apollo Property Management'
  and not exists(select 1 from public.organization_contacts x where x.organization_id=o.id and x.contact_id=c.id);

insert into public.organization_contacts(workspace_id,organization_id,contact_id,relationship_type,is_primary)
select o.workspace_id,o.id,c.id,'property_manager',true
from public.organizations o
join public.contacts c on c.workspace_id=o.workspace_id and c.first_name='Mario' and c.last_name='Martel'
where coalesce(o.operating_name,o.legal_name)='Metcalfe Realty'
  and not exists(select 1 from public.organization_contacts x where x.organization_id=o.id and x.contact_id=c.id);

insert into public.organization_contacts(workspace_id,organization_id,contact_id,relationship_type,is_primary)
select o.workspace_id,o.id,c.id,'leasing',false
from public.organizations o
join public.contacts c on c.workspace_id=o.workspace_id and c.first_name='Mike' and c.last_name='Shore'
where coalesce(o.operating_name,o.legal_name)='Metcalfe Realty'
  and not exists(select 1 from public.organization_contacts x where x.organization_id=o.id and x.contact_id=c.id);

insert into public.organization_contacts(workspace_id,organization_id,contact_id,relationship_type,is_primary)
select o.workspace_id,o.id,c.id,'property_manager',true
from public.organizations o
join public.contacts c on c.workspace_id=o.workspace_id and c.first_name='Scott' and c.last_name='Watson'
where coalesce(o.operating_name,o.legal_name)='Crown Realty Partners'
  and not exists(select 1 from public.organization_contacts x where x.organization_id=o.id and x.contact_id=c.id);

insert into public.property_contacts(workspace_id,property_id,contact_id,relationship_type,is_primary,emergency_contact,notes)
select p.workspace_id,p.id,c.id,'property_manager',true,false,
       'Named property manager on the official 570 Laurier contact page. Source: https://570laurier.com/contact/'
from public.properties p
join public.contacts c on c.workspace_id=p.workspace_id and c.first_name='Anna' and c.last_name='Iordanidi'
where p.name='570 Laurier'
  and not exists(select 1 from public.property_contacts x where x.property_id=p.id and x.contact_id=c.id);

insert into public.property_contacts(workspace_id,property_id,contact_id,relationship_type,is_primary,emergency_contact,notes)
select p.workspace_id,p.id,c.id,'operations',true,false,
       'Portfolio operations routing contact. Official Metcalfe team source identifies Mario Martel as Director of Operations.'
from public.properties p
join public.contacts c on c.workspace_id=p.workspace_id and c.first_name='Mario' and c.last_name='Martel'
where p.name like 'Metcalfe — %'
  and not exists(select 1 from public.property_contacts x where x.property_id=p.id and x.contact_id=c.id);

insert into public.property_contacts(workspace_id,property_id,contact_id,relationship_type,is_primary,emergency_contact,notes)
select p.workspace_id,p.id,c.id,'portfolio_management',false,false,
       'Secondary portfolio routing contact. Official Metcalfe team source identifies Mike Shore as Vice President, Leasing.'
from public.properties p
join public.contacts c on c.workspace_id=p.workspace_id and c.first_name='Mike' and c.last_name='Shore'
where p.name like 'Metcalfe — %'
  and not exists(select 1 from public.property_contacts x where x.property_id=p.id and x.contact_id=c.id);

insert into public.property_contacts(workspace_id,property_id,contact_id,relationship_type,is_primary,emergency_contact,notes)
select p.workspace_id,p.id,c.id,'property_management',true,false,
       'Crown management routing contact. Official Crown source identifies Scott Watson as Managing Partner and head of the Real Estate Services platform.'
from public.properties p
join public.contacts c on c.workspace_id=p.workspace_id and c.first_name='Scott' and c.last_name='Watson'
where p.name in ('Minto Place','Crown — Carling Avenue Office Portfolio')
  and not exists(select 1 from public.property_contacts x where x.property_id=p.id and x.contact_id=c.id);

update public.outreach_targets t
set contact_id=c.id,
    contact_name=c.first_name || ' ' || c.last_name,
    phone=coalesce(t.phone,c.phone),
    email=coalesce(t.email,c.email),
    updated_at=now()
from public.organizations o
join public.contacts c on c.workspace_id=o.workspace_id
where t.workspace_id=o.workspace_id
  and t.organization_id=o.id
  and t.status in ('queued','contacted','responded')
  and coalesce(o.operating_name,o.legal_name)='Crown Realty Partners'
  and c.first_name='Scott' and c.last_name='Watson';

update public.outreach_targets t
set contact_id=c.id,
    contact_name=c.first_name || ' ' || c.last_name,
    phone=coalesce(t.phone,c.phone),
    email=coalesce(t.email,c.email),
    updated_at=now()
from public.organizations o
join public.contacts c on c.workspace_id=o.workspace_id
where t.workspace_id=o.workspace_id
  and t.organization_id=o.id
  and t.status in ('queued','contacted','responded')
  and coalesce(o.operating_name,o.legal_name)='Metcalfe Realty'
  and c.first_name='Mario' and c.last_name='Martel'
  and t.contact_id is null;

update public.outreach_targets t
set contact_id=c.id,
    contact_name=c.first_name || ' ' || c.last_name,
    phone=coalesce(t.phone,c.phone),
    email=coalesce(t.email,c.email),
    updated_at=now()
from public.organizations o
join public.contacts c on c.workspace_id=o.workspace_id
where t.workspace_id=o.workspace_id
  and t.organization_id=o.id
  and t.status in ('queued','contacted','responded')
  and coalesce(o.operating_name,o.legal_name)='570 Laurier — OCSCC 678'
  and c.first_name='Anna' and c.last_name='Iordanidi';

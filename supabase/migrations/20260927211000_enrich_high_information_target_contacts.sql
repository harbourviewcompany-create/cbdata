-- Contact-gap enrichment for high-information targets.
-- Contacts are sourced from the organization's current public team/contact pages.
-- Do not assign a person to a property unless the source explicitly identifies that property relationship.

insert into public.contacts(workspace_id,first_name,last_name,job_title,email,phone,status,notes)
select o.workspace_id,'Nathan','Peacock','Operations Manager','npeacock@huntingtonproperties.ca','613-592-1818 ext. 41','active',
       'Official Huntington Properties team directory. Operations Manager. Source: https://huntingtonproperties.ca/our-team/'
from public.organizations o
where o.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
  and coalesce(o.operating_name,o.legal_name)='Huntington Properties'
  and not exists(select 1 from public.contacts c where c.workspace_id=o.workspace_id and c.first_name='Nathan' and c.last_name='Peacock');

insert into public.contacts(workspace_id,first_name,last_name,job_title,email,phone,status,notes)
select o.workspace_id,'Nick','Thuswaldner','Property Manager','nthuswaldner@huntingtonproperties.ca','613-592-1818 ext. 37','active',
       'Official Huntington Properties team directory. Property Manager. Source: https://huntingtonproperties.ca/our-team/'
from public.organizations o
where o.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
  and coalesce(o.operating_name,o.legal_name)='Huntington Properties'
  and not exists(select 1 from public.contacts c where c.workspace_id=o.workspace_id and c.first_name='Nick' and c.last_name='Thuswaldner');

insert into public.contacts(workspace_id,first_name,last_name,job_title,email,phone,status,notes)
select o.workspace_id,'Maria','El-Zeghayar','Director of Operations and Risk',null,null,'active',
       'Ashbury College leadership page identifies Maria El-Zeghayar as Director of Operations and Risk with responsibility for Operations, Property Management and Facility Rentals. Source: https://ashbury.ca/about-us/'
from public.organizations o
where o.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
  and coalesce(o.operating_name,o.legal_name)='Ashbury College'
  and not exists(select 1 from public.contacts c where c.workspace_id=o.workspace_id and c.first_name='Maria' and c.last_name='El-Zeghayar');

insert into public.contacts(workspace_id,first_name,last_name,job_title,email,phone,status,notes)
select o.workspace_id,'Patricia','Mallouk','Director of Finance and Administration',null,null,'active',
       'Elmwood School current 2026 staff announcement identifies Patricia Mallouk as the new Director of Finance and Administration. Source: https://www.elmwood.ca/parents/school-news/articles/~board/school-news/post/welcoming-new-faces-to-elmwood-1788456453313'
from public.organizations o
where o.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
  and coalesce(o.operating_name,o.legal_name)='Elmwood School'
  and not exists(select 1 from public.contacts c where c.workspace_id=o.workspace_id and c.first_name='Patricia' and c.last_name='Mallouk');

insert into public.contacts(workspace_id,first_name,last_name,job_title,email,phone,status,notes)
select o.workspace_id,'Simon','Nehme','Board Vice-Chair / Facilities Committee Chair',null,null,'active',
       'Elmwood School leadership page identifies Simon Nehme as Board Vice-Chair and Chair of the Facilities Committee. Source: https://www.elmwood.ca/about/leadership'
from public.organizations o
where o.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
  and coalesce(o.operating_name,o.legal_name)='Elmwood School'
  and not exists(select 1 from public.contacts c where c.workspace_id=o.workspace_id and c.first_name='Simon' and c.last_name='Nehme');

insert into public.contacts(workspace_id,first_name,last_name,job_title,email,phone,status,notes)
select o.workspace_id,'Lorie','Stuckless','Director of Support Services',null,null,'active',
       'Perley Health staff page identifies Lorie Stuckless as Director of Support Services. Perley Health property-services materials describe Property Services, Physical Plant Operations, Security, contract administration, grounds and parking under Support Services. Sources: https://www.perleyhealth.ca/staff and https://www.perleyhealth.ca/manager-ps-mm--l'
from public.organizations o
where o.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
  and coalesce(o.operating_name,o.legal_name)='Perley Health'
  and not exists(select 1 from public.contacts c where c.workspace_id=o.workspace_id and c.first_name='Lorie' and c.last_name='Stuckless');

insert into public.organization_contacts(workspace_id,organization_id,contact_id,relationship_type,is_primary)
select o.workspace_id,o.id,c.id,'operations',true
from public.organizations o
join public.contacts c on c.workspace_id=o.workspace_id and c.first_name='Nathan' and c.last_name='Peacock'
where coalesce(o.operating_name,o.legal_name)='Huntington Properties'
  and not exists(select 1 from public.organization_contacts x where x.organization_id=o.id and x.contact_id=c.id);

insert into public.organization_contacts(workspace_id,organization_id,contact_id,relationship_type,is_primary)
select o.workspace_id,o.id,c.id,'property_management',false
from public.organizations o
join public.contacts c on c.workspace_id=o.workspace_id and c.first_name='Nick' and c.last_name='Thuswaldner'
where coalesce(o.operating_name,o.legal_name)='Huntington Properties'
  and not exists(select 1 from public.organization_contacts x where x.organization_id=o.id and x.contact_id=c.id);

insert into public.organization_contacts(workspace_id,organization_id,contact_id,relationship_type,is_primary)
select o.workspace_id,o.id,c.id,'operations',true
from public.organizations o
join public.contacts c on c.workspace_id=o.workspace_id and c.first_name='Maria' and c.last_name='El-Zeghayar'
where coalesce(o.operating_name,o.legal_name)='Ashbury College'
  and not exists(select 1 from public.organization_contacts x where x.organization_id=o.id and x.contact_id=c.id);

insert into public.organization_contacts(workspace_id,organization_id,contact_id,relationship_type,is_primary)
select o.workspace_id,o.id,c.id,'administration',true
from public.organizations o
join public.contacts c on c.workspace_id=o.workspace_id and c.first_name='Patricia' and c.last_name='Mallouk'
where coalesce(o.operating_name,o.legal_name)='Elmwood School'
  and not exists(select 1 from public.organization_contacts x where x.organization_id=o.id and x.contact_id=c.id);

insert into public.organization_contacts(workspace_id,organization_id,contact_id,relationship_type,is_primary)
select o.workspace_id,o.id,c.id,'facilities_governance',false
from public.organizations o
join public.contacts c on c.workspace_id=o.workspace_id and c.first_name='Simon' and c.last_name='Nehme'
where coalesce(o.operating_name,o.legal_name)='Elmwood School'
  and not exists(select 1 from public.organization_contacts x where x.organization_id=o.id and x.contact_id=c.id);

insert into public.organization_contacts(workspace_id,organization_id,contact_id,relationship_type,is_primary)
select o.workspace_id,o.id,c.id,'support_services',true
from public.organizations o
join public.contacts c on c.workspace_id=o.workspace_id and c.first_name='Lorie' and c.last_name='Stuckless'
where coalesce(o.operating_name,o.legal_name)='Perley Health'
  and not exists(select 1 from public.organization_contacts x where x.organization_id=o.id and x.contact_id=c.id);

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
  and c.first_name='Nathan' and c.last_name='Peacock'
  and coalesce(o.operating_name,o.legal_name)='Huntington Properties';

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
  and c.first_name='Maria' and c.last_name='El-Zeghayar'
  and coalesce(o.operating_name,o.legal_name)='Ashbury College';

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
  and c.first_name='Patricia' and c.last_name='Mallouk'
  and coalesce(o.operating_name,o.legal_name)='Elmwood School';

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
  and c.first_name='Lorie' and c.last_name='Stuckless'
  and coalesce(o.operating_name,o.legal_name)='Perley Health';

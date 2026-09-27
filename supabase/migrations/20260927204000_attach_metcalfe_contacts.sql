-- Attach verified Metcalfe operations and leasing contacts to its property portfolio.
-- Contacts are public company/team records; property-specific building managers remain unverified until separately sourced.

insert into public.contacts(workspace_id,first_name,last_name,job_title,email,phone,status,notes)
select '431aa13d-3e7c-41e3-9686-e840b8ea5b7c'::uuid,'Mario','Martel','Director of Operations',null,'613-563-4442','active','Official Metcalfe Realty team page identifies Mario Martel as Director of Operations responsible for building operations and tenant comfort/safety/performance.'
where not exists(select 1 from public.contacts c where c.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and c.first_name='Mario' and c.last_name='Martel' and c.job_title='Director of Operations');

insert into public.contacts(workspace_id,first_name,last_name,job_title,email,phone,status,notes)
select '431aa13d-3e7c-41e3-9686-e840b8ea5b7c'::uuid,'Mike','Shore','Vice President, Leasing','mshore@metcalferealty.com','613-563-4442','active','Official Metcalfe Realty sources identify Mike Shore as VP Leasing; public company post gives direct email and phone.'
where not exists(select 1 from public.contacts c where c.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and c.first_name='Mike' and c.last_name='Shore' and c.job_title='Vice President, Leasing');

insert into public.property_contacts(workspace_id,property_id,contact_id,relationship_type,is_primary,emergency_contact,notes)
select p.workspace_id,p.id,c.id,'operations',true,false,'Primary operational routing contact; verify property-specific building manager before outreach.'
from public.properties p join public.contacts c on c.workspace_id=p.workspace_id and c.first_name='Mario' and c.last_name='Martel'
where p.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and p.name like 'Metcalfe — %'
and not exists(select 1 from public.property_contacts pc where pc.property_id=p.id and pc.contact_id=c.id);

insert into public.property_contacts(workspace_id,property_id,contact_id,relationship_type,is_primary,emergency_contact,notes)
select p.workspace_id,p.id,c.id,'leasing',false,false,'Secondary portfolio contact; useful for occupancy/leasing context and routing.'
from public.properties p join public.contacts c on c.workspace_id=p.workspace_id and c.first_name='Mike' and c.last_name='Shore'
where p.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c' and p.name like 'Metcalfe — %'
and not exists(select 1 from public.property_contacts pc where pc.property_id=p.id and pc.contact_id=c.id);
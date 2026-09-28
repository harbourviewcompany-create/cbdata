-- Contact-gap routing for remaining property-manager and institutional targets.
-- Source-backed organizational routes only; no inferred personal contacts.

with routes(organization_name, contact_name, phone, email, website, next_action) as (
  values
    ('Gold Key Management','Gold Key Management team','613-725-1111',null,'https://www.goldkeymanagement.ca','Vendor introduction for condominium, residential and commercial property services'),
    ('Nova Property Management Experts','Nova PME management team','613-690-4913','info@novapme.com','https://www.novapme.com','Condo-board vendor introduction; reserve-fund/capital project service discussion'),
    ('Ottawa Property Management & Real Estate','Ottawa Property Management & Real Estate team','613-390-0364','info@ottawapropertymgt.ca','https://ottawapropertymgt.ca','Property maintenance and vendor coordination introduction'),
    ('Rescom Property Management','Rescom management team','613-736-7377','sheila@rescompropertymanagement.com','https://www.rescompropertymanagement.com','Property maintenance and site-services introduction'),
    ('The Condo Collective Inc.','The Condo Collective management team','613-366-2346','hello@thecondocollective.ca','https://thecondocollective.ca','Condo-board vendor introduction; common-area and capital service discussion'),
    ('Ottawa Property Managers','Ottawa Property Managers team','613-319-2477','info@ottawapropertymanagers.com','https://www.ottawapropertymanagers.com','Residential and multi-family maintenance/vendor introduction'),
    ('Ottawa Community Housing','OCH procurement / vendor route',null,'bids@och.ca','https://www.och-lco.ca','Register and monitor OCH procurement; pursue facilities and maintenance opportunities'),
    ('Ottawa-Carleton District School Board','OCDSB Facilities Department','613-596-8777','facilities@ocdsb.ca','https://www.ocdsb.ca/about-us/departments/facilities-department','Facilities vendor introduction and maintenance/grounds opportunity monitoring'),
    ('Ottawa Muslim Association / Ottawa Main Mosque','Ottawa Muslim Association administration','613-722-8763','oma@ottawamosque.ca','https://ottawamosque.ca','Facilities and grounds service introduction'),
    ('National Capital Commission','NCC supplier / contracting route',null,null,'https://ncc-ccn.gc.ca/business/contracting-with-the-ncc','Monitor CanadaBuys/NCC tenders and supplier opportunities')
)
update public.outreach_targets t
set
  contact_name = r.contact_name,
  phone = coalesce(r.phone, t.phone),
  email = coalesce(r.email, t.email),
  company_phone = coalesce(r.phone, t.company_phone),
  company_email = coalesce(r.email, t.company_email),
  company_website = coalesce(r.website, t.company_website),
  next_action = r.next_action,
  updated_at = now()
from routes r
where t.organization_name = r.organization_name
  and t.contact_id is null;
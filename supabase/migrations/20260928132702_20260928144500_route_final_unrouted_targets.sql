with routes(organization_name, contact_name, phone, email, website, next_action) as (
  values
    ('Centretown Mosque','Centretown Mosque management team',null,'info@centretownmosque.ca','https://www.centretownmosque.ca','Facilities/grounds introduction; monitor building preservation and service needs'),
    ('Temple Israel of Ottawa','Raquel Black','613-224-1802 ext. 4','execdir@templeisraelottawa.com','https://www.templeisraelottawa.ca','Facilities and building-services introduction')
)
update public.outreach_targets t
set contact_name=r.contact_name, phone=coalesce(r.phone,t.phone), email=coalesce(r.email,t.email),
    company_phone=coalesce(r.phone,t.company_phone), company_email=coalesce(r.email,t.company_email),
    company_website=coalesce(r.website,t.company_website), next_action=r.next_action, updated_at=now()
from routes r
where t.organization_name=r.organization_name and t.contact_id is null;
-- Source-backed organizational routing for remaining property-management targets.
-- Do not infer individual names when the official site publishes only a team route.

update public.outreach_targets
set contact_name='Homes for Rent Ottawa management team',
    phone='613-800-2000',
    email='info@homesforrentottawa.ca',
    company_phone='613-800-2000',
    company_email='info@homesforrentottawa.ca',
    company_website='https://homesforrentottawa.ca',
    next_action='Property management route: maintenance coordination, inspections, vendor/service work'
where organization_name='Homes for Rent Ottawa Property Management Inc.'
  and workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c';

update public.outreach_targets
set contact_name='Oakmont Property Management team',
    phone='613-670-1076',
    email='info@oakmontpropertymanagement.ca',
    company_phone='613-670-1076',
    company_email='info@oakmontpropertymanagement.ca',
    company_website='https://oakmontpropertymanagement.ca',
    next_action='Property management route: maintenance, services/security, vendor coordination'
where organization_name='Oakmont Property Management'
  and workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c';

update public.outreach_targets
set contact_name='Berg Property Management team',
    phone='613-831-0700',
    email='info@bergrealty.ca',
    company_phone='613-831-0700',
    company_email='info@bergrealty.ca',
    company_website='https://www.bergrealty.ca',
    next_action='Condo/commercial property management route: maintenance, repair, site services'
where organization_name='Berg Property Management'
  and workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c';

update public.outreach_targets
set contact_name='Fleming Property Management team',
    phone='613-237-0346',
    email='office@fpm.ca',
    company_phone='613-237-0346',
    company_email='office@fpm.ca',
    company_website='https://www.fpm.ca',
    next_action='Property management route: building service, maintenance and vendor coordination'
where organization_name='Fleming Property Management'
  and workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c';
-- Jami Omar does not publish a named facilities/administration contact.
-- Preserve the verified organizational routing information without fabricating a person.

update public.outreach_targets t
set contact_name='Jami Omar administration',
    phone=coalesce(t.phone,'613-828-2222'),
    email=coalesce(t.email,'jamiomar@jamiomar.org'),
    updated_at=now()
from public.organizations o
where t.workspace_id=o.workspace_id
  and t.organization_id=o.id
  and t.status in ('queued','contacted','responded')
  and coalesce(o.operating_name,o.legal_name)='Jami Omar Mosque'
  and t.contact_id is null;

-- Street-level company profile + extra contact coordinates for PM targets.

alter table public.organizations
  add column if not exists hq_address_line_1 text,
  add column if not exists hq_address_line_2 text,
  add column if not exists hq_postal_code text,
  add column if not exists main_fax text;

alter table public.contacts
  add column if not exists linkedin_url text,
  add column if not exists phone_extension text;

alter table public.outreach_targets
  add column if not exists company_phone text,
  add column if not exists company_email text,
  add column if not exists company_website text,
  add column if not exists company_address text;

comment on column public.organizations.hq_address_line_1 is
  'HQ / main office street address for outreach and site visits.';
comment on column public.outreach_targets.company_phone is
  'Denormalized company switchboard for queue display when org is not joined.';

create table if not exists public.target_opportunity_signals (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null,
  organization_id uuid,
  property_id uuid,
  target_id uuid,
  signal_type text not null check (signal_type in ('procurement','permit','capital_project','vendor_change','contract_renewal','seasonal')),
  title text not null,
  service_fit text[] not null default '{}',
  source_url text not null,
  source_label text,
  source_confidence text not null default 'high',
  published_at timestamptz,
  deadline_at timestamptz,
  status text not null default 'open',
  buyer_contact_name text,
  buyer_contact_email text,
  reference_number text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists target_opportunity_signals_source_ref_uidx
  on public.target_opportunity_signals(workspace_id, source_url, coalesce(reference_number,''));

create index if not exists target_opportunity_signals_org_idx
  on public.target_opportunity_signals(workspace_id, organization_id, status, deadline_at);

create index if not exists target_opportunity_signals_property_idx
  on public.target_opportunity_signals(workspace_id, property_id, status, deadline_at);

alter table public.target_opportunity_signals enable row level security;

insert into public.target_opportunity_signals (
  workspace_id, signal_type, title, service_fit, source_url, source_label,
  source_confidence, published_at, deadline_at, status, buyer_contact_name,
  buyer_contact_email, reference_number, notes
)
select
  '431aa13d-3e7c-41e3-9686-e840b8ea5b7c',
  'procurement',
  'City of Ottawa — Snow and Salt Maintenance Services for City Facilities',
  array['snow'],
  'https://ottawa.ca/en/business/procurement/bidding-opportunities',
  'City of Ottawa procurement / current bidding opportunities',
  'high',
  '2026-09-21T00:00:00-04:00',
  '2026-10-13T15:00:00-04:00',
  'open',
  'City of Ottawa Supply Services',
  'bidresults@ottawa.ca',
  '41726-96872-T01',
  'Formal RCFS/FOS procurement for snow and ice clearing/removal at City facilities; current deadline verified 2026-09-28.'
where not exists (
  select 1 from public.target_opportunity_signals s
  where s.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
    and s.source_url='https://ottawa.ca/en/business/procurement/bidding-opportunities'
    and s.reference_number='41726-96872-T01'
);

insert into public.target_opportunity_signals (
  workspace_id, signal_type, title, service_fit, source_url, source_label,
  source_confidence, published_at, deadline_at, status, buyer_contact_name,
  buyer_contact_email, reference_number, notes
)
select
  '431aa13d-3e7c-41e3-9686-e840b8ea5b7c',
  'procurement',
  'NRC Ottawa Offices Janitorial Services',
  array['janitorial'],
  'https://canadabuys.canada.ca/en/tender-opportunities',
  'CanadaBuys current tender opportunity',
  'high',
  '2026-09-11T00:00:00-04:00',
  '2026-10-22T15:00:00-04:00',
  'open',
  'Jonathan Bullard',
  'jonathan.bullard@nrc-cnrc.gc.ca',
  'cb-708-64614973',
  'Open RFP for routine, scheduled, on-demand, emergency and specialized cleaning at NRC Ottawa Offices; source checked 2026-09-28.'
where not exists (
  select 1 from public.target_opportunity_signals s
  where s.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
    and s.reference_number='cb-708-64614973'
);

insert into public.target_opportunity_signals (
  workspace_id, signal_type, title, service_fit, source_url, source_label,
  source_confidence, published_at, deadline_at, status, buyer_contact_name,
  reference_number, notes
)
select
  '431aa13d-3e7c-41e3-9686-e840b8ea5b7c',
  'procurement',
  'City of Ottawa — Snow and Ice Removal for ROPEC',
  array['snow'],
  'https://civiciq.com/public-rfp/city-of-ottawa-iwsd-lwcs-snow-and-ice-removal-for-ropec-33426-96872-t01',
  'Current tender mirror; verify against MERX before submission',
  'medium',
  '2026-09-08T00:00:00-04:00',
  '2026-09-29T15:00:00-04:00',
  'open',
  'Chris Malloy',
  null,
  '33426-96872-T01',
  'Current Ottawa snow/ice procurement at ROPEC; source is a tender mirror and should be validated against the official MERX notice before action.'
where not exists (
  select 1 from public.target_opportunity_signals s
  where s.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
    and s.reference_number='33426-96872-T01'
);

create table if not exists public.supplier_registrations (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  source_key text not null,
  registration_name text not null,
  status text not null default 'unknown' check (status in ('unknown','not_required','required','in_progress','active','expired','blocked')),
  account_reference text,
  expires_on date,
  evidence_url text,
  notes text,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique(workspace_id, source_key, registration_name)
);

create index if not exists idx_supplier_registrations_workspace_id
  on public.supplier_registrations(workspace_id);
create index if not exists idx_supplier_registrations_source_key
  on public.supplier_registrations(workspace_id, source_key, status);

alter table public.supplier_registrations enable row level security;
alter table public.supplier_registrations force row level security;

drop policy if exists supplier_registrations_select on public.supplier_registrations;
create policy supplier_registrations_select
  on public.supplier_registrations for select to authenticated
  using (private.is_workspace_member(workspace_id));

drop policy if exists supplier_registrations_insert on public.supplier_registrations;
create policy supplier_registrations_insert
  on public.supplier_registrations for insert to authenticated
  with check (private.is_workspace_member(workspace_id));

drop policy if exists supplier_registrations_update on public.supplier_registrations;
create policy supplier_registrations_update
  on public.supplier_registrations for update to authenticated
  using (private.is_workspace_member(workspace_id))
  with check (private.is_workspace_member(workspace_id));

drop policy if exists supplier_registrations_delete on public.supplier_registrations;
create policy supplier_registrations_delete
  on public.supplier_registrations for delete to authenticated
  using (private.is_workspace_member(workspace_id));

revoke all on public.supplier_registrations from anon;
grant select,insert,update,delete on public.supplier_registrations to authenticated;
grant all on public.supplier_registrations to service_role;

insert into public.supplier_registrations(workspace_id,source_key,registration_name,status,notes)
select id,'canadabuys','CanadaBuys / SAP Business Network supplier registration','unknown','Confirm supplier account and bid submission access.'
from public.workspaces
on conflict(workspace_id,source_key,registration_name) do nothing;

insert into public.supplier_registrations(workspace_id,source_key,registration_name,status,notes)
select id,'city_merx','MERX / City of Ottawa vendor access','unknown','Confirm MERX subscription/vendor access and City procurement eligibility.'
from public.workspaces
on conflict(workspace_id,source_key,registration_name) do nothing;

insert into public.supplier_registrations(workspace_id,source_key,registration_name,status,notes)
select id,'ncc','NCC supplier eligibility','unknown','Confirm supplier-list or solicitation-specific registration requirements.'
from public.workspaces
on conflict(workspace_id,source_key,registration_name) do nothing;

insert into public.supplier_registrations(workspace_id,source_key,registration_name,status,notes)
select id,'institutions','Board / institutional prequalification','unknown','Track school-board, hospital and institutional vendor/prequalification requirements.'
from public.workspaces
on conflict(workspace_id,source_key,registration_name) do nothing;

alter table public.tender_records
  add column if not exists submission_method text,
  add column if not exists submission_reference text,
  add column if not exists bid_decision_at timestamptz,
  add column if not exists bid_decision_by uuid references auth.users(id) on delete set null;

create index if not exists idx_tender_records_bid_decision_by
  on public.tender_records(bid_decision_by);

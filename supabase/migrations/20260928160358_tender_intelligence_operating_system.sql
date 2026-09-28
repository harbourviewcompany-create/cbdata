alter table public.tender_records
  add column if not exists owner_user_id uuid references auth.users(id) on delete set null,
  add column if not exists opportunity_id uuid references public.opportunities(id) on delete set null,
  add column if not exists estimate_id uuid references public.estimates(id) on delete set null,
  add column if not exists no_bid_reason text,
  add column if not exists incumbent_name text,
  add column if not exists previous_award_value numeric,
  add column if not exists contract_start_date date,
  add column if not exists contract_end_date date,
  add column if not exists expected_rebid_date date,
  add column if not exists submission_receipt_url text,
  add column if not exists submission_confirmed_at timestamptz,
  add column if not exists last_addenda_checked_at timestamptz,
  add column if not exists addenda_count integer not null default 0,
  add column if not exists fit_breakdown jsonb not null default '{}'::jsonb,
  add column if not exists vendor_prerequisite_status text;

create table if not exists public.tender_requirements (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  tender_record_id uuid not null references public.tender_records(id) on delete cascade,
  requirement_type text not null default 'other',
  title text not null,
  description text,
  mandatory boolean not null default true,
  status text not null default 'pending' check (status in ('pending','in_progress','complete','blocked','not_applicable')),
  due_at timestamptz,
  owner_user_id uuid references auth.users(id) on delete set null,
  evidence_url text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(tender_record_id, title)
);

create table if not exists public.tender_deadlines (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  tender_record_id uuid not null references public.tender_records(id) on delete cascade,
  deadline_type text not null default 'other',
  title text not null,
  due_at timestamptz not null,
  status text not null default 'open' check (status in ('open','complete','missed','not_applicable')),
  mandatory boolean not null default false,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(tender_record_id, deadline_type, due_at)
);

create table if not exists public.tender_documents (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  tender_record_id uuid not null references public.tender_records(id) on delete cascade,
  document_type text not null default 'other',
  title text not null,
  source_url text,
  storage_path text,
  version text,
  is_current boolean not null default true,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  unique(tender_record_id, title, version)
);

create table if not exists public.tender_stage_history (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  tender_record_id uuid not null references public.tender_records(id) on delete cascade,
  from_stage text,
  to_stage text not null,
  changed_by uuid references auth.users(id) on delete set null,
  note text,
  created_at timestamptz not null default now()
);

create table if not exists public.tender_sources (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  source_key text not null,
  display_name text not null,
  source_url text,
  ingestion_mode text not null default 'manual' check (ingestion_mode in ('live','upstream','manual','external_watch')),
  enabled boolean not null default true,
  last_run_at timestamptz,
  last_success_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(workspace_id, source_key)
);

create index if not exists idx_tender_records_open_queue on public.tender_records(workspace_id, closing_date, action_state) where closing_date is not null;
create index if not exists idx_tender_requirements_tender_status on public.tender_requirements(tender_record_id, status, mandatory);
create index if not exists idx_tender_deadlines_tender_due on public.tender_deadlines(tender_record_id, due_at);
create index if not exists idx_tender_documents_tender on public.tender_documents(tender_record_id, is_current);
create index if not exists idx_tender_stage_history_tender_created on public.tender_stage_history(tender_record_id, created_at desc);
create index if not exists idx_tender_sources_workspace_enabled on public.tender_sources(workspace_id, enabled);

alter table public.tender_requirements enable row level security;
alter table public.tender_requirements force row level security;
alter table public.tender_deadlines enable row level security;
alter table public.tender_deadlines force row level security;
alter table public.tender_documents enable row level security;
alter table public.tender_documents force row level security;
alter table public.tender_stage_history enable row level security;
alter table public.tender_stage_history force row level security;
alter table public.tender_sources enable row level security;
alter table public.tender_sources force row level security;

do $$
declare t text;
begin
  foreach t in array array['tender_requirements','tender_deadlines','tender_documents','tender_stage_history','tender_sources']
  loop
    execute format('drop policy if exists %I_select on public.%I', t, t);
    execute format('create policy %I_select on public.%I for select to authenticated using (public.is_workspace_member(workspace_id))', t, t);
    execute format('drop policy if exists %I_insert on public.%I', t, t);
    execute format('create policy %I_insert on public.%I for insert to authenticated with check (public.is_workspace_member(workspace_id))', t, t);
    execute format('drop policy if exists %I_update on public.%I', t, t);
    execute format('create policy %I_update on public.%I for update to authenticated using (public.is_workspace_member(workspace_id)) with check (public.is_workspace_member(workspace_id))', t, t);
    execute format('drop policy if exists %I_delete on public.%I', t, t);
    execute format('create policy %I_delete on public.%I for delete to authenticated using (public.is_workspace_member(workspace_id))', t, t);
    execute format('grant select,insert,update,delete on public.%I to authenticated', t);
  end loop;
end $$;

insert into public.tender_deadlines(workspace_id,tender_record_id,deadline_type,title,due_at,mandatory)
select workspace_id,id,'submission','Tender submission deadline',(closing_date::timestamp + time '23:59') at time zone 'America/Toronto',true
from public.tender_records where closing_date is not null on conflict do nothing;

insert into public.tender_requirements(workspace_id,tender_record_id,requirement_type,title,description,mandatory,status)
select workspace_id,id,'compliance','Review mandatory solicitation requirements',
  'Confirm site visit, supplier registration, insurance, bonding, security, references, pricing forms and signed certifications before submission.',
  true,'pending'
from public.tender_records on conflict(tender_record_id,title) do nothing;

insert into public.tender_sources(workspace_id,source_key,display_name,source_url,ingestion_mode)
select id,'canadabuys','CanadaBuys','https://canadabuys.canada.ca/en/tender-opportunities','live' from public.workspaces
on conflict(workspace_id,source_key) do update set display_name=excluded.display_name,source_url=excluded.source_url,ingestion_mode=excluded.ingestion_mode;
insert into public.tender_sources(workspace_id,source_key,display_name,source_url,ingestion_mode)
select id,'city_merx','City of Ottawa / MERX','https://ottawa.ca/en/business/procurement/bidding-opportunities','external_watch' from public.workspaces
on conflict(workspace_id,source_key) do update set display_name=excluded.display_name,source_url=excluded.source_url,ingestion_mode=excluded.ingestion_mode;
insert into public.tender_sources(workspace_id,source_key,display_name,source_url,ingestion_mode)
select id,'ncc','National Capital Commission','https://ncc-ccn.gc.ca/business/contracting-with-the-ncc','upstream' from public.workspaces
on conflict(workspace_id,source_key) do update set display_name=excluded.display_name,source_url=excluded.source_url,ingestion_mode=excluded.ingestion_mode;
insert into public.tender_sources(workspace_id,source_key,display_name,source_url,ingestion_mode)
select id,'institutions','Boards / institutions',null,'external_watch' from public.workspaces
on conflict(workspace_id,source_key) do update set display_name=excluded.display_name,ingestion_mode=excluded.ingestion_mode;

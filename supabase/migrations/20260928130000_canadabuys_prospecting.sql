-- CanadaBuys prospecting layer for CBData.
-- Stores structured procurement response requirements and run history while
-- retaining the existing tender_records/lead model.

alter table public.tender_records
  add column if not exists response_mode text,
  add column if not exists registration_required boolean not null default false,
  add column if not exists fit_score numeric,
  add column if not exists fit_note text,
  add column if not exists last_verified_at timestamptz,
  add column if not exists watch_query text;

alter table public.tender_records
  drop constraint if exists tender_records_fit_score_check;

alter table public.tender_records
  add constraint tender_records_fit_score_check
  check (fit_score is null or (fit_score >= 0 and fit_score <= 100));

create table if not exists public.canadabuys_runs (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete restrict,
  query text not null,
  region text not null default 'Ottawa / National Capital Region',
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  status text not null default 'running',
  fetched_count integer not null default 0,
  qualifying_count integer not null default 0,
  inserted_count integer not null default 0,
  updated_count integer not null default 0,
  lead_created_count integer not null default 0,
  error_count integer not null default 0,
  error_message text,
  created_at timestamptz not null default now()
);

create index if not exists idx_tender_records_canadabuys_open
  on public.tender_records (workspace_id, closing_date, source);

create index if not exists idx_tender_records_canadabuys_region
  on public.tender_records (workspace_id, region, source);

create index if not exists idx_canadabuys_runs_workspace_started
  on public.canadabuys_runs (workspace_id, started_at desc);

alter table public.canadabuys_runs enable row level security;
alter table public.canadabuys_runs force row level security;

drop policy if exists canadabuys_runs_select on public.canadabuys_runs;
create policy canadabuys_runs_select
  on public.canadabuys_runs for select
  to authenticated
  using (public.is_workspace_member(workspace_id));

drop policy if exists canadabuys_runs_insert on public.canadabuys_runs;
create policy canadabuys_runs_insert
  on public.canadabuys_runs for insert
  to authenticated
  with check (public.is_workspace_member(workspace_id));

drop policy if exists canadabuys_runs_update on public.canadabuys_runs;
create policy canadabuys_runs_update
  on public.canadabuys_runs for update
  to authenticated
  using (public.is_workspace_member(workspace_id))
  with check (public.is_workspace_member(workspace_id));

comment on column public.tender_records.response_mode is
  'Procurement response path observed in the source notice, e.g. formal_rfp or registration_required.';
comment on column public.tender_records.registration_required is
  'True only when the source notice explicitly indicates supplier registration or a prerequisite account.';
comment on column public.tender_records.fit_note is
  'Concise evidence-based CB Contracting fit note; do not infer unsupported scope.';

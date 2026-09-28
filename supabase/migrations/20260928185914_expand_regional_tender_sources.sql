-- Expand CBData tender discovery across the Ottawa / National Capital Region.
-- Adds a generalized run ledger and concrete source registry entries for public
-- procurement channels that can be scanned independently of CanadaBuys.

create table if not exists public.tender_scout_runs (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  source_key text not null,
  source_name text not null,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  status text not null default 'running' check (status in ('running','completed','partial','error')),
  fetched_count integer not null default 0,
  qualifying_count integer not null default 0,
  inserted_count integer not null default 0,
  updated_count integer not null default 0,
  lead_created_count integer not null default 0,
  error_count integer not null default 0,
  error_message text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_tender_scout_runs_workspace_started
  on public.tender_scout_runs(workspace_id, started_at desc);
create index if not exists idx_tender_scout_runs_source_started
  on public.tender_scout_runs(workspace_id, source_key, started_at desc);

alter table public.tender_scout_runs enable row level security;
alter table public.tender_scout_runs force row level security;

drop policy if exists tender_scout_runs_select on public.tender_scout_runs;
create policy tender_scout_runs_select on public.tender_scout_runs
  for select to authenticated using (public.is_workspace_member(workspace_id));

revoke all on public.tender_scout_runs from anon;
grant select on public.tender_scout_runs to authenticated;
grant all on public.tender_scout_runs to service_role;

insert into public.tender_sources(workspace_id,source_key,display_name,source_url,ingestion_mode)
select id,'city_ottawa_merx','City of Ottawa / MERX','https://www.merx.com/cityofottawa/solicitations/open-bids','live'
from public.workspaces
on conflict(workspace_id,source_key) do update set
  display_name=excluded.display_name, source_url=excluded.source_url, ingestion_mode=excluded.ingestion_mode, enabled=true;

insert into public.tender_sources(workspace_id,source_key,display_name,source_url,ingestion_mode)
select id,'och_merx','Ottawa Community Housing / MERX','https://www.merx.com/ottawacommunityhousing/solicitations/open-bids','live'
from public.workspaces
on conflict(workspace_id,source_key) do update set
  display_name=excluded.display_name, source_url=excluded.source_url, ingestion_mode=excluded.ingestion_mode, enabled=true;

insert into public.tender_sources(workspace_id,source_key,display_name,source_url,ingestion_mode)
select id,'ocdsb_bids_tenders','OCDSB Bids & Tenders','https://ocdsb.bidsandtenders.ca/','live'
from public.workspaces
on conflict(workspace_id,source_key) do update set
  display_name=excluded.display_name, source_url=excluded.source_url, ingestion_mode=excluded.ingestion_mode, enabled=true;

insert into public.tender_sources(workspace_id,source_key,display_name,source_url,ingestion_mode)
select id,'ocsb_bids_tenders','OCSB Bids & Tenders','https://ocsb.bidsandtenders.ca/Module/Tenders/en/Home/BidsHomepage','live'
from public.workspaces
on conflict(workspace_id,source_key) do update set
  display_name=excluded.display_name, source_url=excluded.source_url, ingestion_mode=excluded.ingestion_mode, enabled=true;

insert into public.tender_sources(workspace_id,source_key,display_name,source_url,ingestion_mode)
select id,'gatineau_open_data','Ville de Gatineau open tenders','https://www.gatineau.ca/upload/donneesouvertes/appels_offres_utf8.csv','live'
from public.workspaces
on conflict(workspace_id,source_key) do update set
  display_name=excluded.display_name, source_url=excluded.source_url, ingestion_mode=excluded.ingestion_mode, enabled=true;

insert into public.tender_sources(workspace_id,source_key,display_name,source_url,ingestion_mode)
select id,'seao','SEAO Québec','https://www.seao.ca/','external_watch'
from public.workspaces
on conflict(workspace_id,source_key) do update set
  display_name=excluded.display_name, source_url=excluded.source_url, ingestion_mode=excluded.ingestion_mode, enabled=true;

insert into public.tender_sources(workspace_id,source_key,display_name,source_url,ingestion_mode)
select id,'oca','Ottawa Construction Association','https://www.oca.ca/','external_watch'
from public.workspaces
on conflict(workspace_id,source_key) do update set
  display_name=excluded.display_name, source_url=excluded.source_url, ingestion_mode=excluded.ingestion_mode, enabled=true;

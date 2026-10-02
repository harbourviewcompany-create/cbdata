create table if not exists public.outreach_work_sources (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  source_key text not null,
  display_name text not null,
  source_url text not null,
  source_kind text not null default 'network',
  enabled boolean not null default true,
  last_run_at timestamptz,
  last_success_at timestamptz,
  last_error text,
  consecutive_failures integer not null default 0 check (consecutive_failures >= 0),
  last_result_count integer not null default 0 check (last_result_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(workspace_id,source_key)
);

create index if not exists outreach_work_sources_workspace_health_idx
  on public.outreach_work_sources(workspace_id,enabled,last_success_at,last_run_at);

alter table public.outreach_work_sources enable row level security;

drop policy if exists outreach_work_sources_member_select on public.outreach_work_sources;
drop policy if exists outreach_work_sources_sales_update on public.outreach_work_sources;

create policy outreach_work_sources_member_select
on public.outreach_work_sources for select to authenticated
using (private.is_workspace_member(workspace_id));

create policy outreach_work_sources_sales_update
on public.outreach_work_sources for update to authenticated
using (
  private.has_workspace_role(
    workspace_id,
    array['owner','administrator','sales_manager','sales_rep']::public.membership_role[]
  )
)
with check (
  private.has_workspace_role(
    workspace_id,
    array['owner','administrator','sales_manager','sales_rep']::public.membership_role[]
  )
);

grant select,update on public.outreach_work_sources to authenticated;

create table if not exists public.outreach_work_scout_runs (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  status text not null default 'running'
    check (status in ('running','completed','partial','error')),
  discovered_count integer not null default 0 check (discovered_count >= 0),
  upserted_count integer not null default 0 check (upserted_count >= 0),
  promoted_count integer not null default 0 check (promoted_count >= 0),
  draft_count integer not null default 0 check (draft_count >= 0),
  error_count integer not null default 0 check (error_count >= 0),
  source_results jsonb not null default '[]'::jsonb,
  error_message text,
  created_at timestamptz not null default now()
);

create index if not exists outreach_work_scout_runs_workspace_started_idx
  on public.outreach_work_scout_runs(workspace_id,started_at desc);

alter table public.outreach_work_scout_runs enable row level security;

drop policy if exists outreach_work_scout_runs_member_select on public.outreach_work_scout_runs;
create policy outreach_work_scout_runs_member_select
on public.outreach_work_scout_runs for select to authenticated
using (private.is_workspace_member(workspace_id));

grant select on public.outreach_work_scout_runs to authenticated;

create or replace view public.v_outreach_work_source_health
with (security_invoker=true) as
select
  s.*,
  case
    when not s.enabled then 'disabled'
    when s.consecutive_failures >= 2 then 'failing'
    when s.last_error is not null then 'degraded'
    when s.last_success_at is null then 'untested'
    when s.last_success_at < now()-interval '48 hours' then 'stale'
    else 'healthy'
  end as health_state,
  case
    when not s.enabled then 'Source disabled'
    when s.consecutive_failures >= 2 then
      'Repeated source failures: '||s.consecutive_failures::text
    when s.last_error is not null then s.last_error
    when s.last_success_at is null then 'No successful scan recorded yet'
    when s.last_success_at < now()-interval '48 hours' then
      'No successful scan in the last 48 hours'
    else 'Source responding normally'
  end as health_reason
from public.outreach_work_sources s;

grant select on public.v_outreach_work_source_health to authenticated;

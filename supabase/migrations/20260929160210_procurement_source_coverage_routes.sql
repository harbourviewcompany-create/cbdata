-- Route catalog aliases to the executable source that actually scans them.
create table if not exists public.procurement_source_coverage_map (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  source_key text not null,
  executor_source_key text not null,
  coverage_method text not null default 'alias'
    check (coverage_method in ('alias','upstream','portal')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (workspace_id, source_key)
);

alter table public.procurement_source_coverage_map enable row level security;

drop policy if exists procurement_source_coverage_map_select on public.procurement_source_coverage_map;
create policy procurement_source_coverage_map_select
on public.procurement_source_coverage_map
for select
to authenticated
using (public.is_workspace_member(workspace_id));

revoke all on public.procurement_source_coverage_map from anon;
grant select on public.procurement_source_coverage_map to authenticated;
grant all on public.procurement_source_coverage_map to service_role;

insert into public.procurement_source_coverage_map (workspace_id,source_key,executor_source_key,coverage_method,notes)
select workspace_id,'ncc','canadabuys','upstream','NCC public opportunities are covered through CanadaBuys.'
from public.tender_sources where source_key='ncc'
on conflict (workspace_id,source_key) do update
set executor_source_key=excluded.executor_source_key,coverage_method=excluded.coverage_method,notes=excluded.notes,updated_at=now();

insert into public.procurement_source_coverage_map (workspace_id,source_key,executor_source_key,coverage_method,notes)
select workspace_id,'city_merx','city_ottawa_merx','alias','Legacy City/MERX catalog row is covered by the live City of Ottawa MERX adapter.'
from public.tender_sources where source_key='city_merx'
on conflict (workspace_id,source_key) do update
set executor_source_key=excluded.executor_source_key,coverage_method=excluded.coverage_method,notes=excluded.notes,updated_at=now();

insert into public.procurement_source_coverage_map (workspace_id,source_key,executor_source_key,coverage_method,notes)
select workspace_id,'uottawa_procurement','uottawa_merx','alias','University procurement catalog row is covered by the live uOttawa MERX adapter.'
from public.tender_sources where source_key='uottawa_procurement'
on conflict (workspace_id,source_key) do update
set executor_source_key=excluded.executor_source_key,coverage_method=excluded.coverage_method,notes=excluded.notes,updated_at=now();

insert into public.procurement_source_coverage_map (workspace_id,source_key,executor_source_key,coverage_method,notes)
select workspace_id,'carleton_procurement','carleton_merx','alias','University procurement catalog row is covered by the live Carleton MERX adapter.'
from public.tender_sources where source_key='carleton_procurement'
on conflict (workspace_id,source_key) do update
set executor_source_key=excluded.executor_source_key,coverage_method=excluded.coverage_method,notes=excluded.notes,updated_at=now();

insert into public.procurement_source_coverage_map (workspace_id,source_key,executor_source_key,coverage_method,notes)
select workspace_id,'algonquin_procurement','algonquin_merx','alias','College procurement catalog row is covered by the live Algonquin MERX adapter.'
from public.tender_sources where source_key='algonquin_procurement'
on conflict (workspace_id,source_key) do update
set executor_source_key=excluded.executor_source_key,coverage_method=excluded.coverage_method,notes=excluded.notes,updated_at=now();

create or replace view public.v_procurement_source_health
with (security_invoker = true)
as
select
  s.workspace_id,
  s.source_key,
  s.display_name,
  s.source_url,
  s.ingestion_mode,
  s.coverage_tier,
  s.adapter_status,
  s.buyer_scope,
  coalesce(exec.last_run_at,s.last_run_at) as last_run_at,
  coalesce(exec.last_success_at,s.last_success_at) as last_success_at,
  coalesce(exec.last_error,s.last_error) as last_error,
  coalesce(exec.last_verified_at,s.last_verified_at) as last_verified_at,
  case
    when m.executor_source_key is null and s.adapter_status='manual_only' then 'manual_only'
    when coalesce(exec.last_error,s.last_error) is not null
      and (
        coalesce(exec.last_success_at,s.last_success_at) is null
        or coalesce(exec.last_run_at,s.last_run_at) > coalesce(exec.last_success_at,s.last_success_at)
      ) then 'failing'
    when coalesce(exec.last_success_at,s.last_success_at) is null then 'never_scanned'
    when coalesce(exec.last_success_at,s.last_success_at) < now() - interval '36 hours' then 'stale'
    else 'healthy'
  end as health_status,
  extract(epoch from (now() - coalesce(exec.last_success_at,s.last_success_at,exec.created_at,s.created_at)))/3600 as hours_since_success,
  m.executor_source_key,
  m.coverage_method
from public.tender_sources s
left join public.procurement_source_coverage_map m
  on m.workspace_id=s.workspace_id and m.source_key=s.source_key
left join public.tender_sources exec
  on exec.workspace_id=s.workspace_id and exec.source_key=m.executor_source_key
where s.enabled;

grant select on public.v_procurement_source_health to authenticated;

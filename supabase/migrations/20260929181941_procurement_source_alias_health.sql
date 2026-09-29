-- Normalize remaining source aliases so source-health states are explicit rather than ambiguous.
insert into public.procurement_source_coverage_map
  (workspace_id,source_key,executor_source_key,coverage_method,notes)
select workspace_id,'cepeo_procurement_watch','oca_link2build','portal',
       'Secondary public construction/facilities coverage through OCA / Link2Build; direct CEPEO procurement remains a separate portal gap.'
from public.tender_sources where source_key='cepeo_procurement_watch'
on conflict (workspace_id,source_key) do update
set executor_source_key=excluded.executor_source_key,
    coverage_method=excluded.coverage_method,
    notes=excluded.notes,
    updated_at=now();

insert into public.procurement_source_coverage_map
  (workspace_id,source_key,executor_source_key,coverage_method,notes)
select workspace_id,'cisss_outaouais_seao','seao','portal',
       'Direct opportunity access is through SEAO; automated SEAO adapter is not yet enabled.'
from public.tender_sources where source_key='cisss_outaouais_seao'
on conflict (workspace_id,source_key) do update
set executor_source_key=excluded.executor_source_key,
    coverage_method=excluded.coverage_method,
    notes=excluded.notes,
    updated_at=now();

insert into public.procurement_source_coverage_map
  (workspace_id,source_key,executor_source_key,coverage_method,notes)
select workspace_id,'sto_seao','seao','portal',
       'Direct opportunity access is through SEAO; automated SEAO adapter is not yet enabled.'
from public.tender_sources where source_key='sto_seao'
on conflict (workspace_id,source_key) do update
set executor_source_key=excluded.executor_source_key,
    coverage_method=excluded.coverage_method,
    notes=excluded.notes,
    updated_at=now();

insert into public.procurement_source_coverage_map
  (workspace_id,source_key,executor_source_key,coverage_method,notes)
select workspace_id,'ottawa_hospital_medbuy','biddingo','portal',
       'Direct Mohawk Medbuy opportunities are published through Biddingo; automated Biddingo adapter is not yet enabled.'
from public.tender_sources where source_key='ottawa_hospital_medbuy'
on conflict (workspace_id,source_key) do update
set executor_source_key=excluded.executor_source_key,
    coverage_method=excluded.coverage_method,
    notes=excluded.notes,
    updated_at=now();

insert into public.procurement_source_coverage_map
  (workspace_id,source_key,executor_source_key,coverage_method,notes)
select workspace_id,'royal_biddingo','biddingo','portal',
       'Direct Royal opportunities are published through Biddingo; automated Biddingo adapter is not yet enabled.'
from public.tender_sources where source_key='royal_biddingo'
on conflict (workspace_id,source_key) do update
set executor_source_key=excluded.executor_source_key,
    coverage_method=excluded.coverage_method,
    notes=excluded.notes,
    updated_at=now();

create or replace view public.v_procurement_source_health
with (security_invoker = true)
as
select
  s.workspace_id,s.source_key,s.display_name,s.source_url,s.ingestion_mode,s.coverage_tier,s.adapter_status,s.buyer_scope,
  coalesce(exec.last_run_at,s.last_run_at) as last_run_at,
  coalesce(exec.last_success_at,s.last_success_at) as last_success_at,
  coalesce(exec.last_error,s.last_error) as last_error,
  coalesce(exec.last_verified_at,s.last_verified_at) as last_verified_at,
  case
    when m.executor_source_key is null and s.adapter_status='manual_only' then 'manual_only'
    when exec.adapter_status='manual_only' then 'manual_only'
    when coalesce(exec.last_error,s.last_error) is not null
      and (coalesce(exec.last_success_at,s.last_success_at) is null
        or coalesce(exec.last_run_at,s.last_run_at) > coalesce(exec.last_success_at,s.last_success_at)) then 'failing'
    when coalesce(exec.last_success_at,s.last_success_at) is null then 'never_scanned'
    when coalesce(exec.last_success_at,s.last_success_at) < now() - interval '36 hours' then 'stale'
    when m.coverage_method='portal' then 'secondary_coverage'
    else 'healthy'
  end as health_status,
  extract(epoch from (now() - coalesce(exec.last_success_at,s.last_success_at,exec.created_at,s.created_at)))/3600 as hours_since_success,
  m.executor_source_key,m.coverage_method
from public.tender_sources s
left join public.procurement_source_coverage_map m
  on m.workspace_id=s.workspace_id and m.source_key=s.source_key
left join public.tender_sources exec
  on exec.workspace_id=s.workspace_id and exec.source_key=m.executor_source_key
where s.enabled;

grant select on public.v_procurement_source_health to authenticated;

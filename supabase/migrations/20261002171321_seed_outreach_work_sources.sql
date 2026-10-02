with defs(source_key,display_name,source_url,source_kind) as (
  values
    ('dynamic_building_subcontractors','Dynamic Building Improvements — Trusted Subcontractors','https://www.dynamicbuilding.ca/careers','standing_network'),
    ('fiore_subcontractors','Fiore Corp Renovations — Subcontractor Work','https://fiorecorprenovations.ca/join-the-team','standing_network'),
    ('omsg_service_network','Ottawa Multiservices Group — Service Network','https://www.ottawamultiservicesgroup.com/partners','standing_network'),
    ('machaalani_subcontractors','Machaalani Landscaping & Contracting — Subcontractors','https://www.machaalani.ca/','standing_network'),
    ('certapro_ottawa_subcontractors','CertaPro Painters Ottawa — Independent Contractor','https://app.careerplug.com/jobs/1951264/apps/new','standing_network'),
    ('613painting_subcontractors','613PAINTING — Subcontractor Application','https://613painting.com/join-our-team/','standing_network'),
    ('mbc_trade_registration','McDonald Brothers Construction — Trade Contractor List','https://mbc.ca/trade-registration-form/','standing_network'),
    ('mbc_current_tenders','McDonald Brothers Construction — Current Tenders','https://mbc.ca/current-tenders/','private_tender')
)
insert into public.outreach_work_sources(
  workspace_id,source_key,display_name,source_url,source_kind,enabled
)
select w.id,d.source_key,d.display_name,d.source_url,d.source_kind,true
from public.workspaces w
cross join defs d
where w.id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
on conflict(workspace_id,source_key) do update
set display_name=excluded.display_name,
    source_url=excluded.source_url,
    source_kind=excluded.source_kind,
    updated_at=now();

with seen as (
  select workspace_id,source_key,max(last_seen_at) as last_seen,count(*)::int as result_count
  from public.outreach_work_leads
  where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
  group by workspace_id,source_key
)
update public.outreach_work_sources s
set last_run_at=coalesce(s.last_run_at,seen.last_seen),
    last_success_at=coalesce(s.last_success_at,seen.last_seen),
    last_result_count=greatest(s.last_result_count,seen.result_count),
    updated_at=now()
from seen
where s.workspace_id=seen.workspace_id and s.source_key=seen.source_key;

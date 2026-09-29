-- Contact Gap Engine: prioritize missing buying-committee roles and preserve research evidence.
create table if not exists public.contact_enrichment_tasks(
 id uuid primary key default extensions.uuid_generate_v4(),
 workspace_id uuid not null references public.workspaces(id) on delete cascade,
 outreach_target_id uuid not null references public.outreach_targets(id) on delete cascade,
 organization_id uuid references public.organizations(id) on delete cascade,
 missing_role text not null check(missing_role in ('decision_maker','operations','procurement')),
 priority_score integer not null default 0,
 status text not null default 'queued' check(status in ('queued','researching','found','verified','not_found','dismissed')),
 research_query text,
 evidence_url text,
 evidence_label text,
 candidate_name text,
 candidate_title text,
 candidate_email text,
 candidate_phone text,
 confidence text check(confidence is null or confidence in ('low','medium','high')),
 last_attempt_at timestamptz,
 verified_at timestamptz,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(workspace_id,outreach_target_id,missing_role)
);
create index if not exists contact_enrichment_tasks_queue_idx on public.contact_enrichment_tasks(workspace_id,status,priority_score desc);
create index if not exists contact_enrichment_tasks_target_idx on public.contact_enrichment_tasks(outreach_target_id);
create index if not exists contact_enrichment_tasks_organization_idx on public.contact_enrichment_tasks(organization_id) where organization_id is not null;
alter table public.contact_enrichment_tasks enable row level security;
create policy contact_enrichment_tasks_member_select on public.contact_enrichment_tasks for select to authenticated using(private.is_workspace_member(workspace_id));
create policy contact_enrichment_tasks_member_update on public.contact_enrichment_tasks for update to authenticated using(private.is_workspace_member(workspace_id)) with check(private.is_workspace_member(workspace_id));
grant select,update on public.contact_enrichment_tasks to authenticated;

create or replace function private.refresh_contact_enrichment_queue(p_workspace uuid)
returns integer language plpgsql security invoker set search_path='' as $$
declare n integer;
begin
 insert into public.contact_enrichment_tasks(workspace_id,outreach_target_id,organization_id,missing_role,priority_score,research_query)
 select t.workspace_id,t.id,t.organization_id,r.role,
   least(100,coalesce(t.score,0)::int + case r.role when 'decision_maker' then 15 when 'operations' then 12 else 10 end),
   concat_ws(' ',coalesce(o.operating_name,o.legal_name,t.organization_name),case r.role when 'decision_maker' then 'owner president principal director' when 'operations' then 'operations facilities property maintenance manager' else 'procurement purchasing contracts buyer' end,'Ottawa')
 from public.outreach_targets t
 left join public.organizations o on o.id=t.organization_id
 left join public.v_outreach_contact_coverage cv on cv.outreach_target_id=t.id
 cross join lateral (values('decision_maker',coalesce(cv.has_decision_maker,false)),('operations',coalesce(cv.has_operations,false)),('procurement',coalesce(cv.has_procurement,false))) r(role,covered)
 where t.workspace_id=p_workspace and t.status::text in ('queued','contacted','responded') and not r.covered
 on conflict(workspace_id,outreach_target_id,missing_role) do update set
 priority_score=excluded.priority_score,research_query=excluded.research_query,updated_at=now()
 where public.contact_enrichment_tasks.status in ('queued','researching','not_found');
 get diagnostics n=row_count; return n;
end $$;
revoke all on function private.refresh_contact_enrichment_queue(uuid) from public,anon,authenticated;
grant execute on function private.refresh_contact_enrichment_queue(uuid) to service_role;

create or replace view public.v_contact_enrichment_queue with(security_invoker=true) as
select e.*,coalesce(o.operating_name,o.legal_name,t.organization_name) organization_name,t.score target_score,
 cv.contact_count,cv.contact_coverage_score
from public.contact_enrichment_tasks e join public.outreach_targets t on t.id=e.outreach_target_id
left join public.organizations o on o.id=e.organization_id
left join public.v_outreach_contact_coverage cv on cv.outreach_target_id=e.outreach_target_id
where e.status in ('queued','researching','found');
grant select on public.v_contact_enrichment_queue to authenticated;

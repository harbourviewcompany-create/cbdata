-- Research each organization/role once instead of burning capacity on duplicate targets.

update public.contact_enrichment_tasks e
set status='dismissed',
    updated_at=now(),
    last_error=coalesce(e.last_error,'covered by a verified organization contact')
where e.status in ('queued','researching','found','not_found')
  and exists (
    select 1
    from public.contact_enrichment_tasks v
    where v.workspace_id=e.workspace_id
      and v.organization_id=e.organization_id
      and v.missing_role=e.missing_role
      and v.status='verified'
  );

with ranked as (
  select
    e.id,
    row_number() over (
      partition by e.workspace_id,e.organization_id,e.missing_role
      order by
        case e.status when 'found' then 0 when 'researching' then 1 when 'queued' then 2 else 3 end,
        coalesce(e.research_priority_score,0) desc,
        e.priority_score desc,
        e.attempt_count asc,
        e.created_at asc
    ) as rn
  from public.contact_enrichment_tasks e
  where e.status in ('queued','researching','found','not_found')
)
update public.contact_enrichment_tasks e
set status='dismissed',
    updated_at=now(),
    last_error=coalesce(e.last_error,'duplicate organization/role research task')
from ranked r
where e.id=r.id and r.rn>1;

create unique index if not exists contact_enrichment_tasks_active_org_role_uidx
  on public.contact_enrichment_tasks(workspace_id,organization_id,missing_role)
  where status in ('queued','researching','found','not_found');

create or replace function private.refresh_contact_enrichment_queue(p_workspace uuid)
returns integer
language plpgsql
set search_path=''
as $$
declare
  n_updated integer:=0;
  n_inserted integer:=0;
begin
  with candidates as (
    select distinct on (t.workspace_id,t.organization_id,r.role)
      t.workspace_id,
      t.id as outreach_target_id,
      t.organization_id,
      r.role,
      least(
        100,
        coalesce(t.score,0)::int
        + case r.role when 'decision_maker' then 15 when 'operations' then 12 else 10 end
      ) as priority_score,
      concat_ws(
        ' ',
        coalesce(o.operating_name,o.legal_name,t.organization_name),
        case r.role
          when 'decision_maker' then 'owner president principal director'
          when 'operations' then 'operations facilities property maintenance manager'
          else 'procurement purchasing contracts buyer'
        end,
        'Ottawa'
      ) as research_query
    from public.outreach_targets t
    left join public.organizations o on o.id=t.organization_id
    left join public.v_outreach_contact_coverage cv on cv.outreach_target_id=t.id
    cross join lateral (
      values
        ('decision_maker',coalesce(cv.has_decision_maker,false)),
        ('operations',coalesce(cv.has_operations,false)),
        ('procurement',coalesce(cv.has_procurement,false))
    ) r(role,covered)
    where t.workspace_id=p_workspace
      and t.organization_id is not null
      and t.status::text in ('queued','contacted','responded')
      and not r.covered
    order by
      t.workspace_id,
      t.organization_id,
      r.role,
      coalesce(t.score,0) desc,
      t.updated_at desc,
      t.id
  )
  update public.contact_enrichment_tasks e
  set
    outreach_target_id=c.outreach_target_id,
    priority_score=c.priority_score,
    research_query=c.research_query,
    updated_at=now()
  from candidates c
  where e.workspace_id=c.workspace_id
    and e.organization_id=c.organization_id
    and e.missing_role=c.role
    and e.status in ('queued','researching','not_found');

  get diagnostics n_updated=row_count;

  with candidates as (
    select distinct on (t.workspace_id,t.organization_id,r.role)
      t.workspace_id,
      t.id as outreach_target_id,
      t.organization_id,
      r.role,
      least(
        100,
        coalesce(t.score,0)::int
        + case r.role when 'decision_maker' then 15 when 'operations' then 12 else 10 end
      ) as priority_score,
      concat_ws(
        ' ',
        coalesce(o.operating_name,o.legal_name,t.organization_name),
        case r.role
          when 'decision_maker' then 'owner president principal director'
          when 'operations' then 'operations facilities property maintenance manager'
          else 'procurement purchasing contracts buyer'
        end,
        'Ottawa'
      ) as research_query
    from public.outreach_targets t
    left join public.organizations o on o.id=t.organization_id
    left join public.v_outreach_contact_coverage cv on cv.outreach_target_id=t.id
    cross join lateral (
      values
        ('decision_maker',coalesce(cv.has_decision_maker,false)),
        ('operations',coalesce(cv.has_operations,false)),
        ('procurement',coalesce(cv.has_procurement,false))
    ) r(role,covered)
    where t.workspace_id=p_workspace
      and t.organization_id is not null
      and t.status::text in ('queued','contacted','responded')
      and not r.covered
    order by
      t.workspace_id,
      t.organization_id,
      r.role,
      coalesce(t.score,0) desc,
      t.updated_at desc,
      t.id
  )
  insert into public.contact_enrichment_tasks(
    workspace_id,outreach_target_id,organization_id,missing_role,priority_score,research_query
  )
  select
    c.workspace_id,c.outreach_target_id,c.organization_id,c.role,c.priority_score,c.research_query
  from candidates c
  where not exists (
    select 1
    from public.contact_enrichment_tasks e
    where e.workspace_id=c.workspace_id
      and e.organization_id=c.organization_id
      and e.missing_role=c.role
      and e.status in ('queued','researching','found','verified','not_found')
  )
  on conflict(workspace_id,outreach_target_id,missing_role) do update
  set
    status='queued',
    priority_score=excluded.priority_score,
    research_query=excluded.research_query,
    next_attempt_at=null,
    last_error=null,
    updated_at=now()
  where public.contact_enrichment_tasks.status='dismissed';

  get diagnostics n_inserted=row_count;
  return n_updated+n_inserted;
end
$$;

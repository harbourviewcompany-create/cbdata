-- Research backlog prioritization: commercial value + outreach urgency + evidence + role value + retry cost.
alter table public.contact_enrichment_tasks add column if not exists research_priority_score integer not null default 0;
alter table public.contact_enrichment_tasks add column if not exists research_priority_reason text;

create or replace function private.recalculate_contact_research_priorities(p_workspace uuid)
returns integer language plpgsql security invoker set search_path=public,private as $$
declare n integer;
begin
 if current_user not in ('service_role','postgres') then raise exception 'service role required'; end if;
 update public.contact_enrichment_tasks cet set
  research_priority_score=least(100,greatest(0,
   coalesce(t.score,0)
   + case cet.missing_role when 'decision_maker' then 14 when 'operations' then 10 when 'procurement' then 9 else 0 end
   + case when cq.command_mode='research' then 10 when cq.command_mode='verify_contact' then 7 else 0 end
   + least(12,coalesce(cq.high_signal_property_count,0)*4)
   + least(12,coalesce(cq.open_signal_count,0)*6)
   + case when cet.researcher_metadata->>'escalated_from'='outreach_command_queue' then 6 else 0 end
   - least(24,coalesce(cet.attempt_count,0)*8)
  )),
  research_priority_reason=concat_ws(' · ',
   case when coalesce(t.score,0)>=70 then 'high-value target' end,
   case cet.missing_role when 'decision_maker' then 'decision-maker gap' when 'operations' then 'operations gap' when 'procurement' then 'procurement gap' end,
   case when coalesce(cq.open_signal_count,0)>0 then 'active buying signal' end,
   case when coalesce(cq.high_signal_property_count,0)>0 then 'property evidence' end,
   case when cet.researcher_metadata->>'escalated_from'='outreach_command_queue' then 'blocks outreach' end,
   case when coalesce(cet.attempt_count,0)>0 then 'retry penalty '||cet.attempt_count end
  ),
  updated_at=now()
 from public.outreach_targets t
 left join public.v_outreach_command_queue cq on cq.outreach_target_id=t.id
 where cet.workspace_id=p_workspace and cet.outreach_target_id=t.id
 and cet.status in ('queued','researching','not_found');
 get diagnostics n=row_count; return n;
end $$;
revoke all on function private.recalculate_contact_research_priorities(uuid) from public,anon,authenticated;
grant execute on function private.recalculate_contact_research_priorities(uuid) to service_role;

create or replace function public.refresh_contact_research_queue(p_workspace uuid)
returns integer language plpgsql security invoker set search_path=public,private as $$
declare n integer;
begin
 if current_user not in ('service_role','postgres') then raise exception 'service role required'; end if;
 perform private.escalate_outreach_research(p_workspace);
 perform private.recalculate_contact_research_priorities(p_workspace);
 select count(*)::integer into n from public.contact_enrichment_tasks
 where workspace_id=p_workspace and status in ('queued','researching','not_found') and coalesce(next_attempt_at,now())<=now();
 return n;
end $$;
revoke all on function public.refresh_contact_research_queue(uuid) from public,anon,authenticated;
grant execute on function public.refresh_contact_research_queue(uuid) to service_role;

create index if not exists contact_enrichment_research_priority_idx on public.contact_enrichment_tasks(workspace_id,research_priority_score desc,next_attempt_at asc) where status in ('queued','researching','not_found');

drop view if exists public.v_contact_enrichment_queue;
create view public.v_contact_enrichment_queue with(security_invoker=true) as
select e.*,coalesce(o.operating_name,o.legal_name,t.organization_name) organization_name,t.score target_score,
 cv.contact_count,cv.contact_coverage_score
from public.contact_enrichment_tasks e join public.outreach_targets t on t.id=e.outreach_target_id
left join public.organizations o on o.id=e.organization_id left join public.v_outreach_contact_coverage cv on cv.outreach_target_id=e.outreach_target_id
where e.status in ('queued','researching','found');
grant select on public.v_contact_enrichment_queue to authenticated;

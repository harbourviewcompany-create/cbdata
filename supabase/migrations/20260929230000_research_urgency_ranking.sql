-- Uncapped urgency metric breaks ties among saturated research-priority scores.
alter table public.contact_enrichment_tasks add column if not exists research_urgency_rank integer not null default 0;

create or replace function private.recalculate_contact_research_priorities(p_workspace uuid)
returns integer language plpgsql security invoker set search_path=public,private as $$
declare n integer;
begin
 with signal_rollup as (
  select target_id,
   count(*) filter(where status='open' and source_confidence in ('medium','high')) open_signals,
   min(deadline_at) filter(where status='open' and deadline_at>=now()) nearest_deadline
  from public.target_opportunity_signals where workspace_id=p_workspace group by target_id
 )
 update public.contact_enrichment_tasks cet set
  research_priority_score=least(100,greatest(0,
   coalesce(t.score,0)::int + case cet.missing_role when 'decision_maker' then 14 when 'operations' then 10 when 'procurement' then 9 else 0 end
   +case when cq.command_mode='research' then 10 when cq.command_mode='verify_contact' then 7 else 0 end
   +least(12,coalesce(cq.high_signal_property_count,0)*4)+least(12,coalesce(sr.open_signals,0)*6)
   +case when cet.researcher_metadata->>'escalated_from'='outreach_command_queue' then 6 else 0 end
   -least(24,coalesce(cet.attempt_count,0)*8))),
  research_urgency_rank=
   coalesce(t.score,0)::int*10
   +case cet.missing_role when 'decision_maker' then 180 when 'procurement' then 160 when 'operations' then 140 else 0 end
   +case when cq.command_mode in ('research','verify_contact') then 160 else 0 end
   +coalesce(cq.high_signal_property_count,0)*45+coalesce(sr.open_signals,0)*90
   +case when sr.nearest_deadline between now() and now()+interval '7 days' then 350
         when sr.nearest_deadline between now()+interval '7 days' and now()+interval '30 days' then 240
         when sr.nearest_deadline between now()+interval '30 days' and now()+interval '90 days' then 120 else 0 end
   +case when cet.researcher_metadata->>'escalated_from'='outreach_command_queue' then 90 else 0 end
   +least(120,greatest(0,extract(epoch from(now()-cet.created_at))/86400)::int*4)
   -coalesce(cet.attempt_count,0)*110,
  research_priority_reason=concat_ws(' · ',
   case when coalesce(t.score,0)>=70 then 'high-value target' end,
   case cet.missing_role when 'decision_maker' then 'decision-maker gap' when 'operations' then 'operations gap' when 'procurement' then 'procurement gap' end,
   case when coalesce(sr.open_signals,0)>0 then 'active buying signal' end,
   case when sr.nearest_deadline between now() and now()+interval '7 days' then 'deadline <7d'
        when sr.nearest_deadline between now()+interval '7 days' and now()+interval '30 days' then 'deadline <30d' end,
   case when coalesce(cq.high_signal_property_count,0)>0 then 'property evidence' end,
   case when cet.researcher_metadata->>'escalated_from'='outreach_command_queue' then 'blocks outreach' end,
   case when coalesce(cet.attempt_count,0)>0 then 'retry penalty '||cet.attempt_count end),
  updated_at=now()
 from public.outreach_targets t
 left join public.v_outreach_command_queue cq on cq.outreach_target_id=t.id
 left join signal_rollup sr on sr.target_id=t.id
 where cet.workspace_id=p_workspace and cet.outreach_target_id=t.id and cet.status in ('queued','researching','not_found');
 get diagnostics n=row_count; return n;
end $$;

drop index if exists contact_enrichment_research_priority_idx;
create index contact_enrichment_research_priority_idx on public.contact_enrichment_tasks(workspace_id,research_priority_score desc,research_urgency_rank desc,next_attempt_at asc) where status in ('queued','researching','not_found');

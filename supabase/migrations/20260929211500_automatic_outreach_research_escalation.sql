-- Automatically escalate unresolved command-queue routes into contact research.
create or replace function private.escalate_outreach_research(p_workspace uuid)
returns integer language plpgsql security invoker set search_path=public,private as $$
declare n integer:=0;
begin
 if current_user not in ('service_role','postgres') then raise exception 'service role required'; end if;
 perform private.refresh_contact_enrichment_queue(p_workspace);
 with research_targets as (
   select distinct q.outreach_target_id
   from public.v_outreach_command_queue q
   where q.workspace_id=p_workspace and q.command_mode in ('research','verify_contact')
 ), changed as (
   update public.contact_enrichment_tasks cet
   set status='queued',
       next_attempt_at=case when cet.next_attempt_at is null or cet.next_attempt_at>now() then now() else cet.next_attempt_at end,
       last_error=null,
       researcher_metadata=coalesce(cet.researcher_metadata,'{}'::jsonb)||jsonb_build_object('escalated_from','outreach_command_queue','escalated_at',now()),
       updated_at=now()
   from research_targets r
   where cet.workspace_id=p_workspace and cet.outreach_target_id=r.outreach_target_id
     and cet.status in ('queued','researching','not_found','dismissed')
   returning cet.id
 )
 select count(*) into n from changed;
 return n;
end $$;
revoke all on function private.escalate_outreach_research(uuid) from public,anon,authenticated;
grant execute on function private.escalate_outreach_research(uuid) to service_role;

create or replace function public.refresh_contact_research_queue(p_workspace uuid)
returns integer language plpgsql security invoker set search_path=public,private as $$
declare n integer;
begin
 if current_user not in ('service_role','postgres') then raise exception 'service role required'; end if;
 perform private.escalate_outreach_research(p_workspace);
 select count(*)::integer into n from public.contact_enrichment_tasks
 where workspace_id=p_workspace and status in ('queued','researching','not_found')
 and coalesce(next_attempt_at,now())<=now();
 return n;
end $$;
revoke all on function public.refresh_contact_research_queue(uuid) from public,anon,authenticated;
grant execute on function public.refresh_contact_research_queue(uuid) to service_role;

-- Run shortly before the existing contact researcher so research-mode command rows are always queued first.
do $$
declare jid bigint;
begin
 select jobid into jid from cron.job where jobname='cbdata-outreach-research-escalation';
 if jid is not null then perform cron.unschedule(jid); end if;
 perform cron.schedule(
  'cbdata-outreach-research-escalation',
  '35 12 * * *',
  $cron$select private.escalate_outreach_research('431aa13d-3e7c-41e3-9686-e840b8ea5b7c'::uuid);$cron$
 );
end $$;

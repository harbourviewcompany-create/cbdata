begin;
do $$ begin
 if to_regprocedure('private.escalate_outreach_research(uuid)') is null then raise exception 'research escalation missing'; end if;
 if has_function_privilege('authenticated','private.escalate_outreach_research(uuid)','EXECUTE') then raise exception 'research escalation exposed'; end if;
 if to_regprocedure('public.refresh_contact_research_queue(uuid)') is null then raise exception 'research refresh wrapper missing'; end if;
end $$;
select 1/(case when exists(select 1 from cron.job where jobname='cbdata-outreach-research-escalation' and schedule='35 12 * * *') then 1 else 0 end);
rollback;
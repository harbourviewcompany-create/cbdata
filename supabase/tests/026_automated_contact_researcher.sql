begin;
do $$
begin
 if to_regprocedure('public.refresh_contact_research_queue(uuid)') is null then raise exception 'refresh wrapper missing'; end if;
 if to_regprocedure('public.promote_verified_contact_candidate(uuid)') is null then raise exception 'promotion RPC missing'; end if;
 if has_function_privilege('authenticated','public.promote_verified_contact_candidate(uuid)','EXECUTE') then raise exception 'promotion exposed'; end if;
 if not exists(select 1 from cron.job where jobname='cbdata-contact-researcher') then raise exception 'researcher cron missing'; end if;
end $$;
rollback;
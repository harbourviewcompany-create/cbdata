begin;
do $$
begin
 if to_regclass('public.v_procurement_source_health') is null then raise exception 'source health view missing'; end if;
 if to_regclass('public.v_procurement_inbox') is null then raise exception 'procurement inbox view missing'; end if;
 if to_regprocedure('private.refresh_procurement_decision_fields(uuid)') is null then raise exception 'decision refresh missing'; end if;
 if has_function_privilege('anon','private.refresh_procurement_decision_fields(uuid)','EXECUTE')
    or has_function_privilege('authenticated','private.refresh_procurement_decision_fields(uuid)','EXECUTE') then
   raise exception 'decision refresh exposed to clients';
 end if;
 if not exists(select 1 from pg_indexes where schemaname='public' and indexname='procurement_opportunities_workspace_canonical_uidx') then raise exception 'canonical dedupe index missing'; end if;
end $$;
rollback;
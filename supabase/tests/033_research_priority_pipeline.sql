begin;
do $$ begin
 if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='contact_enrichment_tasks' and column_name='research_priority_score') then raise exception 'research priority missing'; end if;
 if to_regprocedure('private.recalculate_contact_research_priorities(uuid)') is null then raise exception 'priority calculator missing'; end if;
 if has_function_privilege('authenticated','private.recalculate_contact_research_priorities(uuid)','EXECUTE') then raise exception 'priority calculator exposed'; end if;
end $$;
rollback;
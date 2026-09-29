begin;
do $$ begin
 if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='contact_enrichment_tasks' and column_name='research_urgency_rank') then raise exception 'urgency rank missing'; end if;
end $$;
rollback;
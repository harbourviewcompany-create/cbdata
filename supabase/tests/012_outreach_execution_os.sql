-- Outreach execution OS regression checks.
do $$
declare n int;
begin
  if to_regclass('public.outreach_drafts') is null then raise exception 'outreach_drafts missing'; end if;
  if to_regclass('public.outreach_replies') is null then raise exception 'outreach_replies missing'; end if;

  select count(*) into n
  from information_schema.columns
  where table_schema='public' and table_name='v_outreach_execution_queue'
    and column_name in ('outreach_readiness_score','contact_confidence_score','recommended_action','why_now');
  if n <> 4 then raise exception 'execution queue scoring/action columns missing'; end if;

  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='generate_outreach_draft'
  ) then raise exception 'generate_outreach_draft missing'; end if;

  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='classify_outreach_reply'
  ) then raise exception 'classify_outreach_reply missing'; end if;
end $$;

begin;
do $$
declare
  fn text;
begin
  if to_regclass('public.outreach_contact_role_requirements') is null then
    raise exception 'contact role requirement table missing';
  end if;
  if to_regclass('public.v_outreach_account_contact_coverage') is null then
    raise exception 'account contact coverage view missing';
  end if;
  if to_regprocedure('public.refresh_contact_coverage_tasks_system(uuid)') is null then
    raise exception 'workspace contact coverage refresh missing';
  end if;
  if to_regprocedure('public.refresh_all_contact_coverage_tasks_system()') is null then
    raise exception 'global contact coverage refresh missing';
  end if;
  if has_function_privilege('authenticated','public.refresh_contact_coverage_tasks_system(uuid)','EXECUTE') then
    raise exception 'authenticated must not execute system contact coverage refresh';
  end if;
  if not has_function_privilege('service_role','public.refresh_contact_coverage_tasks_system(uuid)','EXECUTE') then
    raise exception 'service role cannot execute contact coverage refresh';
  end if;
  if not exists(
    select 1 from information_schema.columns
    where table_schema='public' and table_name='tender_sources' and column_name='source_category'
  ) then raise exception 'tender source category missing'; end if;
  if not exists(
    select 1 from information_schema.columns
    where table_schema='public' and table_name='tender_sources' and column_name='supports_small_jobs'
  ) then raise exception 'small-job source flag missing'; end if;
  if not exists(
    select 1 from pg_constraint
    where conrelid='public.contact_enrichment_tasks'::regclass
      and conname='contact_enrichment_tasks_missing_role_check'
      and pg_get_constraintdef(oid) like '%facilities%'
      and pg_get_constraintdef(oid) like '%project_manager%'
  ) then raise exception 'expanded contact roles missing'; end if;
  select pg_get_functiondef('public.refresh_contact_coverage_tasks_system(uuid)'::regprocedure) into fn;
  if position('contact_coverage_engine' in fn)=0 then
    raise exception 'coverage engine metadata missing from task refresh';
  end if;
end $$;
rollback;

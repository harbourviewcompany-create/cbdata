begin;
do $$
begin
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='log_property_visit') then
    raise exception 'log_property_visit missing';
  end if;
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='convert_estimate_to_contract') then
    raise exception 'convert_estimate_to_contract missing';
  end if;
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='issue_invoice') then
    raise exception 'issue_invoice missing';
  end if;
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='record_invoice_payment') then
    raise exception 'record_invoice_payment missing';
  end if;
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='run_nightly_ops') then
    raise exception 'run_nightly_ops missing';
  end if;
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='assignment_overlaps') then
    raise exception 'assignment_overlaps missing';
  end if;
  if not exists (select 1 from information_schema.tables where table_schema='public' and table_name='workspace_invites') then
    raise exception 'workspace_invites missing';
  end if;
  raise notice 'Operating loop verification passed';
end $$;
rollback;

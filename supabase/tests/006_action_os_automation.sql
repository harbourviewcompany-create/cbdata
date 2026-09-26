begin;
do $$
begin
  if not exists (select 1 from information_schema.tables where table_schema='public' and table_name='notifications') then
    raise exception 'notifications missing';
  end if;
  if not exists (select 1 from information_schema.tables where table_schema='public' and table_name='outreach_sequences') then
    raise exception 'outreach_sequences missing';
  end if;
  if not exists (select 1 from information_schema.tables where table_schema='public' and table_name='outreach_enrollments') then
    raise exception 'outreach_enrollments missing';
  end if;
  if not exists (select 1 from information_schema.views where table_schema='public' and table_name='v_next_actions') then
    raise exception 'v_next_actions missing';
  end if;
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='complete_work_order_with_invoice') then
    raise exception 'complete_work_order_with_invoice missing';
  end if;
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='generate_work_orders_from_contract') then
    raise exception 'generate_work_orders_from_contract missing';
  end if;
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='enroll_outreach_target') then
    raise exception 'enroll_outreach_target missing';
  end if;
  raise notice 'Action OS automation verification passed';
end $$;
rollback;

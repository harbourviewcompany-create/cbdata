begin;
do $$
begin
  if to_regclass('public.v_procurement_source_health') is null then
    raise exception 'source health view missing';
  end if;
  if to_regclass('public.v_procurement_inbox') is null then
    raise exception 'procurement inbox view missing';
  end if;
  if to_regprocedure('public.refresh_procurement_sales_engine(uuid)') is null then
    raise exception 'procurement sales engine refresh missing';
  end if;
  if has_function_privilege('anon','public.refresh_procurement_sales_engine(uuid)','EXECUTE')
     or has_function_privilege('authenticated','public.refresh_procurement_sales_engine(uuid)','EXECUTE') then
    raise exception 'procurement sales engine refresh exposed to clients';
  end if;
  if not has_function_privilege('service_role','public.refresh_procurement_sales_engine(uuid)','EXECUTE') then
    raise exception 'service role cannot refresh procurement sales engine';
  end if;
  if not exists (
    select 1
    from pg_indexes
    where schemaname='public'
      and indexname='procurement_opportunities_workspace_canonical_idx'
  ) then
    raise exception 'canonical lookup index missing';
  end if;
  if exists (
    select 1
    from pg_indexes
    where schemaname='public'
      and indexname='procurement_opportunities_workspace_canonical_idx'
      and indexdef ilike 'create unique%'
  ) then
    raise exception 'canonical cross-source index must not be unique';
  end if;
  if not exists (
    select 1
    from information_schema.columns
    where table_schema='public'
      and table_name='procurement_opportunities'
      and column_name='qualification_gap_count'
  ) then
    raise exception 'qualification gap field missing';
  end if;
  if to_regclass('public.procurement_source_coverage_map') is null then
    raise exception 'procurement source coverage map missing';
  end if;
  if exists (
    select 1 from public.v_procurement_inbox where classification_status='suppressed'
  ) then
    raise exception 'suppressed procurement opportunity leaked into inbox';
  end if;
  if exists (
    select canonical_key
    from public.v_procurement_inbox
    where canonical_key is not null
    group by canonical_key
    having count(*) > 1
  ) then
    raise exception 'canonical duplicate leaked into procurement inbox';
  end if;
  if not exists (
    select 1
    from information_schema.columns
    where table_schema='public'
      and table_name='procurement_opportunities'
      and column_name='auto_next_action'
  ) then
    raise exception 'automatic next action field missing';
  end if;
end $$;

select public.refresh_procurement_sales_engine(null);
rollback;

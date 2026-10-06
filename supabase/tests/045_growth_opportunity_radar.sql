begin;
do $$
declare
  opts text[];
begin
  if to_regclass('public.v_growth_opportunity_radar') is null then
    raise exception 'growth opportunity radar missing';
  end if;
  if to_regclass('public.v_growth_opportunity_radar_deduped') is null then
    raise exception 'deduped growth opportunity radar missing';
  end if;

  select c.reloptions into opts
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname='v_growth_opportunity_radar_deduped';
  if opts is null or not ('security_invoker=true'=any(opts)) then
    raise exception 'deduped opportunity radar must use security_invoker';
  end if;

  if not exists(
    select 1 from information_schema.columns
    where table_schema='public' and table_name='v_growth_opportunity_radar_deduped'
      and column_name='duplicate_count'
  ) then raise exception 'opportunity radar duplicate_count missing'; end if;

  if not exists(
    select 1 from information_schema.columns
    where table_schema='public' and table_name='v_growth_opportunity_radar'
      and column_name='origin'
  ) then raise exception 'opportunity radar origin missing'; end if;

  if not exists(
    select 1 from information_schema.columns
    where table_schema='public' and table_name='tender_sources'
      and column_name='discovery_priority'
  ) then raise exception 'procurement source discovery priority missing'; end if;
end $$;
rollback;

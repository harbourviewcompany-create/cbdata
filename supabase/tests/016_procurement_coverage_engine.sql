begin;

do $$
declare
  expected text[] := array[
    'procurement_buyers',
    'procurement_opportunities',
    'procurement_awards',
    'procurement_coverage_runs'
  ];
  missing text[];
begin
  select array_agg(x order by x) into missing
  from unnest(expected) x
  where not exists (
    select 1 from information_schema.tables t
    where t.table_schema='public' and t.table_name=x and t.table_type='BASE TABLE'
  );
  if missing is not null then raise exception 'Missing procurement coverage tables: %', missing; end if;

  if (
    select count(*)
    from pg_class c
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname=any(expected) and c.relrowsecurity and c.relforcerowsecurity
  ) <> array_length(expected,1) then
    raise exception 'RLS/FORCE RLS missing on procurement coverage tables';
  end if;

  if not exists (
    select 1 from pg_class c
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname='v_procurement_buyer_coverage' and c.relkind='v'
      and coalesce(c.reloptions,'{}'::text[]) @> array['security_invoker=true']
  ) then
    raise exception 'v_procurement_buyer_coverage missing security_invoker';
  end if;

  if not exists (
    select 1 from pg_indexes
    where schemaname='public' and indexname='idx_procurement_opportunities_queue'
  ) then raise exception 'procurement opportunity queue index missing'; end if;

  if (select count(*) from public.procurement_buyers b join public.workspaces w on w.id=b.workspace_id where w.slug='cb-contracting') < 20 then
    raise exception 'regional buyer universe was not seeded';
  end if;

  raise notice 'Regional Procurement Coverage Engine verification passed';
end $$;

rollback;

-- CBData database-level verification.
-- Run against an isolated database after migrations are applied.
begin;
do $$
declare
  expected text[] := array[
    'workspaces','workspace_memberships','organizations','contacts','properties','buildings',
    'leads','opportunities','activities','service_definitions','estimates','estimate_items',
    'documents','photos','proposals','contracts','contract_services','service_schedules',
    'work_orders','work_order_tasks','employees','crews','crew_members','contractors','equipment',
    'work_order_assignments','work_visits','issues','inspections','inspection_items',
    'time_entries','material_usage','subcontractor_costs','expenses','invoices','invoice_items',
    'payments','communications','tasks','notes','audit_events','system_events'
  ];
  missing text[];
  n int;
begin
  select array_agg(x order by x) into missing
  from unnest(expected) x
  where not exists(select 1 from information_schema.tables t where t.table_schema='public' and t.table_name=x and t.table_type='BASE TABLE');
  if missing is not null then raise exception 'Missing canonical tables: %', missing; end if;

  select count(*) into n from information_schema.columns
  where table_schema='public' and column_name='workspace_id';
  if n < 40 then raise exception 'Insufficient workspace-scoped tables: %',n; end if;

  if (select count(*) from pg_type t join pg_namespace ns on ns.oid=t.typnamespace where ns.nspname='public' and t.typtype='e') < 30
    then raise exception 'Canonical enum set incomplete'; end if;

  if (select count(*) from pg_class c join pg_namespace ns on ns.oid=c.relnamespace where ns.nspname='public' and c.relkind='r' and c.relrowsecurity) < 40
    then raise exception 'RLS is not enabled on the canonical tables'; end if;

  if (select count(*) from pg_class c join pg_namespace ns on ns.oid=c.relnamespace where ns.nspname='public' and c.relkind='r' and c.relforcerowsecurity) < 40
    then raise exception 'FORCE RLS is not enabled on the canonical tables'; end if;

  if not exists(select 1 from pg_proc p join pg_namespace ns on ns.oid=p.pronamespace where ns.nspname='public' and p.proname='is_workspace_member')
    then raise exception 'Workspace membership security function missing'; end if;

  if not exists(select 1 from pg_views where schemaname='public' and viewname='property_360')
    then raise exception 'property_360 view missing'; end if;

  if not exists(select 1 from pg_indexes where schemaname='public' and indexname='idx_work_orders_schedule')
    then raise exception 'work-order schedule index missing'; end if;

  raise notice 'CBData canonical schema verification passed';
end $$;
rollback;

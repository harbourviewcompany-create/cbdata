begin;
do $$
begin
  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'next_actions'
  ) then
    raise exception 'next_actions missing';
  end if;

  if not exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'workspace_ops_snapshots'
  ) then
    raise exception 'workspace_ops_snapshots missing';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'user_profiles' and column_name = 'active_workspace_id'
  ) then
    raise exception 'user_profiles.active_workspace_id missing';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'invoices' and column_name = 'work_order_id'
  ) then
    raise exception 'invoices.work_order_id missing';
  end if;

  if not exists (
    select 1 from pg_indexes
    where schemaname = 'public' and indexname = 'idx_memberships_active_user_workspace'
  ) then
    raise exception 'active membership unique index missing';
  end if;

  if not exists (
    select 1 from pg_indexes
    where schemaname = 'public' and indexname = 'idx_invoices_work_order_unique'
  ) then
    raise exception 'invoice work_order unique index missing';
  end if;

  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'is_workspace_member'
  ) then
    raise exception 'private.is_workspace_member missing';
  end if;

  raise notice 'Command center optimization verification passed';
end $$;
rollback;

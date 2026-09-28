begin;

do $$
declare
  r record;
  table_name text;
  required_tables text[] := array[
    'notifications',
    'outreach_sequences',
    'outreach_sequence_steps',
    'outreach_enrollments'
  ];
  required_rpc text[] := array[
    'create_notification',
    'enroll_outreach_target',
    'process_due_sequence_steps',
    'ensure_default_pm_sequence',
    'generate_work_orders_from_contract',
    'complete_work_order_with_invoice'
  ];
begin
  foreach table_name in array required_tables loop
    if not exists (
      select 1
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relname = table_name
        and c.relkind = 'r'
    ) then
      raise exception 'Action OS table missing: %', table_name;
    end if;

    if not exists (
      select 1
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relname = table_name
        and c.relrowsecurity
        and c.relforcerowsecurity
    ) then
      raise exception 'Action OS table must have RLS and FORCE RLS: %', table_name;
    end if;
  end loop;

  if not exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'v_next_actions'
      and c.relkind = 'v'
      and c.reloptions @> array['security_invoker=true']
  ) then
    raise exception 'v_next_actions missing security_invoker=true';
  end if;

  foreach table_name in array required_rpc loop
    if not exists (
      select 1
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname = table_name
    ) then
      raise exception 'Action OS RPC missing: %', table_name;
    end if;
  end loop;

  for r in
    select
      p.oid,
      p.proname,
      pg_get_function_identity_arguments(p.oid) as args
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = any(required_rpc)
  loop
    if r.proname = 'complete_work_order_with_invoice'
       and r.args <> 'p_work_order_id uuid, p_notes text' then
      raise exception 'Unexpected complete_work_order_with_invoice signature: %', r.args;
    end if;

    if (select prosecdef from pg_proc where oid = r.oid) then
      raise exception 'Action OS RPC is SECURITY DEFINER: %', r.proname;
    end if;

    if not has_function_privilege('authenticated', r.oid, 'EXECUTE') then
      raise exception 'authenticated EXECUTE missing: %', r.proname;
    end if;

    if has_function_privilege('anon', r.oid, 'EXECUTE') then
      raise exception 'anon EXECUTE must be revoked: %', r.proname;
    end if;
  end loop;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'notifications'
      and policyname = 'notifications_select_own'
      and 'authenticated' = any(roles)
  ) then
    raise exception 'notifications authenticated select policy missing';
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'notifications'
      and policyname = 'notifications_update_own'
      and 'authenticated' = any(roles)
  ) then
    raise exception 'notifications authenticated update policy missing';
  end if;

  raise notice 'Action OS automation comprehensive verification passed';
end $$;

rollback;

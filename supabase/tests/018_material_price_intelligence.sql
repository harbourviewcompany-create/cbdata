begin;

do $$
declare
  expected text[] := array[
    'material_suppliers',
    'material_catalog_items',
    'material_supplier_products',
    'material_price_observations',
    'material_requests',
    'material_request_items',
    'material_price_runs',
    'material_price_run_results',
    'material_price_plans'
  ];
  t text;
  n integer;
  w uuid;
begin
  select count(*) into n
  from information_schema.tables
  where table_schema='public'
    and table_name=any(expected)
    and table_type='BASE TABLE';
  if n <> array_length(expected,1) then
    raise exception 'Material price intelligence tables missing: found %/%', n, array_length(expected,1);
  end if;

  select count(*) into n
  from pg_class c
  join pg_namespace ns on ns.oid=c.relnamespace
  where ns.nspname='public'
    and c.relname=any(expected)
    and c.relrowsecurity
    and c.relforcerowsecurity;
  if n <> array_length(expected,1) then
    raise exception 'RLS/FORCE RLS missing on material price tables';
  end if;

  foreach t in array expected
  loop
    if has_table_privilege('anon',format('public.%I',t),'SELECT')
       or has_table_privilege('anon',format('public.%I',t),'INSERT')
       or has_table_privilege('anon',format('public.%I',t),'UPDATE')
       or has_table_privilege('anon',format('public.%I',t),'DELETE') then
      raise exception 'anon has material price table access on %', t;
    end if;

    if not has_table_privilege('authenticated',format('public.%I',t),'SELECT') then
      raise exception 'authenticated SELECT missing on %', t;
    end if;

    if (
      select count(*)
      from pg_policies
      where schemaname='public'
        and tablename=t
        and policyname in (
          'workspace_member_select',
          'workspace_material_operator_insert',
          'workspace_material_operator_update',
          'workspace_material_operator_delete'
        )
    ) <> 4 then
      raise exception 'Expected four material policies on %', t;
    end if;
  end loop;

  if not exists (
    select 1
    from pg_class c
    join pg_namespace ns on ns.oid=c.relnamespace
    where ns.nspname='public'
      and c.relname='v_material_request_summary'
      and c.relkind='v'
      and coalesce(c.reloptions,'{}'::text[]) @> array['security_invoker=true']
  ) then
    raise exception 'v_material_request_summary must be a security_invoker view';
  end if;

  if not exists (
    select 1
    from information_schema.table_constraints tc
    join information_schema.constraint_column_usage ccu
      on ccu.constraint_name=tc.constraint_name
     and ccu.constraint_schema=tc.constraint_schema
    where tc.table_schema='public'
      and tc.table_name='material_requests'
      and tc.constraint_type='FOREIGN KEY'
      and ccu.table_schema='public'
      and ccu.table_name='estimates'
  ) then
    raise exception 'material_requests must link to estimates';
  end if;

  select id into w from public.workspaces where slug='cb-contracting' limit 1;
  if w is not null then
    if (select count(*) from public.material_suppliers where workspace_id=w and active) < 4 then
      raise exception 'CB Contracting supplier registry was not seeded';
    end if;
    if (select count(*) from public.material_catalog_items where workspace_id=w and active) < 15 then
      raise exception 'CB Contracting deck lumber catalog was not seeded';
    end if;
  end if;

  raise notice 'Material Price Intelligence verification passed';
end $$;

rollback;

begin;

do $$
declare
  fn_oid oid;
begin
  select p.oid
  into fn_oid
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'convert_estimate_to_contract'
    and pg_get_function_identity_arguments(p.oid) = 'p_estimate_id uuid';

  if fn_oid is null then
    raise exception 'convert_estimate_to_contract(uuid) is missing';
  end if;

  if not exists (
    select 1
    from information_schema.columns
    where table_schema='public'
      and table_name='contracts'
      and column_name='source_estimate_id'
  ) then
    raise exception 'contracts.source_estimate_id is missing';
  end if;

  if not exists (
    select 1
    from pg_index i
    join pg_class t on t.oid=i.indrelid
    join pg_namespace n on n.oid=t.relnamespace
    where n.nspname='public'
      and t.relname='contracts'
      and i.indisunique
      and i.indpred is null
      and (
        select array_agg(a.attname order by z.ordinality)
        from unnest(i.indkey) with ordinality z(attnum, ordinality)
        join pg_attribute a on a.attrelid=i.indrelid and a.attnum=z.attnum
      ) = array['source_estimate_id']::name[]
  ) then
    raise exception 'contracts.source_estimate_id unique index is missing';
  end if;

  if has_function_privilege('anon', 'public.convert_estimate_to_contract(uuid)', 'EXECUTE') then
    raise exception 'anon must not execute convert_estimate_to_contract';
  end if;

  if not has_function_privilege('authenticated', 'public.convert_estimate_to_contract(uuid)', 'EXECUTE') then
    raise exception 'authenticated must execute convert_estimate_to_contract';
  end if;

  if (select prosecdef from pg_proc where oid=fn_oid) then
    raise exception 'convert_estimate_to_contract must remain SECURITY INVOKER';
  end if;
end $$;

rollback;

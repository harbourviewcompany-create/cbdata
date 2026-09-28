begin;

do $$
declare
  n int;
  converter_def text;
begin
  select count(*) into n
  from information_schema.columns
  where table_schema='public' and table_name='estimates'
    and column_name in (
      'sent_at','accepted_at','rejected_at','estimate_kind',
      'site_verified_at','site_verified_by','site_verification_notes'
    );
  if n <> 7 then
    raise exception 'Deck estimate audit columns missing: found %/7', n;
  end if;

  if not exists (
    select 1
    from pg_trigger
    where tgrelid='public.estimate_items'::regclass
      and tgname='sync_estimate_totals'
      and not tgisinternal
  ) then
    raise exception 'estimate total sync trigger missing';
  end if;

  select count(*) into n
  from pg_proc p
  join pg_namespace ns on ns.oid=p.pronamespace
  where ns.nspname='public'
    and p.proname in (
      'create_deck_estimate_draft',
      'update_deck_estimate_draft',
      'advance_estimate',
      'convert_estimate_to_contract'
    )
    and not p.prosecdef;
  if n <> 4 then
    raise exception 'Expected 4 SECURITY INVOKER estimate RPCs, found %', n;
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace ns on ns.oid=p.pronamespace
    where ns.nspname='public'
      and p.proname in (
        'create_deck_estimate_draft',
        'update_deck_estimate_draft',
        'advance_estimate',
        'convert_estimate_to_contract'
      )
      and has_function_privilege('anon',p.oid,'EXECUTE')
  ) then
    raise exception 'anon can execute an estimate workflow RPC';
  end if;

  select count(*) into n
  from pg_proc p
  join pg_namespace ns on ns.oid=p.pronamespace
  where ns.nspname='public'
    and p.proname in (
      'create_deck_estimate_draft',
      'update_deck_estimate_draft',
      'advance_estimate',
      'convert_estimate_to_contract'
    )
    and has_function_privilege('authenticated',p.oid,'EXECUTE');
  if n <> 4 then
    raise exception 'Authenticated execute missing for estimate RPCs';
  end if;

  if has_table_privilege('anon','public.estimates','SELECT')
     or has_table_privilege('anon','public.estimate_items','SELECT') then
    raise exception 'anon estimate table access should be revoked';
  end if;

  if has_table_privilege('authenticated','public.estimates','DELETE') then
    raise exception 'authenticated estimate deletion should be revoked';
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='estimates'
      and policyname='estimate_sales_update'
      and cmd='UPDATE'
      and 'authenticated'=any(roles)
  ) then
    raise exception 'sales-scoped estimate update policy missing';
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='estimate_items'
      and policyname='estimate_item_sales_delete'
      and cmd='DELETE'
      and 'authenticated'=any(roles)
  ) then
    raise exception 'draft estimate item delete policy missing';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='contracts'
      and column_name='source_estimate_id'
  ) then
    raise exception 'contracts.source_estimate_id missing';
  end if;

  select pg_get_functiondef(p.oid) into converter_def
  from pg_proc p
  join pg_namespace ns on ns.oid=p.pronamespace
  where ns.nspname='public'
    and p.proname='convert_estimate_to_contract'
    and pg_get_function_identity_arguments(p.oid)='p_estimate_id uuid';

  if converter_def is null then
    raise exception 'convert_estimate_to_contract(uuid) missing';
  end if;
  if position('i.created_at' in converter_def)>0 then
    raise exception 'converter references nonexistent estimate_items.created_at';
  end if;
  if position('Only accepted estimates can become contracts' in converter_def)=0 then
    raise exception 'converter is not accepted-only';
  end if;
  if position('private.has_workspace_role' in converter_def)=0 then
    raise exception 'converter lacks database role authorization';
  end if;

  raise notice 'Deck estimate workflow verification passed';
end $$;

rollback;

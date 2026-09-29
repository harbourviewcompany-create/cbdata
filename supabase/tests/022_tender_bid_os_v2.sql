begin;

do $$
declare
  missing text[];
  t text;
  rls_ok boolean;
  view_ok boolean;
  trigger_ok boolean;
begin
  select array_agg(x.name order by x.name) into missing
  from (values
    ('tender_amendments'),
    ('tender_clarifications'),
    ('tender_supplier_quotes'),
    ('tender_supplier_quote_lines'),
    ('tender_cost_models'),
    ('tender_risks'),
    ('tender_approvals'),
    ('supplier_document_vault'),
    ('tender_callups')
  ) as x(name)
  where to_regclass('public.'||x.name) is null;

  if missing is not null then
    raise exception 'Tender Bid OS v2 tables missing: %', missing;
  end if;

  foreach t in array array[
    'tender_amendments','tender_clarifications','tender_supplier_quotes',
    'tender_supplier_quote_lines','tender_cost_models','tender_risks',
    'tender_approvals','supplier_document_vault','tender_callups'
  ]
  loop
    select c.relrowsecurity and c.relforcerowsecurity into rls_ok
    from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname=t;

    if rls_ok is distinct from true then
      raise exception 'RLS/FORCE RLS missing on %', t;
    end if;
  end loop;

  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='tender_requirements'
      and column_name='evidence_required'
  ) then
    raise exception 'tender_requirements.evidence_required missing';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='tender_records'
      and column_name='commercial_model_required'
  ) then
    raise exception 'tender_records.commercial_model_required missing';
  end if;

  select coalesce(c.reloptions,'{}'::text[]) @> array['security_invoker=true']
  into view_ok
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname='v_tender_bid_readiness';

  if view_ok is distinct from true then
    raise exception 'v_tender_bid_readiness must be security_invoker';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='v_tender_bid_readiness'
      and column_name='ready_to_submit'
  ) then
    raise exception 'Tender readiness view missing ready_to_submit';
  end if;

  select exists (
    select 1
    from pg_trigger tg
    join pg_class c on c.oid=tg.tgrelid
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public'
      and c.relname='tender_records'
      and tg.tgname='tender_records_capture_amendment'
      and not tg.tgisinternal
  ) into trigger_ok;

  if trigger_ok is distinct from true then
    raise exception 'Tender amendment capture trigger missing';
  end if;

  if not exists (
    select 1
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='private'
      and p.proname='capture_tender_amendment'
      and not p.prosecdef
  ) then
    raise exception 'private.capture_tender_amendment must be SECURITY INVOKER';
  end if;

  if not exists (
    select 1 from public.supplier_document_vault
    where document_type='insurance'
      and title='Commercial General Liability certificate'
  ) then
    raise exception 'Reusable bid vault seed missing';
  end if;
end $$;

rollback;

begin;

do $$
begin
  if to_regclass('public.supplier_registrations') is null then
    raise exception 'supplier_registrations table is missing';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='tender_records'
      and column_name='submission_reference'
  ) then
    raise exception 'tender_records.submission_reference is missing';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='tender_records'
      and column_name='bid_decision_by'
  ) then
    raise exception 'tender_records.bid_decision_by is missing';
  end if;

  if exists (
    select 1
    from pg_constraint c
    where c.contype='f'
      and c.connamespace='public'::regnamespace
      and c.conrelid in (
        'public.supplier_registrations'::regclass,
        'public.tender_records'::regclass
      )
      and not exists (
        select 1 from pg_index i
        where i.indrelid=c.conrelid and i.indisvalid and i.indpred is null
          and (
            select array_agg(x order by ordinality)
            from unnest(i.indkey) with ordinality z(x,ordinality)
            where ordinality <= array_length(c.conkey,1)
          ) = c.conkey
      )
  ) then
    raise exception 'Tender readiness introduced an uncovered foreign key';
  end if;

  if has_table_privilege('anon','public.supplier_registrations','SELECT') then
    raise exception 'anon must not read supplier registrations';
  end if;
end $$;

rollback;

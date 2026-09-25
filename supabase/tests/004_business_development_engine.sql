-- Database-level verification for the business-development engine
-- (20260925201028_business_development_engine).
begin;
do $$
declare
  expected text[] := array[
    'lead_sources','permit_records','referral_events','inbound_submissions',
    'outreach_lists','outreach_targets','outreach_touches'
  ];
  missing text[];
begin
  select array_agg(x order by x) into missing
  from unnest(expected) x
  where not exists(select 1 from information_schema.tables t where t.table_schema='public' and t.table_name=x and t.table_type='BASE TABLE');
  if missing is not null then raise exception 'Missing business-development tables: %', missing; end if;

  if (
    select count(*) from pg_class c
    join pg_namespace ns on ns.oid = c.relnamespace
    where ns.nspname = 'public' and c.relkind = 'r' and c.relname = any(expected)
      and c.relrowsecurity and c.relforcerowsecurity
  ) <> array_length(expected, 1) then
    raise exception 'RLS/FORCE RLS not enabled on every business-development table';
  end if;

  if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='leads' and column_name='source_detail_id')
    then raise exception 'leads.source_detail_id column missing'; end if;
  if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='leads' and column_name='score')
    then raise exception 'leads.score column missing'; end if;

  if not exists(
    select 1 from pg_constraint
    where conname = 'permit_records_jurisdiction_permit_number_key'
  ) then raise exception 'permit_records dedup constraint missing'; end if;

  if not exists(
    select 1 from pg_trigger where tgname = 'touch_updated_at'
      and tgrelid = 'public.lead_sources'::regclass
  ) then raise exception 'lead_sources missing touch_updated_at trigger'; end if;

  raise notice 'CBData business-development engine verification passed';
end $$;
rollback;

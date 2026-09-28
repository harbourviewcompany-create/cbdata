begin;

do $$
declare
  forced_count integer;
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='procurement_contract_cycles' and column_name='contract_title'
  ) then raise exception 'procurement_contract_cycles.contract_title missing'; end if;

  select count(*) into forced_count
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public'
    and c.relname in ('procurement_contract_cycles','procurement_future_opportunities')
    and c.relrowsecurity and c.relforcerowsecurity;
  if forced_count <> 2 then raise exception 'Award/rebid tables must use FORCE RLS'; end if;

  if not exists (
    select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname='v_procurement_rebid_queue'
      and coalesce(c.reloptions,'{}'::text[]) @> array['security_invoker=true']
  ) then raise exception 'v_procurement_rebid_queue must be security_invoker'; end if;

  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='private' and p.proname='refresh_procurement_contract_cycles'
  ) then raise exception 'private.refresh_procurement_contract_cycles missing'; end if;

  if not exists (
    select 1 from cron.job where jobname='cbdata-procurement-cycle-refresh' and active
  ) then raise exception 'procurement cycle refresh cron missing or inactive'; end if;

  if (select count(*) from public.procurement_awards) < 1 then
    raise exception 'No procurement award evidence available';
  end if;

  if (select count(*) from public.procurement_contract_cycles where contract_title is not null) < 1 then
    raise exception 'No titled procurement contract cycles generated';
  end if;

  if (select count(*) from public.procurement_future_opportunities where signal_type='award_rebid') < 1 then
    raise exception 'No award/rebid future opportunities generated';
  end if;

  raise notice 'Procurement award/rebid intelligence verification passed';
end $$;

rollback;

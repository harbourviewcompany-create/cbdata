begin;

do $$
declare
  forced boolean;
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='procurement_future_opportunities' and column_name='target_id'
  ) then raise exception 'procurement_future_opportunities.target_id missing'; end if;

  if not exists (
    select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname='v_procurement_pursuit_queue'
      and coalesce(c.reloptions,'{}'::text[]) @> array['security_invoker=true']
  ) then raise exception 'v_procurement_pursuit_queue must be security_invoker'; end if;

  if exists (select 1 from public.procurement_buyers where organization_id is null) then
    raise exception 'procurement buyer organization bridge is incomplete';
  end if;

  if not exists (
    select 1 from public.outreach_lists where name='Procurement Pre-Position'
  ) then raise exception 'Procurement Pre-Position list missing'; end if;

  if not exists (
    select 1 from public.procurement_future_opportunities
    where status='pre_position' and target_id is not null
  ) then raise exception 'pre-position opportunities are not routed to targets'; end if;

  if not exists (
    select 1 from cron.job where jobname='cbdata-procurement-pursuit-refresh' and active
  ) then raise exception 'pursuit refresh cron missing'; end if;

  if exists (
    select 1 from public.procurement_future_opportunities
    where status='pre_position'
      and (contact_readiness_status='unknown' or vendor_readiness_status='unknown')
  ) then raise exception 'pre-position readiness contains unknown state'; end if;

  raise notice 'Procurement pursuit readiness verification passed';
end $$;

rollback;

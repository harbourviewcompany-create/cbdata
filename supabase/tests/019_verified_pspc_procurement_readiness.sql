begin;

do $$
declare
  w uuid;
  active_count integer;
begin
  select id into w from public.workspaces where slug='cb-contracting' limit 1;
  if w is null then raise exception 'CB Contracting workspace missing'; end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='procurement_future_opportunities' and column_name='pursuit_contact_id'
  ) then raise exception 'pursuit_contact_id missing'; end if;

  select count(*) into active_count
  from public.v_procurement_pursuit_queue
  where workspace_id=w and status='pre_position';

  if active_count < 5 then
    raise exception 'Expected at least five active pre-position pursuits, found %',active_count;
  end if;

  if exists (
    select 1 from public.v_procurement_pursuit_queue
    where workspace_id=w and status='pre_position'
      and (pursuit_contact_id is null or pursuit_contact_email is null or contact_readiness_status<>'ready')
  ) then raise exception 'Active pursuit missing verified contracting authority'; end if;

  if not exists (
    select 1 from public.supplier_registrations
    where workspace_id=w and source_key='canadabuys'
      and registration_name='SAP Business Network — Government of Canada'
      and status in ('required','in_progress','active','blocked')
  ) then raise exception 'CanadaBuys supplier registration readiness record missing'; end if;

  if not exists (
    select 1 from public.procurement_buyers
    where workspace_id=w and buyer_key='pspc' and registration_url is not null
  ) then raise exception 'PSPC registration URL missing'; end if;

  if exists (
    select 1 from public.v_procurement_pursuit_queue
    where workspace_id=w and status='pre_position'
      and (incumbent_name is null or award_value is null)
  ) then raise exception 'Active pursuit incumbent/award intelligence incomplete'; end if;

  raise notice 'Verified PSPC procurement readiness checks passed';
end $$;

rollback;

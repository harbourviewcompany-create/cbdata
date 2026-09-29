begin;

do $$
begin
  if exists (
    select 1
    from public.procurement_buyers
    where buyer_key='cheo'
      and (coverage_status <> 'monitored' or primary_source_key <> 'canadabuys' or portal_url is null)
  ) then
    raise exception 'CHEO procurement route is not monitored through CanadaBuys';
  end if;
end $$;

rollback;

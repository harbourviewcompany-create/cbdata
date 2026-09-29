begin;

do $$
declare
  expected_sources text[] := array[
    'uottawa_merx','carleton_merx','algonquin_merx',
    'montfort_merx','lacite_merx','bruyere_merx'
  ];
  key text;
begin
  foreach key in array expected_sources loop
    if not exists (
      select 1
      from public.tender_sources
      where source_key=key
        and ingestion_mode='live'
        and enabled
    ) then
      raise exception 'Institutional tender source % is not live/enabled', key;
    end if;
  end loop;

  if exists (
    select 1
    from public.procurement_buyers
    where buyer_key in ('uottawa','carleton','algonquin','montfort','la-cite','bruyere')
      and coverage_status <> 'monitored'
  ) then
    raise exception 'Institutional procurement buyer coverage is not monitored';
  end if;
end $$;

rollback;

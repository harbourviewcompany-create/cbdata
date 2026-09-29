begin;

do $$
declare
  expected_external text[] := array[
    'ottawa_hospital_medbuy','royal_biddingo','sto_seao',
    'cisss_outaouais_seao','cecce_merx_watch','cepeo_procurement_watch'
  ];
  key text;
begin
  foreach key in array expected_external loop
    if not exists (
      select 1 from public.tender_sources
      where source_key=key
        and ingestion_mode='external_watch'
        and enabled
    ) then
      raise exception 'Verified external procurement route % is missing', key;
    end if;
  end loop;

  if exists (
    select 1
    from public.procurement_buyers
    where buyer_key in ('ottawa-hospital','royal-ottawa','sto','cisss-outaouais','cecce','cepeo')
      and portal_url is null
  ) then
    raise exception 'A verified external-watch buyer is missing its portal URL';
  end if;
end $$;

rollback;

begin;

do $$
begin
  if to_regclass('public.procurement_source_registration_map') is null then
    raise exception 'procurement_source_registration_map is missing';
  end if;

  if not exists (
    select 1
    from public.procurement_source_registration_map
    where source_key='uottawa_merx'
      and registration_source_key='city_merx'
  ) then
    raise exception 'MERX registration alias is missing';
  end if;

  if not exists (
    select 1
    from public.procurement_source_registration_map
    where source_key='ottawa_hospital_medbuy'
      and registration_source_key='biddingo'
  ) then
    raise exception 'Biddingo registration alias is missing';
  end if;

  if not exists (
    select 1
    from public.procurement_source_registration_map
    where source_key='sto_seao'
      and registration_source_key='seao'
  ) then
    raise exception 'SEAO registration alias is missing';
  end if;

  if not exists (
    select 1
    from public.supplier_registrations
    where source_key='oca_link2build'
  ) then
    raise exception 'OCA/Link2Build readiness record is missing';
  end if;

  if has_table_privilege('anon','public.procurement_source_registration_map','SELECT') then
    raise exception 'anon must not read procurement source registration mappings';
  end if;
end $$;

rollback;

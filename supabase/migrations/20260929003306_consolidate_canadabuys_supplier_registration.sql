do $$
declare
  w uuid;
  canonical_id uuid;
  legacy_id uuid;
  legacy_note text;
begin
  select id into w from public.workspaces where slug='cb-contracting' limit 1;
  if w is null then raise exception 'CB Contracting workspace missing'; end if;

  select id into canonical_id
  from public.supplier_registrations
  where workspace_id=w
    and source_key='canadabuys'
    and registration_name='SAP Business Network — Government of Canada'
  limit 1;

  if canonical_id is null then
    raise exception 'Canonical CanadaBuys supplier registration missing';
  end if;

  select id,notes into legacy_id,legacy_note
  from public.supplier_registrations
  where workspace_id=w
    and source_key='canadabuys'
    and registration_name='CanadaBuys / SAP Business Network supplier registration'
  limit 1;

  if legacy_id is not null then
    update public.supplier_registrations
    set notes=case
      when coalesce(notes,'') ilike '%Legacy alias retired:%' then notes
      else concat_ws(E'\n',notes,
        'Legacy alias retired: "CanadaBuys / SAP Business Network supplier registration". Previous note: '||
        coalesce(legacy_note,'(none)'))
    end,
    updated_at=now()
    where id=canonical_id;

    delete from public.supplier_registrations where id=legacy_id;
  end if;
end $$;

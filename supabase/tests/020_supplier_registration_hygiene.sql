do $$
declare
  w uuid;
  n integer;
begin
  select id into w from public.workspaces where slug='cb-contracting' limit 1;
  if w is null then raise exception 'CB Contracting workspace missing'; end if;

  select count(*) into n
  from public.supplier_registrations
  where workspace_id=w and source_key='canadabuys';
  if n <> 1 then
    raise exception 'Expected exactly one CanadaBuys supplier registration, found %', n;
  end if;

  if not exists (
    select 1 from public.supplier_registrations
    where workspace_id=w
      and source_key='canadabuys'
      and registration_name='SAP Business Network — Government of Canada'
      and status in ('required','in_progress','active','blocked')
      and evidence_url is not null
  ) then
    raise exception 'Canonical evidenced CanadaBuys supplier registration missing';
  end if;

  if exists (
    select 1 from public.supplier_registrations
    where workspace_id=w
      and source_key='canadabuys'
      and registration_name='CanadaBuys / SAP Business Network supplier registration'
  ) then
    raise exception 'Legacy CanadaBuys supplier registration alias still present';
  end if;
end $$;

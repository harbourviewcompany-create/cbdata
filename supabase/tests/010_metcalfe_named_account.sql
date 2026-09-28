-- Metcalfe named-account regression checks.
do $$
declare
  v_workspace uuid := '431aa13d-3e7c-41e3-9686-e840b8ea5b7c';
  v_org uuid;
  v_target uuid;
  n int;
begin
  select id into v_org from public.organizations
  where workspace_id=v_workspace and coalesce(operating_name,legal_name)='Metcalfe Realty' limit 1;
  if v_org is null then raise exception 'Metcalfe organization missing'; end if;

  select count(*) into n from public.properties
  where workspace_id=v_workspace and management_organization_id=v_org and name like 'Metcalfe — %';
  if n < 18 then raise exception 'Expected at least 18 Metcalfe properties, found %', n; end if;

  select count(*) into n
  from public.properties p join public.property_intelligence pi on pi.property_id=p.id
  where p.workspace_id=v_workspace and p.management_organization_id=v_org and p.city='Ottawa'
    and pi.intelligence_score >= 90;
  if n < 6 then raise exception 'Expected at least 6 high-signal Ottawa Metcalfe sites, found %', n; end if;

  select count(*) into n from public.contacts
  where workspace_id=v_workspace and first_name='Natalie' and last_name='Williams'
    and source_confidence='high';
  if n <> 1 then raise exception 'Expected one verified Natalie Williams contact, found %', n; end if;

  select id into v_target from public.outreach_targets
  where workspace_id=v_workspace and organization_id=v_org order by created_at limit 1;
  if v_target is null then raise exception 'Metcalfe outreach target missing'; end if;

  select count(*) into n from public.outreach_target_properties
  where workspace_id=v_workspace and outreach_target_id=v_target;
  if n < 18 then raise exception 'Expected target links for full Metcalfe portfolio, found %', n; end if;

  select count(*) into n from public.target_opportunity_signals
  where workspace_id=v_workspace and organization_id=v_org and signal_type='seasonal'
    and title like 'Metcalfe winter-readiness pursuit%';
  if n < 4 then raise exception 'Expected portfolio winter pursuit signals, found %', n; end if;

  if exists (
    select 1 from public.target_opportunity_signals
    where workspace_id=v_workspace and organization_id=v_org
      and signal_type='contract_renewal'
  ) then
    raise exception 'Metcalfe contract renewal signal exists without verified renewal evidence';
  end if;
end $$;

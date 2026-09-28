-- Priority-target portfolio regression checks.
do $$
declare
  v_workspace uuid := '431aa13d-3e7c-41e3-9686-e840b8ea5b7c';
  n int;
begin
  select count(*) into n from public.outreach_targets
  where workspace_id=v_workspace and organization_name in ('District Realty','Regional Group','Merkburn Holdings')
    and priority='high' and score>=95;
  if n <> 3 then raise exception 'Expected 3 initial Tier-1 portfolio targets, found %', n; end if;

  select count(*) into n from public.outreach_targets
  where workspace_id=v_workspace and organization_name in ('Colonnade BridgePort','Taggart Realty Management','CLV Group','Minto Commercial','Osgoode Properties')
    and priority='high' and score>=90;
  if n <> 5 then raise exception 'Expected 5 additional Tier-1 Ottawa portfolio targets, found %', n; end if;

  select count(*) into n from public.properties p
  join public.outreach_target_properties otp on otp.property_id=p.id
  join public.outreach_targets t on t.id=otp.outreach_target_id
  where t.workspace_id=v_workspace and t.organization_name='Colonnade BridgePort'
    and p.name in ('CBP — Mata','CBP — Ori','CBP — 600 Mountaineer','CBP — 601 Mountaineer');
  if n <> 4 then raise exception 'Expected 4 fresh CBP mandate properties, found %', n; end if;

  select count(*) into n from public.target_opportunity_signals s
  join public.outreach_targets t on t.id=s.target_id
  where t.workspace_id=v_workspace and t.organization_name='Colonnade BridgePort'
    and s.signal_type='management_change' and s.status='open';
  if n < 4 then raise exception 'Expected CBP management-change signals, found %', n; end if;

  select count(*) into n from public.contacts
  where workspace_id=v_workspace and first_name='Kandas' and last_name='Miller' and source_confidence='high';
  if n <> 1 then raise exception 'Expected verified Kandas Miller contact, found %', n; end if;

  select count(*) into n from public.contacts
  where workspace_id=v_workspace and email='michaelmorin@districtrealty.com'
    and source_confidence='high';
  if n <> 1 then raise exception 'Expected verified District commercial-operations contact, found %', n; end if;

  if exists (
    select 1 from public.outreach_targets
    where workspace_id=v_workspace and status in ('queued','contacted','responded')
      and (next_action is null or length(trim(next_action)) < 12)
  ) then raise exception 'Open target remains without an executable next action'; end if;

  if exists (
    select 1 from public.outreach_targets
    where workspace_id=v_workspace and (score < 0 or score > 100)
  ) then raise exception 'Target score outside 0..100'; end if;

  select count(*) into n from public.outreach_targets
  where workspace_id=v_workspace and status in ('queued','contacted','responded') and priority='high';
  if n < 3 then raise exception 'Expected high-priority open target queue'; end if;
end $$;

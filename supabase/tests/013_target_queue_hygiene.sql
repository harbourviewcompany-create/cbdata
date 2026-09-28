-- Queue-hygiene regression for canonical Regional Group targeting.
do $$
declare
  v_workspace uuid := '431aa13d-3e7c-41e3-9686-e840b8ea5b7c';
  n int;
begin
  select count(*) into n
  from public.outreach_targets
  where workspace_id=v_workspace
    and organization_name='Regional Group'
    and status in ('queued','contacted','responded');
  if n <> 1 then
    raise exception 'Expected exactly one open Regional Group target, found %', n;
  end if;

  if exists (
    select 1 from public.outreach_targets
    where workspace_id=v_workspace
      and organization_name='Regional Group'
      and status in ('queued','contacted','responded')
      and organization_id is null
  ) then
    raise exception 'Open Regional Group target is not linked to canonical organization';
  end if;
end $$;

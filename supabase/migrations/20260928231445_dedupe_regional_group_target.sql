-- Retire the stale pre-enrichment Regional Group queue row.
-- Preserve the row for audit history; the linked canonical account remains active.

do $$
declare
  v_workspace uuid := '431aa13d-3e7c-41e3-9686-e840b8ea5b7c';
  v_canonical uuid;
begin
  select id into v_canonical
  from public.outreach_targets
  where workspace_id=v_workspace
    and organization_name='Regional Group'
    and organization_id is not null
    and status in ('queued','contacted','responded')
  order by score desc nulls last, created_at desc
  limit 1;

  if v_canonical is not null then
    update public.outreach_targets
    set status='rejected',
        next_action='Superseded by canonical Regional Group account target.',
        notes=case
          when coalesce(notes,'') ilike '%superseded by canonical regional group%' then notes
          else concat_ws(E'\n',notes,'Queue hygiene: superseded by canonical Regional Group target '||v_canonical::text||'.')
        end,
        updated_at=now()
    where workspace_id=v_workspace
      and organization_name='Regional Group'
      and organization_id is null
      and status in ('queued','contacted','responded');
  end if;
end $$;

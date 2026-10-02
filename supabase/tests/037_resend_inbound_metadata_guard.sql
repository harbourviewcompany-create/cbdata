begin;

do $$
declare
  fn text;
begin
  if to_regprocedure('public.pause_outreach_sequences_for_inbound(uuid,uuid,text)') is null then
    raise exception 'metadata-only inbound pause RPC missing';
  end if;

  if has_function_privilege(
    'authenticated',
    'public.pause_outreach_sequences_for_inbound(uuid,uuid,text)',
    'EXECUTE'
  ) then raise exception 'authenticated must not execute system inbound pause'; end if;

  if not has_function_privilege(
    'service_role',
    'public.pause_outreach_sequences_for_inbound(uuid,uuid,text)',
    'EXECUTE'
  ) then raise exception 'service role cannot pause pursuit for inbound metadata'; end if;

  select pg_get_functiondef(
    'public.pause_outreach_sequences_for_inbound(uuid,uuid,text)'::regprocedure
  ) into fn;

  if position('t.pursuit_id=v_pursuit' in replace(fn,' ',''))=0 then
    raise exception 'metadata-only reply does not pause the whole canonical pursuit';
  end if;

  if not exists (
    select 1
    from pg_constraint c
    join pg_class r on r.oid=c.conrelid
    join pg_namespace n on n.oid=r.relnamespace
    where n.nspname='public'
      and r.relname='outreach_inbound_events'
      and c.conname='outreach_inbound_events_status_check'
      and pg_get_constraintdef(c.oid) like '%pending_content%'
  ) then raise exception 'pending_content inbound state missing'; end if;
end $$;

rollback;

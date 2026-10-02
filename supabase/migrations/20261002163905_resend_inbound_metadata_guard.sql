-- Resend email.received webhooks contain metadata first; full message content
-- is retrieved separately. Preserve the event, pause matched pursuit sequences
-- immediately, and let the reply classifier run only after the full body arrives.

alter table public.outreach_inbound_events
  drop constraint if exists outreach_inbound_events_status_check;

alter table public.outreach_inbound_events
  add constraint outreach_inbound_events_status_check
  check (status in ('matched','unmatched','ambiguous','pending_content','duplicate','error'));

create or replace function public.pause_outreach_sequences_for_inbound(
  p_workspace_id uuid,
  p_target_id uuid,
  p_reason text default 'inbound_reply_pending_content'
)
returns uuid
language plpgsql
security definer
set search_path=pg_catalog,public
as $$
declare
  v_target public.outreach_targets%rowtype;
  v_pursuit uuid;
begin
  select * into v_target
  from public.outreach_targets
  where id=p_target_id and workspace_id=p_workspace_id;

  if not found then raise exception 'target unavailable'; end if;
  v_pursuit:=v_target.pursuit_id;

  update public.outreach_enrollments e
  set
    status='paused',
    paused_at=now(),
    paused_reason=coalesce(nullif(p_reason,''),'inbound_reply_pending_content'),
    last_guard_check_at=now()
  from public.outreach_targets t
  where e.outreach_target_id=t.id
    and e.workspace_id=p_workspace_id
    and t.workspace_id=p_workspace_id
    and e.status='active'
    and (
      t.id=p_target_id
      or (v_pursuit is not null and t.pursuit_id=v_pursuit)
    );

  if v_pursuit is not null then
    update public.outreach_pursuits
    set
      next_action='Review inbound reply',
      next_action_due_at=now(),
      last_activity_at=now(),
      updated_at=now()
    where id=v_pursuit and workspace_id=p_workspace_id;
  end if;

  return p_target_id;
end
$$;

revoke all on function public.pause_outreach_sequences_for_inbound(uuid,uuid,text)
  from public,anon,authenticated;
grant execute on function public.pause_outreach_sequences_for_inbound(uuid,uuid,text)
  to service_role;

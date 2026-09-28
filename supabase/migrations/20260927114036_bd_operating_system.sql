-- BD OS: research gate, 12-call cap, outcomes, convert to lead+estimate+visit task.

create or replace function public.target_is_reachable(p_target_id uuid)
returns boolean language sql stable set search_path = public as $$
  select exists (
    select 1 from public.outreach_targets t
    left join public.contacts c on c.id = t.contact_id
    left join public.organizations o on o.id = t.organization_id
    where t.id = p_target_id and (
      nullif(t.phone,'') is not null or nullif(t.email,'') is not null
      or nullif(t.company_phone,'') is not null or nullif(t.company_email,'') is not null
      or nullif(c.phone,'') is not null or nullif(c.mobile,'') is not null or nullif(c.email,'') is not null
      or nullif(o.phone,'') is not null or nullif(o.email,'') is not null
    )
  );
$$;

create or replace function public.claim_outreach_target(p_target_id uuid)
returns uuid language plpgsql security invoker set search_path = public as $$
declare v_ws uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select workspace_id into v_ws from public.outreach_targets where id = p_target_id;
  if v_ws is null then raise exception 'target not found'; end if;
  if not private.is_workspace_member(v_ws) then raise exception 'not a member of workspace'; end if;
  update public.outreach_targets set owner_user_id = auth.uid(), updated_at = now() where id = p_target_id;
  return p_target_id;
end;
$$;

create or replace function public.log_bd_outcome(p_target_id uuid, p_outcome text)
returns uuid language plpgsql security invoker set search_path = public as $$
declare
  v_channel public.outreach_touch_channel := 'call';
  v_status public.outreach_target_status;
  v_next text;
  v_due timestamptz;
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not public.target_is_reachable(p_target_id) and p_outcome <> 'needs_research' then
    raise exception 'Add a phone or email before logging a live outcome';
  end if;
  case p_outcome
    when 'voicemail' then v_status := 'contacted'; v_next := 'Second call'; v_due := now() + interval '3 days';
    when 'reached' then v_status := 'contacted'; v_next := 'Send follow-up / book walk'; v_due := now() + interval '2 days';
    when 'meeting' then v_status := 'responded'; v_next := 'Site visit'; v_due := now() + interval '7 days';
    when 'dead' then v_status := 'rejected'; v_next := 'Closed — no fit'; v_due := null;
    when 'needs_research' then v_status := 'queued'; v_next := 'Find phone / decision maker'; v_due := now() + interval '1 day'; v_channel := 'other';
    else raise exception 'Unknown outcome %', p_outcome;
  end case;
  v_id := public.log_outreach_touch(p_target_id, v_channel, p_outcome, p_outcome, v_status, v_next, v_due);
  if p_outcome = 'meeting' then
    insert into public.tasks (
      workspace_id, title, description, task_type, status, priority,
      outreach_target_id, assigned_to, due_at, created_by
    )
    select t.workspace_id, 'Book site visit — ' || coalesce(t.organization_name, 'target'),
           'Meeting booked from BD queue', 'follow_up', 'open', 'high',
           t.id, coalesce(t.owner_user_id, auth.uid()), now() + interval '7 days', auth.uid()
    from public.outreach_targets t where t.id = p_target_id;
  end if;
  return v_id;
end;
$$;

grant execute on function public.target_is_reachable(uuid) to authenticated;
grant execute on function public.claim_outreach_target(uuid) to authenticated;
grant execute on function public.log_bd_outcome(uuid, text) to authenticated;

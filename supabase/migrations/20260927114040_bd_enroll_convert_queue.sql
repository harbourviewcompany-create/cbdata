create or replace function public.enroll_outreach_target(p_target_id uuid, p_sequence_id uuid)
returns uuid
language plpgsql security invoker set search_path = public as $$
declare
  v_target public.outreach_targets%rowtype;
  v_seq public.outreach_sequences%rowtype;
  v_id uuid;
  v_due int;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_target from public.outreach_targets where id = p_target_id;
  if not found then raise exception 'target not found'; end if;
  if not private.is_workspace_member(v_target.workspace_id) then
    raise exception 'not a member of workspace';
  end if;
  if v_target.status in ('do_not_contact', 'converted', 'rejected') then
    raise exception 'cannot enroll a closed target';
  end if;
  if not public.target_is_reachable(p_target_id) then
    raise exception 'Add a phone or email before enrolling. This target is research-only.';
  end if;
  select * into v_seq from public.outreach_sequences
  where id = p_sequence_id and workspace_id = v_target.workspace_id and is_active;
  if not found then raise exception 'sequence not found or inactive'; end if;
  insert into public.outreach_enrollments (
    workspace_id, sequence_id, outreach_target_id, status, current_step_order, next_run_at, enrolled_by
  ) values (
    v_target.workspace_id, p_sequence_id, p_target_id, 'active', 1, now(), auth.uid()
  )
  on conflict (sequence_id, outreach_target_id) do update
    set status = 'active', current_step_order = 1, next_run_at = now(), completed_at = null
  returning id into v_id;
  select count(*)::int into v_due from public.outreach_targets
  where workspace_id = v_target.workspace_id
    and owner_user_id = coalesce(v_target.owner_user_id, auth.uid())
    and status in ('queued','contacted','responded')
    and next_action_due_at::date = current_date;
  update public.outreach_targets
  set owner_user_id = coalesce(owner_user_id, auth.uid()),
      next_action = 'Sequence enrolled: ' || v_seq.name,
      next_action_due_at = case when v_due >= 12 then now() + interval '1 day' else now() end,
      updated_at = now()
  where id = p_target_id;
  return v_id;
end;
$$;

grant execute on function public.enroll_outreach_target(uuid, uuid) to authenticated;

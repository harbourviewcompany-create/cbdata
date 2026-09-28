-- Harden outreach execution state transitions, reply-channel attribution, and evidence provenance.

alter table public.outreach_replies
  add column if not exists channel text not null default 'email';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid='public.outreach_replies'::regclass
      and conname='outreach_replies_channel_check'
  ) then
    alter table public.outreach_replies
      add constraint outreach_replies_channel_check
      check (channel in ('email','linkedin','call','voicemail','sms','other'));
  end if;
end $$;

create or replace function public.normalize_outreach_draft_evidence()
returns trigger
language plpgsql
security invoker
set search_path=public
as $$
declare
  v_contact_verified_at timestamptz;
  v_property_verified_at timestamptz;
  v_signal_confidence text;
  v_verified boolean := false;
  v_level text := 'generic';
begin
  if new.contact_id is not null then
    select c.source_verified_at
      into v_contact_verified_at
    from public.contacts c
    where c.id=new.contact_id
      and c.workspace_id=new.workspace_id;
  end if;

  if new.property_id is not null then
    select pi.verified_at
      into v_property_verified_at
    from public.property_intelligence pi
    where pi.property_id=new.property_id
      and pi.workspace_id=new.workspace_id
    order by pi.verified_at desc nulls last
    limit 1;
  end if;

  if nullif(new.evidence->>'signal','') is not null then
    select s.source_confidence
      into v_signal_confidence
    from public.target_opportunity_signals s
    where s.workspace_id=new.workspace_id
      and s.status='open'
      and s.title=new.evidence->>'signal'
      and (
        s.target_id=new.outreach_target_id
        or (new.property_id is not null and s.property_id=new.property_id)
      )
    order by case s.source_confidence when 'high' then 1 when 'medium' then 2 else 3 end,
             s.created_at desc
    limit 1;
  end if;

  v_verified :=
    v_contact_verified_at is not null
    or v_property_verified_at is not null
    or v_signal_confidence='high';

  if v_verified then
    v_level := 'verified';
  elsif new.contact_id is not null
     or new.property_id is not null
     or nullif(new.evidence->>'signal','') is not null then
    v_level := 'database_only';
  end if;

  new.evidence := coalesce(new.evidence,'{}'::jsonb) || jsonb_build_object(
    'generated_from_verified_data',v_verified,
    'evidence_level',v_level,
    'provenance',jsonb_build_object(
      'contact_verified_at',v_contact_verified_at,
      'property_verified_at',v_property_verified_at,
      'signal_source_confidence',v_signal_confidence
    )
  );

  return new;
end;
$$;

drop trigger if exists trg_outreach_draft_evidence_provenance on public.outreach_drafts;
create trigger trg_outreach_draft_evidence_provenance
before insert or update of contact_id,property_id,evidence
on public.outreach_drafts
for each row
execute function public.normalize_outreach_draft_evidence();

-- Backfill any drafts created before the provenance trigger was installed.
update public.outreach_drafts
set evidence=evidence;

create or replace function public.approve_outreach_draft(p_draft_id uuid)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare d public.outreach_drafts%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select * into d
  from public.outreach_drafts
  where id=p_draft_id
  for update;

  if not found then raise exception 'draft not found'; end if;
  if not private.is_workspace_member(d.workspace_id) then raise exception 'not a member of workspace'; end if;
  if d.state <> 'draft' then
    raise exception 'invalid outreach draft transition: % -> approved', d.state
      using errcode='22023';
  end if;

  update public.outreach_drafts
  set state='approved',approved_at=now(),updated_at=now()
  where id=p_draft_id;

  update public.outreach_targets
  set next_action='Send approved outreach',next_action_due_at=now(),updated_at=now()
  where id=d.outreach_target_id;

  return p_draft_id;
end;
$$;

create or replace function public.mark_outreach_draft_sent(
  p_draft_id uuid,
  p_provider text default null,
  p_provider_message_id text default null,
  p_provider_thread_id text default null
)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare
  d public.outreach_drafts%rowtype;
  v_touch_channel public.outreach_touch_channel;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select * into d
  from public.outreach_drafts
  where id=p_draft_id
  for update;

  if not found then raise exception 'draft not found'; end if;
  if not private.is_workspace_member(d.workspace_id) then raise exception 'not a member of workspace'; end if;
  if d.state <> 'approved' then
    raise exception 'invalid outreach draft transition: % -> sent', d.state
      using errcode='22023';
  end if;

  update public.outreach_drafts
  set state='sent',
      provider=p_provider,
      provider_message_id=p_provider_message_id,
      provider_thread_id=p_provider_thread_id,
      sent_at=now(),
      updated_at=now()
  where id=p_draft_id;

  v_touch_channel := case d.channel
    when 'email' then 'email'::public.outreach_touch_channel
    when 'sms' then 'sms'::public.outreach_touch_channel
    when 'call' then 'call'::public.outreach_touch_channel
    when 'voicemail' then 'call'::public.outreach_touch_channel
    else 'other'::public.outreach_touch_channel
  end;

  perform public.log_outreach_touch(
    d.outreach_target_id,v_touch_channel,'sent',left(d.body,1000),'contacted',
    'Follow up on outreach',now()+interval '4 days'
  );

  return p_draft_id;
end;
$$;

drop function if exists public.classify_outreach_reply(uuid,text,text,date,text,text,text,text);

create or replace function public.classify_outreach_reply(
  p_target_id uuid,
  p_classification text,
  p_summary text default null,
  p_channel text default 'email',
  p_renewal_date date default null,
  p_referred_contact text default null,
  p_provider text default null,
  p_provider_message_id text default null,
  p_provider_thread_id text default null
)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare
  t public.outreach_targets%rowtype;
  v_id uuid;
  v_status public.outreach_target_status := 'responded';
  v_next text;
  v_due timestamptz;
  v_touch_channel public.outreach_touch_channel;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  if p_channel not in ('email','linkedin','call','voicemail','sms','other') then
    raise exception 'unsupported reply channel %',p_channel
      using errcode='22023';
  end if;

  select * into t
  from public.outreach_targets
  where id=p_target_id;

  if not found then raise exception 'target not found'; end if;
  if not private.is_workspace_member(t.workspace_id) then raise exception 'not a member of workspace'; end if;

  case p_classification
    when 'interested' then v_next:='Book discovery/site walk'; v_due:=now()+interval '1 day';
    when 'referral' then v_next:='Contact referred decision-maker'; v_due:=now()+interval '1 day';
    when 'request_quote' then v_next:='Build quote / estimate'; v_due:=now()+interval '1 day';
    when 'request_call' then v_next:='Call requested contact'; v_due:=now()+interval '1 day';
    when 'under_contract' then v_next:='Capture incumbent and renewal timing'; v_due:=now()+interval '30 days';
    when 'future_renewal' then v_next:='Re-enter before contract renewal'; v_due:=coalesce(p_renewal_date::timestamptz - interval '90 days',now()+interval '90 days');
    when 'wrong_person' then v_next:='Enrich correct decision-maker'; v_due:=now()+interval '1 day';
    when 'out_of_office' then v_next:='Retry after out-of-office window'; v_due:=now()+interval '7 days';
    when 'bounce' then v_next:='Repair contact data'; v_due:=now()+interval '1 day'; v_status:='queued';
    when 'not_interested' then v_next:='Nurture / revisit later'; v_due:=now()+interval '90 days'; v_status:='rejected';
    else v_next:='Review reply and set next action'; v_due:=now()+interval '1 day';
  end case;

  v_touch_channel := case p_channel
    when 'email' then 'email'::public.outreach_touch_channel
    when 'sms' then 'sms'::public.outreach_touch_channel
    when 'call' then 'call'::public.outreach_touch_channel
    when 'voicemail' then 'call'::public.outreach_touch_channel
    else 'other'::public.outreach_touch_channel
  end;

  insert into public.outreach_replies(
    workspace_id,outreach_target_id,channel,provider,provider_message_id,provider_thread_id,
    classification,summary,renewal_date,referred_contact,raw_metadata
  ) values (
    t.workspace_id,t.id,p_channel,p_provider,p_provider_message_id,p_provider_thread_id,
    p_classification,p_summary,p_renewal_date,p_referred_contact,
    jsonb_build_object('channel',p_channel)
  ) returning id into v_id;

  perform public.log_outreach_touch(
    t.id,v_touch_channel,p_classification,p_summary,v_status,v_next,v_due
  );

  return v_id;
end;
$$;

revoke all on function public.normalize_outreach_draft_evidence() from public;
revoke all on function public.approve_outreach_draft(uuid) from public;
revoke all on function public.mark_outreach_draft_sent(uuid,text,text,text) from public;
revoke all on function public.classify_outreach_reply(uuid,text,text,text,date,text,text,text,text) from public;

grant execute on function public.approve_outreach_draft(uuid) to authenticated;
grant execute on function public.mark_outreach_draft_sent(uuid,text,text,text) to authenticated;
grant execute on function public.classify_outreach_reply(uuid,text,text,text,date,text,text,text,text) to authenticated;

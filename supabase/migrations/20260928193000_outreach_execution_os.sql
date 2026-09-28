-- Outreach execution OS: readiness, evidence-aware drafts, touches, and reply intelligence.
-- Additive only: existing target, property, contact, signal, sequence, and touch models remain authoritative.

create table if not exists public.outreach_drafts (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  outreach_target_id uuid not null references public.outreach_targets(id) on delete cascade,
  contact_id uuid references public.contacts(id) on delete set null,
  property_id uuid references public.properties(id) on delete set null,
  channel text not null default 'email' check (channel in ('email','linkedin','call','voicemail','sms')),
  objective text not null default 'introduction',
  subject text,
  body text not null,
  evidence jsonb not null default '{}'::jsonb,
  state text not null default 'draft' check (state in ('draft','approved','sent','archived')),
  provider text,
  provider_message_id text,
  provider_thread_id text,
  generated_at timestamptz not null default now(),
  approved_at timestamptz,
  sent_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists outreach_drafts_target_idx
  on public.outreach_drafts(workspace_id,outreach_target_id,created_at desc);
create index if not exists outreach_drafts_state_idx
  on public.outreach_drafts(workspace_id,state,created_at desc);

create table if not exists public.outreach_replies (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  outreach_target_id uuid not null references public.outreach_targets(id) on delete cascade,
  outreach_draft_id uuid references public.outreach_drafts(id) on delete set null,
  provider text,
  provider_message_id text,
  provider_thread_id text,
  received_at timestamptz not null default now(),
  classification text not null check (classification in (
    'interested','referral','request_quote','request_call','under_contract',
    'future_renewal','not_interested','wrong_person','out_of_office','bounce','other'
  )),
  summary text,
  renewal_date date,
  referred_contact text,
  raw_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists outreach_replies_target_idx
  on public.outreach_replies(workspace_id,outreach_target_id,received_at desc);

alter table public.outreach_drafts enable row level security;
alter table public.outreach_replies enable row level security;

drop policy if exists outreach_drafts_member_select on public.outreach_drafts;
drop policy if exists outreach_drafts_member_insert on public.outreach_drafts;
drop policy if exists outreach_drafts_member_update on public.outreach_drafts;
create policy outreach_drafts_member_select on public.outreach_drafts for select to authenticated
  using (private.is_workspace_member(workspace_id));
create policy outreach_drafts_member_insert on public.outreach_drafts for insert to authenticated
  with check (private.is_workspace_member(workspace_id));
create policy outreach_drafts_member_update on public.outreach_drafts for update to authenticated
  using (private.is_workspace_member(workspace_id))
  with check (private.is_workspace_member(workspace_id));

drop policy if exists outreach_replies_member_select on public.outreach_replies;
drop policy if exists outreach_replies_member_insert on public.outreach_replies;
create policy outreach_replies_member_select on public.outreach_replies for select to authenticated
  using (private.is_workspace_member(workspace_id));
create policy outreach_replies_member_insert on public.outreach_replies for insert to authenticated
  with check (private.is_workspace_member(workspace_id));

grant select, insert, update on public.outreach_drafts to authenticated;
grant select, insert on public.outreach_replies to authenticated;

create or replace view public.v_outreach_execution_queue
with (security_invoker=true) as
with property_rollup as (
  select
    otp.workspace_id,
    otp.outreach_target_id,
    count(distinct otp.property_id)::int as property_count,
    count(distinct case when pi.intelligence_score >= 80 then otp.property_id end)::int as high_signal_property_count,
    bool_or(nullif(pi.snow_scope,'') is not null) as has_snow,
    bool_or(nullif(pi.grounds_scope,'') is not null) as has_grounds,
    bool_or(nullif(pi.janitorial_scope,'') is not null) as has_janitorial,
    max(pi.intelligence_score) as max_property_score,
    max(pi.verified_at) as property_verified_at
  from public.outreach_target_properties otp
  left join public.property_intelligence pi
    on pi.workspace_id=otp.workspace_id and pi.property_id=otp.property_id
  group by otp.workspace_id,otp.outreach_target_id
),
signal_rollup as (
  select
    t.id as outreach_target_id,
    count(distinct s.id) filter (where s.status='open')::int as open_signal_count,
    bool_or(s.status='open' and s.source_confidence='high') as has_high_confidence_signal,
    min(s.deadline_at) filter (where s.status='open' and s.deadline_at is not null) as nearest_deadline,
    (array_agg(s.title order by coalesce(s.deadline_at,'9999-12-31'::timestamptz),s.created_at desc)
      filter (where s.status='open'))[1] as top_signal
  from public.outreach_targets t
  left join public.outreach_target_properties otp on otp.outreach_target_id=t.id
  left join public.target_opportunity_signals s
    on s.workspace_id=t.workspace_id
    and s.status='open'
    and (s.target_id=t.id or s.organization_id=t.organization_id or s.property_id=otp.property_id)
  group by t.id
),
latest_draft as (
  select distinct on (d.outreach_target_id)
    d.outreach_target_id,d.id,d.state,d.subject,d.body,d.channel,d.sent_at,d.created_at
  from public.outreach_drafts d
  order by d.outreach_target_id,d.created_at desc
)
select
  q.*,
  coalesce(pr.property_count,0) as property_count,
  coalesce(pr.high_signal_property_count,0) as high_signal_property_count,
  coalesce(sr.open_signal_count,0) as open_signal_count,
  sr.nearest_deadline,
  sr.top_signal,
  case
    when q.contact_id is not null and q.contact_email is not null and c.source_confidence='high' then 100
    when q.contact_id is not null and q.contact_email is not null then 90
    when q.contact_id is not null and q.contact_phone is not null then 80
    when q.contact_display_name is not null and (q.contact_email is not null or q.contact_phone is not null) then 70
    when q.contact_email is not null or q.contact_phone is not null then 50
    else 15
  end as contact_confidence_score,
  least(100,
    20
    + case when q.contact_id is not null then 15 when q.contact_display_name is not null then 8 else 0 end
    + case when q.contact_email is not null then 15 when q.contact_phone is not null then 10 else 0 end
    + least(20,coalesce(pr.high_signal_property_count,0)*5)
    + least(15,coalesce(sr.open_signal_count,0)*5)
    + case when coalesce(sr.has_high_confidence_signal,false) then 10 else 0 end
    + case when q.next_action is not null and length(trim(q.next_action)) >= 12 then 5 else 0 end
  )::int as outreach_readiness_score,
  case
    when q.contact_email is null and q.contact_phone is null then 'research'
    when q.contact_id is null then 'verify_contact'
    when ld.id is null then 'generate_draft'
    when ld.state='draft' then 'review_draft'
    when ld.state='approved' then 'send'
    when q.status='responded' then 'handle_reply'
    when q.next_action_due_at is not null and q.next_action_due_at <= now() then 'follow_up'
    else 'nurture'
  end as recommended_action,
  case
    when sr.top_signal is not null then sr.top_signal
    when coalesce(pr.high_signal_property_count,0) > 0 then coalesce(pr.high_signal_property_count,0)::text || ' high-signal linked propert' || case when pr.high_signal_property_count=1 then 'y' else 'ies' end
    when q.score_reason is not null then q.score_reason
    else 'Target score and service fit'
  end as why_now,
  array_remove(array[
    case when coalesce(pr.has_snow,false) then 'snow' end,
    case when coalesce(pr.has_grounds,false) then 'grounds' end,
    case when coalesce(pr.has_janitorial,false) then 'janitorial' end
  ],null)::text[] as service_fit,
  ld.id as latest_draft_id,
  ld.state as latest_draft_state,
  ld.subject as latest_draft_subject,
  ld.body as latest_draft_body,
  ld.channel as latest_draft_channel,
  ld.sent_at as latest_draft_sent_at
from public.v_outreach_target_queue q
left join public.contacts c on c.id=q.contact_id
left join property_rollup pr on pr.outreach_target_id=q.id
left join signal_rollup sr on sr.outreach_target_id=q.id
left join latest_draft ld on ld.outreach_target_id=q.id;

grant select on public.v_outreach_execution_queue to authenticated;

create or replace function public.generate_outreach_draft(
  p_target_id uuid,
  p_channel text default 'email',
  p_objective text default 'introduction'
)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare
  t public.outreach_targets%rowtype;
  v_contact_name text;
  v_first_name text;
  v_contact_id uuid;
  v_property_id uuid;
  v_property_name text;
  v_property_address text;
  v_signal text;
  v_services text;
  v_subject text;
  v_body text;
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into t from public.outreach_targets where id=p_target_id;
  if not found then raise exception 'target not found'; end if;
  if not private.is_workspace_member(t.workspace_id) then raise exception 'not a member of workspace'; end if;

  select
    coalesce(nullif(trim(coalesce(c.first_name,'') || ' ' || coalesce(c.last_name,'')),''),t.contact_name),
    c.id
  into v_contact_name,v_contact_id
  from public.contacts c
  where c.id=t.contact_id;
  v_contact_name := coalesce(v_contact_name,t.contact_name,'there');
  v_first_name := case when v_contact_name='there' then 'there' else split_part(v_contact_name,' ',1) end;

  select p.id,p.name,p.address_line_1
  into v_property_id,v_property_name,v_property_address
  from public.outreach_target_properties otp
  join public.properties p on p.id=otp.property_id
  left join public.property_intelligence pi on pi.property_id=p.id
  where otp.outreach_target_id=t.id
  order by coalesce(pi.intelligence_score,0) desc,p.created_at desc
  limit 1;

  select s.title
  into v_signal
  from public.target_opportunity_signals s
  left join public.outreach_target_properties otp on otp.outreach_target_id=t.id
  where s.workspace_id=t.workspace_id and s.status='open'
    and (s.target_id=t.id or s.organization_id=t.organization_id or s.property_id=otp.property_id)
  order by case s.source_confidence when 'high' then 1 when 'medium' then 2 else 3 end,
           coalesce(s.deadline_at,'9999-12-31'::timestamptz)
  limit 1;

  select nullif(array_to_string(array_remove(array[
      case when bool_or(nullif(pi.snow_scope,'') is not null) then 'snow' end,
      case when bool_or(nullif(pi.grounds_scope,'') is not null) then 'grounds' end,
      case when bool_or(nullif(pi.janitorial_scope,'') is not null) then 'janitorial' end
    ],null),', '),'')
  into v_services
  from public.outreach_target_properties otp
  join public.property_intelligence pi on pi.property_id=otp.property_id
  where otp.outreach_target_id=t.id;

  v_services := coalesce(v_services,'property services');
  v_subject := case
    when v_property_name is not null then 'Service support for ' || v_property_name
    else 'Property service support for ' || coalesce(t.organization_name,'your portfolio')
  end;

  v_body :=
    'Hi ' || v_first_name || ',' || E'\n\n' ||
    'I’m reaching out from CB Contracting in Ottawa. ' ||
    case
      when v_property_name is not null then
        'I was reviewing ' || v_property_name ||
        case when v_property_address is not null then ' at ' || v_property_address else '' end ||
        ' and wanted to understand how you currently handle ' || v_services || '.'
      else
        'I was reviewing ' || coalesce(t.organization_name,'your portfolio') ||
        ' and wanted to understand how you currently handle ' || v_services || '.'
    end ||
    case when v_signal is not null then
      E'\n\n' || 'I also noticed a current planning/procurement signal relevant to the account: ' || v_signal || '.'
    else '' end ||
    E'\n\n' ||
    'If you are reviewing contractors, dealing with a service gap, or approaching a renewal, I can price one site so you have a direct comparison without committing to a portfolio-wide change.' ||
    E'\n\n' ||
    'Are you the right person for this, or should I speak with someone on the property/facilities team?' ||
    E'\n\n' || 'Tyler' || E'\n' || 'CB Contracting';

  insert into public.outreach_drafts(
    workspace_id,outreach_target_id,contact_id,property_id,channel,objective,subject,body,evidence,created_by
  ) values (
    t.workspace_id,t.id,v_contact_id,v_property_id,p_channel,p_objective,v_subject,v_body,
    jsonb_build_object(
      'property_id',v_property_id,
      'property_name',v_property_name,
      'property_address',v_property_address,
      'signal',v_signal,
      'service_fit',v_services,
      'generated_from_verified_data',true
    ),
    auth.uid()
  ) returning id into v_id;

  update public.outreach_targets
  set next_action='Review personalized outreach draft',next_action_due_at=now(),updated_at=now()
  where id=t.id;

  return v_id;
end;
$$;

create or replace function public.approve_outreach_draft(p_draft_id uuid)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare d public.outreach_drafts%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into d from public.outreach_drafts where id=p_draft_id;
  if not found then raise exception 'draft not found'; end if;
  if not private.is_workspace_member(d.workspace_id) then raise exception 'not a member of workspace'; end if;
  update public.outreach_drafts set state='approved',approved_at=now(),updated_at=now() where id=p_draft_id;
  update public.outreach_targets set next_action='Send approved outreach',next_action_due_at=now(),updated_at=now()
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
declare d public.outreach_drafts%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into d from public.outreach_drafts where id=p_draft_id for update;
  if not found then raise exception 'draft not found'; end if;
  if not private.is_workspace_member(d.workspace_id) then raise exception 'not a member of workspace'; end if;

  update public.outreach_drafts
  set state='sent',provider=p_provider,provider_message_id=p_provider_message_id,
      provider_thread_id=p_provider_thread_id,sent_at=now(),updated_at=now()
  where id=p_draft_id;

  perform public.log_outreach_touch(
    d.outreach_target_id,'email','sent',left(d.body,1000),'contacted',
    'Follow up on outreach',now()+interval '4 days'
  );
  return p_draft_id;
end;
$$;

create or replace function public.classify_outreach_reply(
  p_target_id uuid,
  p_classification text,
  p_summary text default null,
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
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into t from public.outreach_targets where id=p_target_id;
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

  insert into public.outreach_replies(
    workspace_id,outreach_target_id,provider,provider_message_id,provider_thread_id,
    classification,summary,renewal_date,referred_contact
  ) values (
    t.workspace_id,t.id,p_provider,p_provider_message_id,p_provider_thread_id,
    p_classification,p_summary,p_renewal_date,p_referred_contact
  ) returning id into v_id;

  perform public.log_outreach_touch(t.id,'email',p_classification,p_summary,v_status,v_next,v_due);
  return v_id;
end;
$$;

create or replace function public.ensure_cb_outreach_sequence(p_workspace_id uuid)
returns uuid
language plpgsql
security invoker
set search_path=public
as $cbseq$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not private.is_workspace_member(p_workspace_id) then raise exception 'not a member of workspace'; end if;

  select id into v_id
  from public.outreach_sequences
  where workspace_id=p_workspace_id and name='CB Contracting – 7 touch'
  limit 1;

  if v_id is not null then return v_id; end if;

  insert into public.outreach_sequences(workspace_id,name,description)
  values (
    p_workspace_id,
    'CB Contracting – 7 touch',
    'Evidence-led introduction, call, follow-ups, and 90-day nurture for property and facility targets.'
  ) returning id into v_id;

  insert into public.outreach_sequence_steps(
    workspace_id,sequence_id,step_order,channel,delay_days,title,body_template
  ) values
    (p_workspace_id,v_id,1,'email',0,'Personalized introduction',
      'Generate and review an evidence-aware email referencing one verified property or buying signal. Use one CTA.'),
    (p_workspace_id,v_id,2,'call',2,'Call decision maker',
      'Reference the introduction. Confirm vendor ownership, incumbent status, service gaps, and the next renewal/tender window.'),
    (p_workspace_id,v_id,3,'email',3,'Short follow-up',
      'Send a concise follow-up tied to the property/service opportunity. Do not repeat the full capability list.'),
    (p_workspace_id,v_id,4,'task',4,'LinkedIn / second call',
      'Use the best verified alternate channel. Goal: establish the correct buying route, not force a pitch.'),
    (p_workspace_id,v_id,5,'email',7,'Value follow-up',
      'Offer a site walk, benchmark quote, overflow/backup coverage, or a one-property pilot based on known evidence.'),
    (p_workspace_id,v_id,6,'call',14,'Timing check',
      'Ask directly about contract timing and whether CB Contracting should reconnect before the next bid or renewal.'),
    (p_workspace_id,v_id,7,'wait',60,'Nurture',
      'Re-enter the account at roughly day 90 unless a known renewal date creates a better trigger.');

  return v_id;
end;
$cbseq$;

revoke all on function public.generate_outreach_draft(uuid,text,text) from public;
revoke all on function public.approve_outreach_draft(uuid) from public;
revoke all on function public.mark_outreach_draft_sent(uuid,text,text,text) from public;
revoke all on function public.classify_outreach_reply(uuid,text,text,date,text,text,text,text) from public;
revoke all on function public.ensure_cb_outreach_sequence(uuid) from public;
grant execute on function public.generate_outreach_draft(uuid,text,text) to authenticated;
grant execute on function public.approve_outreach_draft(uuid) to authenticated;
grant execute on function public.mark_outreach_draft_sent(uuid,text,text,text) to authenticated;
grant execute on function public.classify_outreach_reply(uuid,text,text,date,text,text,text,text) to authenticated;
grant execute on function public.ensure_cb_outreach_sequence(uuid) to authenticated;

-- Outreach inbound automation + reply/revenue hardening
-- Adds provider-neutral automatic reply ingestion, unmatched/ambiguous inbox events,
-- pursuit-wide sequence pausing, and fixes opportunity probability semantics (0..1).

alter table public.outreach_replies
  add column if not exists sender_email text,
  add column if not exists subject text;

create table if not exists public.outreach_inbound_events (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  provider text not null,
  provider_message_id text,
  provider_thread_id text,
  sender_email text,
  subject text,
  body text not null,
  received_at timestamptz not null default now(),
  status text not null default 'unmatched'
    check (status in ('matched','unmatched','ambiguous','duplicate','error')),
  matched_target_id uuid references public.outreach_targets(id) on delete set null,
  matched_pursuit_id uuid references public.outreach_pursuits(id) on delete set null,
  reply_id uuid references public.outreach_replies(id) on delete set null,
  match_reason text,
  raw_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists outreach_inbound_events_provider_message_uidx
  on public.outreach_inbound_events(workspace_id,provider,provider_message_id)
  where provider_message_id is not null;
create index if not exists outreach_inbound_events_workspace_status_idx
  on public.outreach_inbound_events(workspace_id,status,received_at desc);
create index if not exists outreach_inbound_events_target_fk_idx
  on public.outreach_inbound_events(matched_target_id);
create index if not exists outreach_inbound_events_pursuit_fk_idx
  on public.outreach_inbound_events(matched_pursuit_id);
create index if not exists outreach_inbound_events_reply_fk_idx
  on public.outreach_inbound_events(reply_id);

alter table public.outreach_inbound_events enable row level security;
drop policy if exists outreach_inbound_events_member_select on public.outreach_inbound_events;
create policy outreach_inbound_events_member_select
on public.outreach_inbound_events
for select
to authenticated
using (private.is_workspace_member(workspace_id));

revoke all on public.outreach_inbound_events from public,anon,authenticated;
grant select on public.outreach_inbound_events to authenticated;
grant all on public.outreach_inbound_events to service_role;

create or replace function public.find_outreach_reply_targets(
  p_workspace_id uuid,
  p_sender_email text,
  p_provider_thread_id text default null
)
returns table(
  target_id uuid,
  pursuit_id uuid,
  match_score integer,
  match_reason text,
  last_touch_at timestamptz
)
language sql
security definer
set search_path=pg_catalog,public,private
as $$
  with candidate_rows as (
    select
      d.outreach_target_id as target_id,
      t.pursuit_id,
      100::int as match_score,
      'provider_thread'::text as match_reason,
      coalesce(d.sent_at,t.last_touch_at,d.created_at) as last_touch_at
    from public.outreach_drafts d
    join public.outreach_targets t on t.id=d.outreach_target_id
    where t.workspace_id=p_workspace_id
      and d.workspace_id=p_workspace_id
      and d.state='sent'
      and nullif(p_provider_thread_id,'') is not null
      and d.provider_thread_id=p_provider_thread_id

    union all

    select
      t.id,
      t.pursuit_id,
      80::int,
      'sender_email'::text,
      t.last_touch_at
    from public.outreach_targets t
    left join public.contacts c on c.id=t.contact_id
    where t.workspace_id=p_workspace_id
      and nullif(lower(btrim(coalesce(p_sender_email,''))),'') is not null
      and lower(btrim(coalesce(c.email,t.email,'')))=lower(btrim(p_sender_email))
  ),
  deduped as (
    select distinct on (target_id)
      target_id,pursuit_id,match_score,match_reason,last_touch_at
    from candidate_rows
    order by target_id,match_score desc,last_touch_at desc nulls last
  )
  select *
  from deduped
  order by match_score desc,last_touch_at desc nulls last,target_id
  limit 10
$$;

revoke all on function public.find_outreach_reply_targets(uuid,text,text) from public,anon,authenticated;
grant execute on function public.find_outreach_reply_targets(uuid,text,text) to service_role;

create or replace function public.pause_outreach_pursuit_sequences_on_reply()
returns trigger
language plpgsql
security definer
set search_path=pg_catalog,public
as $$
begin
  update public.outreach_enrollments e
  set
    status='paused',
    paused_at=now(),
    paused_reason='reply:'||coalesce(new.classification,'other'),
    last_guard_check_at=now()
  from public.outreach_targets t
  where e.outreach_target_id=t.id
    and e.workspace_id=new.workspace_id
    and e.status='active'
    and (
      t.id=new.outreach_target_id
      or (new.pursuit_id is not null and t.pursuit_id=new.pursuit_id)
    );
  return new;
end
$$;

revoke all on function public.pause_outreach_pursuit_sequences_on_reply() from public,anon,authenticated;
drop trigger if exists trg_pause_outreach_pursuit_sequences_on_reply on public.outreach_replies;
create trigger trg_pause_outreach_pursuit_sequences_on_reply
after insert on public.outreach_replies
for each row execute function public.pause_outreach_pursuit_sequences_on_reply();

create or replace function public.ingest_outreach_reply_system(
  p_workspace_id uuid,
  p_target_id uuid,
  p_body text,
  p_sender_email text default null,
  p_subject text default null,
  p_channel text default 'email',
  p_provider text default 'inbound',
  p_provider_message_id text default null,
  p_provider_thread_id text default null,
  p_received_at timestamptz default now(),
  p_raw_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path=pg_catalog,public,private
as $$
declare
  t public.outreach_targets%rowtype;
  c public.contacts%rowtype;
  p public.outreach_pursuits%rowtype;
  cls record;
  v_reply_id uuid;
  v_existing uuid;
  v_classification text;
  v_confidence numeric;
  v_reason text;
  v_status public.outreach_target_status:='responded';
  v_next text;
  v_due timestamptz;
  v_needs_response boolean:=true;
  v_touch_channel public.outreach_touch_channel;
  v_draft_id uuid;
  v_opportunity_id uuid;
  v_received_at timestamptz:=coalesce(p_received_at,now());
begin
  if nullif(btrim(coalesce(p_body,'')),'') is null then
    raise exception 'reply body is required';
  end if;
  if p_channel not in ('email','linkedin','call','voicemail','sms','other') then
    raise exception 'unsupported reply channel %',p_channel using errcode='22023';
  end if;

  select * into t
  from public.outreach_targets
  where id=p_target_id and workspace_id=p_workspace_id
  for update;
  if not found then raise exception 'target unavailable'; end if;

  select * into c from public.contacts where id=t.contact_id;
  select * into p from public.outreach_pursuits where id=t.pursuit_id for update;

  if p_provider_message_id is not null then
    select id into v_existing
    from public.outreach_replies
    where workspace_id=p_workspace_id
      and provider is not distinct from p_provider
      and provider_message_id=p_provider_message_id
    limit 1;
    if v_existing is not null then
      return jsonb_build_object('reply_id',v_existing,'duplicate',true,'target_id',t.id,'pursuit_id',t.pursuit_id);
    end if;
  end if;

  select * into cls from public.classify_outreach_reply_text(p_body);
  v_classification:=cls.classification;
  v_confidence:=cls.confidence;
  v_reason:=cls.reason;

  case v_classification
    when 'interested' then v_next:='Reply and book discovery/site walk'; v_due:=now()+interval '1 day';
    when 'referral' then v_next:='Contact referred decision-maker'; v_due:=now()+interval '1 day';
    when 'request_quote' then v_next:='Build estimate / quote'; v_due:=now()+interval '1 day';
    when 'request_call' then v_next:='Call requested contact'; v_due:=now()+interval '1 day';
    when 'site_visit_request' then v_next:='Book site visit'; v_due:=now()+interval '1 day';
    when 'send_information' then v_next:='Send relevant capability information'; v_due:=now()+interval '1 day';
    when 'under_contract' then v_next:='Capture incumbent and renewal timing'; v_due:=now()+interval '30 days';
    when 'future_renewal' then v_next:='Re-enter before contract renewal'; v_due:=now()+interval '90 days';
    when 'wrong_person' then v_next:='Research correct decision-maker'; v_due:=now()+interval '1 day';
    when 'out_of_office' then v_next:='Retry after out-of-office window'; v_due:=now()+interval '7 days'; v_needs_response:=false;
    when 'bounce' then v_next:='Repair contact data'; v_due:=now()+interval '1 day'; v_status:='queued'; v_needs_response:=false;
    when 'unsubscribe' then v_next:='Do not contact'; v_due:=null; v_status:='do_not_contact'; v_needs_response:=false;
    when 'not_interested' then v_next:='Closed / nurture only if appropriate'; v_due:=null; v_status:='rejected'; v_needs_response:=false;
    else v_next:='Review reply and set next action'; v_due:=now()+interval '1 day';
  end case;

  select d.id into v_draft_id
  from public.outreach_drafts d
  where d.workspace_id=p_workspace_id
    and d.outreach_target_id=t.id
    and d.state='sent'
    and (
      nullif(p_provider_thread_id,'') is null
      or d.provider_thread_id=p_provider_thread_id
      or d.provider_thread_id is null
    )
  order by
    case when d.provider_thread_id=p_provider_thread_id then 0 else 1 end,
    d.sent_at desc nulls last,
    d.created_at desc
  limit 1;

  insert into public.outreach_replies(
    workspace_id,pursuit_id,outreach_target_id,outreach_draft_id,channel,
    provider,provider_message_id,provider_thread_id,received_at,
    classification,classification_confidence,classification_reason,summary,body,
    sender_email,subject,referred_contact,raw_metadata,needs_response
  )
  values(
    p_workspace_id,t.pursuit_id,t.id,v_draft_id,p_channel,
    p_provider,p_provider_message_id,p_provider_thread_id,v_received_at,
    v_classification,v_confidence,v_reason,
    left(regexp_replace(p_body,'[[:space:]]+',' ','g'),500),p_body,
    lower(nullif(btrim(coalesce(p_sender_email,'')),'')),nullif(btrim(coalesce(p_subject,'')),''),
    case when v_classification in ('referral','wrong_person')
      then substring(p_body from '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}')
      else null
    end,
    coalesce(p_raw_metadata,'{}'::jsonb)||jsonb_build_object('auto_classified',true,'ingested_by','outreach_inbound'),
    v_needs_response
  )
  returning id into v_reply_id;

  if v_classification in ('bounce','unsubscribe') then
    if not exists(
      select 1 from public.outreach_suppressions s
      where s.workspace_id=p_workspace_id and s.active
        and (
          (t.contact_id is not null and s.contact_id=t.contact_id)
          or (
            nullif(lower(coalesce(c.email,t.email,p_sender_email,'')),'') is not null
            and lower(coalesce(s.email,''))=lower(coalesce(c.email,t.email,p_sender_email,''))
          )
        )
    ) then
      insert into public.outreach_suppressions(
        workspace_id,contact_id,email,phone,reason,source_reply_id,created_by,notes
      )
      values(
        p_workspace_id,t.contact_id,coalesce(c.email,t.email,p_sender_email),coalesce(c.phone,c.mobile,t.phone),
        v_classification,v_reply_id,null,v_reason
      );
    end if;
  end if;

  v_touch_channel:=case p_channel
    when 'email' then 'email'::public.outreach_touch_channel
    when 'sms' then 'sms'::public.outreach_touch_channel
    when 'call' then 'call'::public.outreach_touch_channel
    when 'voicemail' then 'call'::public.outreach_touch_channel
    else 'other'::public.outreach_touch_channel
  end;

  insert into public.outreach_touches(
    workspace_id,outreach_target_id,channel,outcome,notes,occurred_at,performed_by
  )
  values(
    p_workspace_id,t.id,v_touch_channel,v_classification,left(p_body,1000),v_received_at,null
  );

  update public.outreach_targets
  set
    last_touch_at=greatest(coalesce(last_touch_at,'epoch'::timestamptz),v_received_at),
    status=v_status,
    next_action=v_next,
    next_action_due_at=v_due,
    updated_at=now()
  where id=t.id and workspace_id=p_workspace_id;

  if t.pursuit_id is not null then
    if v_classification in ('request_quote','site_visit_request')
      and p.organization_id is not null
      and p.opportunity_id is null
    then
      insert into public.opportunities(
        workspace_id,organization_id,property_id,name,stage,status,owner_user_id,
        estimated_value,probability,notes
      )
      values(
        p_workspace_id,p.organization_id,p.primary_property_id,
        p.display_name||' — outreach opportunity',
        case when v_classification='request_quote' then 'estimating'::public.opportunity_stage else 'site_visit'::public.opportunity_stage end,
        'open',coalesce(p.next_action_owner_user_id,p.owner_user_id),
        0,
        case when v_classification='request_quote' then 0.55 else 0.45 end,
        'Created automatically from inbound outreach reply '||v_reply_id::text
      )
      returning id into v_opportunity_id;
    else
      v_opportunity_id:=p.opportunity_id;
    end if;

    update public.outreach_pursuits
    set
      opportunity_id=coalesce(v_opportunity_id,opportunity_id),
      stage=case
        when v_classification in ('interested','request_call','send_information','referral')
          and stage in ('research','contact_ready','outreach') then 'engaged'
        when v_classification='site_visit_request' then 'site_visit'
        when v_classification='request_quote' then 'estimating'
        when v_classification in ('not_interested','unsubscribe') then 'lost'
        when v_classification in ('under_contract','future_renewal','out_of_office') then 'nurture'
        else stage
      end,
      status=case
        when v_classification in ('not_interested','unsubscribe') then 'lost'
        when v_classification in ('under_contract','future_renewal','out_of_office') then 'paused'
        else 'active'
      end,
      next_action=v_next,
      next_action_due_at=v_due,
      next_action_owner_user_id=coalesce(next_action_owner_user_id,owner_user_id),
      last_activity_at=v_received_at,
      updated_at=now()
    where id=t.pursuit_id;
  end if;

  return jsonb_build_object(
    'reply_id',v_reply_id,
    'duplicate',false,
    'target_id',t.id,
    'pursuit_id',t.pursuit_id,
    'classification',v_classification,
    'confidence',v_confidence,
    'opportunity_id',v_opportunity_id
  );
end
$$;

revoke all on function public.ingest_outreach_reply_system(uuid,uuid,text,text,text,text,text,text,text,timestamptz,jsonb)
  from public,anon,authenticated;
grant execute on function public.ingest_outreach_reply_system(uuid,uuid,text,text,text,text,text,text,text,timestamptz,jsonb)
  to service_role;

create or replace function public.resolve_outreach_inbound_event(
  p_event_id uuid,
  p_target_id uuid
)
returns uuid
language plpgsql
security invoker
set search_path=pg_catalog,public,private
as $$
declare
  e public.outreach_inbound_events%rowtype;
  t public.outreach_targets%rowtype;
  v_reply uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select * into e
  from public.outreach_inbound_events
  where id=p_event_id
  for update;
  if not found then raise exception 'inbound event not found'; end if;
  if not private.has_workspace_role(
    e.workspace_id,
    array['owner','administrator','sales_manager','sales_rep']::public.membership_role[]
  ) then raise exception 'inbound event unavailable'; end if;

  select * into t
  from public.outreach_targets
  where id=p_target_id and workspace_id=e.workspace_id;
  if not found then raise exception 'target unavailable'; end if;

  if e.reply_id is not null then return e.reply_id; end if;

  v_reply:=public.ingest_outreach_reply(
    t.id,
    e.body,
    'email',
    e.provider,
    e.provider_message_id,
    e.provider_thread_id,
    null,
    null,
    null,
    coalesce(e.raw_metadata,'{}'::jsonb)||jsonb_build_object('resolved_from_inbound_event',e.id)
  );

  update public.outreach_replies
  set
    sender_email=coalesce(sender_email,e.sender_email),
    subject=coalesce(subject,e.subject),
    received_at=e.received_at
  where id=v_reply;

  update public.outreach_inbound_events
  set
    status='matched',
    matched_target_id=t.id,
    matched_pursuit_id=t.pursuit_id,
    reply_id=v_reply,
    match_reason='operator_resolution',
    updated_at=now()
  where id=e.id;

  return v_reply;
end
$$;

revoke all on function public.resolve_outreach_inbound_event(uuid,uuid) from public,anon;
grant execute on function public.resolve_outreach_inbound_event(uuid,uuid) to authenticated;

-- Fix probability semantics: opportunities.probability is constrained to 0..1.
create or replace function public.ensure_outreach_opportunity(
  p_pursuit_id uuid,
  p_reply_id uuid default null,
  p_estimated_value numeric default 0
)
returns uuid
language plpgsql
security invoker
set search_path=pg_catalog,public,private
as $
declare
  p public.outreach_pursuits%rowtype;
  r public.outreach_replies%rowtype;
  v_id uuid;
  v_stage public.opportunity_stage:='qualified';
  v_owner uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select * into p from public.outreach_pursuits where id=p_pursuit_id for update;
  if not found then raise exception 'pursuit not found'; end if;
  if not private.has_workspace_role(p.workspace_id,array['owner','administrator','sales_manager','sales_rep']::public.membership_role[]) then
    raise exception 'pursuit unavailable';
  end if;
  if p.organization_id is null then raise exception 'Link an organization before creating an opportunity'; end if;
  if p.opportunity_id is not null then return p.opportunity_id; end if;

  if p_reply_id is not null then
    select * into r from public.outreach_replies
    where id=p_reply_id and pursuit_id=p.id and workspace_id=p.workspace_id;
    if r.classification='request_quote' then v_stage:='estimating';
    elsif r.classification='site_visit_request' then v_stage:='site_visit';
    else v_stage:='qualified';
    end if;
  end if;

  v_owner:=coalesce(p.next_action_owner_user_id,p.owner_user_id,auth.uid());

  insert into public.opportunities(
    workspace_id,organization_id,property_id,name,stage,status,owner_user_id,
    estimated_value,probability,notes
  )
  values(
    p.workspace_id,p.organization_id,p.primary_property_id,
    p.display_name||' — outreach opportunity',
    v_stage,'open',v_owner,greatest(coalesce(p_estimated_value,0),0),
    case v_stage when 'estimating' then 0.55 when 'site_visit' then 0.45 else 0.30 end,
    'Created from CBData Outreach pursuit '||p.id::text||
      case when p_reply_id is not null then ' / reply '||p_reply_id::text else '' end
  )
  returning id into v_id;

  update public.outreach_pursuits
  set opportunity_id=v_id,
      stage=v_stage::text,
      estimated_value=greatest(coalesce(p_estimated_value,0),estimated_value),
      next_action=case v_stage when 'estimating' then 'Build estimate' when 'site_visit' then 'Book site visit' else 'Qualify opportunity' end,
      next_action_due_at=now()+interval '1 day',
      next_action_owner_user_id=v_owner,
      last_activity_at=now(),
      updated_at=now()
  where id=p.id;

  return v_id;
end
$$;
revoke all on function public.ensure_outreach_opportunity(uuid,uuid,numeric) from public,anon;
grant execute on function public.ensure_outreach_opportunity(uuid,uuid,numeric) to authenticated;

create or replace function public.sync_outreach_opportunity_from_estimate()
returns trigger
language plpgsql
security invoker
set search_path=pg_catalog,public
as $
begin
  if new.opportunity_id is null then return new; end if;

  if new.status::text='accepted' then
    update public.opportunities
    set stage='won',status='won',estimated_value=greatest(estimated_value,coalesce(new.total,0)),
        probability=1.0,closed_at=coalesce(closed_at,now()),updated_at=now()
    where id=new.opportunity_id and workspace_id=new.workspace_id and status::text<>'lost';
  elsif new.status::text='sent' then
    update public.opportunities
    set stage='proposal',estimated_value=greatest(estimated_value,coalesce(new.total,0)),updated_at=now()
    where id=new.opportunity_id and workspace_id=new.workspace_id
      and stage::text in ('new','qualified','site_visit','estimating');
  elsif new.status::text='draft' then
    update public.opportunities
    set stage='estimating',estimated_value=greatest(estimated_value,coalesce(new.total,0)),updated_at=now()
    where id=new.opportunity_id and workspace_id=new.workspace_id
      and stage::text in ('new','qualified','site_visit');
  end if;

  return new;
end
$$;

-- Append actual sender metadata to the existing reply inbox without changing
-- its existing column order.
create or replace view public.v_outreach_reply_inbox
with (security_invoker=true) as
select
  r.workspace_id,
  r.id as reply_id,
  r.pursuit_id,
  r.outreach_target_id,
  p.display_name as organization_display_name,
  coalesce(nullif(trim(coalesce(c.first_name,'')||' '||coalesce(c.last_name,'')),''),t.contact_name) as contact_display_name,
  coalesce(c.email,t.email) as contact_email,
  c.job_title as contact_job_title,
  r.channel,
  r.received_at,
  r.classification,
  r.classification_confidence,
  r.classification_reason,
  r.summary,
  r.body,
  r.renewal_date,
  r.referred_contact,
  r.needs_response,
  r.handled_at,
  r.handled_by,
  p.stage as pursuit_stage,
  p.next_action,
  p.next_action_due_at,
  p.opportunity_id,
  exists(
    select 1 from public.outreach_enrollments e
    where e.outreach_target_id=t.id and e.status='paused'
  ) as sequence_paused,
  r.sender_email,
  r.subject
from public.outreach_replies r
join public.outreach_targets t on t.id=r.outreach_target_id
left join public.outreach_pursuits p on p.id=r.pursuit_id
left join public.contacts c on c.id=t.contact_id;

grant select on public.v_outreach_reply_inbox to authenticated;

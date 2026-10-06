-- CBData inbound reply operating system
-- Applied to production Supabase as migration 20261006104223.
-- Unifies Gmail/Resend events, adds deterministic header matching,
-- structured intent/action data, sync health, reconciliation and dead-letter handling.

alter table public.outreach_inbound_events
  add column if not exists processing_stage text not null default 'received',
  add column if not exists failure_count integer not null default 0,
  add column if not exists last_attempt_at timestamptz,
  add column if not exists last_error text,
  add column if not exists dead_letter_at timestamptz,
  add column if not exists is_test boolean not null default false,
  add column if not exists in_reply_to text,
  add column if not exists reference_message_ids text[] not null default '{}'::text[],
  add column if not exists verified_sent_target_email text,
  add column if not exists finalized_at timestamptz;

alter table public.outreach_inbound_events drop constraint if exists outreach_inbound_events_status_check;
alter table public.outreach_inbound_events add constraint outreach_inbound_events_status_check
  check (status in ('matched','unmatched','ambiguous','pending_content','duplicate','error','dead_letter'));
alter table public.outreach_inbound_events drop constraint if exists outreach_inbound_events_processing_stage_check;
alter table public.outreach_inbound_events add constraint outreach_inbound_events_processing_stage_check
  check (processing_stage in ('received','pending_content','matching','matched','classified','actioned','unresolved','error','dead_letter'));

create index if not exists outreach_inbound_events_processing_idx
  on public.outreach_inbound_events(workspace_id,processing_stage,received_at desc);
create index if not exists outreach_inbound_events_review_idx
  on public.outreach_inbound_events(workspace_id,status,received_at desc)
  where status in ('unmatched','ambiguous','error','dead_letter') and is_test=false;

alter table public.outreach_replies
  add column if not exists intelligence jsonb not null default '{}'::jsonb,
  add column if not exists action_kind text,
  add column if not exists action_payload jsonb not null default '{}'::jsonb;

create table if not exists public.outreach_sync_state (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  provider text not null,
  cursor text,
  status text not null default 'idle' check (status in ('idle','healthy','running','error')),
  last_attempt_at timestamptz,
  last_successful_sync_at timestamptz,
  last_error text,
  details jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key(workspace_id,provider)
);
alter table public.outreach_sync_state enable row level security;
drop policy if exists outreach_sync_state_member_select on public.outreach_sync_state;
create policy outreach_sync_state_member_select on public.outreach_sync_state
for select to authenticated using (private.is_workspace_member(workspace_id));
revoke all on public.outreach_sync_state from public,anon,authenticated;
grant select on public.outreach_sync_state to authenticated;
grant all on public.outreach_sync_state to service_role;

create table if not exists public.outreach_referral_candidates (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  pursuit_id uuid references public.outreach_pursuits(id) on delete cascade,
  source_reply_id uuid not null references public.outreach_replies(id) on delete cascade,
  referred_email text not null,
  referred_name text,
  referred_phone text,
  referred_title text,
  status text not null default 'pending' check (status in ('pending','linked','dismissed')),
  contact_id uuid references public.contacts(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(workspace_id,source_reply_id,referred_email)
);
alter table public.outreach_referral_candidates enable row level security;
drop policy if exists outreach_referral_candidates_member_select on public.outreach_referral_candidates;
create policy outreach_referral_candidates_member_select on public.outreach_referral_candidates
for select to authenticated using (private.is_workspace_member(workspace_id));
revoke all on public.outreach_referral_candidates from public,anon,authenticated;
grant select on public.outreach_referral_candidates to authenticated;
grant all on public.outreach_referral_candidates to service_role;

create or replace function public.extract_outreach_reply_intelligence(p_body text)
returns jsonb language plpgsql immutable parallel safe
set search_path=pg_catalog,public
as $$
declare b text:=coalesce(p_body,''); v_email text; v_phone text; v_url text;
begin
  v_email:=substring(b from '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}');
  v_phone:=substring(b from '(?:\+?1[ .-]?)?\(?[0-9]{3}\)?[ .-][0-9]{3}[ .-][0-9]{4}');
  v_url:=substring(b from 'https?://[^[:space:]<>"'']+');
  return jsonb_strip_nulls(jsonb_build_object(
    'referred_email',lower(v_email),'phone',v_phone,'url',v_url,
    'mentions_quote',lower(b)~'(quote|pricing|estimate|proposal|bid)',
    'mentions_site_visit',lower(b)~'(site visit|site walk|walkthrough|walk through|come (by|out)|visit the (site|property))',
    'mentions_vendor_registration',lower(b)~'(register|registration|approved vendor|vendor list|subcontractor list|supplier list|vendor portal)',
    'mentions_procurement',lower(b)~'(procurement|purchasing|strategic sourcing|tender|rfp|rfq|bid portal)'
  ));
end $$;
revoke all on function public.extract_outreach_reply_intelligence(text) from public,anon;
grant execute on function public.extract_outreach_reply_intelligence(text) to authenticated,service_role;

create or replace function public.classify_outreach_reply_text(p_body text)
returns table(classification text,confidence numeric,reason text)
language plpgsql immutable parallel safe set search_path=pg_catalog,public
as $$
declare b text:=lower(coalesce(p_body,''));
begin
  if b~'(unsubscribe|remove me|do not contact|stop (emailing|contacting)|opt[ -]?out)' then return query select 'unsubscribe'::text,.99::numeric,'Explicit unsubscribe / do-not-contact language'::text;
  elsif b~'(delivery status notification|undeliverable|message not delivered|mailbox unavailable|address not found|recipient rejected|550[ -])' then return query select 'bounce'::text,.99::numeric,'Delivery failure language'::text;
  elsif b~'(out of office|automatic reply|auto.?reply|away from (the )?office|on vacation)' then return query select 'out_of_office'::text,.98::numeric,'Automatic absence language'::text;
  elsif b~'(register|registration|approved vendor|vendor list|subcontractor list|supplier list|become a vendor|become a supplier)' then return query select 'vendor_registration'::text,.94::numeric,'Vendor or subcontractor registration route provided'::text;
  elsif b~'(bid portal|tender portal|bidding portal|bonfire|bids&tenders|merx|biddingo|buildingconnected|planhub)' then return query select 'bid_portal'::text,.93::numeric,'Reply routes opportunity through a bid portal'::text;
  elsif b~'(procurement|purchasing|strategic sourcing).{0,80}(contact|department|team|only|process)' then return query select 'procurement_only'::text,.91::numeric,'Reply routes vendor engagement through procurement'::text;
  elsif b~'((send|share|provide).{0,35}(capabilities|capability statement|company profile|brochure|insurance|wsib|references))' then return query select 'send_capabilities'::text,.91::numeric,'Requested capability or qualification information'::text;
  elsif b~'(not interested|no thank|no thanks|not looking|do not need|don''t need|we''re good)' then return query select 'not_interested'::text,.96::numeric,'Explicit negative intent'::text;
  elsif b~'(not the right person|wrong person|i don''t handle|i do not handle|not responsible for)' then return query select 'wrong_person'::text,.95::numeric,'Contact says they do not own the decision'::text;
  elsif b~'(please contact|you should contact|reach out to|speak (with|to)|the right person is|copying|cc''?ing)' then return query select 'referral'::text,.90::numeric,'Reply routes CB Contracting to another contact'::text;
  elsif b~'((send|provide|share|need|want|looking for).{0,40}(quote|pricing|estimate|proposal|bid)|(quote|pricing|estimate|proposal|bid).{0,40}(send|provide|share|need|want))' then return query select 'request_quote'::text,.94::numeric,'Explicit request for pricing / quote / proposal'::text;
  elsif b~'(site visit|site walk|walkthrough|walk through|come (by|out)|visit the (site|property)|meet (at|on) site)' then return query select 'site_visit_request'::text,.92::numeric,'Explicit site meeting / walkthrough request'::text;
  elsif b~'(call me|give me a call|phone me|can we (talk|speak)|schedule a call|set up a call)' then return query select 'request_call'::text,.92::numeric,'Explicit call request'::text;
  elsif b~'((send|share).{0,30}(information|details|capabilities|brochure|company info)|tell me more)' then return query select 'send_information'::text,.88::numeric,'Asked for company information or capabilities'::text;
  elsif b~'(under contract|existing vendor|current contractor|already have (a )?(vendor|contractor)|contract is in place)' then return query select 'under_contract'::text,.90::numeric,'Existing vendor / incumbent contract stated'::text;
  elsif b~'(renewal|renews|expires|contract end|next (spring|summer|fall|winter|year)|later this year)' then return query select 'future_renewal'::text,.80::numeric,'Future contract or renewal timing mentioned'::text;
  elsif b~'(interested|sounds good|let''s discuss|lets discuss|would like to|happy to (talk|chat|meet)|open to|yes[, .])' then return query select 'interested'::text,.84::numeric,'Positive commercial intent'::text;
  else return query select 'other'::text,.55::numeric,'No high-confidence deterministic intent pattern'::text;
  end if;
end $$;

create or replace function public.find_outreach_reply_targets_v2(
  p_workspace_id uuid,p_sender_email text,p_provider_thread_id text default null,p_in_reply_to text default null,
  p_reference_message_ids text[] default '{}'::text[],p_verified_sent_target_email text default null
) returns table(target_id uuid,pursuit_id uuid,match_score integer,match_reason text,last_touch_at timestamptz)
language sql security definer set search_path=pg_catalog,public,private
as $$
with candidate_rows(target_id,pursuit_id,match_score,match_reason,last_touch_at) as (
  select d.outreach_target_id,t.pursuit_id,130,'in_reply_to',coalesce(d.sent_at,t.last_touch_at,d.created_at)
  from public.outreach_drafts d join public.outreach_targets t on t.id=d.outreach_target_id
  where t.workspace_id=p_workspace_id and d.workspace_id=p_workspace_id and d.state='sent'
    and nullif(p_in_reply_to,'') is not null and d.provider_message_id=p_in_reply_to
  union all
  select d.outreach_target_id,t.pursuit_id,125,'references',coalesce(d.sent_at,t.last_touch_at,d.created_at)
  from public.outreach_drafts d join public.outreach_targets t on t.id=d.outreach_target_id
  where t.workspace_id=p_workspace_id and d.workspace_id=p_workspace_id and d.state='sent'
    and cardinality(coalesce(p_reference_message_ids,'{}'::text[]))>0 and d.provider_message_id=any(p_reference_message_ids)
  union all
  select d.outreach_target_id,t.pursuit_id,120,'provider_thread',coalesce(d.sent_at,t.last_touch_at,d.created_at)
  from public.outreach_drafts d join public.outreach_targets t on t.id=d.outreach_target_id
  where t.workspace_id=p_workspace_id and d.workspace_id=p_workspace_id and d.state='sent'
    and nullif(p_provider_thread_id,'') is not null and d.provider_thread_id=p_provider_thread_id
  union all
  select t.id,t.pursuit_id,100,'verified_sent_target_email',t.last_touch_at
  from public.outreach_targets t left join public.contacts c on c.id=t.contact_id
  where t.workspace_id=p_workspace_id and nullif(lower(btrim(coalesce(p_verified_sent_target_email,''))),'') is not null
    and lower(btrim(coalesce(c.email,t.email,'')))=lower(btrim(p_verified_sent_target_email))
  union all
  select t.id,t.pursuit_id,80,'sender_email',t.last_touch_at
  from public.outreach_targets t left join public.contacts c on c.id=t.contact_id
  where t.workspace_id=p_workspace_id and nullif(lower(btrim(coalesce(p_sender_email,''))),'') is not null
    and lower(btrim(coalesce(c.email,t.email,'')))=lower(btrim(p_sender_email))
), deduped as (
  select distinct on(target_id) target_id,pursuit_id,match_score,match_reason,last_touch_at
  from candidate_rows order by target_id,match_score desc,last_touch_at desc nulls last
)
select * from deduped order by match_score desc,last_touch_at desc nulls last,target_id limit 20
$$;
revoke all on function public.find_outreach_reply_targets_v2(uuid,text,text,text,text[],text) from public,anon,authenticated;
grant execute on function public.find_outreach_reply_targets_v2(uuid,text,text,text,text[],text) to service_role;

create or replace function public.enrich_outreach_reply_after_insert()
returns trigger language plpgsql security definer set search_path=pg_catalog,public,private
as $$
declare v_intel jsonb; v_email text; v_action text; v_action_payload jsonb:='{}'::jsonb;
begin
  v_intel:=public.extract_outreach_reply_intelligence(new.body);
  v_email:=nullif(lower(v_intel->>'referred_email'),'');
  v_action:=case new.classification
    when 'vendor_registration' then 'complete_vendor_registration' when 'bid_portal' then 'open_bid_portal'
    when 'procurement_only' then 'route_to_procurement' when 'send_capabilities' then 'send_capabilities'
    when 'request_quote' then 'build_quote' when 'site_visit_request' then 'book_site_visit'
    when 'request_call' then 'call_contact' when 'referral' then 'contact_referral'
    when 'wrong_person' then 'find_correct_contact' when 'future_renewal' then 'schedule_renewal_followup'
    when 'under_contract' then 'capture_incumbent_timing' when 'unsubscribe' then 'suppress_contact'
    when 'bounce' then 'repair_contact' when 'not_interested' then 'close_or_nurture'
    else case when new.needs_response then 'review_reply' else 'no_action' end end;
  v_action_payload:=jsonb_strip_nulls(jsonb_build_object('url',v_intel->>'url','referred_email',v_email,'classification',new.classification));
  update public.outreach_replies set intelligence=v_intel,action_kind=v_action,action_payload=v_action_payload where id=new.id;

  update public.outreach_targets set
    next_action=case new.classification
      when 'vendor_registration' then 'Complete vendor / subcontractor registration'
      when 'bid_portal' then 'Open bid portal and review available packages'
      when 'procurement_only' then 'Route pursuit through procurement / sourcing'
      when 'send_capabilities' then 'Send capability and qualification package' else next_action end,
    next_action_due_at=case when new.classification in ('vendor_registration','bid_portal','procurement_only','send_capabilities') then now()+interval '1 day' else next_action_due_at end,
    updated_at=now()
  where id=new.outreach_target_id;

  if new.pursuit_id is not null then
    update public.outreach_pursuits set
      stage=case when new.classification in ('vendor_registration','bid_portal','procurement_only') and stage in ('research','contact_ready','outreach') then 'engaged' else stage end,
      next_action=case new.classification
        when 'vendor_registration' then 'Complete vendor / subcontractor registration'
        when 'bid_portal' then 'Open bid portal and review available packages'
        when 'procurement_only' then 'Route pursuit through procurement / sourcing'
        when 'send_capabilities' then 'Send capability and qualification package' else next_action end,
      next_action_due_at=case when new.classification in ('vendor_registration','bid_portal','procurement_only','send_capabilities') then now()+interval '1 day' else next_action_due_at end,
      updated_at=now()
    where id=new.pursuit_id;
    if v_email is not null and v_email<>lower(coalesce(new.sender_email,'')) then
      insert into public.outreach_referral_candidates(workspace_id,pursuit_id,source_reply_id,referred_email,referred_phone)
      values(new.workspace_id,new.pursuit_id,new.id,v_email,v_intel->>'phone')
      on conflict(workspace_id,source_reply_id,referred_email) do nothing;
    end if;
  end if;
  return new;
end $$;
revoke all on function public.enrich_outreach_reply_after_insert() from public,anon,authenticated;
drop trigger if exists trg_enrich_outreach_reply_after_insert on public.outreach_replies;
create trigger trg_enrich_outreach_reply_after_insert after insert on public.outreach_replies
for each row execute function public.enrich_outreach_reply_after_insert();

create or replace function public.record_outreach_sync_state_system(
  p_workspace_id uuid,p_provider text,p_cursor text default null,p_status text default 'healthy',
  p_error text default null,p_details jsonb default '{}'::jsonb
) returns void language plpgsql security definer set search_path=pg_catalog,public
as $$
begin
  if p_status not in ('idle','healthy','running','error') then raise exception 'invalid sync status'; end if;
  insert into public.outreach_sync_state(workspace_id,provider,cursor,status,last_attempt_at,last_successful_sync_at,last_error,details,updated_at)
  values(p_workspace_id,p_provider,p_cursor,p_status,now(),case when p_status='healthy' then now() else null end,p_error,coalesce(p_details,'{}'::jsonb),now())
  on conflict(workspace_id,provider) do update set
    cursor=coalesce(excluded.cursor,public.outreach_sync_state.cursor),status=excluded.status,last_attempt_at=excluded.last_attempt_at,
    last_successful_sync_at=case when excluded.status='healthy' then now() else public.outreach_sync_state.last_successful_sync_at end,
    last_error=excluded.last_error,details=coalesce(public.outreach_sync_state.details,'{}'::jsonb)||excluded.details,updated_at=now();
end $$;
revoke all on function public.record_outreach_sync_state_system(uuid,text,text,text,text,jsonb) from public,anon,authenticated;
grant execute on function public.record_outreach_sync_state_system(uuid,text,text,text,text,jsonb) to service_role;

create or replace function public.record_outreach_inbound_failure_system(p_event_id uuid,p_error text)
returns text language plpgsql security definer set search_path=pg_catalog,public
as $$
declare v_status text;
begin
  update public.outreach_inbound_events set failure_count=failure_count+1,last_attempt_at=now(),
    last_error=left(coalesce(p_error,'unknown inbound processing error'),2000),
    status=case when failure_count+1>=3 then 'dead_letter' else 'error' end,
    processing_stage=case when failure_count+1>=3 then 'dead_letter' else 'error' end,
    dead_letter_at=case when failure_count+1>=3 then now() else dead_letter_at end,updated_at=now()
  where id=p_event_id returning status into v_status;
  if not found then raise exception 'inbound event not found'; end if;
  return v_status;
end $$;
revoke all on function public.record_outreach_inbound_failure_system(uuid,text) from public,anon,authenticated;
grant execute on function public.record_outreach_inbound_failure_system(uuid,text) to service_role;

create or replace function public.finalize_outreach_inbound_event_system(
  p_event_id uuid,p_body text,p_subject text default null,p_sender_email text default null,
  p_provider_thread_id text default null,p_raw_metadata jsonb default '{}'::jsonb
) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private
as $$
declare e public.outreach_inbound_events%rowtype; v_target_id uuid; v_pursuit_id uuid; v_match_reason text;
  v_candidate_count integer:=0; v_best_score integer; v_best_pursuits integer; v_result jsonb; v_status text;
  v_in_reply_to text; v_refs text[]:='{}'::text[]; v_verified_target text;
begin
  if nullif(btrim(coalesce(p_body,'')),'') is null then raise exception 'reply body is required'; end if;
  select * into e from public.outreach_inbound_events where id=p_event_id for update;
  if not found then raise exception 'inbound event not found'; end if;
  if e.reply_id is not null then return jsonb_build_object('event_id',e.id,'status','matched','reply_id',e.reply_id,'duplicate',true); end if;
  if e.status not in ('pending_content','error') then return jsonb_build_object('event_id',e.id,'status',e.status,'reply_id',e.reply_id,'duplicate',true); end if;
  update public.outreach_inbound_events set processing_stage='matching',last_attempt_at=now(),last_error=null,updated_at=now() where id=e.id;
  v_in_reply_to:=coalesce(nullif(p_raw_metadata->>'in_reply_to',''),e.in_reply_to);
  v_verified_target:=coalesce(nullif(lower(p_raw_metadata->>'verified_sent_target_email'),''),e.verified_sent_target_email);
  if jsonb_typeof(p_raw_metadata->'reference_message_ids')='array' then
    select coalesce(array_agg(value),'{}'::text[]) into v_refs from jsonb_array_elements_text(p_raw_metadata->'reference_message_ids');
  else v_refs:=coalesce(e.reference_message_ids,'{}'::text[]); end if;
  with candidates as (
    select * from public.find_outreach_reply_targets_v2(e.workspace_id,coalesce(nullif(lower(btrim(p_sender_email)),''),e.sender_email),
      coalesce(nullif(btrim(p_provider_thread_id),''),e.provider_thread_id),v_in_reply_to,v_refs,v_verified_target)
  ), ranked as (select *,max(match_score) over() best_score from candidates)
  select count(*)::int,max(best_score)::int,count(distinct coalesce(pursuit_id::text,target_id::text)) filter(where match_score=best_score)::int
  into v_candidate_count,v_best_score,v_best_pursuits from ranked;
  if v_candidate_count>0 and v_best_pursuits=1 then
    select target_id,pursuit_id,match_reason into v_target_id,v_pursuit_id,v_match_reason
    from public.find_outreach_reply_targets_v2(e.workspace_id,coalesce(nullif(lower(btrim(p_sender_email)),''),e.sender_email),
      coalesce(nullif(btrim(p_provider_thread_id),''),e.provider_thread_id),v_in_reply_to,v_refs,v_verified_target)
    where match_score=v_best_score order by last_touch_at desc nulls last,target_id limit 1;
  end if;
  if v_target_id is null then
    v_status:=case when v_candidate_count>0 then 'ambiguous' else 'unmatched' end;
    update public.outreach_inbound_events set body=p_body,subject=coalesce(nullif(btrim(p_subject),''),subject),
      sender_email=coalesce(nullif(lower(btrim(p_sender_email)),''),sender_email),
      provider_thread_id=coalesce(nullif(btrim(p_provider_thread_id),''),provider_thread_id),
      in_reply_to=coalesce(v_in_reply_to,in_reply_to),reference_message_ids=coalesce(v_refs,reference_message_ids),
      verified_sent_target_email=coalesce(v_verified_target,verified_sent_target_email),status=v_status,processing_stage='unresolved',
      match_reason=case when v_candidate_count>0 then 'multiple_candidate_pursuits' else 'no_target_match' end,
      raw_metadata=coalesce(raw_metadata,'{}'::jsonb)||coalesce(p_raw_metadata,'{}'::jsonb)||jsonb_build_object('content_pending',false,'finalized_at',now()),
      finalized_at=now(),last_attempt_at=now(),last_error=null,updated_at=now()
    where id=e.id;
    return jsonb_build_object('event_id',e.id,'status',v_status,'matched',false,'candidates',v_candidate_count);
  end if;
  v_result:=public.ingest_outreach_reply_system(e.workspace_id,v_target_id,p_body,
    coalesce(nullif(lower(btrim(p_sender_email)),''),e.sender_email),coalesce(nullif(btrim(p_subject),''),e.subject),
    'email',e.provider,e.provider_message_id,coalesce(nullif(btrim(p_provider_thread_id),''),e.provider_thread_id),
    e.received_at,coalesce(e.raw_metadata,'{}'::jsonb)||coalesce(p_raw_metadata,'{}'::jsonb)||jsonb_build_object('inbound_event_id',e.id,'finalized_from_pending_content',true));
  update public.outreach_inbound_events set body=p_body,subject=coalesce(nullif(btrim(p_subject),''),subject),
    sender_email=coalesce(nullif(lower(btrim(p_sender_email)),''),sender_email),
    provider_thread_id=coalesce(nullif(btrim(p_provider_thread_id),''),provider_thread_id),
    in_reply_to=coalesce(v_in_reply_to,in_reply_to),reference_message_ids=coalesce(v_refs,reference_message_ids),
    verified_sent_target_email=coalesce(v_verified_target,verified_sent_target_email),status='matched',processing_stage='actioned',
    matched_target_id=v_target_id,matched_pursuit_id=v_pursuit_id,reply_id=(v_result->>'reply_id')::uuid,match_reason=v_match_reason,
    raw_metadata=coalesce(raw_metadata,'{}'::jsonb)||coalesce(p_raw_metadata,'{}'::jsonb)||jsonb_build_object('content_pending',false,'finalized_at',now()),
    finalized_at=now(),last_attempt_at=now(),last_error=null,updated_at=now()
  where id=e.id;
  return jsonb_build_object('event_id',e.id,'status','matched','matched',true)||v_result;
exception when others then
  update public.outreach_inbound_events set failure_count=failure_count+1,last_attempt_at=now(),last_error=left(sqlerrm,2000),
    status=case when failure_count+1>=3 then 'dead_letter' else 'error' end,
    processing_stage=case when failure_count+1>=3 then 'dead_letter' else 'error' end,
    dead_letter_at=case when failure_count+1>=3 then now() else dead_letter_at end,updated_at=now()
  where id=p_event_id;
  select status into v_status from public.outreach_inbound_events where id=p_event_id;
  return jsonb_build_object('event_id',p_event_id,'status',coalesce(v_status,'error'),'matched',false,'error',sqlerrm);
end $$;
revoke all on function public.finalize_outreach_inbound_event_system(uuid,text,text,text,text,jsonb) from public,anon,authenticated;
grant execute on function public.finalize_outreach_inbound_event_system(uuid,text,text,text,text,jsonb) to service_role;

create or replace function public.register_outreach_inbound_event_system(
  p_workspace_id uuid,p_provider text,p_provider_message_id text,p_provider_thread_id text default null,
  p_sender_email text default null,p_subject text default null,p_body text default null,p_received_at timestamptz default now(),
  p_in_reply_to text default null,p_reference_message_ids text[] default '{}'::text[],p_verified_sent_target_email text default null,
  p_is_test boolean default false,p_raw_metadata jsonb default '{}'::jsonb
) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private
as $$
declare v_event public.outreach_inbound_events%rowtype; v_result jsonb;
begin
  if nullif(btrim(coalesce(p_provider,'')),'') is null then raise exception 'provider required'; end if;
  if nullif(btrim(coalesce(p_provider_message_id,'')),'') is null then raise exception 'provider message id required'; end if;
  select * into v_event from public.outreach_inbound_events
  where workspace_id=p_workspace_id and provider=p_provider and provider_message_id=p_provider_message_id limit 1;
  if found then return jsonb_build_object('event_id',v_event.id,'status',v_event.status,'reply_id',v_event.reply_id,'duplicate',true); end if;
  insert into public.outreach_inbound_events(workspace_id,provider,provider_message_id,provider_thread_id,sender_email,subject,body,received_at,
    status,processing_stage,match_reason,raw_metadata,is_test,in_reply_to,reference_message_ids,verified_sent_target_email,last_attempt_at)
  values(p_workspace_id,p_provider,p_provider_message_id,p_provider_thread_id,lower(nullif(btrim(coalesce(p_sender_email,'')),'')),
    nullif(btrim(coalesce(p_subject,'')),''),coalesce(nullif(p_body,''),'Inbound content pending retrieval'),coalesce(p_received_at,now()),
    'pending_content','pending_content','awaiting_content_or_match',coalesce(p_raw_metadata,'{}'::jsonb)||jsonb_build_object('content_pending',p_body is null),
    coalesce(p_is_test,false),p_in_reply_to,coalesce(p_reference_message_ids,'{}'::text[]),lower(nullif(btrim(coalesce(p_verified_sent_target_email,'')),'')),now())
  returning * into v_event;
  if p_body is null then return jsonb_build_object('event_id',v_event.id,'status','pending_content','duplicate',false); end if;
  v_result:=public.finalize_outreach_inbound_event_system(v_event.id,p_body,p_subject,p_sender_email,p_provider_thread_id,
    coalesce(p_raw_metadata,'{}'::jsonb)||jsonb_build_object('in_reply_to',p_in_reply_to,'reference_message_ids',to_jsonb(coalesce(p_reference_message_ids,'{}'::text[])),'verified_sent_target_email',p_verified_sent_target_email));
  return v_result||jsonb_build_object('duplicate',false);
end $$;
revoke all on function public.register_outreach_inbound_event_system(uuid,text,text,text,text,text,text,timestamptz,text,text[],text,boolean,jsonb) from public,anon,authenticated;
grant execute on function public.register_outreach_inbound_event_system(uuid,text,text,text,text,text,text,timestamptz,text,text[],text,boolean,jsonb) to service_role;

create or replace function public.promote_outreach_referral_candidate(p_candidate_id uuid,p_first_name text,p_last_name text,p_title text default null)
returns uuid language plpgsql set search_path=pg_catalog,public,private
as $$
declare r public.outreach_referral_candidates%rowtype; p public.outreach_pursuits%rowtype; v_contact uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into r from public.outreach_referral_candidates where id=p_candidate_id for update;
  if not found then raise exception 'referral candidate not found'; end if;
  if not private.has_workspace_role(r.workspace_id,array['owner','administrator','sales_manager','sales_rep']::public.membership_role[]) then raise exception 'referral candidate unavailable'; end if;
  if nullif(btrim(coalesce(p_first_name,'')),'') is null or nullif(btrim(coalesce(p_last_name,'')),'') is null then raise exception 'first and last name are required'; end if;
  select * into p from public.outreach_pursuits where id=r.pursuit_id;
  select id into v_contact from public.contacts where workspace_id=r.workspace_id and lower(email)=lower(r.referred_email) limit 1;
  if v_contact is null then
    insert into public.contacts(workspace_id,first_name,last_name,job_title,email,status,source_label,source_confidence,source_verified_at)
    values(r.workspace_id,btrim(p_first_name),btrim(p_last_name),nullif(btrim(coalesce(p_title,'')),''),
      lower(r.referred_email),'active','Inbound referral','high',now()) returning id into v_contact;
  end if;
  if p.organization_id is not null and not exists(select 1 from public.organization_contacts oc where oc.workspace_id=r.workspace_id and oc.organization_id=p.organization_id and oc.contact_id=v_contact) then
    insert into public.organization_contacts(workspace_id,organization_id,contact_id,relationship_type,is_primary)
    values(r.workspace_id,p.organization_id,v_contact,'referral',false);
  end if;
  if r.pursuit_id is not null and not exists(select 1 from public.outreach_pursuit_contacts pc where pc.workspace_id=r.workspace_id and pc.pursuit_id=r.pursuit_id and pc.contact_id=v_contact) then
    insert into public.outreach_pursuit_contacts(workspace_id,pursuit_id,contact_id,buying_role,is_primary,status,evidence_confidence,last_verified_at)
    values(r.workspace_id,r.pursuit_id,v_contact,'referred_contact',false,'active','high',now());
  end if;
  update public.outreach_referral_candidates set status='linked',contact_id=v_contact,referred_name=btrim(p_first_name)||' '||btrim(p_last_name),
    referred_title=coalesce(nullif(btrim(coalesce(p_title,'')),''),referred_title),updated_at=now() where id=r.id;
  update public.outreach_pursuits set next_action='Contact referred decision-maker',next_action_due_at=now()+interval '1 day',updated_at=now() where id=r.pursuit_id;
  return v_contact;
end $$;
revoke all on function public.promote_outreach_referral_candidate(uuid,text,text,text) from public,anon;
grant execute on function public.promote_outreach_referral_candidate(uuid,text,text,text) to authenticated;

create or replace view public.v_outreach_needs_review with(security_invoker=true) as
select e.workspace_id,e.id event_id,e.provider,e.provider_message_id,e.provider_thread_id,e.sender_email,e.subject,e.received_at,
  e.status,e.processing_stage,e.match_reason,e.failure_count,e.last_error,e.dead_letter_at,e.raw_metadata,
  case when e.status='ambiguous' then 'Choose the correct pursuit' when e.status='unmatched' then 'Link to an existing pursuit or create the missing target'
    when e.status='dead_letter' then 'Repair processing error, then retry' when e.status='error' then 'Retry inbound processing' else 'Review inbound message' end recommended_action
from public.outreach_inbound_events e
where e.is_test=false and e.status in ('unmatched','ambiguous','error','dead_letter');
grant select on public.v_outreach_needs_review to authenticated,service_role;

create or replace view public.v_outreach_inbound_health with(security_invoker=true) as
with providers as (
  select workspace_id,provider from public.outreach_sync_state union select distinct workspace_id,provider from public.outreach_inbound_events
), event_stats as (
  select workspace_id,provider,max(received_at) last_inbound_at,
    count(*) filter(where status='pending_content') pending_content_count,
    count(*) filter(where status in ('unmatched','ambiguous') and is_test=false) needs_review_count,
    count(*) filter(where status='error' and is_test=false) error_count,
    count(*) filter(where status='dead_letter' and is_test=false) dead_letter_count,
    min(received_at) filter(where status='pending_content') oldest_pending_at
  from public.outreach_inbound_events group by workspace_id,provider
)
select p.workspace_id,p.provider,coalesce(s.status,'idle') sync_status,s.cursor,s.last_attempt_at,s.last_successful_sync_at,s.last_error,s.details,
  es.last_inbound_at,coalesce(es.pending_content_count,0) pending_content_count,coalesce(es.needs_review_count,0) needs_review_count,
  coalesce(es.error_count,0) error_count,coalesce(es.dead_letter_count,0) dead_letter_count,es.oldest_pending_at,
  case when coalesce(es.dead_letter_count,0)>0 or coalesce(es.error_count,0)>0 or s.status='error' then 'error'
    when es.oldest_pending_at is not null and es.oldest_pending_at<now()-interval '10 minutes' then 'degraded' else 'healthy' end health
from providers p left join public.outreach_sync_state s on s.workspace_id=p.workspace_id and s.provider=p.provider
left join event_stats es on es.workspace_id=p.workspace_id and es.provider=p.provider;
grant select on public.v_outreach_inbound_health to authenticated,service_role;

create or replace view public.v_outreach_reply_command_center with(security_invoker=true) as
select i.*,r.action_kind,r.action_payload,r.intelligence,
  case when r.classification='vendor_registration' then 'Vendor registration' when r.classification='bid_portal' then 'Bid portal'
    when r.classification='procurement_only' then 'Procurement route' when r.classification='send_capabilities' then 'Capabilities requested'
    when r.classification='request_quote' then 'Quote requested' when r.classification='site_visit_request' then 'Site visit requested'
    when r.classification='referral' then 'Referral' else initcap(replace(r.classification,'_',' ')) end intent_label
from public.v_outreach_reply_inbox i join public.outreach_replies r on r.id=i.reply_id;
grant select on public.v_outreach_reply_command_center to authenticated,service_role;

update public.outreach_inbound_events set processing_stage=case
  when status='pending_content' then 'pending_content' when status='matched' and reply_id is not null then 'actioned'
  when status in ('unmatched','ambiguous') then 'unresolved' when status='error' then 'error'
  when status='dead_letter' then 'dead_letter' else processing_stage end;

-- Adaptive outreach follow-up engine. Replaces fixed cadence decisions with state/evidence decisions.
create or replace view public.v_outreach_adaptive_next_touch with(security_invoker=true) as
with stats as (
 select t.id target_id,
  count(d.id) filter(where d.state='sent')::int sent_count,
  max(d.sent_at) filter(where d.state='sent') last_sent_at,
  (array_agg(r.classification order by r.received_at desc) filter(where r.id is not null))[1] last_reply,
  (array_agg(r.renewal_date order by r.received_at desc) filter(where r.renewal_date is not null))[1] renewal_date,
  count(r.id)::int reply_count
 from public.outreach_targets t
 left join public.outreach_drafts d on d.outreach_target_id=t.id
 left join public.outreach_replies r on r.outreach_target_id=t.id
 group by t.id
), sig as (
 select t.id target_id,bool_or(s.status='open' and s.source_confidence='high') high_signal,
 min(s.deadline_at) filter(where s.status='open' and s.deadline_at is not null) deadline
 from public.outreach_targets t left join public.outreach_target_properties otp on otp.outreach_target_id=t.id
 left join public.target_opportunity_signals s on s.workspace_id=t.workspace_id and (s.target_id=t.id or s.organization_id=t.organization_id or s.property_id=otp.property_id)
 group by t.id
)
select t.workspace_id,t.id outreach_target_id,coalesce(st.sent_count,0) sent_count,st.last_sent_at,st.last_reply,st.renewal_date,
 case
  when t.status::text in ('converted','rejected') or st.last_reply='not_interested' then 'stop'
  when st.last_reply in ('interested','request_call') then 'site_walk'
  when st.last_reply='request_quote' then 'quote'
  when st.last_reply in ('referral','wrong_person') then 'referral'
  when st.last_reply='bounce' then 'repair_contact'
  when st.last_reply='out_of_office' then 'wait'
  when st.last_reply='under_contract' or st.last_reply='future_renewal' then 'renewal_timing'
  when coalesce(st.sent_count,0)=0 then 'introduction'
  when coalesce(st.sent_count,0)>=4 and st.reply_count=0 then 'close_loop'
  when coalesce(sg.high_signal,false) then 'value_add'
  when coalesce(st.sent_count,0)=1 then 'value_add'
  when coalesce(st.sent_count,0)=2 then 'timing_check'
  else 'close_loop' end next_touch_type,
 case
  when st.last_reply='out_of_office' then st.last_sent_at+interval '7 days'
  when st.last_reply in ('under_contract','future_renewal') and st.renewal_date is not null then st.renewal_date::timestamptz-interval '90 days'
  when coalesce(st.sent_count,0)=1 then st.last_sent_at+interval '4 days'
  when coalesce(st.sent_count,0)=2 then st.last_sent_at+interval '7 days'
  when coalesce(st.sent_count,0)=3 then st.last_sent_at+interval '14 days'
  when coalesce(st.sent_count,0)>=4 then st.last_sent_at+interval '30 days'
  else now() end next_touch_at,
 sg.deadline signal_deadline
from public.outreach_targets t left join stats st on st.target_id=t.id left join sig sg on sg.target_id=t.id;
grant select on public.v_outreach_adaptive_next_touch to authenticated;

create or replace function public.generate_adaptive_followup(p_target_id uuid,p_channel text default 'email')
returns uuid language plpgsql security invoker set search_path=public as $$
declare n record; v_objective text; v_id uuid; d public.outreach_drafts%rowtype; v_prefix text; v_body text;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 select * into n from public.v_outreach_adaptive_next_touch where outreach_target_id=p_target_id;
 if not found or not private.is_workspace_member(n.workspace_id) then raise exception 'target unavailable'; end if;
 if n.next_touch_type in ('stop','wait','repair_contact','renewal_timing') then raise exception 'adaptive engine recommends %, not a new message',n.next_touch_type; end if;
 v_objective:=case n.next_touch_type when 'site_walk' then 'site_walk' when 'quote' then 'quote' when 'referral' then 'referral' else 'introduction' end;
 v_id:=public.generate_outreach_draft(p_target_id,p_channel,v_objective);
 select * into d from public.outreach_drafts where id=v_id for update;
 v_prefix:=case n.next_touch_type
   when 'value_add' then 'I wanted to add one useful point rather than repeat my earlier note. '
   when 'timing_check' then 'One quick timing question. '
   when 'close_loop' then 'I’ll close the loop after this note. '
   else '' end;
 if n.sent_count>0 and n.next_touch_type in ('value_add','timing_check','close_loop') then
   v_body:=case n.next_touch_type
    when 'value_add' then regexp_replace(d.body,'^(Hi [^,]+,\n\n)','\1'||v_prefix)||E'\n\nIf contractor coverage is already set, I’m also happy to be a backup option for overflow or an upcoming site review.'
    when 'timing_check' then regexp_replace(d.body,'^(Hi [^,]+,\n\n)','\1'||v_prefix)||E'\n\nIs there a renewal or bid window I should work backward from rather than continuing to follow up now?'
    else regexp_replace(d.body,'^(Hi [^,]+,\n\n)','\1'||v_prefix)||E'\n\nIf this is not a priority right now, no need to reply. I can reconnect when there is an actual service or bid window.' end;
   update public.outreach_drafts set body=v_body,strategy=n.next_touch_type,evidence=evidence||jsonb_build_object('adaptive_followup',true,'prior_sent_count',n.sent_count,'next_touch_type',n.next_touch_type),updated_at=now() where id=v_id;
 end if;
 return v_id;
end $$;
revoke all on function public.generate_adaptive_followup(uuid,text) from public;
grant execute on function public.generate_adaptive_followup(uuid,text) to authenticated;

create or replace function public.mark_outreach_draft_sent(p_draft_id uuid,p_provider text default null,p_provider_message_id text default null,p_provider_thread_id text default null)
returns uuid language plpgsql security invoker set search_path=public as $$
declare d public.outreach_drafts%rowtype; n record; v_touch_channel public.outreach_touch_channel;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 select * into d from public.outreach_drafts where id=p_draft_id for update;
 if not found or not private.is_workspace_member(d.workspace_id) then raise exception 'draft unavailable'; end if;
 if d.state <> 'approved' then raise exception 'invalid outreach draft transition: % -> sent',d.state using errcode='22023'; end if;
 update public.outreach_drafts set state='sent',provider=p_provider,provider_message_id=p_provider_message_id,provider_thread_id=p_provider_thread_id,sent_at=now(),updated_at=now() where id=p_draft_id;
 v_touch_channel:=case d.channel when 'email' then 'email'::public.outreach_touch_channel when 'sms' then 'sms'::public.outreach_touch_channel when 'call' then 'call'::public.outreach_touch_channel when 'voicemail' then 'call'::public.outreach_touch_channel else 'other'::public.outreach_touch_channel end;
 perform public.log_outreach_touch(d.outreach_target_id,v_touch_channel,'sent',left(d.body,1000),'contacted','Recalculate adaptive next touch',now()+interval '1 minute');
 select * into n from public.v_outreach_adaptive_next_touch where outreach_target_id=d.outreach_target_id;
 update public.outreach_targets set next_action=case n.next_touch_type when 'stop' then 'No further outreach' when 'repair_contact' then 'Repair contact data' when 'renewal_timing' then 'Wait for renewal window' when 'wait' then 'Wait before retry' else 'Adaptive follow-up: '||replace(n.next_touch_type,'_',' ') end,next_action_due_at=n.next_touch_at,updated_at=now() where id=d.outreach_target_id;
 return p_draft_id;
end $$;
revoke all on function public.mark_outreach_draft_sent(uuid,text,text,text) from public;
grant execute on function public.mark_outreach_draft_sent(uuid,text,text,text) to authenticated;

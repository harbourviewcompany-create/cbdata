-- Contact-quality-aware command ranking.\ndrop view if exists public.v_outreach_command_queue;\ncreate view public.v_outreach_command_queue with(security_invoker=true) as
with base as (
 select e.*,a.next_touch_type,a.next_touch_at,a.sent_count,a.last_reply,
  c.source_confidence,c.source_url,
  case when e.contact_display_name is not null
    and e.contact_display_name !~* '(department|team|route|procurement|facilities|operations|vendor|supply|management)$'
    and e.contact_display_name ~ '^[[:alpha:]][[:alpha:]''.-]+[[:space:]]+[[:alpha:]][[:alpha:]''.-]+'
    then true else false end named_person,
  case when coalesce(e.contact_email,'') ~* '^(info|contact|admin|office|facilities|procurement|purchasing|bids|bidresults|board|hello|general|reception|service|services|support)@' then true else false end generic_inbox,
  case when c.source_confidence::text='high' and c.source_url is not null then true else false end provenance_verified
 from public.v_outreach_execution_queue e
 join public.v_outreach_adaptive_next_touch a on a.outreach_target_id=e.id
 left join public.outreach_targets t on t.id=e.id
 left join public.contacts c on c.id=t.contact_id
 where e.status in ('queued','contacted','responded')
  and a.next_touch_type not in ('stop','wait','repair_contact','renewal_timing')
  and (a.next_touch_at is null or a.next_touch_at<=now()+interval '1 day')
)
select workspace_id,id outreach_target_id,organization_display_name,contact_display_name,contact_email,contact_job_title,
 outreach_readiness_score,contact_confidence_score,property_count,high_signal_property_count,open_signal_count,why_now,service_fit,
 next_touch_type,next_touch_at,sent_count,last_reply,named_person,generic_inbox,provenance_verified,
 least(100,greatest(0,round(
   coalesce(outreach_readiness_score,0)*0.34 + coalesce(contact_confidence_score,0)*0.16
   + least(15,coalesce(high_signal_property_count,0)*5)+least(10,coalesce(open_signal_count,0)*5)
   + case when next_touch_at<=now() then 8 else 0 end
   + case next_touch_type when 'site_walk' then 12 when 'quote' then 12 when 'referral' then 9 when 'value_add' then 7 when 'timing_check' then 5 when 'introduction' then 4 else 0 end
   + case when named_person then 10 else -18 end
   + case when provenance_verified then 8 else 0 end
   + case when generic_inbox then -12 else 0 end
   + case when contact_email is null or btrim(contact_email)='' then -8 else 0 end
 )::int)) command_score,
 case
  when not named_person then 'Research named decision-maker'
  when generic_inbox then 'Verify direct contact channel'
  when next_touch_type in ('site_walk','quote') then 'Reply requires action'
  when next_touch_type='referral' then 'Referral / correct-contact route'
  when open_signal_count>0 then 'Verified buying signal'
  when high_signal_property_count>0 then 'Strong property-service fit'
  when provenance_verified then 'Verified decision route'
  else 'Account readiness' end priority_reason,
 case
  when not named_person then 'research'
  when generic_inbox and next_touch_type='introduction' then 'verify_contact'
  else 'outreach' end command_mode,
 latest_draft_id,latest_draft_state,latest_draft_subject,latest_draft_body,latest_draft_channel
from base;
grant select on public.v_outreach_command_queue to authenticated;

create or replace function public.get_daily_outreach_command_queue(p_limit integer default 20)
returns setof public.v_outreach_command_queue language sql security invoker set search_path=public as $$
 select * from public.v_outreach_command_queue
 order by case command_mode when 'outreach' then 0 when 'verify_contact' then 1 else 2 end,
 command_score desc,next_touch_at asc nulls first,outreach_readiness_score desc
 limit least(greatest(coalesce(p_limit,20),1),50)
$$;

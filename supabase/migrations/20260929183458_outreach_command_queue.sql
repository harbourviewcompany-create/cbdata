-- Ranked daily Outreach Command Queue.
create or replace view public.v_outreach_command_queue with(security_invoker=true) as
select e.workspace_id,e.id outreach_target_id,e.organization_display_name,e.contact_display_name,e.contact_email,e.contact_job_title,
 e.outreach_readiness_score,e.contact_confidence_score,e.property_count,e.high_signal_property_count,e.open_signal_count,e.why_now,e.service_fit,
 a.next_touch_type,a.next_touch_at,a.sent_count,a.last_reply,
 least(100,greatest(0,
   round(coalesce(e.outreach_readiness_score,0)*0.38
   + coalesce(e.contact_confidence_score,0)*0.22
   + least(15,coalesce(e.high_signal_property_count,0)*5)
   + least(10,coalesce(e.open_signal_count,0)*5)
   + case when a.next_touch_at<=now() then 8 else 0 end
   + case a.next_touch_type when 'site_walk' then 12 when 'quote' then 12 when 'referral' then 9 when 'value_add' then 7 when 'timing_check' then 5 when 'introduction' then 4 else 0 end
   )::int)) command_score,
 case
   when a.next_touch_type in ('site_walk','quote') then 'Reply requires action'
   when a.next_touch_type='referral' then 'Referral / correct-contact route'
   when e.open_signal_count>0 then 'Verified buying signal'
   when e.high_signal_property_count>0 then 'Strong property-service fit'
   when e.contact_confidence_score>=90 then 'Verified decision route'
   else 'Account readiness' end priority_reason,
 e.latest_draft_id,e.latest_draft_state,e.latest_draft_subject,e.latest_draft_body,e.latest_draft_channel
from public.v_outreach_execution_queue e
join public.v_outreach_adaptive_next_touch a on a.outreach_target_id=e.id
where e.status in ('queued','contacted','responded')
 and a.next_touch_type not in ('stop','wait','repair_contact','renewal_timing')
 and (a.next_touch_at is null or a.next_touch_at<=now()+interval '1 day');
grant select on public.v_outreach_command_queue to authenticated;

create or replace function public.get_daily_outreach_command_queue(p_limit integer default 20)
returns setof public.v_outreach_command_queue language sql security invoker set search_path=public as $$
 select * from public.v_outreach_command_queue
 order by command_score desc,next_touch_at asc nulls first,outreach_readiness_score desc
 limit least(greatest(coalesce(p_limit,20),1),50)
$$;
revoke all on function public.get_daily_outreach_command_queue(integer) from public,anon;
grant execute on function public.get_daily_outreach_command_queue(integer) to authenticated;

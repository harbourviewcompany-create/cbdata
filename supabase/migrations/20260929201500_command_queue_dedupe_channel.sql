-- Final command queue hygiene: email readiness and duplicate suppression.
create or replace function public.get_daily_outreach_command_queue(p_limit integer default 20)
returns setof public.v_outreach_command_queue language sql security invoker set search_path=public as $$
 with ranked as (
  select q.*,
   row_number() over (
    partition by lower(coalesce(q.organization_display_name,'')),lower(coalesce(q.contact_display_name,''))
    order by
     case when nullif(btrim(q.contact_email),'') is not null then 0 else 1 end,
     q.command_score desc,q.outreach_readiness_score desc
   ) duplicate_rank
  from public.v_outreach_command_queue q
 )
 select workspace_id,outreach_target_id,organization_display_name,contact_display_name,contact_email,contact_job_title,
 outreach_readiness_score,contact_confidence_score,property_count,high_signal_property_count,open_signal_count,why_now,service_fit,
 next_touch_type,next_touch_at,sent_count,last_reply,named_person,generic_inbox,provenance_verified,
 case when nullif(btrim(contact_email),'') is null then greatest(0,command_score-15) else command_score end command_score,
 case when nullif(btrim(contact_email),'') is null then 'Verify direct contact channel' else priority_reason end priority_reason,
 case when nullif(btrim(contact_email),'') is null then 'verify_contact' else command_mode end command_mode,
 latest_draft_id,latest_draft_state,latest_draft_subject,latest_draft_body,latest_draft_channel
 from ranked
 where duplicate_rank=1
 order by
  case when nullif(btrim(contact_email),'') is not null and command_mode='outreach' then 0 when nullif(btrim(contact_email),'') is null or command_mode='verify_contact' then 1 else 2 end,
  case when nullif(btrim(contact_email),'') is null then greatest(0,command_score-15) else command_score end desc,
  next_touch_at asc nulls first,outreach_readiness_score desc
 limit least(greatest(coalesce(p_limit,20),1),50)
$$;

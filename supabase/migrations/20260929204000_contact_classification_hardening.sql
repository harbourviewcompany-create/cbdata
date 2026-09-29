-- Harden person-vs-route classification and feed route records into enrichment.
create or replace function public.is_named_outreach_person(p_name text)
returns boolean language sql immutable parallel safe as $$
 select coalesce(
   p_name is not null
   and btrim(p_name)<>''
   and p_name ~ '^[[:alpha:]][[:alpha:]''.-]+[[:space:]]+[[:alpha:]][[:alpha:]''.-]+'
   and p_name !~* '\m(administration|department|team|route|routing|office|staff|management|procurement|purchasing|facilities|operations|vendor|supplier|services|service|board|committee|association|residences|property|properties|commercial|support|general|contact|leasing|maintenance|reception)\M',
 false)
$$;
revoke all on function public.is_named_outreach_person(text) from public,anon;
grant execute on function public.is_named_outreach_person(text) to authenticated,service_role;

drop function if exists public.get_daily_outreach_command_queue(integer);
drop view if exists public.v_outreach_command_queue;
create view public.v_outreach_command_queue with(security_invoker=true) as
with base as (
 select e.*,a.next_touch_type,a.next_touch_at,a.sent_count,a.last_reply,c.source_confidence,c.source_url,
  public.is_named_outreach_person(e.contact_display_name) named_person,
  case when coalesce(e.contact_email,'') ~* '^(info|contact|admin|office|facilities|procurement|purchasing|bids|bidresults|board|hello|general|reception|service|services|support)@' then true else false end generic_inbox,
  case when c.source_confidence::text='high' and c.source_url is not null then true else false end provenance_verified
 from public.v_outreach_execution_queue e
 join public.v_outreach_adaptive_next_touch a on a.outreach_target_id=e.id
 left join public.outreach_targets t on t.id=e.id left join public.contacts c on c.id=t.contact_id
 where e.status in ('queued','contacted','responded') and a.next_touch_type not in ('stop','wait','repair_contact','renewal_timing')
 and (a.next_touch_at is null or a.next_touch_at<=now()+interval '1 day')
)
select workspace_id,id outreach_target_id,organization_display_name,contact_display_name,contact_email,contact_job_title,
 outreach_readiness_score,contact_confidence_score,property_count,high_signal_property_count,open_signal_count,why_now,service_fit,
 next_touch_type,next_touch_at,sent_count,last_reply,named_person,generic_inbox,provenance_verified,
 least(100,greatest(0,round(coalesce(outreach_readiness_score,0)*.34+coalesce(contact_confidence_score,0)*.16
 +least(15,coalesce(high_signal_property_count,0)*5)+least(10,coalesce(open_signal_count,0)*5)
 +case when next_touch_at<=now() then 8 else 0 end
 +case next_touch_type when 'site_walk' then 12 when 'quote' then 12 when 'referral' then 9 when 'value_add' then 7 when 'timing_check' then 5 when 'introduction' then 4 else 0 end
 +case when named_person then 10 else -18 end+case when provenance_verified then 8 else 0 end+case when generic_inbox then -12 else 0 end
 +case when contact_email is null or btrim(contact_email)='' then -8 else 0 end)::int)) command_score,
 case when not named_person then 'Research named decision-maker' when generic_inbox then 'Verify direct contact channel'
 when next_touch_type in ('site_walk','quote') then 'Reply requires action' when next_touch_type='referral' then 'Referral / correct-contact route'
 when open_signal_count>0 then 'Verified buying signal' when high_signal_property_count>0 then 'Strong property-service fit'
 when provenance_verified then 'Verified decision route' else 'Account readiness' end priority_reason,
 case when not named_person then 'research' when generic_inbox and next_touch_type='introduction' then 'verify_contact' else 'outreach' end command_mode,
 latest_draft_id,latest_draft_state,latest_draft_subject,latest_draft_body,latest_draft_channel
from base;
grant select on public.v_outreach_command_queue to authenticated;

create function public.get_daily_outreach_command_queue(p_limit integer default 20)
returns setof public.v_outreach_command_queue language sql security invoker set search_path=public as $$
 with ranked as (
  select q.*,row_number() over(partition by lower(coalesce(q.organization_display_name,'')),lower(coalesce(q.contact_display_name,''))
   order by case when nullif(btrim(q.contact_email),'') is not null then 0 else 1 end,q.command_score desc,q.outreach_readiness_score desc) duplicate_rank
  from public.v_outreach_command_queue q)
 select workspace_id,outreach_target_id,organization_display_name,contact_display_name,contact_email,contact_job_title,
 outreach_readiness_score,contact_confidence_score,property_count,high_signal_property_count,open_signal_count,why_now,service_fit,
 next_touch_type,next_touch_at,sent_count,last_reply,named_person,generic_inbox,provenance_verified,
 case when nullif(btrim(contact_email),'') is null then greatest(0,command_score-15) else command_score end,
 case when nullif(btrim(contact_email),'') is null then 'Verify direct contact channel' else priority_reason end,
 case when nullif(btrim(contact_email),'') is null then 'verify_contact' else command_mode end,
 latest_draft_id,latest_draft_state,latest_draft_subject,latest_draft_body,latest_draft_channel
 from ranked where duplicate_rank=1
 order by case when nullif(btrim(contact_email),'') is not null and command_mode='outreach' then 0 when nullif(btrim(contact_email),'') is null or command_mode='verify_contact' then 1 else 2 end,
 case when nullif(btrim(contact_email),'') is null then greatest(0,command_score-15) else command_score end desc,next_touch_at asc nulls first
 limit least(greatest(coalesce(p_limit,20),1),50)
$$;
revoke all on function public.get_daily_outreach_command_queue(integer) from public,anon;
grant execute on function public.get_daily_outreach_command_queue(integer) to authenticated;

create or replace function private.queue_route_contacts_for_research(p_workspace uuid)
returns integer language plpgsql security invoker set search_path=public,private as $$
declare n integer;
begin
 if current_user not in ('service_role','postgres') then raise exception 'service role required'; end if;
 perform private.refresh_contact_enrichment_queue(p_workspace);
 update public.contact_enrichment_tasks cet set status='queued',next_attempt_at=now(),last_error=null,updated_at=now()
 from public.outreach_targets t
 where cet.outreach_target_id=t.id and cet.workspace_id=p_workspace
 and not public.is_named_outreach_person(coalesce(t.contact_name,'')) and cet.status in ('not_found','dismissed');
 get diagnostics n=row_count; return n;
end $$;
revoke all on function private.queue_route_contacts_for_research(uuid) from public,anon,authenticated;
grant execute on function private.queue_route_contacts_for_research(uuid) to service_role;

create or replace view public.v_growth_opportunity_radar
with (security_invoker=true)
as
select
  po.workspace_id,
  'procurement:'||po.id::text as opportunity_key,
  po.id::text as source_record_id,
  'procurement'::text as origin,
  po.source_key,
  coalesce(ts.display_name,po.source_key) as source_label,
  po.buyer_name,
  po.title,
  po.opportunity_type,
  po.description,
  po.region,
  po.published_at,
  po.closing_at as deadline_at,
  po.source_url,
  po.service_fit,
  coalesce(po.bid_score,po.relevance_score,0)::numeric as score,
  po.classification_status as status,
  po.matched_organization_id,
  po.matched_target_id as outreach_target_id,
  ot.pursuit_id,
  null::text as contact_name,
  null::text as contact_email,
  po.auto_next_action as next_action,
  case
    when pi.inbox_bucket is not null then pi.inbox_bucket
    when po.bid_recommendation='pursue' then 'best_new'
    when po.bid_recommendation='review' then 'needs_review'
    when po.bid_recommendation='monitor' then 'watching'
    else 'archive'
  end as priority_bucket,
  (po.classification_status in ('actionable','watch','promoted')
    and coalesce(po.bid_recommendation,'pass') not in ('pass','expired')) as is_actionable
from public.procurement_opportunities po
left join public.tender_sources ts
  on ts.workspace_id=po.workspace_id and ts.source_key=po.source_key
left join public.outreach_targets ot on ot.id=po.matched_target_id
left join public.v_procurement_inbox pi on pi.id=po.id
where (po.closing_at is null or po.closing_at>=now())
  and po.classification_status<>'suppressed'

union all

select
  w.workspace_id,
  'work_lead:'||w.id::text,
  w.id::text,
  'work_lead'::text,
  w.source_key,
  w.source_label,
  w.buyer_name,
  w.opportunity_title,
  w.opportunity_type,
  w.description,
  w.region,
  w.published_at,
  w.deadline_at,
  w.source_url,
  w.service_fit,
  coalesce(w.conversion_score,0)::numeric,
  w.status,
  w.matched_organization_id,
  w.outreach_target_id,
  w.pursuit_id,
  w.contact_name,
  w.contact_email,
  wi.recommended_next_action,
  coalesce(wi.inbox_bucket,'review') as priority_bucket,
  w.status<>'dismissed' as is_actionable
from public.outreach_work_leads w
left join public.v_outreach_work_lead_inbox wi on wi.id=w.id
where w.status<>'dismissed'
  and (w.deadline_at is null or w.deadline_at>=now())

union all

select
  s.workspace_id,
  'signal:'||s.id::text,
  s.id::text,
  'signal'::text,
  'target_signal'::text,
  coalesce(s.source_label,'Opportunity signal'),
  coalesce(o.operating_name,o.legal_name,t.organization_name,'Account'),
  s.title,
  s.signal_type,
  s.notes,
  coalesce(p.city,o.hq_city,'Ottawa'),
  s.published_at,
  s.deadline_at,
  s.source_url,
  s.service_fit,
  (
    case s.source_confidence when 'high' then 72 when 'medium' then 58 else 45 end
    + case
        when s.deadline_at is not null and s.deadline_at<=now()+interval '14 days' then 12
        when s.deadline_at is not null and s.deadline_at<=now()+interval '30 days' then 7
        else 0
      end
  )::numeric as score,
  s.status,
  s.organization_id,
  s.target_id,
  t.pursuit_id,
  s.buyer_contact_name,
  s.buyer_contact_email,
  case when s.buyer_contact_email is not null
    then 'Contact buyer about this signal'
    else 'Research the buyer and convert this signal into outreach' end,
  case
    when s.deadline_at is not null and s.deadline_at<=now()+interval '14 days' then 'contact_now'
    when s.source_confidence='high' then 'review'
    else 'watching'
  end,
  s.status='open'
from public.target_opportunity_signals s
left join public.organizations o on o.id=s.organization_id
left join public.outreach_targets t on t.id=s.target_id
left join public.properties p on p.id=s.property_id
where s.status='open'
  and (s.deadline_at is null or s.deadline_at>=now());

grant select on public.v_growth_opportunity_radar to authenticated,service_role;

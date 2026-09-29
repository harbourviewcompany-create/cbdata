-- Keep the decision engine consistent with classification suppression.
create or replace function public.refresh_procurement_sales_engine(p_workspace uuid default null)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_count integer := 0;
begin
  with requirement_state as (
    select
      o.id as opportunity_id,
      count(r.id) filter (
        where r.mandatory
          and r.status not in ('complete','not_applicable')
      )::integer as submission_gaps,
      count(r.id) filter (
        where r.mandatory
          and r.status not in ('complete','not_applicable')
          and r.requirement_type in (
            'registration','bonding','insurance','workers_comp','security',
            'experience','references','site_visit','bilingual','certification',
            'equipment','indigenous_eligibility'
          )
      )::integer as qualification_gaps,
      count(r.id) filter (
        where r.mandatory and r.status = 'blocked'
      )::integer as hard_blockers,
      (
        array_agg(
          r.title order by
            case
              when r.status = 'blocked' then 0
              when r.requirement_type in ('registration','experience','security','bonding') then 1
              else 2
            end,
            r.created_at
        ) filter (
          where r.mandatory and r.status not in ('complete','not_applicable')
        )
      )[1] as next_requirement
    from public.procurement_opportunities o
    left join public.tender_requirements r
      on r.workspace_id = o.workspace_id
     and r.tender_record_id = o.promoted_tender_record_id
    where p_workspace is null or o.workspace_id = p_workspace
    group by o.id
  )
  update public.procurement_opportunities o
  set
    canonical_key = public.procurement_canonical_key(o.buyer_name,o.title,o.closing_at),
    qualification_gap_count = coalesce(rs.qualification_gaps,0),
    submission_gap_count = coalesce(rs.submission_gaps,0),
    hard_blocker_count = coalesce(rs.hard_blockers,0),
    raw_payload = coalesce(o.raw_payload,'{}'::jsonb) ||
      jsonb_build_object('next_detected_requirement',rs.next_requirement),
    last_decision_at = now()
  from requirement_state rs
  where o.id = rs.opportunity_id;

  update public.procurement_opportunities o
  set
    bid_score = least(100,greatest(0,
      coalesce(o.relevance_score,0) * 0.55
      + case
          when coalesce(o.region,'') ~* '(ottawa|national capital|gatineau|outaouais|nepean|orleans|gloucester|kanata|barrhaven|stittsville|rockland|kemptville|arnprior|renfrew|carleton place|almonte|cornwall|prescott|brockville|eastern ontario|lanark|smiths falls)' then 18
          else 8
        end
      + case when o.estimated_value is not null then 8 else 2 end
      + case
          when o.closing_at is null then 3
          when o.closing_at >= now() + interval '7 days' then 10
          when o.closing_at >= now() + interval '2 days' then 5
          else -8
        end
      + case when coalesce(cardinality(o.service_fit),0) >= 1 then 9 else 0 end
      - least(36, coalesce(o.qualification_gap_count,0) * 9)
      - least(30, coalesce(o.hard_blocker_count,0) * 15)
    )),
    bid_score_breakdown = jsonb_build_object(
      'trade_fit',coalesce(o.relevance_score,0),
      'region',coalesce(o.region,'unknown'),
      'value_known',o.estimated_value is not null,
      'service_matches',coalesce(cardinality(o.service_fit),0),
      'days_remaining',case
        when o.closing_at is null then null
        else floor(extract(epoch from (o.closing_at-now()))/86400)
      end,
      'qualification_gaps',coalesce(o.qualification_gap_count,0),
      'submission_gaps',coalesce(o.submission_gap_count,0),
      'hard_blockers',coalesce(o.hard_blocker_count,0)
    )
  where p_workspace is null or o.workspace_id = p_workspace;

  update public.procurement_opportunities o
  set
    bid_recommendation = case
      when o.classification_status = 'suppressed' then 'pass'
      when o.closing_at is not null and o.closing_at < now() then 'expired'
      when coalesce(o.hard_blocker_count,0) > 0 then 'blocked'
      when o.bid_score >= 80 then 'pursue'
      when o.bid_score >= 60 then 'review'
      when o.bid_score >= 40 then 'monitor'
      else 'pass'
    end,
    auto_next_action = case
      when o.classification_status = 'suppressed'
        then 'Archive suppressed opportunity'
      when o.closing_at is not null and o.closing_at < now()
        then 'Archive expired opportunity'
      when coalesce(o.hard_blocker_count,0) > 0
        then 'Resolve blocker: ' || coalesce(o.raw_payload->>'next_detected_requirement','mandatory qualification')
      when coalesce(o.qualification_gap_count,0) > 0
        then 'Resolve qualification gap: ' || coalesce(o.raw_payload->>'next_detected_requirement','mandatory qualification')
      when o.promoted_tender_record_id is null
        then 'Review source and promote qualifying opportunity'
      when tr.estimate_id is null
        then 'Create estimate / takeoff'
      when coalesce(o.submission_gap_count,0) > 0
        then 'Complete bid requirement: ' || coalesce(o.raw_payload->>'next_detected_requirement','mandatory submission item')
      when o.closing_at is not null and o.closing_at <= now() + interval '3 days'
        then 'Final compliance review and submit'
      else 'Confirm bid/no-bid and assign next pursuit step'
    end,
    auto_next_action_due_at = case
      when o.classification_status = 'suppressed' then null
      when o.closing_at is not null and o.closing_at < now() then null
      when o.closing_at is null then now() + interval '1 day'
      when o.closing_at <= now() + interval '3 days' then now()
      else least(now() + interval '1 day', o.closing_at - interval '3 days')
    end,
    last_decision_at = now()
  from public.tender_records tr
  where tr.id is not distinct from o.promoted_tender_record_id
    and (p_workspace is null or o.workspace_id = p_workspace);

  update public.procurement_opportunities o
  set
    bid_recommendation = case
      when o.classification_status = 'suppressed' then 'pass'
      when o.closing_at is not null and o.closing_at < now() then 'expired'
      when coalesce(o.hard_blocker_count,0) > 0 then 'blocked'
      when o.bid_score >= 80 then 'pursue'
      when o.bid_score >= 60 then 'review'
      when o.bid_score >= 40 then 'monitor'
      else 'pass'
    end,
    auto_next_action = case
      when o.classification_status = 'suppressed'
        then 'Archive suppressed opportunity'
      when o.closing_at is not null and o.closing_at < now()
        then 'Archive expired opportunity'
      when coalesce(o.hard_blocker_count,0) > 0
        then 'Resolve blocker: ' || coalesce(o.raw_payload->>'next_detected_requirement','mandatory qualification')
      when coalesce(o.qualification_gap_count,0) > 0
        then 'Resolve qualification gap: ' || coalesce(o.raw_payload->>'next_detected_requirement','mandatory qualification')
      else 'Review source and promote qualifying opportunity'
    end,
    auto_next_action_due_at = case
      when o.classification_status = 'suppressed' then null
      when o.closing_at is not null and o.closing_at < now() then null
      when o.closing_at is null then now() + interval '1 day'
      when o.closing_at <= now() + interval '3 days' then now()
      else least(now() + interval '1 day', o.closing_at - interval '3 days')
    end,
    last_decision_at = now()
  where o.promoted_tender_record_id is null
    and (p_workspace is null or o.workspace_id = p_workspace);

  update public.tender_records t
  set
    next_action = o.auto_next_action,
    next_action_due_at = o.auto_next_action_due_at,
    updated_at = now()
  from public.procurement_opportunities o
  where o.workspace_id = t.workspace_id
    and o.promoted_tender_record_id = t.id
    and o.auto_next_action is not null
    and (
      t.next_action is null
      or t.next_action in (
        'Review solicitation and mandatory requirements',
        'Assign next bid-review step',
        'Review source notice and attachments'
      )
      or t.next_action like 'Review solicitation%'
    );

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.refresh_procurement_sales_engine(uuid) from public, anon, authenticated;
grant execute on function public.refresh_procurement_sales_engine(uuid) to service_role;
select public.refresh_procurement_sales_engine(null);

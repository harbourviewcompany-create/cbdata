-- Procurement Sales Engine: normalized scoring, qualification gaps, deduplicated inbox and next actions.
alter table public.procurement_opportunities
  add column if not exists canonical_key text,
  add column if not exists bid_score numeric,
  add column if not exists bid_recommendation text,
  add column if not exists bid_score_breakdown jsonb not null default '{}'::jsonb,
  add column if not exists qualification_gap_count integer not null default 0,
  add column if not exists submission_gap_count integer not null default 0,
  add column if not exists hard_blocker_count integer not null default 0,
  add column if not exists auto_next_action text,
  add column if not exists auto_next_action_due_at timestamptz,
  add column if not exists last_decision_at timestamptz;

create index if not exists procurement_opportunities_workspace_canonical_idx
  on public.procurement_opportunities(workspace_id, canonical_key)
  where canonical_key is not null;

create index if not exists procurement_opportunities_inbox_idx
  on public.procurement_opportunities(workspace_id, bid_recommendation, bid_score desc, closing_at);

create or replace function public.procurement_canonical_key(
  p_buyer text,
  p_title text,
  p_closing timestamptz
)
returns text
language sql
stable
parallel safe
set search_path = ''
as $$
  with normalized as (
    select
      regexp_replace(lower(coalesce(p_buyer,'')), '[^a-z0-9]+', '', 'g') as buyer,
      regexp_replace(lower(coalesce(p_title,'')), '[^a-z0-9]+', '', 'g') as title,
      coalesce((p_closing at time zone 'America/Toronto')::date::text, '') as closing_day
  )
  select case
    when title = '' then null
    else md5(buyer || '|' || title || '|' || closing_day)
  end
  from normalized;
$$;

revoke all on function public.procurement_canonical_key(text,text,timestamptz) from public, anon, authenticated;
grant execute on function public.procurement_canonical_key(text,text,timestamptz) to service_role;

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
          when coalesce(o.region,'') ~* '(ottawa|national capital|gatineau|outaouais)' then 18
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
      when o.closing_at is not null and o.closing_at < now() then 'expired'
      when coalesce(o.hard_blocker_count,0) > 0 then 'blocked'
      when o.bid_score >= 80 then 'pursue'
      when o.bid_score >= 60 then 'review'
      when o.bid_score >= 40 then 'monitor'
      else 'pass'
    end,
    auto_next_action = case
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
      when o.closing_at is not null and o.closing_at < now() then 'expired'
      when coalesce(o.hard_blocker_count,0) > 0 then 'blocked'
      when o.bid_score >= 80 then 'pursue'
      when o.bid_score >= 60 then 'review'
      when o.bid_score >= 40 then 'monitor'
      else 'pass'
    end,
    auto_next_action = case
      when o.closing_at is not null and o.closing_at < now()
        then 'Archive expired opportunity'
      when coalesce(o.hard_blocker_count,0) > 0
        then 'Resolve blocker: ' || coalesce(o.raw_payload->>'next_detected_requirement','mandatory qualification')
      when coalesce(o.qualification_gap_count,0) > 0
        then 'Resolve qualification gap: ' || coalesce(o.raw_payload->>'next_detected_requirement','mandatory qualification')
      else 'Review source and promote qualifying opportunity'
    end,
    auto_next_action_due_at = case
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

create or replace view public.v_procurement_source_health
with (security_invoker = true)
as
select
  s.workspace_id,
  s.source_key,
  s.display_name,
  s.source_url,
  s.ingestion_mode,
  s.coverage_tier,
  s.adapter_status,
  s.buyer_scope,
  s.last_run_at,
  s.last_success_at,
  s.last_error,
  s.last_verified_at,
  case
    when s.last_error is not null
      and (s.last_success_at is null or s.last_run_at > s.last_success_at) then 'failing'
    when s.last_success_at is null then 'never_scanned'
    when s.last_success_at < now() - interval '36 hours' then 'stale'
    else 'healthy'
  end as health_status,
  extract(epoch from (now() - coalesce(s.last_success_at,s.created_at)))/3600 as hours_since_success
from public.tender_sources s
where s.enabled;

grant select on public.v_procurement_source_health to authenticated;

create or replace view public.v_procurement_inbox
with (security_invoker = true)
as
with ranked as (
  select
    o.*,
    count(*) over (
      partition by o.workspace_id, coalesce(o.canonical_key,o.id::text)
    )::integer as duplicate_count,
    row_number() over (
      partition by o.workspace_id, coalesce(o.canonical_key,o.id::text)
      order by
        (o.promoted_tender_record_id is not null) desc,
        o.bid_score desc nulls last,
        o.last_seen_at desc,
        o.id
    ) as canonical_rank
  from public.procurement_opportunities o
  where o.closing_at is null or o.closing_at >= now()
)
select
  r.*,
  case
    when r.closing_at is not null
      and r.closing_at <= now() + interval '3 days'
      and r.bid_recommendation in ('blocked','pursue','review') then 'deadline'
    when r.qualification_gap_count > 0
      and r.bid_recommendation not in ('pass','expired') then 'qualification_gap'
    when r.bid_recommendation = 'pursue' then 'best_new'
    when r.bid_recommendation in ('review','blocked') then 'needs_review'
    when r.bid_recommendation = 'monitor' then 'watching'
    else 'archive'
  end as inbox_bucket
from ranked r
where r.canonical_rank = 1;

grant select on public.v_procurement_inbox to authenticated;

select public.refresh_procurement_sales_engine(null);

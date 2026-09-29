-- Keep suppressed procurement rows out of the actionable inbox and archive them explicitly.
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
  where (o.closing_at is null or o.closing_at >= now())
    and o.classification_status <> 'suppressed'
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

update public.procurement_opportunities
set
  bid_recommendation='pass',
  auto_next_action='Archive suppressed opportunity',
  auto_next_action_due_at=null,
  last_decision_at=now()
where classification_status='suppressed';

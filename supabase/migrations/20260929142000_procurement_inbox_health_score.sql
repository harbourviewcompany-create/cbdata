-- Procurement source health, canonical dedupe and explainable bid scoring.
alter table public.procurement_opportunities
  add column if not exists canonical_key text,
  add column if not exists bid_score numeric,
  add column if not exists bid_recommendation text,
  add column if not exists bid_score_breakdown jsonb not null default '{}'::jsonb;

create unique index if not exists procurement_opportunities_workspace_canonical_uidx
  on public.procurement_opportunities(workspace_id, canonical_key)
  where canonical_key is not null;

create index if not exists procurement_opportunities_inbox_idx
  on public.procurement_opportunities(workspace_id, bid_recommendation, bid_score desc, closing_at);

create or replace function public.procurement_canonical_key(p_buyer text,p_title text,p_closing timestamptz)
returns text language sql immutable parallel safe set search_path=''
as $$
 select md5(
   regexp_replace(lower(coalesce(p_buyer,'')), '[^a-z0-9]+', '', 'g') || '|' ||
   regexp_replace(lower(coalesce(p_title,'')), '[^a-z0-9]+', '', 'g') || '|' ||
   coalesce(p_closing::date::text,'')
 );
$$;

revoke all on function public.procurement_canonical_key(text,text,timestamptz) from public,anon,authenticated;
grant execute on function public.procurement_canonical_key(text,text,timestamptz) to service_role;

create or replace function private.refresh_procurement_decision_fields(p_workspace uuid default null)
returns integer language plpgsql security invoker set search_path=''
as $$
declare v_count integer;
begin
 update public.procurement_opportunities o
 set canonical_key=public.procurement_canonical_key(o.buyer_name,o.title,o.closing_at),
     bid_score=least(100,greatest(0,
       coalesce(o.relevance_score,0) * 0.55
       + case when o.region ilike '%ottawa%' or o.region ilike '%national capital%' or o.region ilike '%gatineau%' then 18 else 8 end
       + case when o.estimated_value is not null then 8 else 2 end
       + case when o.closing_at is null then 3 when o.closing_at >= now()+interval '7 days' then 10 when o.closing_at >= now()+interval '2 days' then 5 else -8 end
       + case when cardinality(o.service_fit)>=1 then 9 else 0 end
     )),
     bid_score_breakdown=jsonb_build_object(
       'trade_fit',coalesce(o.relevance_score,0),
       'region',coalesce(o.region,'unknown'),
       'value_known',o.estimated_value is not null,
       'service_matches',coalesce(cardinality(o.service_fit),0),
       'days_remaining',case when o.closing_at is null then null else floor(extract(epoch from (o.closing_at-now()))/86400) end
     )
 where (p_workspace is null or o.workspace_id=p_workspace);

 update public.procurement_opportunities o
 set bid_recommendation=case
   when o.closing_at is not null and o.closing_at<now() then 'expired'
   when o.bid_score>=80 then 'pursue'
   when o.bid_score>=60 then 'review'
   when o.bid_score>=40 then 'monitor'
   else 'pass'
 end
 where (p_workspace is null or o.workspace_id=p_workspace);
 get diagnostics v_count=row_count;
 return v_count;
end $$;

revoke all on function private.refresh_procurement_decision_fields(uuid) from public,anon,authenticated;
grant execute on function private.refresh_procurement_decision_fields(uuid) to service_role;

create or replace view public.v_procurement_source_health
with (security_invoker=true) as
select s.workspace_id,s.source_key,s.display_name,s.ingestion_mode,s.coverage_tier,s.adapter_status,
 s.last_run_at,s.last_success_at,s.last_error,
 case
   when s.last_error is not null and (s.last_success_at is null or s.last_run_at>s.last_success_at) then 'failing'
   when s.last_success_at is null then 'never_scanned'
   when s.last_success_at<now()-interval '36 hours' then 'stale'
   else 'healthy'
 end as health_status,
 extract(epoch from (now()-coalesce(s.last_success_at,s.created_at)))/3600 as hours_since_success
from public.tender_sources s where s.enabled;

grant select on public.v_procurement_source_health to authenticated;

create or replace view public.v_procurement_inbox
with (security_invoker=true) as
select o.*,
 case
   when o.closing_at is not null and o.closing_at<=now()+interval '3 days' and o.bid_recommendation in ('pursue','review') then 'deadline'
   when o.bid_recommendation='pursue' then 'best_new'
   when o.bid_recommendation='review' then 'needs_review'
   when o.bid_recommendation='monitor' then 'watching'
   else 'archive'
 end as inbox_bucket
from public.procurement_opportunities o
where o.closing_at is null or o.closing_at>=now();

grant select on public.v_procurement_inbox to authenticated;

select private.refresh_procurement_decision_fields(null);

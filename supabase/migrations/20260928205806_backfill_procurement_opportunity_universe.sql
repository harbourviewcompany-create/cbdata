-- Backfill the raw procurement universe from already-known tender records so the
-- coverage engine has immediate history before the next source scan.

insert into public.procurement_opportunities(
  workspace_id,source_key,external_id,buyer_key,buyer_name,title,opportunity_type,
  category,region,published_at,closing_at,estimated_value,currency,source_url,
  service_fit,relevance_score,classification_status,matched_organization_id,
  promoted_tender_record_id,raw_payload,first_seen_at,last_seen_at,created_at,updated_at
)
select
  t.workspace_id,
  coalesce(ts.source_key,lower(regexp_replace(t.source,'[^a-zA-Z0-9]+','_','g'))),
  t.external_id,
  b.buyer_key,
  t.buyer_name,
  t.title,
  case
    when lower(coalesce(t.response_mode,'')) like '%rfq%' then 'rfq'
    when lower(coalesce(t.response_mode,'')) like '%prequal%' then 'prequalification'
    when lower(coalesce(t.response_mode,'')) like '%standing%' then 'standing_offer'
    else 'tender'
  end,
  t.category,
  t.region,
  case when t.published_date is not null then (t.published_date::timestamp + time '12:00') at time zone 'America/Toronto' end,
  case when t.closing_date is not null then (t.closing_date::timestamp + time '23:59') at time zone 'America/Toronto' end,
  t.estimated_value,
  coalesce(t.currency,'CAD'),
  coalesce(t.source_url,'https://cbdata-three.vercel.app/procurement/'||t.id::text),
  case when nullif(t.watch_query,'') is null then '{}'::text[] else string_to_array(t.watch_query,', ') end,
  t.fit_score,
  'promoted',
  t.matched_organization_id,
  t.id,
  jsonb_build_object('backfilled_from','tender_records','tender_payload',t.raw_payload),
  coalesce(t.created_at,now()),
  coalesce(t.last_verified_at,t.updated_at,t.created_at,now()),
  coalesce(t.created_at,now()),
  now()
from public.tender_records t
left join public.tender_sources ts
  on ts.workspace_id=t.workspace_id and lower(ts.display_name)=lower(t.source)
left join public.procurement_buyers b
  on b.workspace_id=t.workspace_id and lower(b.display_name)=lower(coalesce(t.buyer_name,''))
on conflict(workspace_id,source_key,external_id) do update set
  buyer_key=coalesce(excluded.buyer_key,public.procurement_opportunities.buyer_key),
  buyer_name=coalesce(excluded.buyer_name,public.procurement_opportunities.buyer_name),
  title=excluded.title,
  category=excluded.category,
  region=excluded.region,
  published_at=excluded.published_at,
  closing_at=excluded.closing_at,
  estimated_value=excluded.estimated_value,
  source_url=excluded.source_url,
  relevance_score=coalesce(excluded.relevance_score,public.procurement_opportunities.relevance_score),
  matched_organization_id=coalesce(excluded.matched_organization_id,public.procurement_opportunities.matched_organization_id),
  promoted_tender_record_id=excluded.promoted_tender_record_id,
  last_seen_at=excluded.last_seen_at,
  updated_at=now();

update public.procurement_buyers b
set
  last_opportunity_at=x.last_opportunity_at,
  last_scanned_at=now(),
  organization_id=coalesce(b.organization_id,x.organization_id),
  updated_at=now()
from (
  select buyer_key,max(coalesce(published_at,first_seen_at)) as last_opportunity_at,
         max(matched_organization_id::text)::uuid as organization_id
  from public.procurement_opportunities
  where buyer_key is not null
  group by buyer_key
) x
where b.buyer_key=x.buyer_key;

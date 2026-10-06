-- Seed verified current opportunities using CBData's canonical bid recommendation vocabulary.

insert into public.procurement_opportunities(
  workspace_id,source_key,external_id,buyer_key,buyer_name,title,opportunity_type,
  description,category,region,published_at,source_url,service_fit,relevance_score,
  classification_status,score_breakdown,bid_score,bid_recommendation,bid_score_breakdown,
  auto_next_action,auto_next_action_due_at,raw_payload,last_seen_at,updated_at
)
select
  workspace_id,'supply_ontario_vor','tender-21454-rdbgc','supply-ontario','Supply Ontario',
  'Tender #21454 — Renovation, Demolition, Other Building and General Contractor Services EVOR',
  'vendor_roster',
  'Multi-vendor Enterprise Vendor of Record arrangement covering general contracting, renovations, building repairs and trade services across Ontario public-sector entities.',
  'Construction / renovation / building repairs','Ontario','2026-08-26T00:00:00Z'::timestamptz,
  'https://www.supplyontario.ca/news/call-for-vendors-renovation-demolition-other-building-and-general-contractor-services-rdbgc/',
  array['general_contracting','renovation','building_repairs','trade_services','building_envelope','emergency_response'],
  96,'actionable',
  jsonb_build_object('source_confidence','high','strategic_value','repeat_public_sector_access','verified_at',now()),
  94,'pursue',
  jsonb_build_object('fit',95,'repeat_work_potential',100,'geographic_fit',90,'qualification_value',100,'strategy_label','Pursue qualification'),
  'Open Ontario Tenders Portal and review Tender #21454 qualification requirements',
  now()+interval '1 day',
  jsonb_build_object('verified_source','Supply Ontario','tender_number','21454','opportunity_kind','EVOR qualification'),
  now(),now()
from (select distinct workspace_id from public.tender_sources) w
on conflict(workspace_id,source_key,external_id) do update set
  title=excluded.title,description=excluded.description,service_fit=excluded.service_fit,
  relevance_score=excluded.relevance_score,classification_status=excluded.classification_status,
  bid_score=excluded.bid_score,bid_recommendation=excluded.bid_recommendation,
  bid_score_breakdown=excluded.bid_score_breakdown,
  auto_next_action=excluded.auto_next_action,
  auto_next_action_due_at=least(coalesce(public.procurement_opportunities.auto_next_action_due_at,excluded.auto_next_action_due_at),excluded.auto_next_action_due_at),
  raw_payload=coalesce(public.procurement_opportunities.raw_payload,'{}'::jsonb)||excluded.raw_payload,
  last_seen_at=now(),updated_at=now();

insert into public.procurement_opportunities(
  workspace_id,source_key,external_id,buyer_key,buyer_name,title,opportunity_type,
  description,category,region,published_at,source_url,service_fit,relevance_score,
  classification_status,score_breakdown,bid_score,bid_recommendation,bid_score_breakdown,
  auto_next_action,auto_next_action_due_at,raw_payload,last_seen_at,updated_at
)
select
  workspace_id,'yow_bonfire','current-plumbing-services-maintenance-repairs-support',
  'ottawa-international-airport-authority','Ottawa International Airport Authority',
  'Plumbing Services, Maintenance, Repairs and Support','tender',
  'Current operational procurement opportunity listed by the Ottawa International Airport Authority.',
  'Facilities maintenance','Ottawa',now(),'https://www.yow.ca/business/procurement-opportunities',
  array['property_maintenance','facility_repairs','mechanical'],72,'watch',
  jsonb_build_object('source_confidence','high','verified_at',now()),
  68,'review',jsonb_build_object('fit',60,'relationship_value',85,'locality',100,'strategy_label','Review scope'),
  'Open YOW Bonfire opportunity and verify subcontractable scope',now()+interval '1 day',
  jsonb_build_object('verified_source','YOW procurement opportunities','current_listing',true),now(),now()
from (select distinct workspace_id from public.tender_sources) w
on conflict(workspace_id,source_key,external_id) do update set
  bid_recommendation=excluded.bid_recommendation,bid_score_breakdown=excluded.bid_score_breakdown,
  last_seen_at=now(),updated_at=now(),classification_status='watch',
  auto_next_action=excluded.auto_next_action,auto_next_action_due_at=excluded.auto_next_action_due_at;

insert into public.procurement_opportunities(
  workspace_id,source_key,external_id,buyer_key,buyer_name,title,opportunity_type,
  description,category,region,published_at,source_url,service_fit,relevance_score,
  classification_status,score_breakdown,bid_score,bid_recommendation,bid_score_breakdown,
  auto_next_action,auto_next_action_due_at,raw_payload,last_seen_at,updated_at
)
select
  workspace_id,'city_ottawa_standing_offers','rebid-roofing-maintenance-repairs-2026-10-31',
  'city-of-ottawa','City of Ottawa',
  'Rebid signal — Roofing Maintenance and Repairs standing offer expires October 31, 2026',
  'rebid_signal',
  'Current City construction standing-offer list shows Roofing Maintenance and Repairs expiring October 31, 2026.',
  'Building maintenance','Ottawa',now(),
  'https://ottawa.ca/en/business/procurement/standing-offers-client-unit/construction',
  array['building_repairs','roofing','property_maintenance'],90,'watch',
  jsonb_build_object('source_confidence','high','standing_offer_expiry','2026-10-31','verified_at',now()),
  88,'monitor',
  jsonb_build_object('fit',80,'timing',100,'repeat_work_potential',95,'locality',100,'strategy_label','Prepare for rebid'),
  'Identify City purchasing contact, incumbent vendors and expected roofing maintenance rebid',
  now()+interval '1 day',
  jsonb_build_object('standing_offer_expiry','2026-10-31','signal_type','contract_expiry'),now(),now()
from (select distinct workspace_id from public.tender_sources) w
on conflict(workspace_id,source_key,external_id) do update set
  bid_recommendation=excluded.bid_recommendation,bid_score_breakdown=excluded.bid_score_breakdown,
  last_seen_at=now(),updated_at=now(),classification_status='watch',
  auto_next_action=excluded.auto_next_action,auto_next_action_due_at=excluded.auto_next_action_due_at;

insert into public.procurement_opportunities(
  workspace_id,source_key,external_id,buyer_key,buyer_name,title,opportunity_type,
  description,category,region,published_at,source_url,service_fit,relevance_score,
  classification_status,score_breakdown,bid_score,bid_recommendation,bid_score_breakdown,
  auto_next_action,auto_next_action_due_at,raw_payload,last_seen_at,updated_at
)
select
  workspace_id,'city_ottawa_standing_offers','rebid-mechanical-piping-2026-12-31',
  'city-of-ottawa','City of Ottawa',
  'Rebid signal — Mechanical and Piping Supply and Installation Services expires December 31, 2026',
  'rebid_signal',
  'Current City construction standing-offer list shows Mechanical and Piping Supply and Installation Services expiring December 31, 2026.',
  'Mechanical / piping','Ottawa',now(),
  'https://ottawa.ca/en/business/procurement/standing-offers-client-unit/construction',
  array['mechanical','sheet_metal','facility_repairs'],94,'watch',
  jsonb_build_object('source_confidence','high','standing_offer_expiry','2026-12-31','verified_at',now()),
  92,'monitor',
  jsonb_build_object('fit',95,'timing',90,'repeat_work_potential',95,'locality',100,'strategy_label','Prepare for rebid'),
  'Identify City purchasing contact, incumbent vendors and expected mechanical/piping rebid',
  now()+interval '1 day',
  jsonb_build_object('standing_offer_expiry','2026-12-31','signal_type','contract_expiry'),now(),now()
from (select distinct workspace_id from public.tender_sources) w
on conflict(workspace_id,source_key,external_id) do update set
  bid_recommendation=excluded.bid_recommendation,bid_score_breakdown=excluded.bid_score_breakdown,
  last_seen_at=now(),updated_at=now(),classification_status='watch',
  auto_next_action=excluded.auto_next_action,auto_next_action_due_at=excluded.auto_next_action_due_at;

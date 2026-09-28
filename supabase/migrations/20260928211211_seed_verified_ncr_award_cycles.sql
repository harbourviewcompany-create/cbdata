-- Seed verified Ottawa/NCR award-cycle evidence from CanadaBuys award listings.
-- These rows intentionally omit incumbent when the listing evidence does not expose supplier identity.

do $$
declare w uuid;
begin
  select id into w from public.workspaces where slug='cb-contracting' limit 1;
  if w is null then return; end if;

  insert into public.procurement_awards(
    workspace_id,source_key,external_id,buyer_key,buyer_name,title,award_date,contract_end_date,
    expected_rebid_date,source_url,raw_payload
  ) values
  (w,'canadabuys','seed-southern-lands-maintenance-20260316','ncc','National Capital Commission',
    'Southern Lands Maintenance','2026-03-16','2031-03-31','2031-10-02'::date - 365,
    'https://canadabuys.canada.ca/en/tender-opportunities?current_tab=t&items_per_page=50&order=field_sortable_contract_amount&sort=desc&wbdisable=true&words=72102905',
    '{"evidence":"CanadaBuys award listing","service_fit":["grounds","landscaping"],"verified_on":"2026-09-28"}'::jsonb),
  (w,'canadabuys','seed-eastern-lands-maintenance-20240109','ncc','National Capital Commission',
    'EASTERN LANDS MAINTENANCE MANAGEMENT CONTRACT','2024-01-09','2031-03-31','2031-10-02'::date - 365,
    'https://canadabuys.canada.ca/en/tender-opportunities?current_tab=c&items_per_page=50&order=field_tender_contract_date_end_value&sort=desc&words=Swish+Maintenance+Limited',
    '{"evidence":"CanadaBuys award listing","service_fit":["grounds","facility maintenance"],"verified_on":"2026-09-28"}'::jsonb),
  (w,'canadabuys','seed-ej196-250700-award','pspc','Public Services and Procurement Canada',
    'EJ196-250700_CFSU Snow removal and Landscaping_NCR','2026-09-18','2027-04-30','2026-11-01',
    'https://canadabuys.canada.ca/en/tender-opportunities?current_tab=t&items_per_page=50&order=field_sortable_contract_amount&sort=desc&wbdisable=true&words=72102905',
    '{"evidence":"CanadaBuys award listing","service_fit":["snow","landscaping"],"verified_on":"2026-09-28"}'::jsonb),
  (w,'canadabuys','seed-ej196-250628-award','pspc','Public Services and Procurement Canada',
    'EJ196-250628_East End Snow removal and Landscaping_NCR','2026-03-06','2027-04-30','2026-11-01',
    'https://canadabuys.canada.ca/en/tender-opportunities?current_tab=t&items_per_page=50&order=field_sortable_contract_amount&sort=desc&wbdisable=true&words=72102905',
    '{"evidence":"CanadaBuys award listing","service_fit":["snow","landscaping"],"verified_on":"2026-09-28"}'::jsonb),
  (w,'canadabuys','seed-ej196-230671-award','pspc','Public Services and Procurement Canada',
    'AMD 006_NDMC - Grounds - EJ196-230671','2026-07-14','2027-04-30','2026-11-01',
    'https://canadabuys.canada.ca/en/tender-opportunities?current_tab=c&items_per_page=50&order=field_term_label_1_1&sort=asc&words=Caltrio',
    '{"evidence":"CanadaBuys award listing","service_fit":["grounds"],"verified_on":"2026-09-28"}'::jsonb),
  (w,'canadabuys','seed-ej196-241349-award','pspc','Public Services and Procurement Canada',
    'EJ196-241349_AMD 003_Janitorial Services 181 Queen_NCR','2026-08-28','2027-06-30','2027-01-01',
    'https://canadabuys.canada.ca/en/tender-opportunities?current_tab=t&items_per_page=50&order=field_award_contract_number&sort=asc&wbdisable=false&words=76110000',
    '{"evidence":"CanadaBuys award listing","service_fit":["janitorial"],"verified_on":"2026-09-28"}'::jsonb),
  (w,'canadabuys','seed-ej196-211887-award','pspc','Public Services and Procurement Canada',
    'EJ196-211887_Amend 010_Janitorial Services for Crown NDMC building','2026-07-23','2027-07-31','2027-02-01',
    'https://canadabuys.canada.ca/en/tender-opportunities?current_tab=t&items_per_page=50&order=field_award_contract_number&sort=asc&wbdisable=false&words=76110000',
    '{"evidence":"CanadaBuys award listing","service_fit":["janitorial"],"verified_on":"2026-09-28"}'::jsonb),
  (w,'canadabuys','seed-ottawa-hospital-tree-planting-20230619','ottawa-hospital','The Ottawa Hospital',
    'Tree Planting Services','2023-06-19','2026-07-19','2026-01-20',
    'https://canadabuys.canada.ca/en/tender-opportunities?current_tab=c&items_per_page=50&order=field_term_label_1_1&sort=asc&words=Caltrio',
    '{"evidence":"CanadaBuys award listing","service_fit":["landscaping","grounds"],"verified_on":"2026-09-28"}'::jsonb)
  on conflict(workspace_id,source_key,external_id) do update set
    buyer_key=excluded.buyer_key,
    buyer_name=excluded.buyer_name,
    title=excluded.title,
    award_date=excluded.award_date,
    contract_end_date=excluded.contract_end_date,
    expected_rebid_date=excluded.expected_rebid_date,
    source_url=excluded.source_url,
    raw_payload=excluded.raw_payload,
    updated_at=now();

  perform private.refresh_procurement_contract_cycles();
end $$;

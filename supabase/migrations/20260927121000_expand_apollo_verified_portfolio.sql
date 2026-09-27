-- Apollo CI portfolio enrichment. Source: https://apollocicondomanagement.com/properties/
-- Production data was seeded from the official portfolio and is intentionally idempotent.
-- This migration records the portfolio source; property rows are keyed by canonical name/address.
insert into public.property_intelligence_sources(workspace_id,property_id,source_type,source_url,source_title,summary,confidence)
select p.workspace_id,p.id,'official_website','https://apollocicondomanagement.com/properties/','Apollo CI Condo Management portfolio',
       'Official Apollo CI portfolio identifies the condominium corporation, unit count and property type.','high'
from public.properties p
where p.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
and p.management_organization_id='044a899b-e5ba-4ca7-a7f9-1c78f11ec3e7'::uuid
and p.name in (
'OCSCC 735 — 179 George St.','OCSCC 829 — 324 Laurier Avenue','OCSCC 893 — 808 Bronson Avenue',
'OCSCC 994 — 2785 Baseline Road','CCC 286 — 275 Charlotte Street','OCSCC 1020 — 2 The Parkway',
'OCSCC 725 — 205 Bolton St.','CCC 498 — 40 Landry','OCSCC 1004 — 10 Rosemount Ave',
'OCSCC 1007 — 315 Terravita Pvt.','OCSCC 931 — 300 Lisgar Street','CCC 476 — 35 & 45 Holland Ave',
'OCLCC 973 — 428 Sparks St.','CCC 15 — 158B McArthur Ave.','CCC 12 — 158A McArthur Ave.','CCC 47 — 158C McArthur Ave.'
)
and not exists(select 1 from public.property_intelligence_sources s where s.property_id=p.id and s.source_url='https://apollocicondomanagement.com/properties/');
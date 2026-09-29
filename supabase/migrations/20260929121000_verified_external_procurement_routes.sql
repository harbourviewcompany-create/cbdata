-- Record verified procurement routes that are not yet directly parsed by CBData.
-- These remain external_watch/partial until an authenticated or stable public ingestion path is implemented.

insert into public.tender_sources (
  workspace_id, source_key, display_name, source_url, ingestion_mode, enabled, created_at, updated_at
)
select w.id, s.source_key, s.display_name, s.source_url, 'external_watch', true, now(), now()
from public.workspaces w
cross join (values
  ('ottawa_hospital_medbuy','Ottawa Hospital / Mohawk Medbuy Biddingo','https://www.biddingo.com/medbuy'),
  ('royal_biddingo','The Royal / Biddingo','https://www.biddingo.com/'),
  ('sto_seao','STO / SEAO','https://www.seao.ca/'),
  ('cisss_outaouais_seao','CISSS de l''Outaouais / SEAO','https://www.seao.ca/'),
  ('cecce_merx_watch','CECCE / MERX','https://www.merx.com/'),
  ('cepeo_procurement_watch','CEPEO procurement notices','https://cepeo.on.ca/services/services-a-la-communaute/appels-doffres/')
) as s(source_key,display_name,source_url)
on conflict(workspace_id,source_key) do update
set display_name=excluded.display_name,
    source_url=excluded.source_url,
    ingestion_mode='external_watch',
    enabled=true,
    updated_at=now();

update public.procurement_buyers
set primary_source_key='ottawa_hospital_medbuy',
    portal_url='https://www.biddingo.com/medbuy',
    coverage_status='partial',
    updated_at=now()
where buyer_key='ottawa-hospital';

update public.procurement_buyers
set primary_source_key='royal_biddingo',
    portal_url='https://www.biddingo.com/',
    coverage_status='partial',
    updated_at=now()
where buyer_key='royal-ottawa';

update public.procurement_buyers
set primary_source_key='sto_seao',
    portal_url='https://www.seao.ca/',
    coverage_status='partial',
    updated_at=now()
where buyer_key='sto';

update public.procurement_buyers
set primary_source_key='cisss_outaouais_seao',
    portal_url='https://www.seao.ca/',
    coverage_status='partial',
    updated_at=now()
where buyer_key='cisss-outaouais';

update public.procurement_buyers
set primary_source_key='cecce_merx_watch',
    portal_url='https://www.merx.com/',
    coverage_status='partial',
    updated_at=now()
where buyer_key='cecce';

update public.procurement_buyers
set primary_source_key='cepeo_procurement_watch',
    portal_url='https://cepeo.on.ca/services/services-a-la-communaute/appels-doffres/',
    coverage_status='partial',
    updated_at=now()
where buyer_key='cepeo';

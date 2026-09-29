-- Promote verified Ottawa institutional procurement portals into first-class coverage.

insert into public.tender_sources (
  workspace_id, source_key, display_name, source_url, ingestion_mode, enabled, created_at, updated_at
)
select w.id, s.source_key, s.display_name, s.source_url, 'live', true, now(), now()
from public.workspaces w
cross join (values
  ('uottawa_merx','University of Ottawa / MERX','https://www.merx.com/oupma/uottawa/solicitations/open-bids'),
  ('carleton_merx','Carleton University / MERX','https://www.merx.com/oupma/carleton/solicitations/open-bids'),
  ('algonquin_merx','Algonquin College / MERX','https://www.merx.com/algonquincollege/solicitations/open-bids'),
  ('montfort_merx','Hôpital Montfort / MERX','https://www.merx.com/hopitalmontfort/solicitations/open-bids'),
  ('lacite_merx','La Cité / MERX','https://www.merx.com/lacitecollegiale/solicitations/open-bids'),
  ('bruyere_merx','Bruyère / MERX','https://www.merx.com/bruyerecontinuingcare/solicitations/open-bids')
) as s(source_key,display_name,source_url)
on conflict(workspace_id,source_key) do update
set display_name=excluded.display_name,
    source_url=excluded.source_url,
    ingestion_mode='live',
    enabled=true,
    updated_at=now();

update public.procurement_buyers
set primary_source_key='uottawa_merx',
    portal_url='https://www.merx.com/oupma/uottawa/solicitations/open-bids',
    coverage_status='monitored',
    updated_at=now()
where buyer_key='uottawa';

update public.procurement_buyers
set primary_source_key='carleton_merx',
    portal_url='https://www.merx.com/oupma/carleton/solicitations/open-bids',
    coverage_status='monitored',
    updated_at=now()
where buyer_key='carleton';

update public.procurement_buyers
set primary_source_key='algonquin_merx',
    portal_url='https://www.merx.com/algonquincollege/solicitations/open-bids',
    coverage_status='monitored',
    updated_at=now()
where buyer_key='algonquin';

update public.procurement_buyers
set primary_source_key='montfort_merx',
    portal_url='https://www.merx.com/hopitalmontfort/solicitations/open-bids',
    coverage_status='monitored',
    updated_at=now()
where buyer_key='montfort';

update public.procurement_buyers
set primary_source_key='lacite_merx',
    portal_url='https://www.merx.com/lacitecollegiale/solicitations/open-bids',
    coverage_status='monitored',
    updated_at=now()
where buyer_key='la-cite';

update public.procurement_buyers
set primary_source_key='bruyere_merx',
    portal_url='https://www.merx.com/bruyerecontinuingcare/solicitations/open-bids',
    coverage_status='monitored',
    updated_at=now()
where buyer_key='bruyere';

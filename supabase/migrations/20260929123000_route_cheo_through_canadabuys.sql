update public.procurement_buyers
set primary_source_key='canadabuys',
    portal_url='https://canadabuys.canada.ca/en/tender-opportunities?current_tab=c&words=CHEO',
    coverage_status='monitored',
    updated_at=now()
where buyer_key='cheo';

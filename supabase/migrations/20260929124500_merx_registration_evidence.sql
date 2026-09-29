update public.supplier_registrations
set evidence_url='https://www.merx.com/public/user-registration?language=EN',
    notes='One MERX supplier account can provide access to multiple MERX-hosted buyer portals. Confirm CB Contracting account/subscription and electronic bid access.',
    updated_at=now()
where source_key='city_merx';

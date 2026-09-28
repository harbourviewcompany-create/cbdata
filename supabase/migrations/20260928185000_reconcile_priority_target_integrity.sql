-- Reconcile existing production rows with the evidence model introduced by this PR.
-- Idempotent and scoped to CB Contracting + records created/enriched by these migrations.

do $$
declare
  v_workspace uuid := '431aa13d-3e7c-41e3-9686-e840b8ea5b7c';
  v_org uuid;
begin
  -- Existing Michael Morin row predates contact provenance. Enrich it in place.
  update public.contacts
  set job_title='Director of Commercial Properties',
      phone=coalesce(nullif(phone,''),'613-759-8383'),
      source_url='https://www.districtrealty.com/about-us/team/',
      source_label='District Realty official team page',
      source_confidence='high',
      source_verified_at=coalesce(source_verified_at,now()),
      notes=case
        when coalesce(notes,'') ilike '%contract management%' then notes
        else concat_ws(E'\n',notes,'District team page states Michael manages daily operations of a significant commercial portfolio, tenant/base-building fit-ups and contract management.')
      end,
      updated_at=now()
  where workspace_id=v_workspace
    and lower(coalesce(email,''))='michaelmorin@districtrealty.com';

  -- District inventory pages can be brokerage assignments. Direct target links remain,
  -- but the organization-level management FK must not imply an unverified relationship.
  select id into v_org from public.organizations
  where workspace_id=v_workspace and coalesce(operating_name,legal_name)='District Realty' limit 1;
  if v_org is not null then
    update public.organizations
    set buildings_managed=coalesce(buildings_managed,60),
        source_notes=coalesce(source_notes,
          'First-party sources report 60+ Ottawa buildings and more than 3M sq ft of commercial management. Michael Morin oversees commercial operations, fit-ups and contract management.')
    where id=v_org;

    update public.properties
    set management_organization_id=null
    where workspace_id=v_workspace and name like 'District — %'
      and management_organization_id=v_org;

    update public.outreach_targets
    set score=greatest(coalesce(score,0),99), priority='high',
        score_reason='Tier-1 portfolio account: 60+ buildings, >3M commercial sq ft, documented contract-management capability and a verified Director of Commercial Properties.',
        next_action='Email Michael Morin, then call head office: request vendor qualification for snow/grounds/janitorial and identify three managed properties where service contracts are being tendered, benchmarked or reviewed.',
        updated_at=now()
    where workspace_id=v_workspace and organization_id=v_org;
  end if;

  -- Regional: only 150 Slater has explicit acquisition + operational-oversight evidence
  -- in this PR. Featured-project pages alone do not prove ownership/management.
  select id into v_org from public.organizations
  where workspace_id=v_workspace and coalesce(operating_name,legal_name)='Regional Group' limit 1;
  if v_org is not null then
    update public.organizations
    set doors_managed=coalesce(doors_managed,2000),
        source_notes=coalesce(source_notes,
          'Official sources describe a large Ottawa-Gatineau real-estate platform. Property management covers repairs, maintenance, daily operations, capital expenditures and building-service tendering.')
    where id=v_org;

    update public.properties
    set owner_organization_id=case when name='Regional — 150 Slater Street' then v_org else null end,
        management_organization_id=case when name='Regional — 150 Slater Street' then v_org else null end
    where workspace_id=v_workspace and name like 'Regional — %';

    update public.outreach_targets
    set score=greatest(coalesce(score,0),98), priority='high',
        score_reason='Tier-1 Ottawa-Gatineau portfolio with explicit repairs, maintenance, capital-expenditure and building-service tendering capability.',
        next_action='Call property management: identify vendor onboarding ownership and current snow/grounds/janitorial tender windows; use 150 Slater as the first acquisition-transition discovery point.',
        updated_at=now()
    where workspace_id=v_workspace and organization_id=v_org;
  end if;

  select id into v_org from public.organizations
  where workspace_id=v_workspace and coalesce(operating_name,legal_name)='Merkburn Holdings' limit 1;
  if v_org is not null then
    update public.outreach_targets
    set score=greatest(coalesce(score,0),96), priority='high',
        score_reason='Tier-1 commercial/industrial owner-manager with documented bid oversight and maintenance-contract administration.',
        next_action='Call property management: request approved-vendor routing and identify industrial/warehouse sites where winter access, loading areas or exterior maintenance are being competitively bid.',
        updated_at=now()
    where workspace_id=v_workspace and organization_id=v_org;
  end if;

  -- Minto residential REIT properties are useful account intelligence, but they are not
  -- asserted as managed by the Minto Commercial organization record.
  select id into v_org from public.organizations
  where workspace_id=v_workspace and coalesce(operating_name,legal_name)='Minto Commercial' limit 1;
  if v_org is not null then
    update public.properties
    set management_organization_id=null
    where workspace_id=v_workspace
      and name in ('Minto — one80five','Minto — Aventura','Minto — Parkwood Hills','Minto — Skyline')
      and management_organization_id=v_org;

    update public.outreach_targets
    set score=greatest(coalesce(score,0),97), priority='high',
        score_reason='High-value Ottawa commercial owner/operator; external service opportunity depends on make-vs-buy by property and category.',
        updated_at=now()
    where workspace_id=v_workspace and organization_id=v_org;
  end if;

  select id into v_org from public.organizations
  where workspace_id=v_workspace and coalesce(operating_name,legal_name)='CLV Group' limit 1;
  if v_org is not null then
    update public.organizations
    set source_notes=coalesce(source_notes,
      'Official CLV sources describe an integrated acquisition, development, construction and property-management platform with property managers coordinating maintenance, renovation work and vendor relationships.')
    where id=v_org;

    update public.outreach_targets
    set score=greatest(coalesce(score,0),99), priority='high',
        score_reason='Tier-1 Ottawa portfolio with active acquisitions/development and documented property-management responsibility for maintenance and vendor coordination.',
        updated_at=now()
    where workspace_id=v_workspace and organization_id=v_org;
  end if;

  -- Recompute evidence scores consistently. The same effective score controls both the
  -- score column and priority thresholds; this fixes the earlier formula drift.
  with metrics as (
    select
      t.id,
      count(distinct case when pi.intelligence_score >= 80 then otp.property_id end) as high_signal_properties,
      count(distinct case when pis.confidence='high' then pis.id end) as evidence_count,
      count(distinct case when tos.status='open' then tos.id end) as open_signals,
      bool_or(coalesce(pi.procurement_signal,'') <> '' or coalesce(pi.vendor_signal,'') <> '') as has_buying_route,
      bool_or(coalesce(pi.snow_scope,'') <> '') as has_snow,
      bool_or(coalesce(pi.grounds_scope,'') <> '') as has_grounds,
      bool_or(coalesce(pi.janitorial_scope,'') <> '') as has_janitorial
    from public.outreach_targets t
    left join public.outreach_target_properties otp
      on otp.outreach_target_id=t.id and otp.workspace_id=t.workspace_id
    left join public.property_intelligence pi
      on pi.property_id=otp.property_id and pi.workspace_id=t.workspace_id
    left join public.property_intelligence_sources pis
      on pis.property_id=otp.property_id and pis.workspace_id=t.workspace_id
    left join public.target_opportunity_signals tos
      on tos.workspace_id=t.workspace_id and tos.status='open'
      and (tos.target_id=t.id or tos.property_id=otp.property_id or tos.organization_id=t.organization_id)
    where t.workspace_id=v_workspace and t.status in ('queued','contacted','responded')
    group by t.id
  ), scored as (
    select t.id,
      greatest(coalesce(t.score,0), least(100,
        35
        + case when t.contact_id is not null then 15 when nullif(t.contact_name,'') is not null then 8 else 0 end
        + case when nullif(t.email,'') is not null then 7 else 0 end
        + case when nullif(t.phone,'') is not null then 5 else 0 end
        + least(15,m.high_signal_properties*3)
        + least(8,m.evidence_count*2)
        + least(10,m.open_signals*5)
        + case when m.has_buying_route then 5 else 0 end
        + case when m.has_snow and m.has_grounds then 4 when m.has_snow or m.has_grounds then 2 else 0 end
        + case when m.has_janitorial then 2 else 0 end
      ))::numeric as effective_score
    from public.outreach_targets t join metrics m on m.id=t.id
  )
  update public.outreach_targets t
  set score=s.effective_score,
      priority=case
        when s.effective_score >= 85 then 'high'::work_priority
        when s.effective_score >= 65 then 'medium'::work_priority
        else t.priority
      end,
      updated_at=now()
  from scored s where s.id=t.id;
end $$;

-- Verified procurement contacts + supplier registration readiness for active PSPC pursuits.

alter table public.procurement_future_opportunities
  add column if not exists pursuit_contact_id uuid references public.contacts(id) on delete set null;

create index if not exists procurement_future_pursuit_contact_idx
  on public.procurement_future_opportunities(pursuit_contact_id);

do $$
declare
  w uuid;
  org uuid;
  shauna uuid;
  leticia uuid;
begin
  select id into w from public.workspaces where slug='cb-contracting' limit 1;
  if w is null then return; end if;

  select organization_id into org
  from public.procurement_buyers
  where workspace_id=w and buyer_key='pspc'
  limit 1;

  if org is null then
    raise exception 'PSPC procurement buyer is not linked to an organization';
  end if;

  select id into shauna
  from public.contacts
  where workspace_id=w and lower(email)=lower('shauna.barrett@tpsgc-pwgsc.gc.ca')
  limit 1;

  if shauna is null then
    insert into public.contacts(
      workspace_id,first_name,last_name,job_title,email,status,notes,
      source_url,source_label,source_confidence,source_verified_at
    ) values (
      w,'Shauna','Barrett','Contracting Authority — PSPC','shauna.barrett@tpsgc-pwgsc.gc.ca','active',
      'Verified contracting authority on multiple PSPC NCR grounds and janitorial contract histories.',
      'https://canadabuys.canada.ca/en/tender-opportunities/contract-history/cw2296074-005',
      'CanadaBuys contract history','high',now()
    ) returning id into shauna;
  else
    update public.contacts set
      job_title='Contracting Authority — PSPC',
      source_url='https://canadabuys.canada.ca/en/tender-opportunities/contract-history/cw2296074-005',
      source_label='CanadaBuys contract history',
      source_confidence='high',
      source_verified_at=now(),
      updated_at=now()
    where id=shauna;
  end if;

  select id into leticia
  from public.contacts
  where workspace_id=w and lower(email)=lower('leticia.obeng-asante@tpsgc-pwgsc.gc.ca')
  limit 1;

  if leticia is null then
    insert into public.contacts(
      workspace_id,first_name,last_name,job_title,email,status,notes,
      source_url,source_label,source_confidence,source_verified_at
    ) values (
      w,'Leticia','Obeng-Asante','Contracting Authority — PSPC','leticia.obeng-asante@tpsgc-pwgsc.gc.ca','active',
      'Verified contracting authority for PSPC CFSU Uplands snow removal and landscaping contract.',
      'https://canadabuys.canada.ca/en/tender-opportunities/contract-history/cw2389146-009',
      'CanadaBuys contract history','high',now()
    ) returning id into leticia;
  else
    update public.contacts set
      job_title='Contracting Authority — PSPC',
      source_url='https://canadabuys.canada.ca/en/tender-opportunities/contract-history/cw2389146-009',
      source_label='CanadaBuys contract history',
      source_confidence='high',
      source_verified_at=now(),
      updated_at=now()
    where id=leticia;
  end if;

  insert into public.organization_contacts(
    workspace_id,organization_id,contact_id,relationship_type,is_primary,start_date
  ) values
    (w,org,shauna,'procurement_contracting_authority',true,current_date),
    (w,org,leticia,'procurement_contracting_authority',false,current_date)
  on conflict(organization_id,contact_id,relationship_type) do update
    set end_date=null;

  update public.procurement_future_opportunities
  set pursuit_contact_id=shauna, updated_at=now()
  where workspace_id=w and (
    title ilike '%NDMC - Grounds - EJ196-230671%'
    or title ilike '%East End Snow removal and Landscaping%'
    or title ilike '%Janitorial Services 181 Queen%'
    or title ilike '%Janitorial Services for Crown NDMC%'
  );

  update public.procurement_future_opportunities
  set pursuit_contact_id=leticia, updated_at=now()
  where workspace_id=w and title ilike '%CFSU Snow removal and Landscaping%';

  update public.procurement_buyers
  set
    registration_url='https://canadabuys.canada.ca/en/notification-ariba-registration',
    metadata=coalesce(metadata,'{}'::jsonb) || jsonb_build_object(
      'supplier_registration','SAP Business Network / Government of Canada questionnaire',
      'registration_evidence_url','https://canadabuys.canada.ca/en/support/registering-sap-ariba-viewer',
      'registration_verified_at',now()
    ),
    updated_at=now()
  where workspace_id=w and buyer_key='pspc';

  insert into public.supplier_registrations(
    workspace_id,source_key,registration_name,status,evidence_url,notes
  ) values (
    w,'canadabuys','SAP Business Network — Government of Canada','required',
    'https://canadabuys.canada.ca/en/support/registering-sap-ariba-viewer',
    'CanadaBuys requires an SAP Business Network account and Government of Canada customer-requested questionnaire to access PSPC tender opportunities. CB Contracting account completion/status has not yet been independently verified.'
  )
  on conflict(workspace_id,source_key,registration_name) do update
    set status=case
      when supplier_registrations.status in ('active','in_progress') then supplier_registrations.status
      else 'required'
    end,
    evidence_url=excluded.evidence_url,
    notes=excluded.notes,
    updated_at=now();

  -- Current incumbent and contract-value evidence from CanadaBuys contract history.
  update public.procurement_awards set
    awarded_to='Caltrio Company Ltd',award_amount=994693.12,
    source_url='https://canadabuys.canada.ca/en/tender-opportunities/contract-history/cw2296074-005',
    updated_at=now()
  where workspace_id=w and title ilike '%NDMC - Grounds - EJ196-230671%';

  update public.procurement_awards set
    awarded_to='Caltrio Company Ltd',award_amount=668666.20,
    source_url='https://canadabuys.canada.ca/en/tender-opportunities/contract-history/cw2378970-001',
    updated_at=now()
  where workspace_id=w and title ilike '%East End Snow removal and Landscaping%';

  update public.procurement_awards set
    awarded_to='Caltrio Company Ltd',award_amount=2644812.57,
    source_url='https://canadabuys.canada.ca/en/tender-opportunities/contract-history/cw2389146-009',
    updated_at=now()
  where workspace_id=w and title ilike '%CFSU Snow removal and Landscaping%';

  update public.procurement_awards set
    awarded_to='Papasay Bee-Clean GP LTD.',award_amount=1590086.10,
    source_url='https://canadabuys.canada.ca/en/tender-opportunities/contract-history/cw2346628-002',
    updated_at=now()
  where workspace_id=w and title ilike '%Janitorial Services 181 Queen%';

  update public.procurement_awards set
    awarded_to='Conciergerie SPEICO Inc.',award_amount=1624319.54,
    source_url='https://canadabuys.canada.ca/en/tender-opportunities/contract-history/cw2250938-005',
    updated_at=now()
  where workspace_id=w and title ilike '%Janitorial Services for Crown NDMC%';

  update public.procurement_contract_cycles c
  set
    incumbent_name=a.awarded_to,
    award_value=a.award_amount,
    evidence_url=a.source_url,
    last_verified_at=now(),
    updated_at=now()
  from public.procurement_awards a
  where c.workspace_id=w
    and a.workspace_id=c.workspace_id
    and lower(a.title)=lower(c.contract_title);

  perform private.refresh_procurement_pursuits();

  -- Re-apply contract-specific contacts after the generic pursuit refresh.
  update public.procurement_future_opportunities
  set pursuit_contact_id=shauna,contact_readiness_status='ready',updated_at=now()
  where workspace_id=w and (
    title ilike '%NDMC - Grounds - EJ196-230671%'
    or title ilike '%East End Snow removal and Landscaping%'
    or title ilike '%Janitorial Services 181 Queen%'
    or title ilike '%Janitorial Services for Crown NDMC%'
  );

  update public.procurement_future_opportunities
  set pursuit_contact_id=leticia,contact_readiness_status='ready',updated_at=now()
  where workspace_id=w and title ilike '%CFSU Snow removal and Landscaping%';

  update public.outreach_targets ot
  set
    contact_id=shauna,
    contact_name='Shauna Barrett',
    email='shauna.barrett@tpsgc-pwgsc.gc.ca',
    next_action='Complete or verify CanadaBuys SAP Business Network supplier registration, then begin pre-position outreach to the verified PSPC contracting authority',
    updated_at=now()
  from public.outreach_lists ol
  where ot.outreach_list_id=ol.id
    and ol.workspace_id=w
    and ol.name='Procurement Pre-Position'
    and ot.organization_id=org;
end $$;

drop view if exists public.v_procurement_pursuit_queue;
create view public.v_procurement_pursuit_queue
with (security_invoker = true)
as
select
  f.id,f.workspace_id,f.buyer_name,f.title,f.service_category,
  f.expected_publish_start,f.expected_publish_end,f.fit_score,f.confidence,f.status,
  f.pursuit_priority,f.contact_readiness_status,f.vendor_readiness_status,
  f.next_action,f.next_action_at,f.target_id,f.owner_user_id,f.routed_at,f.source_url,
  f.pursuit_contact_id,
  concat_ws(' ',pc.first_name,pc.last_name) as pursuit_contact_name,
  pc.job_title as pursuit_contact_title,
  pc.email as pursuit_contact_email,
  pc.phone as pursuit_contact_phone,
  pc.source_url as pursuit_contact_source_url,
  pc.source_verified_at as pursuit_contact_verified_at,
  c.contract_title,c.incumbent_name,c.award_value,c.currency,c.contract_end_date,c.expected_rebid_date,
  b.buyer_key,b.primary_source_key,b.coverage_status,b.watch_priority,b.registration_url,
  coalesce(contact_stats.known_contact_count,0)::integer as known_contact_count,
  sr.status as supplier_registration_status,
  sr.expires_on as supplier_registration_expires_on,
  sr.evidence_url as supplier_registration_evidence_url
from public.procurement_future_opportunities f
left join public.procurement_contract_cycles c on c.id=f.contract_cycle_id
left join public.procurement_buyers b
  on b.workspace_id=f.workspace_id
 and (b.organization_id=f.organization_id or lower(b.display_name)=lower(f.buyer_name))
left join public.contacts pc on pc.id=f.pursuit_contact_id
left join lateral (
  select count(*)::integer as known_contact_count
  from public.organization_contacts oc
  where oc.workspace_id=f.workspace_id
    and oc.organization_id=f.organization_id
    and oc.end_date is null
) contact_stats on true
left join lateral (
  select x.status,x.expires_on,x.evidence_url
  from public.supplier_registrations x
  where x.workspace_id=f.workspace_id and x.source_key=b.primary_source_key
  order by x.updated_at desc
  limit 1
) sr on true;

grant select on public.v_procurement_pursuit_queue to authenticated;

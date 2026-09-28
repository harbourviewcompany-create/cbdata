-- Optimize the full BD queue and add three high-value Ottawa portfolio accounts.
-- Evidence checked 2026-09-28 against first-party organization sources.
-- This migration deliberately separates evidence quality from pursuit priority.

do $$
declare
  v_workspace uuid := '431aa13d-3e7c-41e3-9686-e840b8ea5b7c';
  v_list uuid := 'a15af411-9b05-4b7b-9e5b-9da4909b1dcf';
  v_org uuid;
begin
  -- District Realty: 60+ Ottawa buildings; commercial management page reports >3M sf.
  insert into public.organizations(
    workspace_id,legal_name,operating_name,organization_type,status,website,phone,email,
    primary_region,service_regions,hq_city,hq_province,hq_address_line_1,buildings_managed,source_notes
  )
  select v_workspace,'District Realty Corporation','District Realty','property_manager','active',
    'https://www.districtrealty.com','613-759-8383','district@districtrealty.com',
    'Ottawa',array['Ottawa'],'Ottawa','ON','20 James St, Suite 100',60,
    'First-party sources report 60+ Ottawa buildings and more than 3M sq ft of commercial management. District says its managers negotiate tender contracts regularly. Michael Morin is Director of Commercial Properties and oversees daily operations, fit-ups and contract management.'
  where not exists(select 1 from public.organizations where workspace_id=v_workspace and coalesce(operating_name,legal_name)='District Realty');

  select id into v_org from public.organizations where workspace_id=v_workspace and coalesce(operating_name,legal_name)='District Realty' limit 1;
  insert into public.outreach_targets(
    workspace_id,outreach_list_id,organization_name,contact_name,phone,email,property_address,status,
    organization_id,region,score,score_reason,next_action,priority,notes,company_phone,company_email,company_website,company_address
  )
  select v_workspace,v_list,'District Realty','Michael Morin','613-759-8383','michaelmorin@districtrealty.com','Ottawa','queued',
    v_org,'Ottawa',99,
    'Tier-1 portfolio account: 60+ buildings, >3M commercial sq ft, documented tender-contract activity and a named Director of Commercial Properties responsible for contract management.',
    'Email Michael Morin, then call head office: request vendor qualification for snow/grounds/janitorial and identify 3 properties where District is tendering or reviewing service contracts.',
    'high','Best first message: portfolio-level backup/overflow and competitive tender capability; ask for one property walk rather than a portfolio-wide award.',
    '613-759-8383','district@districtrealty.com','https://www.districtrealty.com','20 James St, Suite 100, Ottawa, ON'
  where not exists(select 1 from public.outreach_targets where workspace_id=v_workspace and organization_id=v_org);

  insert into public.contacts(workspace_id,first_name,last_name,job_title,email,phone,status,notes,source_url,source_label,source_confidence,source_verified_at)
  select v_workspace,'Michael','Morin','Director of Commercial Properties','michaelmorin@districtrealty.com','613-759-8383','active',
    'District team page states Michael manages daily operations of a significant commercial portfolio, tenant/base-building fit-ups and contract management.',
    'https://www.districtrealty.com/about-us/team/','District Realty official team page','high',now()
  where not exists(select 1 from public.contacts where workspace_id=v_workspace and first_name='Michael' and last_name='Morin' and email='michaelmorin@districtrealty.com');

  insert into public.organization_contacts(workspace_id,organization_id,contact_id,relationship_type,is_primary)
  select v_workspace,v_org,c.id,'commercial_operations',true from public.contacts c
  where c.workspace_id=v_workspace and c.email='michaelmorin@districtrealty.com'
    and not exists(select 1 from public.organization_contacts oc where oc.organization_id=v_org and oc.contact_id=c.id);

  update public.outreach_targets t set contact_id=c.id, contact_name='Michael Morin', phone='613-759-8383',
    email='michaelmorin@districtrealty.com', updated_at=now()
  from public.contacts c where t.workspace_id=v_workspace and t.organization_id=v_org
    and c.workspace_id=v_workspace and c.email='michaelmorin@districtrealty.com';

  -- Regional Group: 2,000+ residential units + 2.3M sf commercial/industrial/retail.
  insert into public.organizations(
    workspace_id,legal_name,operating_name,organization_type,status,website,phone,email,
    primary_region,service_regions,hq_city,hq_province,hq_address_line_1,doors_managed,source_notes
  )
  select v_workspace,'Regional Group of Companies Inc.','Regional Group','property_manager','active',
    'https://regionalgroup.com','613-230-2100','info@regionalgroup.com',
    'Ottawa-Gatineau',array['Ottawa','Gatineau'],'Ottawa','ON','1737 Woodward Drive, 2nd Floor',2000,
    'Official property-management page reports 2,000+ residential units and 2.3M sq ft of commercial, industrial and retail space. Regional states it handles repairs, maintenance, daily operations, capital expenditures and building-service tendering.'
  where not exists(select 1 from public.organizations where workspace_id=v_workspace and coalesce(operating_name,legal_name)='Regional Group');

  select id into v_org from public.organizations where workspace_id=v_workspace and coalesce(operating_name,legal_name)='Regional Group' limit 1;
  insert into public.outreach_targets(
    workspace_id,outreach_list_id,organization_name,contact_name,phone,email,property_address,status,
    organization_id,region,score,score_reason,next_action,priority,notes,company_phone,company_email,company_website,company_address
  )
  select v_workspace,v_list,'Regional Group','Regional property management team','613-230-2100','info@regionalgroup.com','Ottawa','queued',
    v_org,'Ottawa',98,
    'Tier-1 portfolio account: 2,000+ residential units plus 2.3M sq ft commercial/industrial/retail; first-party evidence explicitly includes repairs, maintenance and building-service tendering.',
    'Call property management via main office: identify vendor onboarding owner and current snow/grounds/janitorial tender windows; ask to qualify for one commercial or multi-residential cluster.',
    'high','Use route-density pitch: one accountable vendor across nearby assets, documented winter response, photo closeout and overflow capacity.',
    '613-230-2100','info@regionalgroup.com','https://regionalgroup.com','1737 Woodward Drive, 2nd Floor, Ottawa, ON K2C 0P9'
  where not exists(select 1 from public.outreach_targets where workspace_id=v_workspace and organization_id=v_org);

  -- Merkburn: close to 1M sf owned/managed commercial + industrial Ottawa portfolio.
  insert into public.organizations(
    workspace_id,legal_name,operating_name,organization_type,status,website,phone,email,
    primary_region,service_regions,hq_city,hq_province,hq_address_line_1,source_notes
  )
  select v_workspace,'Merkburn Holdings Ltd.','Merkburn Holdings','property_manager','active',
    'https://merkburn.com','613-224-5464','info@merkburn.com',
    'Ottawa',array['Ottawa'],'Ottawa','ON','2191 Thurston Drive, Suite 4',
    'Official sources say Merkburn owns/manages close to 1M sq ft of commercial and industrial Ottawa-region property. Property-management services include on-call maintenance, obtaining/overseeing bids, project management and payment of maintenance contracts.'
  where not exists(select 1 from public.organizations where workspace_id=v_workspace and coalesce(operating_name,legal_name)='Merkburn Holdings');

  select id into v_org from public.organizations where workspace_id=v_workspace and coalesce(operating_name,legal_name)='Merkburn Holdings' limit 1;
  insert into public.outreach_targets(
    workspace_id,outreach_list_id,organization_name,contact_name,phone,email,property_address,status,
    organization_id,region,score,score_reason,next_action,priority,notes,company_phone,company_email,company_website,company_address
  )
  select v_workspace,v_list,'Merkburn Holdings','Merkburn property management team','613-224-5464','info@merkburn.com','Ottawa','queued',
    v_org,'Ottawa',96,
    'Tier-1 owner/operator: close to 1M sq ft of Ottawa commercial/industrial space with documented maintenance-contract bidding and project oversight.',
    'Call/email property management: request approved-vendor route and identify industrial/warehouse sites where winter access, loading areas or exterior maintenance are being competitively bid.',
    'high','Lead with industrial snow/loading continuity plus grounds; expand to janitorial only after property-level fit is confirmed.',
    '613-224-5464','info@merkburn.com','https://merkburn.com','2191 Thurston Drive, Suite 4, Ottawa, ON K1G 6C9'
  where not exists(select 1 from public.outreach_targets where workspace_id=v_workspace and organization_id=v_org);

  -- Re-score every open target using the same evidence-based operating model.
  -- Base 35 + property evidence + contactability + service/buying signals + freshness.
  with metrics as (
    select
      t.id,
      count(distinct otp.property_id) as property_count,
      count(distinct case when pi.intelligence_score >= 80 then otp.property_id end) as high_signal_properties,
      count(distinct case when pis.confidence='high' then pis.id end) as evidence_count,
      count(distinct case when tos.status='open' then tos.id end) as open_signals,
      bool_or(coalesce(pi.procurement_signal,'') <> '' or coalesce(pi.vendor_signal,'') <> '') as has_buying_route,
      bool_or(coalesce(pi.snow_scope,'') <> '') as has_snow,
      bool_or(coalesce(pi.grounds_scope,'') <> '') as has_grounds,
      bool_or(coalesce(pi.janitorial_scope,'') <> '') as has_janitorial
    from public.outreach_targets t
    left join public.outreach_target_properties otp on otp.outreach_target_id=t.id and otp.workspace_id=t.workspace_id
    left join public.property_intelligence pi on pi.property_id=otp.property_id and pi.workspace_id=t.workspace_id
    left join public.property_intelligence_sources pis on pis.property_id=otp.property_id and pis.workspace_id=t.workspace_id
    left join public.target_opportunity_signals tos on tos.workspace_id=t.workspace_id
      and tos.status='open' and (tos.target_id=t.id or tos.property_id=otp.property_id or tos.organization_id=t.organization_id)
    where t.workspace_id=v_workspace and t.status in ('queued','contacted','responded')
    group by t.id
  )
  update public.outreach_targets t
  set score = greatest(coalesce(t.score,0), least(100,
      35
      + case when t.contact_id is not null then 15 when nullif(t.contact_name,'') is not null then 8 else 0 end
      + case when nullif(t.email,'') is not null then 7 else 0 end
      + case when nullif(t.phone,'') is not null then 5 else 0 end
      + least(15, m.high_signal_properties * 3)
      + least(8, m.evidence_count * 2)
      + least(10, m.open_signals * 5)
      + case when m.has_buying_route then 5 else 0 end
      + case when m.has_snow and m.has_grounds then 4 when m.has_snow or m.has_grounds then 2 else 0 end
      + case when m.has_janitorial then 2 else 0 end
    )),
    priority = case
      when greatest(coalesce(t.score,0), 35
        + case when t.contact_id is not null then 15 when nullif(t.contact_name,'') is not null then 8 else 0 end
        + case when nullif(t.email,'') is not null then 7 else 0 end
        + case when nullif(t.phone,'') is not null then 5 else 0 end
        + least(15,m.high_signal_properties*3) + least(8,m.evidence_count*2)
        + least(10,m.open_signals*5) + case when m.has_buying_route then 5 else 0 end
      ) >= 85 then 'high'
      when coalesce(t.score,0) >= 65 then 'normal'
      else t.priority end,
    updated_at=now()
  from metrics m where t.id=m.id;

  -- Make weak routes executable instead of leaving generic "research" instructions.
  update public.outreach_targets
  set next_action = case
    when contact_id is null and nullif(email,'') is null and nullif(phone,'') is null
      then 'Enrich decision-maker and vendor/procurement route before outreach.'
    when contact_id is null and nullif(contact_name,'') is null
      then 'Confirm named facilities/property/procurement owner, then make vendor introduction.'
    when next_action is null or length(trim(next_action)) < 12
      then 'Contact verified route; confirm incumbent, buying process, next bid/renewal window and one pilot property.'
    else next_action end,
    updated_at=now()
  where workspace_id=v_workspace and status in ('queued','contacted','responded');
end $$;

-- Complete and prioritize the Metcalfe Realty named-account pursuit.
-- Facts are limited to public Metcalfe sources; unknown incumbents/renewal dates remain explicit discovery gaps.
-- Official sources checked 2026-09-28:
-- https://metcalfe.ca/properties/
-- https://metcalfe.ca/about-us/our-team/
-- https://metcalfe.ca/properties/1926-merivale-road/
-- https://metcalfe.ca/blog/property/116-albert-street/
-- https://metcalfe.ca/blog/property/1385-bank-street/

do $$
declare
  v_workspace uuid := '431aa13d-3e7c-41e3-9686-e840b8ea5b7c';
  v_org uuid;
  v_target uuid;
begin
  select id into v_org from public.organizations
  where workspace_id=v_workspace and coalesce(operating_name,legal_name)='Metcalfe Realty'
  limit 1;
  if v_org is null then raise exception 'Metcalfe Realty organization missing'; end if;

  update public.organizations
  set source_notes='Official Metcalfe sources identify 20+ diverse properties and an integrated Leasing, Construction, Operations and Finance model. Mario Martel leads Operations; Natalie Williams manages 2,200+ parking stalls. Public leasing pages expose 18 distinct properties relevant to this pursuit, including two Brockville expansion sites.'
  where id=v_org;

  select id into v_target from public.outreach_targets
  where workspace_id=v_workspace and organization_id=v_org
  order by created_at limit 1;

  if v_target is not null then
    update public.outreach_targets
    set score=96,
        priority='high',
        score_reason='Tier-1 named account: multi-property commercial portfolio, centralized operations, 2,200+ parking stalls, recurring cleaning evidence and multiple high-exposure snow/grounds sites.',
        next_action='Call Operations: confirm snow/grounds/janitorial procurement ownership, identify building managers for Beacon Hill, Queensview and 700 Industrial, and ask for one site walk or backup-vendor qualification.',
        notes=concat_ws(E'\n', notes, 'Pursuit KPI (30 days): 1 site walk + 1 incumbent identified + 1 renewal/retender window + 1 quote opportunity + approved/backup vendor status. Do not infer incumbent or renewal dates without evidence.')
    where id=v_target;
  end if;

  create temporary table tmp_metcalfe_missing(
    name text,address text,city text,province text,property_type text,score int,summary text,
    sqft int,parking int,floors int,grounds text,snow text,janitorial text,access text,liability text,source_url text
  ) on commit drop;

  insert into tmp_metcalfe_missing values
  ('Metcalfe — 116 Albert Street','116 Albert Street','Ottawa','ON','office',88,'Downtown 97,307 sf office; daily full-service green cleaning; on-site day engineer; building manager shared with an adjacent building; underground parking.',97307,null,12,'limited downtown exterior/entrance scope','entrances, sidewalks and access-focused snow/ice response','daily full-service green cleaning publicly documented','downtown/LRT access; underground parking','high pedestrian and tenant exposure','https://metcalfe.ca/blog/property/116-albert-street/'),
  ('Metcalfe — 85 Albert Street','85 Albert Street','Ottawa','ON','office',86,'Downtown office property near government, courthouse and transit; prioritize janitorial, entrances and specialty exterior services.',89339,null,null,'limited downtown exterior scope','entrances and sidewalk snow/ice','commercial common-area/tenancy cleaning opportunity; verify incumbent','dense downtown access','high pedestrian exposure','https://metcalfe.ca/properties/85-albert-street/'),
  ('Metcalfe — Kilborn Medical Centre','1385 Bank Street','Ottawa','ON','medical',92,'Medical office centre with public parking garage and patient traffic; reliability and infection-sensitive cleaning make janitorial and access safety strategically important.',31128,null,null,'presentation-focused medical-site exterior scope','patient entrances, sidewalks and parking access','medical-office cleaning opportunity; confirm scope, standards and incumbent','patient/public access and parking garage','elevated patient slip/fall and service-continuity exposure','https://metcalfe.ca/blog/property/1385-bank-street/'),
  ('Metcalfe — 1926 Merivale Road','1926 Merivale Road','Ottawa','ON','office_warehouse',94,'Mixed office/warehouse with 53 surface and 20 covered parking spaces, daily full-service cleaning, itinerant building manager/day porter and three overhead garage doors.',37798,73,3,'suburban commercial grounds and frontage','surface parking, entrances and loading/garage access','daily full-service cleaning publicly documented','warehouse doors plus surface/covered parking','tenant, vehicle and loading access exposure','https://metcalfe.ca/properties/1926-merivale-road/'),
  ('Metcalfe — Thomas Fuller Building','14 Courthouse Avenue','Brockville','ON','office',62,'Brockville expansion property. Keep outside initial Ottawa route unless CB establishes local operating capacity.',13154,null,null,'verify before pursuit','verify before pursuit','verify before pursuit','outside current Ottawa route density','travel/coverage risk if serviced from Ottawa','https://metcalfe.ca/properties/thomas-fuller-building/'),
  ('Metcalfe — Tall Ships Landing','15 St. Andrew Street','Brockville','ON','mixed_use',64,'Brockville mixed-use expansion property. Strategic only after local capacity or subcontractor coverage is established.',33000,null,null,'mixed-use exterior scope; verify','mixed-use access snow/ice; verify','mixed-use common-area scope; verify','outside current Ottawa route density','public/tenant mixed-use exposure','https://metcalfe.ca/properties/tall-ships-landing/');

  insert into public.properties(workspace_id,name,address_line_1,city,province,country,property_type,status,management_organization_id,site_notes)
  select v_workspace,m.name,m.address,m.city,m.province,'Canada',m.property_type,'prospect',v_org,
    case when m.city='Ottawa' then 'Verified Metcalfe portfolio asset; include in named-account pursuit.' else 'Verified Metcalfe portfolio asset; expansion geography, not initial Ottawa route.' end
  from tmp_metcalfe_missing m
  where not exists(select 1 from public.properties p where p.workspace_id=v_workspace and p.name=m.name);

  insert into public.property_intelligence(
    workspace_id,property_id,building_count,floor_count,estimated_sqft,parking_spaces,property_class,ownership_type,
    grounds_scope,snow_scope,janitorial_scope,capital_projects_signal,vendor_signal,procurement_signal,
    seasonal_priority,access_complexity,liability_signal,intelligence_score,intelligence_summary,
    primary_source_url,primary_source_label,data_confidence,verified_at
  )
  select v_workspace,p.id,1,m.floors,m.sqft,m.parking,'commercial','professional_property_manager',
    m.grounds,m.snow,m.janitorial,
    'Metcalfe has an internal Construction division; confirm property-specific planned work.',
    'External service vendor opportunity exists; incumbent identity is not publicly verified.',
    'Route through Director of Operations; confirm whether category buying is centralized or delegated to building managers.',
    case when m.city='Ottawa' then 'winter' else 'expansion' end,m.access,m.liability,m.score,m.summary,
    m.source_url,'Metcalfe Realty official property page','high',now()
  from tmp_metcalfe_missing m join public.properties p on p.workspace_id=v_workspace and p.name=m.name
  where not exists(select 1 from public.property_intelligence pi where pi.property_id=p.id);

  insert into public.property_intelligence_sources(workspace_id,property_id,source_type,source_url,source_title,summary,confidence)
  select v_workspace,p.id,'official_website',m.source_url,'Metcalfe Realty official property page',m.summary,'high'
  from tmp_metcalfe_missing m join public.properties p on p.workspace_id=v_workspace and p.name=m.name
  where not exists(select 1 from public.property_intelligence_sources x where x.property_id=p.id and x.source_url=m.source_url);

  if v_target is not null then
    insert into public.outreach_target_properties(workspace_id,outreach_target_id,property_id,relationship_type,is_primary)
    select v_workspace,v_target,p.id,'management_site',false
    from public.properties p
    where p.workspace_id=v_workspace
      and p.management_organization_id=v_org
      and not exists(
        select 1
        from public.outreach_target_properties x
        where x.workspace_id=v_workspace
          and x.outreach_target_id=v_target
          and x.property_id=p.id
      );
  end if;

  -- Correct/strengthen existing high-value sites with property-specific pursuit intelligence.
  update public.property_intelligence pi set
    parking_spaces=552, intelligence_score=98,
    grounds_scope='retail-centre grounds, frontage and high-visibility exterior presentation',
    snow_scope='552-space surface lot plus pedestrian entrances; high-priority storm response',
    janitorial_scope='common-area cleaning opportunity; on-site concierge/common-area service model documented',
    access_complexity='retail traffic, 552 surface stalls and continuous tenant/customer access',
    liability_signal='very high pedestrian/vehicle slip-and-fall exposure',
    vendor_signal='Tier-1 pilot candidate; identify current snow/grounds/janitorial incumbents through Operations/building management.',
    procurement_signal='Ask for 2026/27 winter coverage status, backup-vendor qualification and next competitive quote window.',
    seasonal_priority='winter',
    intelligence_summary='Top Metcalfe entry site: 92,235 sf retail/office complex with 552 surface parking spaces and high public exposure.'
  from public.properties p where pi.property_id=p.id and p.workspace_id=v_workspace and p.name='Metcalfe — Beacon Hill Shopping Centre';

  update public.property_intelligence pi set
    parking_spaces=296, intelligence_score=97,
    grounds_scope='suburban office grounds and exterior presentation',
    snow_scope='207 surface stalls plus garage access; route-density anchor with 2680 Queensview',
    janitorial_scope='daily cleaning opportunity publicly documented',
    access_complexity='surface parking, garage access and tenant circulation',
    liability_signal='high winter vehicle/pedestrian exposure',
    vendor_signal='Pair with 2680 Queensview for a clustered operating proposal.',
    procurement_signal='Ask Operations for one combined Queensview site walk and current vendor coverage.',
    seasonal_priority='winter',
    intelligence_summary='West-cluster anchor with 207 surface and 89 garage spaces; strong snow, grounds and janitorial fit.'
  from public.properties p where pi.property_id=p.id and p.workspace_id=v_workspace and p.name='Metcalfe — 2650 Queensview Drive';

  update public.property_intelligence pi set
    parking_spaces=181, intelligence_score=96,
    snow_scope='181-space surface lot, 25 truck bays, entrances and loading access',
    janitorial_scope='daily cleaning opportunity publicly documented',
    access_complexity='truck bays, warehouse/loading circulation and tenant parking',
    liability_signal='high operational-continuity and winter access exposure',
    vendor_signal='Tier-1 snow/ice and facility-services candidate; identify incumbent and response SLA.',
    procurement_signal='Lead with uninterrupted loading/access and documented storm-response capability.',
    seasonal_priority='winter',
    intelligence_summary='East-cluster anchor: office/warehouse site with 181 surface stalls and 25 truck bays.'
  from public.properties p where pi.property_id=p.id and p.workspace_id=v_workspace and p.name='Metcalfe — 700 Industrial Avenue';

  update public.property_intelligence pi set
    intelligence_score=95,
    grounds_scope='landscape presentation is explicitly marketed as a property feature; strong grounds-maintenance fit',
    snow_scope='suburban office parking/entrance snow and ice; verify exact paved area',
    janitorial_scope='daily cleaning opportunity; verify incumbent and scope',
    vendor_signal='Best landscape-led entry site in portfolio.',
    procurement_signal='Ask specifically who owns landscape quality and seasonal enhancement decisions.',
    seasonal_priority='spring_fall',
    intelligence_summary='Landscape-led pursuit site; Metcalfe publicly markets the property landscaping as an asset.'
  from public.properties p where pi.property_id=p.id and p.workspace_id=v_workspace and p.name='Metcalfe — 161 Greenbank Road';

  -- Portfolio operations stakeholder: useful for snow/parking coordination, but not asserted as procurement owner.
  insert into public.contacts(workspace_id,first_name,last_name,job_title,email,phone,status,notes,source_url,source_label,source_confidence,source_verified_at)
  select v_workspace,'Natalie','Williams','Parking Coordinator',null,'613-563-4442','active',
    'Official Metcalfe team page states Natalie manages parking operations across 2,200+ stalls. Operational influencer for snow/ice access; procurement ownership must be confirmed.',
    'https://metcalfe.ca/our-team/','Metcalfe Realty team page','high',now()
  where not exists(select 1 from public.contacts c where c.workspace_id=v_workspace and c.first_name='Natalie' and c.last_name='Williams');

  insert into public.property_contacts(workspace_id,property_id,contact_id,relationship_type,is_primary,emergency_contact,notes)
  select v_workspace,p.id,c.id,'parking_operations',false,false,
    'Portfolio parking stakeholder; useful for winter access requirements. Do not treat as contract owner without confirmation.'
  from public.properties p
  join public.contacts c on c.workspace_id=v_workspace and c.first_name='Natalie' and c.last_name='Williams'
  where p.workspace_id=v_workspace and p.name in (
    'Metcalfe — Beacon Hill Shopping Centre','Metcalfe — 2650 Queensview Drive','Metcalfe — 700 Industrial Avenue',
    'Metcalfe — 2680 Queensview Drive','Metcalfe — 1926 Merivale Road','Metcalfe — Killeany Place'
  )
  and not exists(select 1 from public.property_contacts pc where pc.property_id=p.id and pc.contact_id=c.id);

  -- Seasonal pursuit signals are explicit BD timing signals, not claims of an expiring contract.
  insert into public.target_opportunity_signals(
    workspace_id,organization_id,property_id,target_id,signal_type,title,service_fit,source_url,source_label,
    source_confidence,status,buyer_contact_name,notes
  )
  select v_workspace,v_org,p.id,v_target,'seasonal',
    'Metcalfe winter-readiness pursuit — '||replace(p.name,'Metcalfe — ',''),
    array['snow','grounds'],
    coalesce(pi.primary_source_url,'https://metcalfe.ca/properties/'),
    'Metcalfe Realty official property information','high','open','Mario Martel',
    'BD timing signal created for fall 2026. Confirm incumbent, contract status, renewal/retender timing and backup-vendor process directly; none are assumed.'
  from public.properties p join public.property_intelligence pi on pi.property_id=p.id
  where p.workspace_id=v_workspace and p.management_organization_id=v_org
    and p.city='Ottawa' and coalesce(pi.intelligence_score,0)>=90
    and not exists(
      select 1 from public.target_opportunity_signals s
      where s.workspace_id=v_workspace and s.property_id=p.id and s.signal_type='seasonal'
        and s.title like 'Metcalfe winter-readiness pursuit%'
    );
end $$;

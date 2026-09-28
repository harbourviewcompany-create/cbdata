-- Deepen highest-priority Ottawa portfolio targets with current first-party property evidence.
-- Checked 2026-09-28. Leasing/management evidence does not by itself prove ownership or an open service contract.

do $$
declare
 v_workspace uuid := '431aa13d-3e7c-41e3-9686-e840b8ea5b7c';
 v_org uuid; v_target uuid;
begin
 -- District: current commercial inventory gives concrete serviceable sites.
 select id into v_org from public.organizations where workspace_id=v_workspace and coalesce(operating_name,legal_name)='District Realty' limit 1;
 select id into v_target from public.outreach_targets where workspace_id=v_workspace and organization_id=v_org order by created_at limit 1;

 create temporary table tmp_district(name text,address text,ptype text,score int,summary text,snow text,grounds text,jan text,src text) on commit drop;
 insert into tmp_district values
 ('District — Train Yards','Ottawa Train Yards / Industrial Avenue','retail',98,'District currently markets multiple Train Yards retail addresses including 505, 515, 590, 610 and 665 Industrial plus 100/150 Trainyards and 500 Terminal. Treat as a cluster opportunity; confirm which assets District actually manages versus brokers.','large retail parking/access and pedestrian winter service potential','high-visibility retail exterior/grounds potential','retail common-area/service opportunity; scope to confirm','https://www.districtrealty.com/commercial/'),
 ('District — 1000-1010 Belfast Road','1000-1010 Belfast Road','industrial_office',94,'Current District commercial availability includes office/industrial space at 1000-1010 Belfast Road.','industrial access/loading and parking winter potential','commercial exterior scope to confirm','office/common-area cleaning potential','https://www.districtrealty.com/commercial/'),
 ('District — 3020 Hawthorne Road','3020 Hawthorne Road','industrial',94,'Current District commercial availability includes industrial space at 3020 Hawthorne Road.','industrial access/loading and parking winter potential','industrial exterior scope to confirm','industrial/office cleaning scope to confirm','https://www.districtrealty.com/commercial/'),
 ('District — 250 City Centre Avenue','250 City Centre Avenue','industrial_office',93,'Current District commercial availability includes warehouse and office space at City Centre.','urban loading/parking/entrance winter potential','limited urban grounds; exterior cleanup potential','office/warehouse common-area cleaning potential','https://www.districtrealty.com/commercial/'),
 ('District — 885 Meadowlands Drive','885 Meadowlands Drive','medical_office',93,'District currently markets multiple medical/office suites at 885 Meadowlands.','patient/tenant entrance and parking winter safety potential','professional-office exterior presentation','medical/office common-area cleaning opportunity; standards and incumbent unknown','https://www.districtrealty.com/commercial/'),
 ('District — 815 Taylor Creek Drive','815 Taylor Creek Drive','office',91,'Current District commercial availability includes office space at 815 Taylor Creek Drive in east Ottawa.','suburban parking/entrance winter potential','suburban office grounds potential','office common-area cleaning potential','https://www.districtrealty.com/commercial/');

 insert into public.properties(workspace_id,name,address_line_1,city,province,country,property_type,status,management_organization_id)
 select v_workspace,d.name,d.address,'Ottawa','ON','Canada',d.ptype,'prospect',v_org from tmp_district d
 where not exists(select 1 from public.properties p where p.workspace_id=v_workspace and p.name=d.name);

 insert into public.property_intelligence(workspace_id,property_id,building_count,property_class,ownership_type,grounds_scope,snow_scope,janitorial_scope,vendor_signal,procurement_signal,seasonal_priority,access_complexity,liability_signal,intelligence_score,intelligence_summary,primary_source_url,primary_source_label,data_confidence,verified_at)
 select v_workspace,p.id,1,d.ptype,'management_or_brokerage_relationship_unconfirmed',d.grounds,d.snow,d.jan,
 'Current District commercial inventory is verified; CB must confirm District management responsibility and incumbent service vendor before proposing.',
 'Route through Director of Commercial Properties Michael Morin; ask which listed assets District manages and which are only brokerage assignments.',
 'winter','property-specific site walk required','commercial tenant/public access exposure',d.score,d.summary,d.src,'District Realty current commercial inventory','high',now()
 from tmp_district d join public.properties p on p.workspace_id=v_workspace and p.name=d.name
 where not exists(select 1 from public.property_intelligence pi where pi.property_id=p.id);

 insert into public.property_intelligence_sources(workspace_id,property_id,source_type,source_url,source_title,summary,confidence)
 select v_workspace,p.id,'official_website',d.src,'District Realty current commercial inventory',d.summary,'high'
 from tmp_district d join public.properties p on p.workspace_id=v_workspace and p.name=d.name
 where not exists(select 1 from public.property_intelligence_sources s where s.property_id=p.id and s.source_url=d.src);

 insert into public.outreach_target_properties(workspace_id,outreach_target_id,property_id,relationship_type,is_primary)
 select v_workspace,v_target,p.id,'commercial_inventory_site',false
 from tmp_district d join public.properties p on p.workspace_id=v_workspace and p.name=d.name
 where v_target is not null and not exists(select 1 from public.outreach_target_properties x where x.outreach_target_id=v_target and x.property_id=p.id);

 -- Regional: current first-party projects and a fresh 2026 acquisition.
 select id into v_org from public.organizations where workspace_id=v_workspace and coalesce(operating_name,legal_name)='Regional Group' limit 1;
 select id into v_target from public.outreach_targets where workspace_id=v_workspace and organization_id=v_org order by created_at limit 1;

 create temporary table tmp_regional(name text,address text,ptype text,score int,summary text,src text) on commit drop;
 insert into tmp_regional values
 ('Regional — 150 Slater Street','150 Slater Street','office',99,'Regional announced acquisition of 150 Slater Street in February 2026, creating a fresh operational-change signal at a major downtown Class A office asset. Do not assume vendor turnover; ask directly.','https://regionalgroup.com/'),
 ('Regional — Hazeldean Mall','300 Eagleson Road','retail',98,'Hazeldean Mall is a featured Regional project and a high-value retail winter/grounds/cleaning pursuit site.','https://regionalgroup.com/featured-projects/'),
 ('Regional — Greystone Village Rentals','Greystone Village','multi_residential',94,'Regional features Milieu and Ballantyne rental properties at Greystone Village; multi-building residential route with common-area and winter service potential.','https://regionalgroup.com/featured-projects/'),
 ('Regional — 234-250 Montreal Road','234-250 Montreal Road','mixed_use',92,'Regional lists 234-250 Montreal Road among featured Ottawa projects; mixed-use operating scope should be confirmed property by property.','https://regionalgroup.com/featured-projects/'),
 ('Regional — CITIGATE','CITIGATE, Barrhaven','commercial_development',94,'Large Barrhaven/Ottawa featured Regional project; development/industrial-commercial route creates exterior and winter service potential as sites operate.','https://regionalgroup.com/featured-projects/');

 insert into public.properties(workspace_id,name,address_line_1,city,province,country,property_type,status,owner_organization_id,management_organization_id)
 select v_workspace,r.name,r.address,'Ottawa','ON','Canada',r.ptype,'prospect',v_org,v_org from tmp_regional r
 where not exists(select 1 from public.properties p where p.workspace_id=v_workspace and p.name=r.name);

 insert into public.property_intelligence(workspace_id,property_id,building_count,property_class,ownership_type,grounds_scope,snow_scope,janitorial_scope,capital_projects_signal,vendor_signal,procurement_signal,seasonal_priority,access_complexity,liability_signal,intelligence_score,intelligence_summary,primary_source_url,primary_source_label,data_confidence,verified_at)
 select v_workspace,p.id,1,r.ptype,'owner_operator_or_managed_project',
 case when r.ptype='office' then 'downtown exterior/entrance scope' else 'portfolio exterior/grounds scope; site walk required' end,
 case when r.ptype='office' then 'entrances/sidewalks/loading access' else 'parking, entrances and access winter scope; verify site footprint' end,
 'common-area/facility cleaning opportunity; incumbent and self-performed scope unknown',
 case when r.name='Regional — 150 Slater Street' then '2026 acquisition is an operational change point; no vendor change is assumed.' else 'Regional project/management platform; confirm active capital work.' end,
 'Regional states it manages building services including tendering for capital improvements.',
 'Route through property management; ask for vendor onboarding and property-specific tender calendar.',
 'winter','site-specific access requirements to confirm','public/tenant commercial exposure',r.score,r.summary,r.src,'Regional Group official project/corporate source','high',now()
 from tmp_regional r join public.properties p on p.workspace_id=v_workspace and p.name=r.name
 where not exists(select 1 from public.property_intelligence pi where pi.property_id=p.id);

 insert into public.property_intelligence_sources(workspace_id,property_id,source_type,source_url,source_title,summary,confidence)
 select v_workspace,p.id,'official_website',r.src,'Regional Group official project/corporate source',r.summary,'high'
 from tmp_regional r join public.properties p on p.workspace_id=v_workspace and p.name=r.name
 where not exists(select 1 from public.property_intelligence_sources s where s.property_id=p.id and s.source_url=r.src);

 insert into public.outreach_target_properties(workspace_id,outreach_target_id,property_id,relationship_type,is_primary)
 select v_workspace,v_target,p.id,'owned_or_managed_site',false
 from tmp_regional r join public.properties p on p.workspace_id=v_workspace and p.name=r.name
 where v_target is not null and not exists(select 1 from public.outreach_target_properties x where x.outreach_target_id=v_target and x.property_id=p.id);

 insert into public.target_opportunity_signals(workspace_id,organization_id,property_id,target_id,signal_type,title,service_fit,source_url,source_label,source_confidence,status,notes)
 select v_workspace,v_org,p.id,v_target,'acquisition','Regional 2026 acquisition — 150 Slater Street',
 array['snow','janitorial','facility_maintenance'],'https://regionalgroup.com/','Regional Group official corporate news','high','open',
 'Acquisition announced February 2026. Treat as a discovery trigger only: confirm operations transition, incumbent contracts and tender timing directly.'
 from public.properties p where p.workspace_id=v_workspace and p.name='Regional — 150 Slater Street'
 and not exists(select 1 from public.target_opportunity_signals s where s.workspace_id=v_workspace and s.property_id=p.id and s.signal_type='acquisition');

 -- CBP: 2026 Ottawa management additions provide unusually fresh pursuit signals.
 select id into v_org from public.organizations where workspace_id=v_workspace and coalesce(operating_name,legal_name)='Colonnade BridgePort' limit 1;
 select id into v_target from public.outreach_targets where workspace_id=v_workspace and organization_id=v_org order by created_at limit 1;

 create temporary table tmp_cbp(name text,address text,score int,summary text,src text) on commit drop;
 insert into tmp_cbp values
 ('CBP — Mata','300 Tremblay Road',98,'CBP announced a new residential management mandate at Mata in January 2026. Fresh mandate creates an operations-discovery window; incumbent status remains unknown.','https://colonnadebridgeport.ca/cbp-residential-expands-tcu-partnership-with-two-new-east-end-ottawa-mandates/'),
 ('CBP — Ori','1188 Cummings Avenue',98,'CBP announced a new residential management mandate at Ori in January 2026. Fresh mandate creates an operations-discovery window; incumbent status remains unknown.','https://colonnadebridgeport.ca/cbp-residential-expands-tcu-partnership-with-two-new-east-end-ottawa-mandates/'),
 ('CBP — 600 Mountaineer','600 Mountaineer Private',98,'CBP added this purpose-built rental property to its Ottawa management portfolio in February 2026.','https://colonnadebridgeport.ca/cbp-residential-grows-ottawa-portfolio-with-600-and-601-mountaineer/'),
 ('CBP — 601 Mountaineer','601 Mountaineer Private',98,'CBP added this purpose-built rental property to its Ottawa management portfolio in February 2026.','https://colonnadebridgeport.ca/cbp-residential-grows-ottawa-portfolio-with-600-and-601-mountaineer/');

 insert into public.properties(workspace_id,name,address_line_1,city,province,country,property_type,status,management_organization_id)
 select v_workspace,c.name,c.address,'Ottawa','ON','Canada','multi_residential','prospect',v_org from tmp_cbp c
 where not exists(select 1 from public.properties p where p.workspace_id=v_workspace and p.name=c.name);

 insert into public.property_intelligence(workspace_id,property_id,building_count,property_class,ownership_type,grounds_scope,snow_scope,janitorial_scope,capital_projects_signal,vendor_signal,procurement_signal,seasonal_priority,access_complexity,liability_signal,intelligence_score,intelligence_summary,primary_source_url,primary_source_label,data_confidence,verified_at)
 select v_workspace,p.id,1,'multi_residential','third_party_management_mandate',
 'newer purpose-built residential grounds/exterior scope','residential parking/entrances/walkways winter scope','residential common-area cleaning opportunity; scope unknown',
 'recent management onboarding/lease-up environment','2026 management mandate is verified; incumbent service contractors are not.',
 'Route through CBP Residential; ask what service contracts transferred with mandate and what categories are being rebid/benchmarked.',
 'winter','resident/visitor access and parking','residential slip/fall and service-continuity exposure',c.score,c.summary,c.src,'Colonnade BridgePort 2026 management announcement','high',now()
 from tmp_cbp c join public.properties p on p.workspace_id=v_workspace and p.name=c.name
 where not exists(select 1 from public.property_intelligence pi where pi.property_id=p.id);

 insert into public.property_intelligence_sources(workspace_id,property_id,source_type,source_url,source_title,summary,confidence)
 select v_workspace,p.id,'official_website',c.src,'Colonnade BridgePort 2026 management announcement',c.summary,'high'
 from tmp_cbp c join public.properties p on p.workspace_id=v_workspace and p.name=c.name
 where not exists(select 1 from public.property_intelligence_sources s where s.property_id=p.id and s.source_url=c.src);

 insert into public.outreach_target_properties(workspace_id,outreach_target_id,property_id,relationship_type,is_primary)
 select v_workspace,v_target,p.id,'new_management_mandate',false
 from tmp_cbp c join public.properties p on p.workspace_id=v_workspace and p.name=c.name
 where v_target is not null and not exists(select 1 from public.outreach_target_properties x where x.outreach_target_id=v_target and x.property_id=p.id);

 insert into public.target_opportunity_signals(workspace_id,organization_id,property_id,target_id,signal_type,title,service_fit,source_url,source_label,source_confidence,status,notes)
 select v_workspace,v_org,p.id,v_target,'management_change','CBP 2026 new management mandate — '||replace(p.name,'CBP — ',''),
 array['snow','grounds','janitorial'],c.src,'Colonnade BridgePort official 2026 announcement','high','open',
 'Fresh management mandate is a high-value discovery trigger. Ask which service contracts transferred, expire, or need benchmarking; do not assume replacement.'
 from tmp_cbp c join public.properties p on p.workspace_id=v_workspace and p.name=c.name
 where not exists(select 1 from public.target_opportunity_signals s where s.workspace_id=v_workspace and s.property_id=p.id and s.signal_type='management_change');

 update public.outreach_targets set
   contact_name='Kandas Miller',
   next_action='Contact CBP Residential leadership about the 2026 Mata, Ori and Mountaineer mandates: ask which snow/grounds/janitorial contracts transferred, which are being benchmarked, and request qualification for one east-end cluster.',
   score=100,priority='high',updated_at=now()
 where workspace_id=v_workspace and organization_id=v_org;

 insert into public.contacts(workspace_id,first_name,last_name,job_title,status,notes,source_url,source_label,source_confidence,source_verified_at)
 select v_workspace,'Kandas','Miller','Director, Residential Real Estate','active',
 'Named by Colonnade BridgePort in 2026 Ottawa management-mandate announcements. Relevant executive route for newly managed residential properties; direct email/phone not asserted.',
 'https://colonnadebridgeport.ca/cbp-residential-expands-tcu-partnership-with-two-new-east-end-ottawa-mandates/','Colonnade BridgePort official 2026 announcement','high',now()
 where not exists(select 1 from public.contacts c where c.workspace_id=v_workspace and c.first_name='Kandas' and c.last_name='Miller');

 insert into public.organization_contacts(workspace_id,organization_id,contact_id,relationship_type,is_primary)
 select v_workspace,v_org,c.id,'residential_real_estate',true from public.contacts c
 where c.workspace_id=v_workspace and c.first_name='Kandas' and c.last_name='Miller'
 and not exists(select 1 from public.organization_contacts oc where oc.organization_id=v_org and oc.contact_id=c.id);
end $$;

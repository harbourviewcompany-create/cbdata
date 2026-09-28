-- Add first-party verified CLV Ottawa property depth.
do $$
declare
 v_workspace uuid := '431aa13d-3e7c-41e3-9686-e840b8ea5b7c';
 v_org uuid; v_target uuid;
begin
 select id into v_org from public.organizations where workspace_id=v_workspace and coalesce(operating_name,legal_name)='CLV Group' limit 1;
 select id into v_target from public.outreach_targets where workspace_id=v_workspace and organization_id=v_org order by created_at limit 1;
 create temporary table tmp_clv(name text,address text,ptype text,score int,summary text,signal text,src text) on commit drop;
 insert into tmp_clv values
 ('CLV — 101 Queen Street','101 Queen Street','mixed_use',99,'Recent acquisition: extended-stay hotel, condominium and retail uses in downtown Ottawa.','acquisition','https://www.clvgroup.com/our-portfolio/'),
 ('CLV — 25 Cartier Street','25 Cartier Street','multi_residential',98,'Recent acquisition: prominent 11-storey purpose-built residential property in downtown Ottawa.','acquisition','https://www.clvgroup.com/our-portfolio/'),
 ('CLV — Metcalfe & Cooper','Metcalfe Street & Cooper Street','multi_residential',96,'Two active high-rise residential rental buildings in Centretown.','active_portfolio','https://www.clvgroup.com/our-portfolio/'),
 ('CLV — 360 Laurier','360 Laurier Avenue West','multi_residential',97,'Active Ottawa office-to-residential conversion.','active_project','https://www.clvgroup.com/our-portfolio/'),
 ('CLV — LIV Apartments','207 Bell Street North','multi_residential',95,'Completed luxury purpose-built rental redevelopment in downtown Ottawa.','active_portfolio','https://www.clvgroup.com/our-portfolio/'),
 ('CLV — 330 Metcalfe','330 Metcalfe Street','multi_residential',94,'Currently listed CLV-managed Ottawa apartment community.','active_portfolio','https://www.clvgroup.com/our-platform/property-management/');

 insert into public.properties(workspace_id,name,address_line_1,city,province,country,property_type,status,management_organization_id)
 select v_workspace,c.name,c.address,'Ottawa','ON','Canada',c.ptype,'prospect',v_org from tmp_clv c
 where not exists(select 1 from public.properties p where p.workspace_id=v_workspace and p.name=c.name);

 insert into public.property_intelligence(workspace_id,property_id,building_count,property_class,ownership_type,grounds_scope,snow_scope,janitorial_scope,capital_projects_signal,vendor_signal,procurement_signal,seasonal_priority,access_complexity,liability_signal,intelligence_score,intelligence_summary,primary_source_url,primary_source_label,data_confidence,verified_at)
 select v_workspace,p.id,1,c.ptype,'clv_managed_or_development_asset',
 'residential/mixed-use exterior and grounds scope; verify footprint',
 'resident/guest/retail entrances, walkways and parking; site walk required',
 'common-area and project-cleaning potential; external scope unknown',
 case when c.signal in ('acquisition','active_project') then 'Recent acquisition/development activity; vendor impact must be confirmed.' else 'Active managed asset.' end,
 'CLV property management coordinates maintenance and vendors.',
 'Route through CLV property management; confirm vendor onboarding and external service categories.',
 'winter','dense residential/mixed-use access','resident/public service-continuity exposure',
 c.score,c.summary,c.src,'CLV Group official source','high',now()
 from tmp_clv c join public.properties p on p.workspace_id=v_workspace and p.name=c.name
 where not exists(select 1 from public.property_intelligence pi where pi.property_id=p.id);

 insert into public.property_intelligence_sources(workspace_id,property_id,source_type,source_url,source_title,summary,confidence)
 select v_workspace,p.id,'official_website',c.src,'CLV Group official source',c.summary,'high'
 from tmp_clv c join public.properties p on p.workspace_id=v_workspace and p.name=c.name
 where not exists(select 1 from public.property_intelligence_sources s where s.property_id=p.id and s.source_url=c.src);

 insert into public.outreach_target_properties(workspace_id,outreach_target_id,property_id,relationship_type,is_primary)
 select v_workspace,v_target,p.id,case when c.signal='acquisition' then 'recent_acquisition' else 'managed_or_development_site' end,false
 from tmp_clv c join public.properties p on p.workspace_id=v_workspace and p.name=c.name
 where v_target is not null and not exists(select 1 from public.outreach_target_properties x where x.outreach_target_id=v_target and x.property_id=p.id);

 update public.outreach_targets set score=99,priority='high',
 next_action='Contact CLV property management about 101 Queen, 25 Cartier and 360 Laurier first; confirm vendor onboarding, external service scopes and transition opportunities.',
 updated_at=now() where workspace_id=v_workspace and organization_id=v_org;
end $$;
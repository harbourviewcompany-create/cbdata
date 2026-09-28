-- Add first-party verified Minto Ottawa property depth.
do $$
declare
 v_workspace uuid := '431aa13d-3e7c-41e3-9686-e840b8ea5b7c';
 v_org uuid; v_target uuid;
begin
 select id into v_org from public.organizations where workspace_id=v_workspace and coalesce(operating_name,legal_name)='Minto Commercial' limit 1;
 select id into v_target from public.outreach_targets where workspace_id=v_workspace and organization_id=v_org order by created_at limit 1;
 create temporary table tmp_minto(name text,address text,ptype text,score int,summary text,src text) on commit drop;
 insert into tmp_minto values
 ('Minto — 180 Kent Street','180 Kent Street','office_retail',97,'Current Minto Place office/retail asset and high-density downtown operations target.','https://www.minto.com/ottawa/commercial-space/projects.html'),
 ('Minto — 407 Laurier Avenue West','407 Laurier Avenue West','retail_office',95,'Current Minto Place commercial/retail asset.','https://www.minto.com/ottawa/commercial-space/projects.html'),
 ('Minto — 427 Laurier Avenue West','427 Laurier Avenue West','office',95,'Current Minto Place Enterprise Building office asset.','https://www.minto.com/ottawa/commercial-space/projects.html'),
 ('Minto — Fifth + Bank','99 Fifth Avenue','retail',93,'Current Minto commercial asset in the Glebe.','https://www.minto.com/ottawa/commercial-space/projects.html'),
 ('Minto — one80five','185 Lyon Street North','multi_residential',96,'Minto Apartment REIT portfolio reports 417 suites at Ottawa one80five.','https://media.minto.com/website/index/image/2025-03%20REIT%20Property%20List.pdf'),
 ('Minto — Aventura','Ottawa','multi_residential',95,'Minto Apartment REIT portfolio reports 354 Ottawa suites at Aventura.','https://media.minto.com/website/index/image/2025-03%20REIT%20Property%20List.pdf'),
 ('Minto — Parkwood Hills','Ottawa','multi_residential',94,'Minto Apartment REIT portfolio reports 204 garden homes/townhomes at Parkwood Hills.','https://media.minto.com/website/index/image/2025-03%20REIT%20Property%20List.pdf'),
 ('Minto — Skyline','Ottawa','multi_residential',94,'Minto Apartment REIT portfolio reports 259 garden homes, maisonettes and walkups at Skyline.','https://media.minto.com/website/index/image/2025-03%20REIT%20Property%20List.pdf');

 insert into public.properties(workspace_id,name,address_line_1,city,province,country,property_type,status,management_organization_id)
 select v_workspace,m.name,m.address,'Ottawa','ON','Canada',m.ptype,'prospect',v_org from tmp_minto m
 where not exists(select 1 from public.properties p where p.workspace_id=v_workspace and p.name=m.name);

 insert into public.property_intelligence(workspace_id,property_id,building_count,property_class,ownership_type,grounds_scope,snow_scope,janitorial_scope,vendor_signal,procurement_signal,seasonal_priority,access_complexity,liability_signal,intelligence_score,intelligence_summary,primary_source_url,primary_source_label,data_confidence,verified_at)
 select v_workspace,p.id,1,m.ptype,'minto_operated_or_portfolio_asset',
 'commercial/residential exterior scope; property footprint varies',
 'entrances, walkways and parking winter scope; verify operating boundaries',
 'common-area/commercial cleaning opportunity; external scope unknown',
 'Minto provides daily building operations; determine which categories are self-performed versus contracted.',
 'Route through Minto property operations; qualify external vendor categories before quoting.',
 'winter','property-specific access and parking','tenant/resident/public access exposure',
 m.score,m.summary,m.src,'Minto official portfolio source','high',now()
 from tmp_minto m join public.properties p on p.workspace_id=v_workspace and p.name=m.name
 where not exists(select 1 from public.property_intelligence pi where pi.property_id=p.id);

 insert into public.property_intelligence_sources(workspace_id,property_id,source_type,source_url,source_title,summary,confidence)
 select v_workspace,p.id,case when m.src like '%.pdf' then 'official_document' else 'official_website' end,m.src,'Minto official portfolio source',m.summary,'high'
 from tmp_minto m join public.properties p on p.workspace_id=v_workspace and p.name=m.name
 where not exists(select 1 from public.property_intelligence_sources s where s.property_id=p.id and s.source_url=m.src);

 insert into public.outreach_target_properties(workspace_id,outreach_target_id,property_id,relationship_type,is_primary)
 select v_workspace,v_target,p.id,'minto_operated_site',false
 from tmp_minto m join public.properties p on p.workspace_id=v_workspace and p.name=m.name
 where v_target is not null and not exists(select 1 from public.outreach_target_properties x where x.outreach_target_id=v_target and x.property_id=p.id);

 update public.outreach_targets set score=97,priority='high',
 next_action='Qualify Minto make-vs-buy model first; identify externally contracted snow, grounds and cleaning categories, then pursue the Kent/Laurier or multi-residential cluster.',
 updated_at=now() where workspace_id=v_workspace and organization_id=v_org;
end $$;
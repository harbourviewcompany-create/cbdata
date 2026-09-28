-- Add the next tier of large, first-party-verified Ottawa portfolio targets.
-- Sources checked 2026-09-28. Scores are CBData pursuit-priority scores, not company ratings.

do $$
declare
  v_workspace uuid := '431aa13d-3e7c-41e3-9686-e840b8ea5b7c';
  v_list uuid := 'a15af411-9b05-4b7b-9e5b-9da4909b1dcf';
  v_org uuid;
begin
  -- Colonnade BridgePort: exceptionally large management platform with explicit service-contract management.
  insert into public.organizations(workspace_id,legal_name,operating_name,organization_type,status,website,phone,
    primary_region,service_regions,hq_city,hq_province,hq_address_line_1,buildings_managed,source_notes)
  select v_workspace,'Colonnade BridgePort Realty Inc.','Colonnade BridgePort','property_manager','active',
    'https://colonnadebridgeport.ca','613-225-8118','Ottawa',array['Ottawa','Eastern Ontario'],'Ottawa','ON',
    '16 Concourse Gate, Suite 200',150,
    'Official site reports 15M sq ft under management, 150 properties and 2,000 tenants. Commercial management explicitly includes building/preventative maintenance, parking management and service contract management. In 2026 CBP reported adding 750,000+ commercial sq ft and 581 residential units.'
  where not exists(select 1 from public.organizations where workspace_id=v_workspace and coalesce(operating_name,legal_name)='Colonnade BridgePort');

  select id into v_org from public.organizations where workspace_id=v_workspace and coalesce(operating_name,legal_name)='Colonnade BridgePort' limit 1;
  insert into public.outreach_targets(workspace_id,outreach_list_id,organization_name,contact_name,phone,property_address,status,
    organization_id,region,score,score_reason,next_action,priority,notes,company_phone,company_website,company_address)
  select v_workspace,v_list,'Colonnade BridgePort','CBP commercial property management','613-225-8118','Ottawa','queued',
    v_org,'Ottawa',100,
    'Tier-1 scale account: 15M sq ft / 150 properties with explicit service-contract, parking and preventative-maintenance management plus current 2026 portfolio growth.',
    'Call Ottawa HQ: identify commercial vendor-management/procurement owner, request approved-vendor onboarding, and ask which newly added Ottawa/Eastern Ontario assets need snow, grounds, janitorial or overflow coverage.',
    'high','Highest-scale private portfolio target currently in CBData. Lead with operational reporting, storm documentation, backup capacity and multi-site route density.',
    '613-225-8118','https://colonnadebridgeport.ca','16 Concourse Gate, Suite 200, Ottawa, ON K2E 7S8'
  where not exists(select 1 from public.outreach_targets where workspace_id=v_workspace and organization_id=v_org);

  -- Taggart Realty Management: 3M+ sf, explicit Ottawa office/retail/industrial management.
  insert into public.organizations(workspace_id,legal_name,operating_name,organization_type,status,website,
    primary_region,service_regions,hq_city,hq_province,hq_address_line_1,source_notes)
  select v_workspace,'Taggart Realty Management','Taggart Realty Management','property_manager','active',
    'https://taggart.ca','Ottawa',array['Ottawa','Eastern Ontario'],'Ottawa','ON','225 Metcalfe St, Suite 708',
    'Official site reports over 3M sq ft under management and a portfolio spanning condominiums, apartments, office, retail and industrial. Office/retail assets range from 10,000 to 120,000 sq ft.'
  where not exists(select 1 from public.organizations where workspace_id=v_workspace and coalesce(operating_name,legal_name)='Taggart Realty Management');

  select id into v_org from public.organizations where workspace_id=v_workspace and coalesce(operating_name,legal_name)='Taggart Realty Management' limit 1;
  insert into public.outreach_targets(workspace_id,outreach_list_id,organization_name,contact_name,property_address,status,
    organization_id,region,score,score_reason,next_action,priority,notes,company_website,company_address)
  select v_workspace,v_list,'Taggart Realty Management','Taggart property management team','Ottawa','queued',
    v_org,'Ottawa',97,
    'Tier-1 local portfolio: 3M+ sq ft managed across commercial, retail, industrial, condominium and multi-residential assets.',
    'Contact property management: confirm vendor onboarding and contract owner; request one office/retail/industrial cluster for winter or exterior-maintenance qualification.',
    'high','Strong Ottawa route-density account. Enrich a named operations/property-management buyer before high-volume outreach.',
    'https://taggart.ca','225 Metcalfe St, Suite 708, Ottawa, ON K2P 1P9'
  where not exists(select 1 from public.outreach_targets where workspace_id=v_workspace and organization_id=v_org);

  -- CLV Group: vertically integrated Ottawa platform with named property managers and active acquisitions.
  insert into public.organizations(workspace_id,legal_name,operating_name,organization_type,status,website,phone,
    primary_region,service_regions,hq_city,hq_province,hq_address_line_1,source_notes)
  select v_workspace,'CLV Group Inc.','CLV Group','property_manager','active',
    'https://www.clvgroup.com','1-855-479-1916','Ottawa',array['Ottawa','Ontario'],'Ottawa','ON','485 Bank St, Suite 200',
    'Official site describes a vertically integrated acquisitions/development/construction/property-management platform. Ottawa portfolio includes numerous residential communities and active acquisitions/developments. Leadership page names property managers overseeing maintenance, renovation projects and vendor relationships.'
  where not exists(select 1 from public.organizations where workspace_id=v_workspace and coalesce(operating_name,legal_name)='CLV Group');

  select id into v_org from public.organizations where workspace_id=v_workspace and coalesce(operating_name,legal_name)='CLV Group' limit 1;
  insert into public.outreach_targets(workspace_id,outreach_list_id,organization_name,contact_name,phone,property_address,status,
    organization_id,region,score,score_reason,next_action,priority,notes,company_phone,company_website,company_address)
  select v_workspace,v_list,'CLV Group','CLV property management team','1-855-479-1916','Ottawa','queued',
    v_org,'Ottawa',97,
    'Tier-1 multi-residential account: large Ottawa portfolio, vertically integrated operations and active acquisitions/development with documented property-manager responsibility for maintenance and vendor relationships.',
    'Route to Ottawa property management leadership: ask for vendor onboarding and identify a 2–3 building cluster needing exterior, snow or janitorial support; use recent acquisitions as discovery points.',
    'high','Recent Ottawa acquisitions/developments create operational change points. Do not assume they imply an open contract; confirm vendor status directly.',
    '1-855-479-1916','https://www.clvgroup.com','485 Bank St, Suite 200, Ottawa, ON K2P 1Z2'
  where not exists(select 1 from public.outreach_targets where workspace_id=v_workspace and organization_id=v_org);

  -- Minto Commercial: major owner/operator with daily building operations.
  insert into public.organizations(workspace_id,legal_name,operating_name,organization_type,status,website,phone,
    primary_region,service_regions,hq_city,hq_province,source_notes)
  select v_workspace,'Minto Properties Inc.','Minto Commercial','property_manager','active',
    'https://www.minto.com','613-786-3000','Ottawa',array['Ottawa'],'Ottawa','ON',
    'Official Minto Commercial sources describe a fully integrated development/construction/management company, 1.5M+ sq ft of commercial real estate developed, a diverse managed portfolio, and hands-on daily building operations.'
  where not exists(select 1 from public.organizations where workspace_id=v_workspace and coalesce(operating_name,legal_name)='Minto Commercial');

  select id into v_org from public.organizations where workspace_id=v_workspace and coalesce(operating_name,legal_name)='Minto Commercial' limit 1;
  insert into public.outreach_targets(workspace_id,outreach_list_id,organization_name,contact_name,phone,property_address,status,
    organization_id,region,score,score_reason,next_action,priority,notes,company_phone,company_website)
  select v_workspace,v_list,'Minto Commercial','Minto Commercial property operations','613-786-3000','Ottawa','queued',
    v_org,'Ottawa',95,
    'High-value owner/operator with substantial Ottawa commercial assets and documented daily building-operations capability.',
    'Call commercial property operations: determine external-vendor categories and qualification process; target surface-heavy retail/office assets rather than assuming services at vertically managed sites.',
    'high','Large account but potentially more self-performed operations; qualification and make-vs-buy discovery comes before proposal.',
    '613-786-3000','https://www.minto.com'
  where not exists(select 1 from public.outreach_targets where workspace_id=v_workspace and organization_id=v_org);

  -- Osgoode: Ottawa residential portfolio with dedicated on-site teams; external opportunity needs qualification.
  insert into public.organizations(workspace_id,legal_name,operating_name,organization_type,status,website,phone,
    primary_region,service_regions,hq_city,hq_province,hq_address_line_1,source_notes)
  select v_workspace,'Osgoode Properties Ltd.','Osgoode Properties','property_manager','active',
    'https://www.osgoodeproperties.com','1-866-794-1222','Ottawa',array['Ottawa'],'Ottawa','ON','1284 Wellington Street',
    'Official site lists 11 Ottawa properties and states every building has dedicated live-in superintendents/building managers. Grounds are a stated presentation priority. External-vendor scope must be qualified because substantial operations are handled on site.'
  where not exists(select 1 from public.organizations where workspace_id=v_workspace and coalesce(operating_name,legal_name)='Osgoode Properties');

  select id into v_org from public.organizations where workspace_id=v_workspace and coalesce(operating_name,legal_name)='Osgoode Properties' limit 1;
  insert into public.outreach_targets(workspace_id,outreach_list_id,organization_name,contact_name,phone,property_address,status,
    organization_id,region,score,score_reason,next_action,priority,notes,company_phone,company_website,company_address)
  select v_workspace,v_list,'Osgoode Properties','Osgoode property operations','1-866-794-1222','Ottawa','queued',
    v_org,'Ottawa',90,
    'Large Ottawa residential route with 11 listed properties and strong grounds/property-condition emphasis; dedicated on-site staff reduces some janitorial opportunity but does not eliminate snow/grounds/project work.',
    'Contact property operations: qualify what is self-performed versus externally contracted, then pursue snow/grounds or project overflow at Ottawa clusters.',
    'high','Do not lead with routine building-manager work that Osgoode publicly says is handled by dedicated on-site teams.',
    '1-866-794-1222','https://www.osgoodeproperties.com','1284 Wellington Street, Ottawa, ON K1Y 3A9'
  where not exists(select 1 from public.outreach_targets where workspace_id=v_workspace and organization_id=v_org);
end $$;

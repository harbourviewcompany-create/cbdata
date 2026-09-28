do $$
declare v_workspace uuid := '431aa13d-3e7c-41e3-9686-e840b8ea5b7c'; v_org uuid; v_contact uuid;
begin
 select id into v_org from public.organizations where workspace_id=v_workspace and coalesce(operating_name,legal_name)='Colonnade BridgePort' limit 1;
 insert into public.contacts(workspace_id,first_name,last_name,job_title,status,notes,source_url,source_label,source_confidence,source_verified_at)
 select v_workspace,'Ron','Matheson','SVP, Real Estate Management Services','active',
 'Official CBP page identifies Ron Matheson as SVP, Real Estate Management Services. CBP includes service contract management, building maintenance and parking management in its commercial offering.',
 'https://colonnadebridgeport.ca/our-services/commercial-property-management-services/','CBP official commercial property management page','high',now()
 where not exists(select 1 from public.contacts c where c.workspace_id=v_workspace and c.first_name='Ron' and c.last_name='Matheson');
 select id into v_contact from public.contacts where workspace_id=v_workspace and first_name='Ron' and last_name='Matheson' limit 1;
 insert into public.organization_contacts(workspace_id,organization_id,contact_id,relationship_type,is_primary)
 select v_workspace,v_org,v_contact,'commercial_real_estate_management',false
 where v_contact is not null and not exists(select 1 from public.organization_contacts oc where oc.organization_id=v_org and oc.contact_id=v_contact);
 update public.outreach_targets set
 notes=concat_ws(E'\n',notes,'BUYING ROUTES: Residential: Kandas Miller. Commercial: Ron Matheson. CBP publicly confirms service-contract management.'),
 next_action='Use two CBP routes: Kandas Miller for 2026 residential mandates; Ron Matheson for commercial vendor qualification. Confirm transferred, benchmarked, rebid and backup service categories.',
 updated_at=now() where workspace_id=v_workspace and organization_id=v_org;
end $$;
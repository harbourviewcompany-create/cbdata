-- Verified public property evidence seed for the CBData workspace.
-- Values are sourced from the URLs stored with each intelligence record.
insert into public.property_intelligence_sources
(workspace_id,property_id,source_type,source_url,source_title,summary,confidence)
select p.workspace_id,p.id,'official_website',pi.primary_source_url,pi.primary_source_label,pi.intelligence_summary,'high'
from public.properties p
join public.property_intelligence pi on pi.property_id=p.id
where p.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
and p.name in ('90 George','Gatespark Private — OCCCEC 677','377 Dalhousie Street','830 Campbell Avenue','Killeany Place','2181 Ogilvie Road')
and not exists (
  select 1 from public.property_intelligence_sources s
  where s.property_id=p.id and s.source_url=pi.primary_source_url
);
insert into public.outreach_target_properties(workspace_id,outreach_target_id,property_id,relationship_type,is_primary)
select t.workspace_id,t.id,p.id,
case when p.name in ('90 George','Gatespark Private — OCCCEC 677') then 'board_site' else 'owned_or_managed_site' end,
true
from public.outreach_targets t
join public.properties p on p.workspace_id=t.workspace_id
where t.organization_id=p.owner_organization_id
and p.name in ('90 George','Gatespark Private — OCCCEC 677','377 Dalhousie Street','830 Campbell Avenue','Killeany Place','2181 Ogilvie Road')
on conflict do nothing;
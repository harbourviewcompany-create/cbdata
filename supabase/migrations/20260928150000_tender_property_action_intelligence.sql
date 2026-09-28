-- Tender-to-property coverage and actionable bid state.
alter table public.tender_records
  add column if not exists action_state text not null default 'new',
  add column if not exists next_action text,
  add column if not exists next_action_due_at timestamptz;

create table if not exists public.tender_properties (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete restrict,
  tender_record_id uuid not null references public.tender_records(id) on delete cascade,
  property_id uuid not null references public.properties(id) on delete cascade,
  scope_note text,
  evidence_url text,
  evidence_label text,
  source_confidence text,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  unique(tender_record_id, property_id)
);

create index if not exists idx_tender_properties_tender on public.tender_properties(tender_record_id);
create index if not exists idx_tender_properties_property on public.tender_properties(property_id);
create index if not exists idx_tender_records_action_state on public.tender_records(workspace_id, action_state, closing_date);

alter table public.tender_properties enable row level security;
alter table public.tender_properties force row level security;

drop policy if exists tender_properties_select on public.tender_properties;
create policy tender_properties_select on public.tender_properties for select to authenticated using (public.is_workspace_member(workspace_id));
drop policy if exists tender_properties_insert on public.tender_properties;
create policy tender_properties_insert on public.tender_properties for insert to authenticated with check (public.is_workspace_member(workspace_id));
drop policy if exists tender_properties_update on public.tender_properties;
create policy tender_properties_update on public.tender_properties for update to authenticated using (public.is_workspace_member(workspace_id)) with check (public.is_workspace_member(workspace_id));

do $$
declare
  w uuid;
  nrc uuid;

  prop_id uuid;
  tender_id uuid;
begin
  select id into w from public.workspaces where slug='cb-contracting' limit 1;
  if w is null then return; end if;
  select id into nrc from public.organizations where workspace_id=w and (lower(legal_name)='national research council of canada' or lower(operating_name)='nrc') limit 1;
  if nrc is null then return; end if;

  insert into public.properties(workspace_id,name,address_line_1,city,province,postal_code,country,property_type,status,owner_organization_id,site_notes)
  select w,'NRC Ottawa — Montreal Road Campus','1200 Montreal Road','Ottawa','ON','K1A 0R6','Canada','government_facility','prospect',nrc,
    'NRC headquarters/campus. Official NRC location page identifies the site; NRC building inventory documents numerous Crown-owned buildings at this address.'
  where not exists(select 1 from public.properties x where x.workspace_id=w and x.name='NRC Ottawa — Montreal Road Campus');

  insert into public.properties(workspace_id,name,address_line_1,city,province,postal_code,country,property_type,status,owner_organization_id,site_notes)
  select w,'NRC Ottawa — Sussex Campus','100 Sussex Drive','Ottawa','ON','K1N 5A2','Canada','government_facility','prospect',nrc,
    'Official NRC location page identifies the Sussex site; federal building inventory identifies S-77 at 100 Sussex Drive.'
  where not exists(select 1 from public.properties x where x.workspace_id=w and x.name='NRC Ottawa — Sussex Campus');

  insert into public.properties(workspace_id,name,address_line_1,city,province,postal_code,country,property_type,status,owner_organization_id,site_notes)
  select w,'NRC Ottawa — Uplands / Aerospace Campus','1920 Research Private','Ottawa','ON','K1V 9B4','Canada','government_facility','prospect',nrc,
    'Official NRC location page identifies Uplands aerospace facilities; federal building inventory identifies multiple Crown-owned buildings on Research Private/Levy Private.'
  where not exists(select 1 from public.properties x where x.workspace_id=w and x.name='NRC Ottawa — Uplands / Aerospace Campus');

  select id into prop_id from public.properties where workspace_id=w and name='NRC Ottawa — Montreal Road Campus';
  if not exists(select 1 from public.property_intelligence where property_id=prop_id) then
    insert into public.property_intelligence(workspace_id,property_id,building_count,property_class,ownership_type,exterior_scope,grounds_scope,snow_scope,janitorial_scope,procurement_signal,seasonal_priority,liability_signal,intelligence_score,intelligence_summary,primary_source_url,primary_source_label,data_confidence,verified_at)
    values(w,prop_id,60,'federal research campus','Crown-owned',
      'Multiple research/office/laboratory buildings; exact contracted exterior scope to be confirmed from solicitation package.',
      'Large multi-building federal campus; grounds and exterior service coordination should be treated as a portfolio scope.',
      'Winter service is operationally significant across campus access, parking and pedestrian circulation.',
      'Janitorial services solicitation explicitly covers Ottawa NRC offices and multiple sites.',
      'Active 2026 Ottawa janitorial procurement; multi-site service footprint creates a portfolio-level buyer relationship.',
      'winter + year-round','Research/lab environment and multi-building circulation increase access and operational coordination requirements.',94,
      'High-density federal research campus with documented multi-building footprint and current janitorial procurement signal.',
      'https://www.nrc.canada.ca/en/corporate/contact-us/locations-across-canada','NRC official locations','high',now());
  end if;

  select id into prop_id from public.properties where workspace_id=w and name='NRC Ottawa — Sussex Campus';
  if not exists(select 1 from public.property_intelligence where property_id=prop_id) then
    insert into public.property_intelligence(workspace_id,property_id,building_count,property_class,ownership_type,grounds_scope,snow_scope,janitorial_scope,procurement_signal,seasonal_priority,liability_signal,intelligence_score,intelligence_summary,primary_source_url,primary_source_label,data_confidence,verified_at)
    values(w,prop_id,1,'federal research campus','Crown-owned',
      'Site-specific exterior scope to be confirmed from solicitation package.',
      'Winter service applies to site access and pedestrian circulation.',
      'NRC current Ottawa janitorial solicitation includes Sussex as a named site.',
      'Current 2026 Ottawa janitorial procurement plus official facility/location evidence.',
      'winter + year-round','Research/lab occupancy and public/researcher access require controlled service windows.',91,
      'Federal NRC research site at 100 Sussex Drive with current procurement relevance.',
      'https://www.nrc.canada.ca/en/corporate/contact-us/locations-across-canada','NRC official locations','high',now());
  end if;

  select id into prop_id from public.properties where workspace_id=w and name='NRC Ottawa — Uplands / Aerospace Campus';
  if not exists(select 1 from public.property_intelligence where property_id=prop_id) then
    insert into public.property_intelligence(workspace_id,property_id,building_count,property_class,ownership_type,grounds_scope,snow_scope,janitorial_scope,procurement_signal,seasonal_priority,liability_signal,intelligence_score,intelligence_summary,primary_source_url,primary_source_label,data_confidence,verified_at)
    values(w,prop_id,6,'federal aerospace/research campus','Crown-owned',
      'Multi-building aerospace campus; exterior scope should be confirmed against solicitation documents.',
      'Winter access across Research Private and associated facilities is a material operating consideration.',
      'Current Ottawa janitorial procurement identifies Uplands among NRC office/site coverage.',
      'Current procurement plus official NRC location and facility evidence.',
      'winter + year-round','Aerospace/research facilities create controlled access and operational continuity constraints.',93,
      'Multi-building NRC aerospace campus with documented research facilities and current procurement signal.',
      'https://www.nrc.canada.ca/en/research-development/nrc-facilities','NRC official facilities','high',now());
  end if;

  select id into tender_id from public.tender_records where workspace_id=w and external_id='cb-708-64614973' limit 1;
  if tender_id is not null then
    update public.tender_records set action_state='researching', next_action='Confirm mandatory site-visit / bid requirements and map exact NRC service buildings', next_action_due_at='2026-09-30T17:00:00-04:00' where id=tender_id;
    for prop_id in select id from public.properties where workspace_id=w and name in ('NRC Ottawa — Montreal Road Campus','NRC Ottawa — Sussex Campus','NRC Ottawa — Uplands / Aerospace Campus')
    loop
      insert into public.tender_properties(workspace_id,tender_record_id,property_id,scope_note,evidence_url,evidence_label,source_confidence,verified_at)
      values(w,tender_id,prop_id,'NRC Ottawa Offices Janitorial Services names Ottawa sites including this campus; exact building-level inclusions remain solicitation-package dependent.','https://www.nrc.canada.ca/en/corporate/contact-us/locations-across-canada','NRC official locations','high',now())
      on conflict(tender_record_id,property_id) do update set scope_note=excluded.scope_note,evidence_url=excluded.evidence_url,evidence_label=excluded.evidence_label,source_confidence=excluded.source_confidence,verified_at=excluded.verified_at;
    end loop;
  end if;
end $$;
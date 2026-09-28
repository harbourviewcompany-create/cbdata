-- Regional Procurement Coverage Engine
-- Raw-opportunity universe, buyer coverage, award/rebid intelligence, and coverage dashboard.

create table if not exists public.procurement_buyers (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  organization_id uuid references public.organizations(id) on delete set null,
  buyer_key text not null,
  display_name text not null,
  sector text not null default 'other',
  jurisdiction text,
  region text,
  primary_source_key text,
  portal_url text,
  registration_url text,
  coverage_status text not null default 'gap'
    check (coverage_status in ('monitored','partial','gap','dormant')),
  watch_priority integer not null default 50 check (watch_priority between 0 and 100),
  service_fit text[] not null default '{}',
  facility_count integer,
  last_opportunity_at timestamptz,
  last_award_at timestamptz,
  next_expected_procurement_at timestamptz,
  last_scanned_at timestamptz,
  source_confidence text not null default 'medium',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(workspace_id,buyer_key)
);

create table if not exists public.procurement_opportunities (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  source_key text not null,
  external_id text not null,
  buyer_key text,
  buyer_name text,
  title text not null,
  opportunity_type text not null default 'other'
    check (opportunity_type in ('tender','rfq','standing_offer','prequalification','vendor_roster','planned_procurement','award','rebid_signal','other')),
  description text,
  category text,
  region text,
  published_at timestamptz,
  closing_at timestamptz,
  estimated_value numeric,
  currency text not null default 'CAD',
  source_url text not null,
  service_fit text[] not null default '{}',
  relevance_score numeric check (relevance_score is null or relevance_score between 0 and 100),
  classification_status text not null default 'unclassified'
    check (classification_status in ('unclassified','actionable','watch','suppressed','promoted','closed')),
  score_breakdown jsonb not null default '{}'::jsonb,
  matched_organization_id uuid references public.organizations(id) on delete set null,
  matched_target_id uuid references public.outreach_targets(id) on delete set null,
  promoted_tender_record_id uuid references public.tender_records(id) on delete set null,
  raw_payload jsonb,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(workspace_id,source_key,external_id)
);

create table if not exists public.procurement_awards (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  source_key text not null,
  external_id text not null,
  buyer_key text,
  buyer_name text,
  title text not null,
  awarded_to text,
  award_amount numeric,
  currency text not null default 'CAD',
  award_date date,
  contract_start_date date,
  contract_end_date date,
  option_end_date date,
  expected_rebid_date date,
  source_url text not null,
  raw_payload jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(workspace_id,source_key,external_id)
);

create table if not exists public.procurement_coverage_runs (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  status text not null default 'running'
    check (status in ('running','completed','partial','error')),
  buyers_checked integer not null default 0,
  opportunities_classified integer not null default 0,
  actionable_count integer not null default 0,
  watch_count integer not null default 0,
  targets_created integer not null default 0,
  signals_created integer not null default 0,
  tenders_promoted integer not null default 0,
  coverage_gaps integer not null default 0,
  source_errors jsonb not null default '[]'::jsonb,
  error_message text,
  created_at timestamptz not null default now()
);

create index if not exists idx_procurement_buyers_workspace_status
  on public.procurement_buyers(workspace_id,coverage_status,watch_priority desc);
create index if not exists idx_procurement_buyers_org
  on public.procurement_buyers(organization_id);
create index if not exists idx_procurement_opportunities_queue
  on public.procurement_opportunities(workspace_id,classification_status,relevance_score desc,closing_at);
create index if not exists idx_procurement_opportunities_buyer
  on public.procurement_opportunities(workspace_id,buyer_key,last_seen_at desc);
create index if not exists idx_procurement_opportunities_org
  on public.procurement_opportunities(matched_organization_id);
create index if not exists idx_procurement_opportunities_target
  on public.procurement_opportunities(matched_target_id);
create index if not exists idx_procurement_opportunities_tender
  on public.procurement_opportunities(promoted_tender_record_id);
create index if not exists idx_procurement_awards_buyer_rebid
  on public.procurement_awards(workspace_id,buyer_key,expected_rebid_date);
create index if not exists idx_procurement_coverage_runs_workspace_started
  on public.procurement_coverage_runs(workspace_id,started_at desc);

do $$
declare t text;
begin
  foreach t in array array['procurement_buyers','procurement_opportunities','procurement_awards','procurement_coverage_runs']
  loop
    execute format('alter table public.%I enable row level security',t);
    execute format('alter table public.%I force row level security',t);
    execute format('drop policy if exists workspace_member_select on public.%I',t);
    execute format('create policy workspace_member_select on public.%I for select to authenticated using (private.is_workspace_member(workspace_id))',t);
    execute format('revoke all on public.%I from anon',t);
    execute format('revoke insert,update,delete,truncate,references,trigger on public.%I from authenticated',t);
    execute format('grant select on public.%I to authenticated',t);
    execute format('grant all on public.%I to service_role',t);
  end loop;
end $$;

create or replace view public.v_procurement_buyer_coverage
with (security_invoker = true)
as
select
  b.id,
  b.workspace_id,
  b.organization_id,
  b.buyer_key,
  b.display_name,
  b.sector,
  b.jurisdiction,
  b.region,
  b.primary_source_key,
  b.portal_url,
  b.registration_url,
  b.coverage_status,
  b.watch_priority,
  b.service_fit,
  b.facility_count,
  b.last_opportunity_at,
  b.last_award_at,
  b.next_expected_procurement_at,
  b.last_scanned_at,
  b.source_confidence,
  coalesce(o.operating_name,o.legal_name) as organization_name,
  count(distinct po.id) filter (
    where po.classification_status in ('actionable','watch','promoted')
      and (po.closing_at is null or po.closing_at >= now())
  )::integer as open_opportunity_count,
  count(distinct po.id) filter (
    where po.classification_status in ('actionable','promoted')
      and (po.closing_at is null or po.closing_at >= now())
  )::integer as actionable_count,
  max(po.relevance_score) filter (
    where po.closing_at is null or po.closing_at >= now()
  ) as best_open_score,
  max(pa.expected_rebid_date) as expected_rebid_date,
  max(ot.score) as target_score,
  bool_or(ot.id is not null) as has_target,
  count(distinct oc.contact_id)::integer as known_contact_count
from public.procurement_buyers b
left join public.organizations o on o.id=b.organization_id
left join public.procurement_opportunities po
  on po.workspace_id=b.workspace_id and po.buyer_key=b.buyer_key
left join public.procurement_awards pa
  on pa.workspace_id=b.workspace_id and pa.buyer_key=b.buyer_key
left join public.outreach_targets ot
  on ot.workspace_id=b.workspace_id and ot.organization_id=b.organization_id
left join public.organization_contacts oc
  on oc.workspace_id=b.workspace_id and oc.organization_id=b.organization_id
group by b.id,o.operating_name,o.legal_name;

grant select on public.v_procurement_buyer_coverage to authenticated;

do $$
declare
  w uuid;
begin
  select id into w from public.workspaces where slug='cb-contracting' limit 1;
  if w is null then return; end if;

  insert into public.procurement_buyers(
    workspace_id,buyer_key,display_name,sector,jurisdiction,region,primary_source_key,
    coverage_status,watch_priority,service_fit,source_confidence
  )
  select w,v.buyer_key,v.display_name,v.sector,v.jurisdiction,v.region,v.source_key,
         v.coverage_status,v.priority,v.service_fit,v.confidence
  from (values
    ('city-of-ottawa','City of Ottawa','municipal','Ontario','Ottawa / NCR','city_ottawa_merx','monitored',100,array['snow','grounds','janitorial','facility maintenance','paving','construction']::text[],'high'),
    ('ottawa-community-housing','Ottawa Community Housing','housing','Ontario','Ottawa / NCR','och_merx','monitored',100,array['snow','grounds','janitorial','facility maintenance','construction']::text[],'high'),
    ('ncc','National Capital Commission','federal','Federal','Ottawa / Gatineau','canadabuys','monitored',100,array['snow','grounds','landscaping','janitorial','facility maintenance']::text[],'high'),
    ('nrc','National Research Council of Canada','federal','Federal','Ottawa / NCR','canadabuys','monitored',95,array['janitorial','snow','facility maintenance','mechanical','sheet metal']::text[],'high'),
    ('pspc','Public Services and Procurement Canada','federal','Federal','Ottawa / NCR','canadabuys','monitored',100,array['facility maintenance','janitorial','snow','mechanical','construction']::text[],'high'),
    ('dnd','Department of National Defence','federal','Federal','Ottawa / NCR','canadabuys','monitored',90,array['facility maintenance','snow','grounds','mechanical','construction']::text[],'high'),
    ('rcmp','Royal Canadian Mounted Police','federal','Federal','Ottawa / NCR','canadabuys','monitored',85,array['facility maintenance','janitorial','snow','construction']::text[],'high'),
    ('ocdsb','Ottawa-Carleton District School Board','education','Ontario','Ottawa','ocdsb_bids_tenders','monitored',100,array['snow','grounds','janitorial','facility maintenance','roofing','mechanical','construction']::text[],'high'),
    ('ocsb','Ottawa Catholic School Board','education','Ontario','Ottawa','ocsb_bids_tenders','monitored',100,array['snow','grounds','janitorial','facility maintenance','roofing','mechanical','construction']::text[],'high'),
    ('cepeo','Conseil des écoles publiques de l''Est de l''Ontario','education','Ontario','Ottawa / Eastern Ontario','institutions','partial',90,array['snow','grounds','janitorial','facility maintenance','construction']::text[],'medium'),
    ('cecce','Conseil des écoles catholiques du Centre-Est','education','Ontario','Ottawa / Eastern Ontario','institutions','partial',90,array['snow','grounds','janitorial','facility maintenance','construction']::text[],'medium'),
    ('uottawa','University of Ottawa','postsecondary','Ontario','Ottawa','city_merx','partial',90,array['janitorial','grounds','snow','facility maintenance','mechanical','construction']::text[],'medium'),
    ('carleton','Carleton University','postsecondary','Ontario','Ottawa','institutions','gap',90,array['janitorial','grounds','snow','facility maintenance','mechanical','construction']::text[],'medium'),
    ('algonquin','Algonquin College','postsecondary','Ontario','Ottawa','institutions','partial',90,array['janitorial','grounds','snow','facility maintenance','mechanical','construction']::text[],'medium'),
    ('la-cite','La Cité','postsecondary','Ontario','Ottawa','institutions','gap',75,array['janitorial','grounds','snow','facility maintenance','construction']::text[],'medium'),
    ('ottawa-hospital','The Ottawa Hospital','healthcare','Ontario','Ottawa','institutions','partial',95,array['janitorial','facility maintenance','mechanical','snow','construction']::text[],'medium'),
    ('cheo','Children''s Hospital of Eastern Ontario','healthcare','Ontario','Ottawa','institutions','partial',90,array['janitorial','facility maintenance','mechanical','snow','construction']::text[],'medium'),
    ('montfort','Hôpital Montfort','healthcare','Ontario','Ottawa','institutions','partial',85,array['janitorial','facility maintenance','mechanical','snow','construction']::text[],'medium'),
    ('bruyere','Bruyère Health','healthcare','Ontario','Ottawa','institutions','partial',85,array['janitorial','facility maintenance','mechanical','snow','construction']::text[],'medium'),
    ('royal-ottawa','The Royal Ottawa Health Care Group','healthcare','Ontario','Ottawa','institutions','gap',80,array['janitorial','facility maintenance','mechanical','snow','construction']::text[],'medium'),
    ('ville-gatineau','Ville de Gatineau','municipal','Québec','Gatineau / Outaouais','gatineau_open_data','monitored',95,array['snow','grounds','janitorial','facility maintenance','paving','construction']::text[],'high'),
    ('cisss-outaouais','CISSS de l''Outaouais','healthcare','Québec','Gatineau / Outaouais','seao','partial',85,array['janitorial','facility maintenance','mechanical','snow','construction']::text[],'medium'),
    ('sto','Société de transport de l''Outaouais','transit','Québec','Gatineau / Outaouais','seao','partial',80,array['snow','janitorial','facility maintenance','paving','construction']::text[],'medium'),
    ('ottawa-police','Ottawa Police Service','municipal','Ontario','Ottawa','city_ottawa_merx','partial',75,array['janitorial','facility maintenance','snow','construction']::text[],'medium'),
    ('ottawa-library','Ottawa Public Library','municipal','Ontario','Ottawa','city_ottawa_merx','partial',75,array['janitorial','facility maintenance','snow','construction']::text[],'medium')
  ) as v(buyer_key,display_name,sector,jurisdiction,region,source_key,coverage_status,priority,service_fit,confidence)
  on conflict(workspace_id,buyer_key) do update set
    display_name=excluded.display_name,
    sector=excluded.sector,
    jurisdiction=excluded.jurisdiction,
    region=excluded.region,
    primary_source_key=excluded.primary_source_key,
    watch_priority=excluded.watch_priority,
    service_fit=excluded.service_fit,
    source_confidence=excluded.source_confidence,
    updated_at=now();

  update public.procurement_buyers b
  set organization_id=o.id, updated_at=now()
  from public.organizations o
  where b.workspace_id=w and o.workspace_id=w and b.organization_id is null
    and (
      lower(o.legal_name)=lower(b.display_name)
      or lower(coalesce(o.operating_name,''))=lower(b.display_name)
      or (b.buyer_key='ncc' and lower(o.legal_name)='national capital commission')
      or (b.buyer_key='nrc' and lower(o.legal_name)='national research council of canada')
    );
end $$;

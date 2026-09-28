-- Tender Intelligence v3
alter table public.tender_sources
  add column if not exists coverage_tier text not null default 'watch'
    check (coverage_tier in ('live','watch','manual')),
  add column if not exists adapter_status text not null default 'unverified'
    check (adapter_status in ('active','unverified','blocked','manual_only')),
  add column if not exists buyer_scope text,
  add column if not exists last_verified_at timestamptz;

alter table public.tender_documents
  add column if not exists extraction_status text not null default 'not_started'
    check (extraction_status in ('not_started','queued','parsed','needs_text_extraction','error')),
  add column if not exists extracted_text text,
  add column if not exists intelligence jsonb not null default '{}'::jsonb,
  add column if not exists parsed_at timestamptz;

create table if not exists public.tender_pursuit_intelligence (
  tender_record_id uuid primary key references public.tender_records(id) on delete cascade,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  pursuit_mode text not null default 'review'
    check (pursuit_mode in ('prime_bid','subtrade','standing_offer','vendor_list','invite_only','future_rebid','review','no_fit')),
  scope_fit integer not null default 0 check (scope_fit between 0 and 100),
  eligibility integer not null default 0 check (eligibility between 0 and 100),
  commercial_attractiveness integer not null default 0 check (commercial_attractiveness between 0 and 100),
  geographic_fit integer not null default 0 check (geographic_fit between 0 and 100),
  timing integer not null default 0 check (timing between 0 and 100),
  competition integer not null default 0 check (competition between 0 and 100),
  strategic_value integer not null default 0 check (strategic_value between 0 and 100),
  subtrade_potential integer not null default 0 check (subtrade_potential between 0 and 100),
  overall_score integer not null default 0 check (overall_score between 0 and 100),
  rationale text,
  next_best_action text,
  evidence jsonb not null default '{}'::jsonb,
  calculated_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists tender_pursuit_intelligence_workspace_score_idx
  on public.tender_pursuit_intelligence(workspace_id,overall_score desc,pursuit_mode);

create table if not exists public.tender_subtrade_opportunities (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  tender_record_id uuid not null references public.tender_records(id) on delete cascade,
  trade text not null,
  package_title text not null,
  scope_summary text,
  fit_score integer not null default 0 check (fit_score between 0 and 100),
  pursuit_status text not null default 'identified'
    check (pursuit_status in ('identified','researching_primes','outreach','pricing','submitted','won','lost','not_pursuing')),
  suggested_action text,
  due_at timestamptz,
  target_primes jsonb not null default '[]'::jsonb,
  evidence jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(workspace_id,tender_record_id,trade)
);

create index if not exists tender_subtrade_workspace_status_idx
  on public.tender_subtrade_opportunities(workspace_id,pursuit_status,fit_score desc);
create index if not exists tender_subtrade_tender_idx
  on public.tender_subtrade_opportunities(tender_record_id);

create table if not exists public.procurement_contract_cycles (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  organization_id uuid references public.organizations(id) on delete set null,
  source_tender_id uuid references public.tender_records(id) on delete set null,
  buyer_name text not null,
  service_category text not null,
  incumbent_name text,
  award_value numeric,
  currency text not null default 'CAD',
  contract_start_date date,
  contract_end_date date,
  expected_rebid_date date,
  confidence text not null default 'medium'
    check (confidence in ('low','medium','high')),
  evidence_url text,
  source text,
  notes text,
  status text not null default 'active'
    check (status in ('active','expired','recompete_expected','recompete_open','unknown')),
  last_verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists procurement_contract_cycles_source_tender_uidx
  on public.procurement_contract_cycles(workspace_id,source_tender_id,service_category)
  where source_tender_id is not null;
create index if not exists procurement_contract_cycles_rebid_idx
  on public.procurement_contract_cycles(workspace_id,expected_rebid_date,status);
create index if not exists procurement_contract_cycles_org_idx
  on public.procurement_contract_cycles(organization_id);

create table if not exists public.procurement_future_opportunities (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  contract_cycle_id uuid references public.procurement_contract_cycles(id) on delete cascade,
  organization_id uuid references public.organizations(id) on delete set null,
  buyer_name text not null,
  title text not null,
  service_category text not null,
  signal_type text not null default 'contract_cycle'
    check (signal_type in ('contract_cycle','capital_plan','budget','planned_procurement','award_rebid','relationship','manual')),
  expected_publish_start date,
  expected_publish_end date,
  fit_score integer not null default 0 check (fit_score between 0 and 100),
  confidence text not null default 'medium'
    check (confidence in ('low','medium','high')),
  status text not null default 'watch'
    check (status in ('watch','research','pre_position','published','converted','closed')),
  source_url text,
  evidence jsonb not null default '{}'::jsonb,
  next_action text,
  next_action_at timestamptz,
  linked_tender_id uuid references public.tender_records(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists procurement_future_cycle_uidx
  on public.procurement_future_opportunities(workspace_id,contract_cycle_id)
  where contract_cycle_id is not null;
create index if not exists procurement_future_pipeline_idx
  on public.procurement_future_opportunities(workspace_id,status,expected_publish_start,fit_score desc);

alter table public.tender_pursuit_intelligence enable row level security;
alter table public.tender_subtrade_opportunities enable row level security;
alter table public.procurement_contract_cycles enable row level security;
alter table public.procurement_future_opportunities enable row level security;

drop policy if exists tender_pursuit_intelligence_member on public.tender_pursuit_intelligence;
create policy tender_pursuit_intelligence_member on public.tender_pursuit_intelligence for all to authenticated
  using (private.is_workspace_member(workspace_id)) with check (private.is_workspace_member(workspace_id));
drop policy if exists tender_subtrade_member on public.tender_subtrade_opportunities;
create policy tender_subtrade_member on public.tender_subtrade_opportunities for all to authenticated
  using (private.is_workspace_member(workspace_id)) with check (private.is_workspace_member(workspace_id));
drop policy if exists procurement_contract_cycles_member on public.procurement_contract_cycles;
create policy procurement_contract_cycles_member on public.procurement_contract_cycles for all to authenticated
  using (private.is_workspace_member(workspace_id)) with check (private.is_workspace_member(workspace_id));
drop policy if exists procurement_future_member on public.procurement_future_opportunities;
create policy procurement_future_member on public.procurement_future_opportunities for all to authenticated
  using (private.is_workspace_member(workspace_id)) with check (private.is_workspace_member(workspace_id));

revoke all on public.tender_pursuit_intelligence from anon;
revoke all on public.tender_subtrade_opportunities from anon;
revoke all on public.procurement_contract_cycles from anon;
revoke all on public.procurement_future_opportunities from anon;
grant select,insert,update,delete on public.tender_pursuit_intelligence to authenticated;
grant select,insert,update,delete on public.tender_subtrade_opportunities to authenticated;
grant select,insert,update,delete on public.procurement_contract_cycles to authenticated;
grant select,insert,update,delete on public.procurement_future_opportunities to authenticated;
grant all on public.tender_pursuit_intelligence to service_role;
grant all on public.tender_subtrade_opportunities to service_role;
grant all on public.procurement_contract_cycles to service_role;
grant all on public.procurement_future_opportunities to service_role;

insert into public.tender_sources(workspace_id,source_key,display_name,source_url,ingestion_mode,coverage_tier,adapter_status,buyer_scope,enabled)
select id,'seao','SEAO Québec','https://www.seao.ca/','external_watch','watch','manual_only','Québec ministries, agencies, municipalities, health and education',true from public.workspaces
on conflict(workspace_id,source_key) do update set coverage_tier='watch',adapter_status='manual_only',buyer_scope=excluded.buyer_scope,enabled=true;
insert into public.tender_sources(workspace_id,source_key,display_name,source_url,ingestion_mode,coverage_tier,adapter_status,buyer_scope,enabled)
select id,'biddingo','Biddingo','https://www.biddingo.com/','external_watch','watch','manual_only','Healthcare, municipal and institutional buyers',true from public.workspaces
on conflict(workspace_id,source_key) do update set coverage_tier='watch',adapter_status='manual_only',buyer_scope=excluded.buyer_scope,enabled=true;
insert into public.tender_sources(workspace_id,source_key,display_name,source_url,ingestion_mode,coverage_tier,adapter_status,buyer_scope,enabled)
select id,'bonfire_euna','Bonfire / Euna','https://eunasolutions.com/','external_watch','watch','manual_only','Institutional RFx document and submission portals',true from public.workspaces
on conflict(workspace_id,source_key) do update set coverage_tier='watch',adapter_status='manual_only',buyer_scope=excluded.buyer_scope,enabled=true;
insert into public.tender_sources(workspace_id,source_key,display_name,source_url,ingestion_mode,coverage_tier,adapter_status,buyer_scope,enabled)
select id,'oca','Ottawa Construction Association','https://www.oca.ca/','external_watch','watch','manual_only','Ottawa construction opportunities and plan-room work',true from public.workspaces
on conflict(workspace_id,source_key) do update set coverage_tier='watch',adapter_status='manual_only',buyer_scope=excluded.buyer_scope,enabled=true;
insert into public.tender_sources(workspace_id,source_key,display_name,source_url,ingestion_mode,coverage_tier,adapter_status,buyer_scope,enabled)
select id,'carleton_procurement','Carleton University Procurement','https://carleton.ca/procurement/','external_watch','watch','manual_only','University facilities, capital renewal and services',true from public.workspaces
on conflict(workspace_id,source_key) do update set coverage_tier='watch',adapter_status='manual_only',buyer_scope=excluded.buyer_scope,enabled=true;
insert into public.tender_sources(workspace_id,source_key,display_name,source_url,ingestion_mode,coverage_tier,adapter_status,buyer_scope,enabled)
select id,'uottawa_procurement','University of Ottawa Procurement','https://www.uottawa.ca/about-us/administration-services/procurement','external_watch','watch','manual_only','University facilities, capital renewal and services',true from public.workspaces
on conflict(workspace_id,source_key) do update set coverage_tier='watch',adapter_status='manual_only',buyer_scope=excluded.buyer_scope,enabled=true;
insert into public.tender_sources(workspace_id,source_key,display_name,source_url,ingestion_mode,coverage_tier,adapter_status,buyer_scope,enabled)
select id,'algonquin_procurement','Algonquin College Procurement','https://www.algonquincollege.com/','external_watch','watch','manual_only','College facilities and capital work',true from public.workspaces
on conflict(workspace_id,source_key) do update set coverage_tier='watch',adapter_status='manual_only',buyer_scope=excluded.buyer_scope,enabled=true;
insert into public.tender_sources(workspace_id,source_key,display_name,source_url,ingestion_mode,coverage_tier,adapter_status,buyer_scope,enabled)
select id,'ottawa_hospital_procurement','The Ottawa Hospital Procurement','https://www.ottawahospital.on.ca/','external_watch','watch','manual_only','Hospital facilities and institutional procurement',true from public.workspaces
on conflict(workspace_id,source_key) do update set coverage_tier='watch',adapter_status='manual_only',buyer_scope=excluded.buyer_scope,enabled=true;

update public.tender_sources
set coverage_tier=case when ingestion_mode='live' then 'live' when ingestion_mode='external_watch' then 'watch' else coverage_tier end,
    adapter_status=case when ingestion_mode='live' then 'active' when ingestion_mode='external_watch' and adapter_status='unverified' then 'manual_only' else adapter_status end,
    last_verified_at=coalesce(last_verified_at,last_success_at,updated_at)
where coverage_tier='watch' or adapter_status='unverified';

create or replace view public.v_procurement_intelligence with (security_invoker=true) as
select t.id tender_record_id,t.workspace_id,t.external_id,t.title,t.buyer_name,t.source,t.region,t.closing_date,
  t.fit_score discovery_fit_score,pi.pursuit_mode,pi.scope_fit,pi.eligibility,pi.commercial_attractiveness,
  pi.geographic_fit,pi.timing,pi.competition,pi.strategic_value,pi.subtrade_potential,pi.overall_score,
  pi.next_best_action,pi.rationale,coalesce(st.subtrade_count,0)::int subtrade_count,
  coalesce(st.best_subtrade_score,0)::int best_subtrade_score,coalesce(fc.future_signal_count,0)::int future_signal_count
from public.tender_records t
left join public.tender_pursuit_intelligence pi on pi.tender_record_id=t.id
left join lateral (select count(*) subtrade_count,max(fit_score) best_subtrade_score from public.tender_subtrade_opportunities s where s.tender_record_id=t.id) st on true
left join lateral (select count(*) future_signal_count from public.procurement_future_opportunities f where f.linked_tender_id=t.id) fc on true;
grant select on public.v_procurement_intelligence to authenticated;
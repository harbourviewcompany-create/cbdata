-- Contact + opportunity coverage engine
-- Production migration: 20261006115102
-- Expands buying-committee role coverage, feeds the existing contact researcher,
-- and makes small-RFQ/vendor-roster/standing-offer channels first-class procurement sources.

alter table public.contact_enrichment_tasks
  drop constraint if exists contact_enrichment_tasks_missing_role_check;
alter table public.contact_enrichment_tasks
  add constraint contact_enrichment_tasks_missing_role_check
  check (missing_role in (
    'decision_maker','operations','procurement','property_manager','facilities','project_manager'
  ));

create table if not exists public.outreach_contact_role_requirements (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  organization_type text not null,
  buying_role text not null,
  min_contacts smallint not null default 1 check (min_contacts between 1 and 5),
  weight smallint not null default 10 check (weight between 1 and 50),
  required boolean not null default true,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key(workspace_id,organization_type,buying_role)
);
alter table public.outreach_contact_role_requirements enable row level security;
drop policy if exists outreach_contact_role_requirements_member_select on public.outreach_contact_role_requirements;
create policy outreach_contact_role_requirements_member_select
on public.outreach_contact_role_requirements for select to authenticated
using (private.is_workspace_member(workspace_id));
revoke all on public.outreach_contact_role_requirements from public,anon,authenticated;
grant select on public.outreach_contact_role_requirements to authenticated;
grant all on public.outreach_contact_role_requirements to service_role;

with ws as (
  select distinct workspace_id from public.outreach_targets
), req(organization_type,buying_role,min_contacts,weight) as (
  values
    ('property_manager','decision_maker',1,20),
    ('property_manager','operations',1,18),
    ('property_manager','property_manager',1,18),
    ('property_manager','procurement',1,16),
    ('property_manager','facilities',1,14),
    ('owner','decision_maker',1,20),
    ('owner','operations',1,18),
    ('owner','facilities',1,18),
    ('owner','procurement',1,16),
    ('owner','project_manager',1,14),
    ('condo_corporation','decision_maker',1,22),
    ('condo_corporation','property_manager',1,20),
    ('condo_corporation','operations',1,18),
    ('condo_corporation','procurement',1,14),
    ('prospect','decision_maker',1,22),
    ('prospect','operations',1,20),
    ('prospect','procurement',1,18),
    ('prospect','project_manager',1,16),
    ('other','decision_maker',1,24),
    ('other','operations',1,20),
    ('other','procurement',1,18)
)
insert into public.outreach_contact_role_requirements(
  workspace_id,organization_type,buying_role,min_contacts,weight
)
select ws.workspace_id,req.organization_type,req.buying_role,req.min_contacts,req.weight
from ws cross join req
on conflict(workspace_id,organization_type,buying_role) do update set
  min_contacts=excluded.min_contacts,
  weight=excluded.weight,
  active=true,
  updated_at=now();

create or replace view public.v_outreach_account_contact_coverage
with (security_invoker=true)
as
with ranked_targets as (
  select t.*,
    row_number() over (
      partition by t.workspace_id,coalesce(t.pursuit_id,t.organization_id,t.id)
      order by coalesce(t.score,0) desc,t.updated_at desc,t.id
    ) rn
  from public.outreach_targets t
  left join public.outreach_pursuits p on p.id=t.pursuit_id
  where coalesce(t.status::text,'') not in ('converted','do_not_contact','lost')
    and coalesce(p.status,'active') not in ('closed','lost','won')
),
base as (
  select
    t.workspace_id,t.id outreach_target_id,t.pursuit_id,t.organization_id,
    coalesce(o.operating_name,o.legal_name,t.organization_name) organization_name,
    case when o.organization_type::text in ('property_manager','owner','condo_corporation','prospect','other')
      then o.organization_type::text else 'other' end organization_type,
    coalesce(t.score,0)::numeric target_score
  from ranked_targets t
  left join public.organizations o on o.id=t.organization_id
  where t.rn=1
),
contact_stats as (
  select b.outreach_target_id,
    count(distinct bc.contact_id)::int contact_count,
    count(distinct bc.contact_id) filter(where nullif(btrim(bc.email),'') is not null)::int email_contact_count,
    count(distinct bc.contact_id) filter(where nullif(btrim(bc.phone),'') is not null)::int phone_contact_count
  from base b
  left join public.v_outreach_buying_committee bc on bc.outreach_target_id=b.outreach_target_id
  group by b.outreach_target_id
),
role_gap as (
  select
    b.workspace_id,b.outreach_target_id,b.pursuit_id,b.organization_id,b.organization_name,b.organization_type,b.target_score,
    r.buying_role,r.min_contacts,r.weight,
    count(distinct bc.contact_id) filter(where bc.buying_role=r.buying_role)::int have_contacts
  from base b
  join public.outreach_contact_role_requirements r
    on r.workspace_id=b.workspace_id
   and r.organization_type=b.organization_type
   and r.active and r.required
  left join public.v_outreach_buying_committee bc on bc.outreach_target_id=b.outreach_target_id
  group by b.workspace_id,b.outreach_target_id,b.pursuit_id,b.organization_id,b.organization_name,b.organization_type,b.target_score,
           r.buying_role,r.min_contacts,r.weight
),
role_summary as (
  select
    workspace_id,outreach_target_id,pursuit_id,organization_id,organization_name,organization_type,target_score,
    sum(min_contacts)::int required_contact_slots,
    sum(least(have_contacts,min_contacts))::int satisfied_contact_slots,
    coalesce(array_agg(buying_role order by weight desc,buying_role)
      filter(where have_contacts<min_contacts),'{}'::text[]) missing_roles
  from role_gap
  group by workspace_id,outreach_target_id,pursuit_id,organization_id,organization_name,organization_type,target_score
),
signals as (
  select b.outreach_target_id,
    count(distinct s.id) filter(
      where s.status='open' and coalesce(s.deadline_at,now()+interval '1 day')>=now()
    )::int live_signal_count
  from base b
  left join public.target_opportunity_signals s
    on s.workspace_id=b.workspace_id
   and (s.target_id=b.outreach_target_id or (b.organization_id is not null and s.organization_id=b.organization_id))
  group by b.outreach_target_id
),
work_leads as (
  select b.outreach_target_id,
    count(distinct w.id) filter(where w.status in ('new','qualified','promoted'))::int open_work_lead_count
  from base b
  left join public.outreach_work_leads w
    on w.workspace_id=b.workspace_id
   and (w.outreach_target_id=b.outreach_target_id
     or (b.pursuit_id is not null and w.pursuit_id=b.pursuit_id)
     or (b.organization_id is not null and w.matched_organization_id=b.organization_id))
  group by b.outreach_target_id
),
procurement as (
  select b.outreach_target_id,
    count(distinct po.id) filter(
      where po.classification_status in ('actionable','watch','promoted')
        and (po.closing_at is null or po.closing_at>=now())
    )::int open_procurement_count
  from base b
  left join public.procurement_opportunities po
    on po.workspace_id=b.workspace_id
   and (po.matched_target_id=b.outreach_target_id
     or (b.organization_id is not null and po.matched_organization_id=b.organization_id))
  group by b.outreach_target_id
),
scored as (
  select rs.*,
    coalesce(cs.contact_count,0) contact_count,
    coalesce(cs.email_contact_count,0) email_contact_count,
    coalesce(cs.phone_contact_count,0) phone_contact_count,
    coalesce(s.live_signal_count,0) live_signal_count,
    coalesce(w.open_work_lead_count,0) open_work_lead_count,
    coalesce(pr.open_procurement_count,0) open_procurement_count,
    least(100,greatest(0,round(
      70*coalesce(rs.satisfied_contact_slots::numeric/nullif(rs.required_contact_slots,0),0)
      + least(coalesce(cs.contact_count,0),5)*3
      + least(coalesce(cs.email_contact_count,0),3)*3
      + least(coalesce(cs.phone_contact_count,0),2)*3
    )))::int contact_coverage_score
  from role_summary rs
  left join contact_stats cs using(outreach_target_id)
  left join signals s using(outreach_target_id)
  left join work_leads w using(outreach_target_id)
  left join procurement pr using(outreach_target_id)
)
select scored.*,
  case
    when cardinality(missing_roles)=0 and contact_count>=3 then 'complete'
    when contact_coverage_score>=70 then 'good'
    when contact_coverage_score>=40 then 'thin'
    else 'critical'
  end coverage_status,
  least(100,greatest(0,round(
    (100-contact_coverage_score)*0.45
    + least(target_score,100)*0.30
    + least(live_signal_count,3)*7
    + least(open_work_lead_count,3)*8
    + least(open_procurement_count,3)*8
  )))::int research_priority_score
from scored;
grant select on public.v_outreach_account_contact_coverage to authenticated,service_role;

create or replace function public.refresh_contact_coverage_tasks_system(p_workspace_id uuid)
returns jsonb
language plpgsql
set search_path=pg_catalog,public
as $$
declare v_upserted integer:=0; v_closed integer:=0;
begin
  insert into public.contact_enrichment_tasks(
    workspace_id,outreach_target_id,organization_id,missing_role,priority_score,status,
    research_query,research_priority_score,research_priority_reason,research_urgency_rank,
    researcher_metadata,next_attempt_at,updated_at
  )
  select
    c.workspace_id,c.outreach_target_id,c.organization_id,role_name,c.research_priority_score,'queued',
    concat('"',c.organization_name,'" "',replace(role_name,'_',' '),'" Ottawa Ontario contact email phone LinkedIn'),
    c.research_priority_score,
    concat('Coverage ',c.contact_coverage_score,'/100; ',c.contact_count,' known contacts; ',
      c.live_signal_count,' live signals; ',c.open_work_lead_count,' work leads; ',
      c.open_procurement_count,' procurement opportunities'),
    greatest(1,100-c.research_priority_score),
    jsonb_build_object(
      'source','contact_coverage_engine','pursuit_id',c.pursuit_id,'coverage_score',c.contact_coverage_score,
      'coverage_status',c.coverage_status,'known_contacts',c.contact_count,
      'live_signal_count',c.live_signal_count,'open_work_lead_count',c.open_work_lead_count,
      'open_procurement_count',c.open_procurement_count
    ),
    now(),now()
  from public.v_outreach_account_contact_coverage c
  cross join lateral unnest(c.missing_roles) role_name
  where c.workspace_id=p_workspace_id
  on conflict(workspace_id,outreach_target_id,missing_role) do update set
    organization_id=excluded.organization_id,
    priority_score=excluded.priority_score,
    research_query=excluded.research_query,
    research_priority_score=excluded.research_priority_score,
    research_priority_reason=excluded.research_priority_reason,
    research_urgency_rank=excluded.research_urgency_rank,
    researcher_metadata=coalesce(public.contact_enrichment_tasks.researcher_metadata,'{}'::jsonb)||excluded.researcher_metadata,
    next_attempt_at=case when public.contact_enrichment_tasks.status in ('verified','dismissed')
      then public.contact_enrichment_tasks.next_attempt_at
      else least(coalesce(public.contact_enrichment_tasks.next_attempt_at,now()),now()) end,
    status=case when public.contact_enrichment_tasks.status in ('verified','dismissed')
      then public.contact_enrichment_tasks.status else 'queued' end,
    updated_at=now();
  get diagnostics v_upserted=row_count;

  update public.contact_enrichment_tasks e
  set status='verified',verified_at=coalesce(e.verified_at,now()),updated_at=now(),
      researcher_metadata=coalesce(e.researcher_metadata,'{}'::jsonb)||jsonb_build_object('closed_by','contact_coverage_engine')
  from public.v_outreach_account_contact_coverage c
  where e.workspace_id=p_workspace_id
    and c.workspace_id=e.workspace_id
    and c.outreach_target_id=e.outreach_target_id
    and e.status in ('queued','researching','found','not_found')
    and not (e.missing_role=any(c.missing_roles));
  get diagnostics v_closed=row_count;

  return jsonb_build_object('workspace_id',p_workspace_id,'tasks_upserted',v_upserted,'tasks_closed',v_closed);
end
$$;
revoke all on function public.refresh_contact_coverage_tasks_system(uuid) from public,anon,authenticated;
grant execute on function public.refresh_contact_coverage_tasks_system(uuid) to service_role;

create or replace function public.refresh_all_contact_coverage_tasks_system()
returns jsonb
language plpgsql
set search_path=pg_catalog,public
as $$
declare r record; v_total integer:=0;
begin
  for r in select distinct workspace_id from public.outreach_targets loop
    perform public.refresh_contact_coverage_tasks_system(r.workspace_id);
    v_total:=v_total+1;
  end loop;
  return jsonb_build_object('workspaces_refreshed',v_total,'refreshed_at',now());
end
$$;
revoke all on function public.refresh_all_contact_coverage_tasks_system() from public,anon,authenticated;
grant execute on function public.refresh_all_contact_coverage_tasks_system() to service_role;

alter table public.tender_sources
  add column if not exists source_category text not null default 'public_tender',
  add column if not exists discovery_priority integer not null default 50,
  add column if not exists registration_url text,
  add column if not exists contact_strategy text,
  add column if not exists supports_awards boolean not null default false,
  add column if not exists supports_small_jobs boolean not null default false,
  add column if not exists geographic_scope text,
  add column if not exists coverage_notes text;
alter table public.tender_sources drop constraint if exists tender_sources_source_category_check;
alter table public.tender_sources add constraint tender_sources_source_category_check
  check(source_category in ('public_tender','small_rfq','standing_offer','vendor_roster','private_tender',
    'subcontractor_network','award_intelligence','permit_signal','procurement_forecast'));
alter table public.tender_sources drop constraint if exists tender_sources_discovery_priority_check;
alter table public.tender_sources add constraint tender_sources_discovery_priority_check
  check(discovery_priority between 0 and 100);

with ws as (select distinct workspace_id from public.tender_sources),
src(source_key,display_name,source_url,ingestion_mode,coverage_tier,adapter_status,buyer_scope,source_category,discovery_priority,registration_url,contact_strategy,supports_awards,supports_small_jobs,geographic_scope,coverage_notes) as (
  values
  ('city_ottawa_small_rfq','City of Ottawa — Small RFQ / selected supplier channel','https://ottawa.ca/en/business/procurement/bidding-opportunities','external_watch','watch','manual_only','City requirements under $125,000 and selected-supplier invitations','small_rfq',100,'https://www.merx.com/cityofottawa','Maintain direct purchasing contacts, MERX registration, prior-work history and department relationships because some smaller requirements are sent to selected suppliers.',true,true,'Ottawa','Official City guidance confirms smaller opportunities may be advertised or sent directly to selected suppliers.'),
  ('city_ottawa_standing_offers','City of Ottawa — Construction Standing Offers','https://ottawa.ca/en/business/procurement/standing-offers-client-unit/construction','external_watch','watch','manual_only','Construction standing offers, expiry dates and rebid signals','standing_offer',98,'https://www.merx.com/cityofottawa','Track every relevant standing-offer expiry 90/60/30 days out, identify purchasing officer and incumbent vendors, then prepare for rebid.',true,true,'Ottawa','Standing offers reveal repeat-demand categories and future rebid timing.'),
  ('ncc_supplier_list','NCC — Trusted Supplier / Small Opportunity List','https://ncc-ccn.gc.ca/business/contracting-with-the-ncc','external_watch','watch','manual_only','NCC smaller construction and land-maintenance opportunities','vendor_roster',98,'https://ncc-ccn.gc.ca/business/contracting-with-the-ncc','Maintain supplier registration and procurement relationships; smaller NCC opportunities are sourced from a trusted-supplier list.',false,true,'National Capital Region','Public tenders flow through CanadaBuys; smaller opportunities use the NCC trusted-supplier list.'),
  ('yow_bonfire','Ottawa International Airport Authority — Bonfire','https://www.yow.ca/business/procurement-opportunities','external_watch','watch','manual_only','Airport operational tenders, RFPs and qualifications','public_tender',94,'https://www.yow.ca/business/procurement-opportunities','Monitor current YOW opportunities and maintain Bonfire vendor registration; prioritize facilities, repairs, maintenance, mechanical and construction work.',false,true,'Ottawa Airport','Official airport page publishes current operational procurement and routes bid documents through Bonfire.'),
  ('hydro_ottawa_supply_chain','Hydro Ottawa — Suppliers and Contractors','https://hydroottawa.com/en/about-us/policies-and-terms/supply-chain','external_watch','watch','manual_only','Local supplier and contractor procurement','vendor_roster',90,'https://hydroottawa.com/en/about-us/policies-and-terms/supply-chain','Build procurement and facilities contacts and monitor contractor/supplier opportunities; Hydro Ottawa states a preference for local procurement.',false,true,'Ottawa','Supplier/contractor relationship channel with local-procurement preference.'),
  ('ontario_tenders_portal','Ontario Tenders Portal / Supply Ontario','https://www.supplyontario.ca/become-a-vendor/','external_watch','watch','manual_only','Ontario ministries and broader public sector procurement','public_tender',92,'https://www.supplyontario.ca/become-a-vendor/','Register and monitor open competitions, invitation thresholds and Vendor-of-Record opportunities relevant to construction and facilities.',true,true,'Ontario','Provincial procurement and VOR gateway.'),
  ('supply_ontario_vor','Supply Ontario — Vendor of Record / EVOR','https://www.supplyontario.ca/become-a-vendor/','external_watch','watch','manual_only','Province-wide Vendor of Record and Enterprise VOR arrangements','vendor_roster',100,'https://www.supplyontario.ca/become-a-vendor/','Track VOR qualification windows and second-stage opportunities; treat qualification as a high-value sales milestone.',true,true,'Ontario','VOR qualification creates access to repeat public-sector second-stage competitions.')
)
insert into public.tender_sources(
  workspace_id,source_key,display_name,source_url,ingestion_mode,enabled,coverage_tier,adapter_status,buyer_scope,last_verified_at,
  source_category,discovery_priority,registration_url,contact_strategy,supports_awards,supports_small_jobs,geographic_scope,coverage_notes
)
select ws.workspace_id,src.source_key,src.display_name,src.source_url,src.ingestion_mode,true,src.coverage_tier,src.adapter_status,
       src.buyer_scope,now(),src.source_category,src.discovery_priority,src.registration_url,src.contact_strategy,
       src.supports_awards,src.supports_small_jobs,src.geographic_scope,src.coverage_notes
from ws cross join src
on conflict(workspace_id,source_key) do update set
  display_name=excluded.display_name,source_url=excluded.source_url,enabled=true,coverage_tier=excluded.coverage_tier,
  adapter_status=excluded.adapter_status,buyer_scope=excluded.buyer_scope,last_verified_at=excluded.last_verified_at,
  source_category=excluded.source_category,discovery_priority=excluded.discovery_priority,
  registration_url=excluded.registration_url,contact_strategy=excluded.contact_strategy,
  supports_awards=excluded.supports_awards,supports_small_jobs=excluded.supports_small_jobs,
  geographic_scope=excluded.geographic_scope,coverage_notes=excluded.coverage_notes,updated_at=now();

insert into public.procurement_source_registration_map(workspace_id,source_key,registration_source_key,platform_name,updated_at)
select workspace_id,'yow_bonfire','bonfire_euna','Bonfire',now() from (select distinct workspace_id from public.tender_sources) w
on conflict(workspace_id,source_key) do update set registration_source_key=excluded.registration_source_key,platform_name=excluded.platform_name,updated_at=now();
insert into public.procurement_source_registration_map(workspace_id,source_key,registration_source_key,platform_name,updated_at)
select workspace_id,'supply_ontario_vor','ontario_tenders_portal','Ontario Tenders Portal',now() from (select distinct workspace_id from public.tender_sources) w
on conflict(workspace_id,source_key) do update set registration_source_key=excluded.registration_source_key,platform_name=excluded.platform_name,updated_at=now();
insert into public.procurement_source_registration_map(workspace_id,source_key,registration_source_key,platform_name,updated_at)
select workspace_id,'city_ottawa_small_rfq','city_ottawa_merx','MERX / direct supplier invitation',now() from (select distinct workspace_id from public.tender_sources) w
on conflict(workspace_id,source_key) do update set registration_source_key=excluded.registration_source_key,platform_name=excluded.platform_name,updated_at=now();
insert into public.procurement_source_registration_map(workspace_id,source_key,registration_source_key,platform_name,updated_at)
select workspace_id,'city_ottawa_standing_offers','city_ottawa_merx','MERX',now() from (select distinct workspace_id from public.tender_sources) w
on conflict(workspace_id,source_key) do update set registration_source_key=excluded.registration_source_key,platform_name=excluded.platform_name,updated_at=now();

do $$
begin
  if exists(select 1 from cron.job where jobname='cbdata-contact-coverage-refresh') then
    perform cron.unschedule('cbdata-contact-coverage-refresh');
  end if;
  perform cron.schedule('cbdata-contact-coverage-refresh','5 * * * *','select public.refresh_all_contact_coverage_tasks_system();');
end $$;

select public.refresh_all_contact_coverage_tasks_system();

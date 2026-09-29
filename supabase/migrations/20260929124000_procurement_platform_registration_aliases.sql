create table if not exists public.procurement_source_registration_map (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  source_key text not null,
  registration_source_key text not null,
  platform_name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (workspace_id, source_key)
);

create index if not exists idx_proc_source_registration_map_registration
  on public.procurement_source_registration_map(workspace_id, registration_source_key);

alter table public.procurement_source_registration_map enable row level security;
alter table public.procurement_source_registration_map force row level security;

drop policy if exists procurement_source_registration_map_select on public.procurement_source_registration_map;
create policy procurement_source_registration_map_select
  on public.procurement_source_registration_map for select to authenticated
  using (private.is_workspace_member(workspace_id));

drop policy if exists procurement_source_registration_map_insert on public.procurement_source_registration_map;
create policy procurement_source_registration_map_insert
  on public.procurement_source_registration_map for insert to authenticated
  with check (private.is_workspace_member(workspace_id));

drop policy if exists procurement_source_registration_map_update on public.procurement_source_registration_map;
create policy procurement_source_registration_map_update
  on public.procurement_source_registration_map for update to authenticated
  using (private.is_workspace_member(workspace_id))
  with check (private.is_workspace_member(workspace_id));

drop policy if exists procurement_source_registration_map_delete on public.procurement_source_registration_map;
create policy procurement_source_registration_map_delete
  on public.procurement_source_registration_map for delete to authenticated
  using (private.is_workspace_member(workspace_id));

grant select,insert,update,delete on public.procurement_source_registration_map to authenticated;
grant all on public.procurement_source_registration_map to service_role;
revoke all on public.procurement_source_registration_map from anon;

insert into public.supplier_registrations (
  workspace_id,source_key,registration_name,status,evidence_url,notes,created_at,updated_at
)
select w.id,s.source_key,s.registration_name,'unknown',s.evidence_url,s.notes,now(),now()
from public.workspaces w
cross join (values
  ('biddingo','Biddingo supplier account','https://www.biddingo.com/suppliers','Required to access/download many Biddingo-hosted procurement packages and receive opportunity notices.'),
  ('seao','SEAO supplier account','https://seao.gouv.qc.ca/','Track Québec public-market account readiness and electronic submission access.'),
  ('oca_link2build','OCA / Link2Build plans-room access','https://www.link2build.ca/about/become-a-member/','OCA/Link2Build access provides Ottawa/Eastern Ontario drawings, specifications, addenda, bidders and results.'),
  ('bids_tenders','Bids&Tenders vendor account','https://bidsandtenders.ca/','Track vendor account readiness for participating municipal and school-board portals.')
) as s(source_key,registration_name,evidence_url,notes)
on conflict(workspace_id,source_key,registration_name) do update
set evidence_url=excluded.evidence_url,
    notes=excluded.notes,
    updated_at=now();

insert into public.procurement_source_registration_map (
  workspace_id,source_key,registration_source_key,platform_name,created_at,updated_at
)
select w.id,m.source_key,m.registration_source_key,m.platform_name,now(),now()
from public.workspaces w
cross join (values
  ('city_ottawa_merx','city_merx','MERX'),
  ('och_merx','city_merx','MERX'),
  ('uottawa_merx','city_merx','MERX'),
  ('carleton_merx','city_merx','MERX'),
  ('algonquin_merx','city_merx','MERX'),
  ('montfort_merx','city_merx','MERX'),
  ('lacite_merx','city_merx','MERX'),
  ('bruyere_merx','city_merx','MERX'),
  ('cecce_merx_watch','city_merx','MERX'),
  ('ottawa_hospital_medbuy','biddingo','Biddingo'),
  ('royal_biddingo','biddingo','Biddingo'),
  ('sto_seao','seao','SEAO'),
  ('cisss_outaouais_seao','seao','SEAO'),
  ('oca_link2build','oca_link2build','Link2Build'),
  ('ocdsb_bids_tenders','bids_tenders','Bids&Tenders'),
  ('ocsb_bids_tenders','bids_tenders','Bids&Tenders'),
  ('clarence_rockland_bids_tenders','bids_tenders','Bids&Tenders'),
  ('prescott_russell_bids_tenders','bids_tenders','Bids&Tenders'),
  ('lanark_county_bids_tenders','bids_tenders','Bids&Tenders'),
  ('county_renfrew_bids_tenders','bids_tenders','Bids&Tenders'),
  ('rcdsb_bids_tenders','bids_tenders','Bids&Tenders'),
  ('ucdsb_bids_tenders','bids_tenders','Bids&Tenders'),
  ('leeds_grenville_bids_tenders','bids_tenders','Bids&Tenders'),
  ('cepeo_procurement_watch','institutions','Institutional prequalification')
) as m(source_key,registration_source_key,platform_name)
on conflict(workspace_id,source_key) do update
set registration_source_key=excluded.registration_source_key,
    platform_name=excluded.platform_name,
    updated_at=now();

create or replace view public.v_procurement_pursuit_queue
with (security_invoker = true)
as
select
  f.id,
  f.workspace_id,
  f.buyer_name,
  f.title,
  f.service_category,
  f.expected_publish_start,
  f.expected_publish_end,
  f.fit_score,
  f.confidence,
  f.status,
  f.pursuit_priority,
  f.contact_readiness_status,
  f.vendor_readiness_status,
  f.next_action,
  f.next_action_at,
  f.target_id,
  f.owner_user_id,
  f.routed_at,
  f.source_url,
  f.pursuit_contact_id,
  concat_ws(' ',pc.first_name,pc.last_name) as pursuit_contact_name,
  pc.job_title as pursuit_contact_title,
  pc.email as pursuit_contact_email,
  pc.phone as pursuit_contact_phone,
  pc.source_url as pursuit_contact_source_url,
  pc.source_verified_at as pursuit_contact_verified_at,
  c.contract_title,
  c.incumbent_name,
  c.award_value,
  c.currency,
  c.contract_end_date,
  c.expected_rebid_date,
  b.buyer_key,
  b.primary_source_key,
  b.coverage_status,
  b.watch_priority,
  b.registration_url,
  coalesce(contact_stats.known_contact_count,0) as known_contact_count,
  sr.status as supplier_registration_status,
  sr.expires_on as supplier_registration_expires_on,
  sr.evidence_url as supplier_registration_evidence_url
from public.procurement_future_opportunities f
left join public.procurement_contract_cycles c on c.id=f.contract_cycle_id
left join public.procurement_buyers b
  on b.workspace_id=f.workspace_id
 and (b.organization_id=f.organization_id or lower(b.display_name)=lower(f.buyer_name))
left join public.contacts pc on pc.id=f.pursuit_contact_id
left join public.procurement_source_registration_map rm
  on rm.workspace_id=f.workspace_id
 and rm.source_key=b.primary_source_key
left join lateral (
  select count(*)::integer as known_contact_count
  from public.organization_contacts oc
  where oc.workspace_id=f.workspace_id
    and oc.organization_id=f.organization_id
    and oc.end_date is null
) contact_stats on true
left join lateral (
  select x.status,x.expires_on,x.evidence_url
  from public.supplier_registrations x
  where x.workspace_id=f.workspace_id
    and x.source_key=coalesce(rm.registration_source_key,b.primary_source_key)
  order by x.updated_at desc
  limit 1
) sr on true;

grant select on public.v_procurement_pursuit_queue to authenticated;
revoke all on public.v_procurement_pursuit_queue from anon;

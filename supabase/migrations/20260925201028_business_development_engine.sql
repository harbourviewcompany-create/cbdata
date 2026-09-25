-- CBData business-development engine.
-- Adds multi-channel lead sourcing (permits, referrals, inbound, cold outreach)
-- that feeds the existing leads/opportunities pipeline. Additive only — no
-- existing table is altered except `leads`, which gets new nullable columns.
-- Migration: 20260925200000_business_development_engine

create type public.lead_channel as enum ('permit','referral','inbound','cold_outreach','other');
create type public.lead_source_status as enum ('active','paused','error');
create type public.outreach_target_status as enum ('queued','contacted','responded','converted','rejected','do_not_contact');
create type public.outreach_touch_channel as enum ('call','email','sms','door_knock','mail','other');

-- One row per active source we watch: a specific municipality's permit feed,
-- a specific ad campaign, a specific cold-list criteria set, etc. Mirrors the
-- source_registry pattern already used elsewhere for cadence + health tracking.
create table public.lead_sources (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  channel lead_channel not null,
  name pg_catalog.text not null,
  region pg_catalog.text,
  jurisdiction_url pg_catalog.text,
  cadence pg_catalog.text,
  status lead_source_status not null default 'active'::lead_source_status,
  last_run_at pg_catalog.timestamptz,
  last_success_at pg_catalog.timestamptz,
  notes pg_catalog.text,
  created_at pg_catalog.timestamptz not null default now(),
  updated_at pg_catalog.timestamptz not null default now()
);

-- Raw building-permit / property-record signals, pre-triage. Each row is one
-- pulled permit; once matched/verified it gets promoted into `leads`.
create table public.permit_records (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  lead_source_id pg_catalog.uuid,
  jurisdiction pg_catalog.text not null,
  permit_number pg_catalog.text,
  permit_type pg_catalog.text,
  work_description pg_catalog.text,
  property_address pg_catalog.text,
  applicant_name pg_catalog.text,
  contractor_of_record pg_catalog.text,
  estimated_value pg_catalog.numeric,
  filed_date pg_catalog.date,
  permit_status pg_catalog.text,
  raw_payload jsonb,
  matched_property_id pg_catalog.uuid,
  matched_organization_id pg_catalog.uuid,
  lead_id pg_catalog.uuid,
  created_at pg_catalog.timestamptz not null default now()
);

-- Attribution for leads that came from an existing contact/organization
-- vouching for someone new. lead_id is required — a referral without a
-- resulting lead is just a note on the referrer, not a business-dev event.
create table public.referral_events (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  referred_by_contact_id pg_catalog.uuid,
  referred_by_organization_id pg_catalog.uuid,
  lead_id pg_catalog.uuid not null,
  relationship_note pg_catalog.text,
  reward_status pg_catalog.text not null default 'none'::text,
  created_at pg_catalog.timestamptz not null default now()
);

-- Website/ad/form submissions land here first (unauthenticated writes come
-- through a service role, never directly from the public), then get triaged
-- into `leads` once a human or a rule confirms they're real.
create table public.inbound_submissions (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  lead_source_id pg_catalog.uuid,
  channel_detail pg_catalog.text,
  submitted_name pg_catalog.text,
  submitted_email pg_catalog.text,
  submitted_phone pg_catalog.text,
  message pg_catalog.text,
  utm_source pg_catalog.text,
  utm_campaign pg_catalog.text,
  matched_lead_id pg_catalog.uuid,
  status pg_catalog.text not null default 'new'::text,
  raw_payload jsonb,
  created_at pg_catalog.timestamptz not null default now()
);

-- Cold-prospecting: a named list of targets built from some criteria
-- (region, org type, etc.), worked manually until a target converts.
create table public.outreach_lists (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  name pg_catalog.text not null,
  criteria jsonb,
  created_by pg_catalog.uuid,
  created_at pg_catalog.timestamptz not null default now()
);

create table public.outreach_targets (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  outreach_list_id pg_catalog.uuid not null,
  organization_name pg_catalog.text,
  contact_name pg_catalog.text,
  phone pg_catalog.text,
  email pg_catalog.text,
  property_address pg_catalog.text,
  status outreach_target_status not null default 'queued'::outreach_target_status,
  last_touch_at pg_catalog.timestamptz,
  converted_lead_id pg_catalog.uuid,
  created_at pg_catalog.timestamptz not null default now(),
  updated_at pg_catalog.timestamptz not null default now()
);

create table public.outreach_touches (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  outreach_target_id pg_catalog.uuid not null,
  channel outreach_touch_channel not null,
  outcome pg_catalog.text,
  notes pg_catalog.text,
  occurred_at pg_catalog.timestamptz not null default now(),
  performed_by pg_catalog.uuid
);

-- Trace every lead back to whichever channel-specific record created it
-- (permit_records / referral_events / inbound_submissions / outreach_targets),
-- and carry a priority score so reps can triage across all four channels
-- from one queue instead of four.
alter table public.leads
  add column region pg_catalog.text,
  add column score pg_catalog.numeric,
  add column source_detail_table pg_catalog.text,
  add column source_detail_id pg_catalog.uuid;

alter table public.leads add constraint leads_source_detail_pair_check check (
  (source_detail_table is null) = (source_detail_id is null)
);

-- Primary keys
alter table public.lead_sources add constraint lead_sources_pkey primary key (id);
alter table public.permit_records add constraint permit_records_pkey primary key (id);
alter table public.referral_events add constraint referral_events_pkey primary key (id);
alter table public.inbound_submissions add constraint inbound_submissions_pkey primary key (id);
alter table public.outreach_lists add constraint outreach_lists_pkey primary key (id);
alter table public.outreach_targets add constraint outreach_targets_pkey primary key (id);
alter table public.outreach_touches add constraint outreach_touches_pkey primary key (id);

-- Foreign keys
alter table public.lead_sources add constraint lead_sources_workspace_id_fkey foreign key (workspace_id) references workspaces(id) on delete restrict;

alter table public.permit_records add constraint permit_records_workspace_id_fkey foreign key (workspace_id) references workspaces(id) on delete restrict;
alter table public.permit_records add constraint permit_records_lead_source_id_fkey foreign key (lead_source_id) references lead_sources(id) on delete set null;
alter table public.permit_records add constraint permit_records_matched_property_id_fkey foreign key (matched_property_id) references properties(id) on delete set null;
alter table public.permit_records add constraint permit_records_matched_organization_id_fkey foreign key (matched_organization_id) references organizations(id) on delete set null;
alter table public.permit_records add constraint permit_records_lead_id_fkey foreign key (lead_id) references leads(id) on delete set null;
alter table public.permit_records add constraint permit_records_jurisdiction_permit_number_key unique (jurisdiction, permit_number);

alter table public.referral_events add constraint referral_events_workspace_id_fkey foreign key (workspace_id) references workspaces(id) on delete restrict;
alter table public.referral_events add constraint referral_events_referred_by_contact_id_fkey foreign key (referred_by_contact_id) references contacts(id) on delete set null;
alter table public.referral_events add constraint referral_events_referred_by_organization_id_fkey foreign key (referred_by_organization_id) references organizations(id) on delete set null;
alter table public.referral_events add constraint referral_events_lead_id_fkey foreign key (lead_id) references leads(id) on delete cascade;

alter table public.inbound_submissions add constraint inbound_submissions_workspace_id_fkey foreign key (workspace_id) references workspaces(id) on delete restrict;
alter table public.inbound_submissions add constraint inbound_submissions_lead_source_id_fkey foreign key (lead_source_id) references lead_sources(id) on delete set null;
alter table public.inbound_submissions add constraint inbound_submissions_matched_lead_id_fkey foreign key (matched_lead_id) references leads(id) on delete set null;

alter table public.outreach_lists add constraint outreach_lists_workspace_id_fkey foreign key (workspace_id) references workspaces(id) on delete restrict;
alter table public.outreach_lists add constraint outreach_lists_created_by_fkey foreign key (created_by) references auth.users(id) on delete set null;

alter table public.outreach_targets add constraint outreach_targets_workspace_id_fkey foreign key (workspace_id) references workspaces(id) on delete restrict;
alter table public.outreach_targets add constraint outreach_targets_outreach_list_id_fkey foreign key (outreach_list_id) references outreach_lists(id) on delete cascade;
alter table public.outreach_targets add constraint outreach_targets_converted_lead_id_fkey foreign key (converted_lead_id) references leads(id) on delete set null;

alter table public.outreach_touches add constraint outreach_touches_workspace_id_fkey foreign key (workspace_id) references workspaces(id) on delete restrict;
alter table public.outreach_touches add constraint outreach_touches_outreach_target_id_fkey foreign key (outreach_target_id) references outreach_targets(id) on delete cascade;
alter table public.outreach_touches add constraint outreach_touches_performed_by_fkey foreign key (performed_by) references auth.users(id) on delete set null;

-- updated_at triggers (existing helper function)
create trigger touch_updated_at before update on public.lead_sources for each row execute function public.touch_updated_at();
create trigger touch_updated_at before update on public.outreach_targets for each row execute function public.touch_updated_at();

-- RLS: identical workspace-member pattern used on every other table.
alter table public.lead_sources enable row level security;
alter table public.lead_sources force row level security;
create policy workspace_member_insert on public.lead_sources for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.lead_sources for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.lead_sources for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));

alter table public.permit_records enable row level security;
alter table public.permit_records force row level security;
create policy workspace_member_insert on public.permit_records for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.permit_records for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.permit_records for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));

alter table public.referral_events enable row level security;
alter table public.referral_events force row level security;
create policy workspace_member_insert on public.referral_events for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.referral_events for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.referral_events for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));

alter table public.inbound_submissions enable row level security;
alter table public.inbound_submissions force row level security;
create policy workspace_member_insert on public.inbound_submissions for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.inbound_submissions for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.inbound_submissions for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));

alter table public.outreach_lists enable row level security;
alter table public.outreach_lists force row level security;
create policy workspace_member_insert on public.outreach_lists for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.outreach_lists for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.outreach_lists for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));

alter table public.outreach_targets enable row level security;
alter table public.outreach_targets force row level security;
create policy workspace_member_insert on public.outreach_targets for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.outreach_targets for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.outreach_targets for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));

alter table public.outreach_touches enable row level security;
alter table public.outreach_touches force row level security;
create policy workspace_member_insert on public.outreach_touches for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.outreach_touches for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.outreach_touches for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));

-- FK-covering indexes (same intent as the generic pass in
-- 20260925195042_performance_hardening_fk_and_rls.sql, written explicitly
-- here since that migration's loop only covers FKs that existed when it ran).
create index if not exists idx_lead_sources_workspace_id on public.lead_sources (workspace_id);
create index if not exists idx_permit_records_workspace_id on public.permit_records (workspace_id);
create index if not exists idx_permit_records_lead_source_id on public.permit_records (lead_source_id);
create index if not exists idx_permit_records_matched_property_id on public.permit_records (matched_property_id);
create index if not exists idx_permit_records_matched_organization_id on public.permit_records (matched_organization_id);
create index if not exists idx_permit_records_lead_id on public.permit_records (lead_id);
create index if not exists idx_referral_events_workspace_id on public.referral_events (workspace_id);
create index if not exists idx_referral_events_referred_by_contact_id on public.referral_events (referred_by_contact_id);
create index if not exists idx_referral_events_referred_by_organization_id on public.referral_events (referred_by_organization_id);
create index if not exists idx_referral_events_lead_id on public.referral_events (lead_id);
create index if not exists idx_inbound_submissions_workspace_id on public.inbound_submissions (workspace_id);
create index if not exists idx_inbound_submissions_lead_source_id on public.inbound_submissions (lead_source_id);
create index if not exists idx_inbound_submissions_matched_lead_id on public.inbound_submissions (matched_lead_id);
create index if not exists idx_outreach_lists_workspace_id on public.outreach_lists (workspace_id);
create index if not exists idx_outreach_targets_workspace_id on public.outreach_targets (workspace_id);
create index if not exists idx_outreach_targets_outreach_list_id on public.outreach_targets (outreach_list_id);
create index if not exists idx_outreach_targets_converted_lead_id on public.outreach_targets (converted_lead_id);
create index if not exists idx_outreach_touches_workspace_id on public.outreach_touches (workspace_id);
create index if not exists idx_outreach_touches_outreach_target_id on public.outreach_touches (outreach_target_id);
create index if not exists idx_leads_source_detail_id on public.leads (source_detail_id);

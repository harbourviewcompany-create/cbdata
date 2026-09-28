-- Reconcile the base tender model that exists in production but was previously
-- missing from the repository's clean migration chain.
do $$ begin
  create type public.tender_record_status as enum (
    'new','reviewing','pursuing','submitted','won','lost','not_pursuing','expired'
  );
exception when duplicate_object then null;
end $$;

create table if not exists public.tender_records (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete restrict,
  lead_source_id uuid references public.lead_sources(id) on delete set null,
  source text not null,
  external_id text not null,
  title text not null,
  buyer_name text,
  category text,
  region text,
  estimated_value numeric,
  currency text not null default 'CAD',
  published_date date,
  closing_date date,
  source_url text,
  raw_payload jsonb,
  status public.tender_record_status not null default 'new',
  matched_organization_id uuid references public.organizations(id) on delete set null,
  lead_id uuid references public.leads(id) on delete set null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(workspace_id, source, external_id)
);

create index if not exists tender_records_workspace_status_idx
  on public.tender_records(workspace_id,status);
create index if not exists tender_records_closing_date_idx
  on public.tender_records(closing_date);
create index if not exists idx_fk_tender_records_lead_source_id
  on public.tender_records(lead_source_id);
create index if not exists idx_fk_tender_records_matched_organization_id
  on public.tender_records(matched_organization_id);
create index if not exists idx_fk_tender_records_lead_id
  on public.tender_records(lead_id);

alter table public.tender_records enable row level security;
alter table public.tender_records force row level security;

drop policy if exists workspace_member_select on public.tender_records;
create policy workspace_member_select on public.tender_records for select
  using (private.is_workspace_member(workspace_id));
drop policy if exists workspace_member_insert on public.tender_records;
create policy workspace_member_insert on public.tender_records for insert
  with check (private.is_workspace_member(workspace_id));
drop policy if exists workspace_member_update on public.tender_records;
create policy workspace_member_update on public.tender_records for update
  using (private.is_workspace_member(workspace_id))
  with check (private.is_workspace_member(workspace_id));

-- CanadaBuys prospecting layer for CBData.
-- Stores structured procurement response requirements and run history while
-- retaining the existing tender_records/lead model.

alter table public.tender_records
  add column if not exists response_mode text,
  add column if not exists registration_required boolean not null default false,
  add column if not exists fit_score numeric,
  add column if not exists fit_note text,
  add column if not exists last_verified_at timestamptz,
  add column if not exists watch_query text;

alter table public.tender_records
  drop constraint if exists tender_records_fit_score_check;

alter table public.tender_records
  add constraint tender_records_fit_score_check
  check (fit_score is null or (fit_score >= 0 and fit_score <= 100));

create table if not exists public.canadabuys_runs (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete restrict,
  query text not null,
  region text not null default 'Ottawa / National Capital Region',
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  status text not null default 'running',
  fetched_count integer not null default 0,
  qualifying_count integer not null default 0,
  inserted_count integer not null default 0,
  updated_count integer not null default 0,
  lead_created_count integer not null default 0,
  error_count integer not null default 0,
  error_message text,
  created_at timestamptz not null default now()
);

create index if not exists idx_tender_records_canadabuys_open
  on public.tender_records (workspace_id, closing_date, source);

create index if not exists idx_tender_records_canadabuys_region
  on public.tender_records (workspace_id, region, source);

create index if not exists idx_canadabuys_runs_workspace_started
  on public.canadabuys_runs (workspace_id, started_at desc);

alter table public.canadabuys_runs enable row level security;
alter table public.canadabuys_runs force row level security;

drop policy if exists canadabuys_runs_select on public.canadabuys_runs;
create policy canadabuys_runs_select
  on public.canadabuys_runs for select
  to authenticated
  using (public.is_workspace_member(workspace_id));

drop policy if exists canadabuys_runs_insert on public.canadabuys_runs;
create policy canadabuys_runs_insert
  on public.canadabuys_runs for insert
  to authenticated
  with check (public.is_workspace_member(workspace_id));

drop policy if exists canadabuys_runs_update on public.canadabuys_runs;
create policy canadabuys_runs_update
  on public.canadabuys_runs for update
  to authenticated
  using (public.is_workspace_member(workspace_id))
  with check (public.is_workspace_member(workspace_id));

comment on column public.tender_records.response_mode is
  'Procurement response path observed in the source notice, e.g. formal_rfp or registration_required.';
comment on column public.tender_records.registration_required is
  'True only when the source notice explicitly indicates supplier registration or a prerequisite account.';
comment on column public.tender_records.fit_note is
  'Concise evidence-based CB Contracting fit note; do not infer unsupported scope.';


-- Seed only source-verified procurement contacts already established by the
-- prospecting workflow. The unique email is used for idempotency.
do $$
declare
  w uuid := '431aa13d-3e7c-41e3-9686-e840b8ea5b7c';
  org uuid;
  c uuid;
begin
  select id into org from public.organizations where workspace_id=w and lower(legal_name)='national capital commission' limit 1;
  if org is not null then
    select id into c from public.contacts where workspace_id=w and lower(email)='contracts@ncc-ccn.ca' limit 1;
    if c is null then
      insert into public.contacts(workspace_id,first_name,last_name,job_title,email,status,notes,source_url,source_label,source_confidence,source_verified_at)
      values(w,'Andrew','Malo','Senior Contract Officer','contracts@ncc-ccn.ca','active','Contracting/technical authority identified in NCC procurement documentation.','https://canadabuys.canada.ca/sites/default/files/webform/tender_notice/77548/ncc-red-1705-1706-rfp_snow-removal-services-fr.pdf','NCC CanadaBuys procurement document','verified',now()) returning id into c;
    end if;
    if not exists(select 1 from public.organization_contacts where workspace_id=w and organization_id=org and contact_id=c) then
      insert into public.organization_contacts(workspace_id,organization_id,contact_id,relationship_type,is_primary) values(w,org,c,'procurement',true);
    end if;
  end if;

  select id into org from public.organizations where workspace_id=w and lower(legal_name)='national research council of canada' limit 1;
  if org is not null then
    select id into c from public.contacts where workspace_id=w and lower(email)='jonathan.bullard@nrc-cnrc.gc.ca' limit 1;
    if c is null then
      insert into public.contacts(workspace_id,first_name,last_name,job_title,email,status,notes,source_url,source_label,source_confidence,source_verified_at)
      values(w,'Jonathan','Bullard','Contracting Authority','jonathan.bullard@nrc-cnrc.gc.ca','active','Contracting authority identified for NRC Ottawa Offices Janitorial Services.','https://www.myprojectworld.ca/tenders/6ab36cd40ab6175d9dac34fa','NRC tender listing','high',now()) returning id into c;
    end if;
    if not exists(select 1 from public.organization_contacts where workspace_id=w and organization_id=org and contact_id=c) then
      insert into public.organization_contacts(workspace_id,organization_id,contact_id,relationship_type,is_primary) values(w,org,c,'procurement',true);
    end if;
  end if;
end $$;

-- Recreate the tender base model on clean databases before the CanadaBuys
-- enrichment migrations run. Production already has this table, so CREATE IF
-- NOT EXISTS keeps the structural creation idempotent.

do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'tender_record_status'
  ) then
    create type public.tender_record_status as enum (
      'new','reviewing','pursuing','submitted','won','lost','not_pursuing','expired'
    );
  end if;
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
  response_mode text,
  registration_required boolean not null default false,
  fit_score numeric,
  fit_note text,
  last_verified_at timestamptz,
  watch_query text,
  action_state text not null default 'new',
  next_action text,
  next_action_due_at timestamptz,
  constraint tender_records_fit_score_check
    check (fit_score is null or (fit_score >= 0 and fit_score <= 100)),
  constraint tender_records_source_external_id_key
    unique (workspace_id, source, external_id)
);

create index if not exists tender_records_closing_date_idx
  on public.tender_records(closing_date);
create index if not exists tender_records_workspace_status_idx
  on public.tender_records(workspace_id, status);
create index if not exists idx_fk_tender_records_2ab8f86410b4f3bdcc747699295eb5a4
  on public.tender_records(lead_source_id);
create index if not exists idx_fk_tender_records_ac09bdc10c90d57bd2d9117485ce3fa7
  on public.tender_records(matched_organization_id);
create index if not exists idx_fk_tender_records_180123dccc1e079eb3dff759832cb255
  on public.tender_records(lead_id);

alter table public.tender_records enable row level security;
alter table public.tender_records force row level security;

drop policy if exists workspace_member_select on public.tender_records;
create policy workspace_member_select
  on public.tender_records for select
  to authenticated
  using (private.is_workspace_member(workspace_id));

drop policy if exists workspace_member_insert on public.tender_records;
create policy workspace_member_insert
  on public.tender_records for insert
  to authenticated
  with check (private.is_workspace_member(workspace_id));

drop policy if exists workspace_member_update on public.tender_records;
create policy workspace_member_update
  on public.tender_records for update
  to authenticated
  using (private.is_workspace_member(workspace_id))
  with check (private.is_workspace_member(workspace_id));

revoke all on public.tender_records from anon;
revoke delete, truncate, references, trigger on public.tender_records from authenticated;
grant select, insert, update on public.tender_records to authenticated;
grant all on public.tender_records to service_role;

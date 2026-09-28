-- Must run before portfolio signal seeds: production currently has the older source/reference-only
-- dedupe index, which rejects multiple property-specific signals backed by the same first-party source.
-- Harden opportunity signals before property-level portfolio signals are inserted.
-- This fixes RLS visibility, signal taxonomy, dedupe semantics and referential integrity.

alter table public.target_opportunity_signals
  drop constraint if exists target_opportunity_signals_signal_type_check;

alter table public.target_opportunity_signals
  add constraint target_opportunity_signals_signal_type_check
  check (signal_type in (
    'procurement','permit','capital_project','vendor_change',
    'contract_renewal','seasonal','acquisition','management_change'
  ));

drop index if exists public.target_opportunity_signals_source_ref_uidx;
create unique index target_opportunity_signals_source_ref_uidx
  on public.target_opportunity_signals (
    workspace_id,
    source_url,
    coalesce(reference_number,''),
    coalesce(property_id,'00000000-0000-0000-0000-000000000000'::uuid),
    signal_type
  );

alter table public.target_opportunity_signals
  add constraint target_opportunity_signals_workspace_id_fkey
  foreign key (workspace_id) references public.workspaces(id) on delete cascade;

alter table public.target_opportunity_signals
  add constraint target_opportunity_signals_organization_id_fkey
  foreign key (organization_id) references public.organizations(id) on delete set null;

alter table public.target_opportunity_signals
  add constraint target_opportunity_signals_property_id_fkey
  foreign key (property_id) references public.properties(id) on delete set null;

alter table public.target_opportunity_signals
  add constraint target_opportunity_signals_target_id_fkey
  foreign key (target_id) references public.outreach_targets(id) on delete set null;

create index if not exists target_opportunity_signals_workspace_fk_idx
  on public.target_opportunity_signals(workspace_id);
create index if not exists target_opportunity_signals_organization_fk_idx
  on public.target_opportunity_signals(organization_id);
create index if not exists target_opportunity_signals_property_fk_idx
  on public.target_opportunity_signals(property_id);
create index if not exists target_opportunity_signals_target_fk_idx
  on public.target_opportunity_signals(target_id);

alter table public.target_opportunity_signals enable row level security;
alter table public.target_opportunity_signals force row level security;

drop policy if exists workspace_member_select on public.target_opportunity_signals;
create policy workspace_member_select on public.target_opportunity_signals
  for select to authenticated
  using (private.is_workspace_member(workspace_id));

revoke all on public.target_opportunity_signals from anon;
revoke insert, update, delete, truncate, references, trigger
  on public.target_opportunity_signals from authenticated;
grant select on public.target_opportunity_signals to authenticated;

create index if not exists idx_tender_properties_workspace_id
  on public.tender_properties(workspace_id);

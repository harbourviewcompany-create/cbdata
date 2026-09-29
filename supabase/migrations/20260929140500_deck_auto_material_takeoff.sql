create table if not exists public.deck_estimate_specs (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  estimate_id uuid not null references public.estimates(id) on delete cascade,
  width_ft numeric(8,2) not null check (width_ft between 4 and 80),
  depth_ft numeric(8,2) not null check (depth_ft between 4 and 80),
  stair_width_ft numeric(8,2) not null default 4 check (stair_width_ft between 2 and 16),
  steps integer not null default 3 check (steps between 0 and 30),
  footings integer not null default 6 check (footings between 1 and 40),
  height_in numeric(8,2) check (height_in is null or height_in between 0 and 180),
  include_guards boolean not null default false,
  site_reference text,
  landing text,
  site_notes text,
  joist_spacing_in numeric(6,2) not null default 16 check (joist_spacing_in between 8 and 24),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(workspace_id,estimate_id)
);

create index if not exists idx_deck_estimate_specs_estimate on public.deck_estimate_specs(estimate_id);
create index if not exists idx_deck_estimate_specs_created_by on public.deck_estimate_specs(created_by);

alter table public.deck_estimate_specs enable row level security;
alter table public.deck_estimate_specs force row level security;

drop policy if exists workspace_member_select on public.deck_estimate_specs;
drop policy if exists workspace_sales_insert on public.deck_estimate_specs;
drop policy if exists workspace_sales_update on public.deck_estimate_specs;
drop policy if exists workspace_sales_delete on public.deck_estimate_specs;

create policy workspace_member_select on public.deck_estimate_specs
for select to authenticated
using (private.is_workspace_member(workspace_id));

create policy workspace_sales_insert on public.deck_estimate_specs
for insert to authenticated
with check (
  private.has_workspace_role(
    workspace_id,
    array['owner','administrator','sales_manager','sales_rep','operations_manager']::public.membership_role[]
  )
);

create policy workspace_sales_update on public.deck_estimate_specs
for update to authenticated
using (
  private.has_workspace_role(
    workspace_id,
    array['owner','administrator','sales_manager','sales_rep','operations_manager']::public.membership_role[]
  )
)
with check (
  private.has_workspace_role(
    workspace_id,
    array['owner','administrator','sales_manager','sales_rep','operations_manager']::public.membership_role[]
  )
);

create policy workspace_sales_delete on public.deck_estimate_specs
for delete to authenticated
using (
  private.has_workspace_role(
    workspace_id,
    array['owner','administrator','sales_manager','sales_rep','operations_manager']::public.membership_role[]
  )
);

revoke all on public.deck_estimate_specs from anon;
grant select,insert,update,delete on public.deck_estimate_specs to authenticated;
grant all on public.deck_estimate_specs to service_role;

alter table public.material_request_items
  add column if not exists source_type text not null default 'manual',
  add column if not exists source_key text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.material_request_items'::regclass
      and conname='material_request_items_source_type_check'
  ) then
    alter table public.material_request_items
      add constraint material_request_items_source_type_check
      check (source_type in ('manual','deck_takeoff'));
  end if;
end $$;

create unique index if not exists uq_material_request_items_generated_key
  on public.material_request_items(request_id,source_key)
  where source_type='deck_takeoff' and source_key is not null;

create or replace function private.guard_deck_estimate_spec()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if not exists (
    select 1 from public.estimates e
    where e.id=new.estimate_id
      and e.workspace_id=new.workspace_id
      and e.estimate_kind='deck'
  ) then
    raise exception 'Deck specification must reference a deck estimate in the same workspace';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

revoke all on function private.guard_deck_estimate_spec() from public,anon,authenticated;

drop trigger if exists guard_deck_estimate_spec on public.deck_estimate_specs;
create trigger guard_deck_estimate_spec
before insert or update on public.deck_estimate_specs
for each row execute function private.guard_deck_estimate_spec();

create or replace function private.invalidate_material_request_pricing_from_spec()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  update public.material_price_plans p
  set is_selected=false
  from public.material_requests r
  where r.estimate_id=new.estimate_id
    and r.workspace_id=new.workspace_id
    and p.request_id=r.id
    and p.workspace_id=r.workspace_id
    and p.is_selected;

  update public.material_requests
  set status='draft',updated_at=now()
  where workspace_id=new.workspace_id
    and estimate_id=new.estimate_id
    and status in ('priced','approved');

  return new;
end;
$$;

revoke all on function private.invalidate_material_request_pricing_from_spec() from public,anon,authenticated;

drop trigger if exists invalidate_material_pricing_from_deck_spec on public.deck_estimate_specs;
create trigger invalidate_material_pricing_from_deck_spec
after insert or update on public.deck_estimate_specs
for each row execute function private.invalidate_material_request_pricing_from_spec();

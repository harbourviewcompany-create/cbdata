create table if not exists public.outreach_target_properties (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  outreach_target_id uuid not null references public.outreach_targets(id) on delete cascade,
  property_id uuid not null references public.properties(id) on delete cascade,
  relationship_type text not null default 'prospect_site',
  is_primary boolean not null default false,
  notes text,
  created_at timestamptz not null default now(),
  unique(outreach_target_id, property_id)
);

create index if not exists outreach_target_properties_target_idx
  on public.outreach_target_properties(outreach_target_id);
create index if not exists outreach_target_properties_property_idx
  on public.outreach_target_properties(property_id);

alter table public.outreach_target_properties enable row level security;

drop policy if exists workspace_member_select on public.outreach_target_properties;
drop policy if exists workspace_member_insert on public.outreach_target_properties;
drop policy if exists workspace_member_update on public.outreach_target_properties;

create policy workspace_member_select on public.outreach_target_properties for select
  using (private.is_workspace_member(workspace_id));
create policy workspace_member_insert on public.outreach_target_properties for insert
  with check (private.is_workspace_member(workspace_id));
create policy workspace_member_update on public.outreach_target_properties for update
  using (private.is_workspace_member(workspace_id))
  with check (private.is_workspace_member(workspace_id));

insert into public.outreach_target_properties(workspace_id,outreach_target_id,property_id,relationship_type,is_primary)
select t.workspace_id,t.id,p.id,'managed_site',false
from public.outreach_targets t
join public.properties p on p.workspace_id=t.workspace_id
 and p.management_organization_id=t.organization_id
on conflict do nothing;
-- The verified property migrations below target the canonical CB Contracting workspace.
-- Production already contains this workspace; keep the fixed identity so clean replays
-- have the same prerequisite without creating duplicate workspaces.
insert into public.workspaces (id, name, slug, status)
values (
  '431aa13d-3e7c-41e3-9686-e840b8ea5b7c'::uuid,
  'CB Contracting',
  'cb-contracting',
  'active'::workspace_status
)
on conflict (id) do nothing;

-- Legacy Apollo and Metcalfe property seeds reference these production identities.
-- Recreate their prerequisites on a fresh database; preserve existing rows in production.
insert into public.organizations (id, workspace_id, legal_name, organization_type, status)
values (
  '044a899b-e5ba-4ca7-a7f9-1c78f11ec3e7'::uuid,
  '431aa13d-3e7c-41e3-9686-e840b8ea5b7c'::uuid,
  'Apollo Property Management', 'property_manager', 'active'
)
on conflict (id) do nothing;

insert into public.outreach_lists (id, workspace_id, name)
values (
  'a15af411-9b05-4b7b-9e5b-9da4909b1dcf'::uuid,
  '431aa13d-3e7c-41e3-9686-e840b8ea5b7c'::uuid,
  'Ottawa property managers — cold outreach'
)
on conflict (id) do nothing;

insert into public.outreach_targets
  (id, workspace_id, outreach_list_id, organization_id, organization_name, status)
values (
  'c645cd3f-1d90-4439-a016-b8b5c601a762'::uuid,
  '431aa13d-3e7c-41e3-9686-e840b8ea5b7c'::uuid,
  'a15af411-9b05-4b7b-9e5b-9da4909b1dcf'::uuid,
  '044a899b-e5ba-4ca7-a7f9-1c78f11ec3e7'::uuid,
  'Apollo Property Management', 'queued'
)
on conflict (id) do nothing;

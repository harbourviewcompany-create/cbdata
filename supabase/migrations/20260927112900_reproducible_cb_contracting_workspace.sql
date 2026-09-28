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

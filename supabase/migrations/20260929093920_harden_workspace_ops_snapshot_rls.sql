alter table public.workspace_ops_snapshots enable row level security;

drop policy if exists workspace_ops_snapshots_select on public.workspace_ops_snapshots;
create policy workspace_ops_snapshots_select
  on public.workspace_ops_snapshots
  for select
  to authenticated
  using (private.is_workspace_member(workspace_id));

revoke all on public.workspace_ops_snapshots from anon;
grant select on public.workspace_ops_snapshots to authenticated;

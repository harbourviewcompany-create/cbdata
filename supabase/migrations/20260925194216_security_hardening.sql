-- CBData security hardening for the canonical schema.
alter table public.workspaces enable row level security;
alter table public.workspaces force row level security;
create policy workspace_member_select on public.workspaces for select using (public.is_workspace_member(id));
create policy workspace_member_update on public.workspaces for update using (public.has_workspace_role(id,array['owner','administrator']::public.membership_role[])) with check (public.has_workspace_role(id,array['owner','administrator']::public.membership_role[]));

alter table public.user_profiles enable row level security;
alter table public.user_profiles force row level security;
create policy profile_self_select on public.user_profiles for select using (id=auth.uid());
create policy profile_self_insert on public.user_profiles for insert with check (id=auth.uid());
create policy profile_self_update on public.user_profiles for update using (id=auth.uid()) with check (id=auth.uid());

create policy membership_manage on public.workspace_memberships for insert with check (public.has_workspace_role(workspace_id,array['owner','administrator']::public.membership_role[]));
create policy membership_manage_update on public.workspace_memberships for update using (public.has_workspace_role(workspace_id,array['owner','administrator']::public.membership_role[])) with check (public.has_workspace_role(workspace_id,array['owner','administrator']::public.membership_role[]));
create policy membership_manage_delete on public.workspace_memberships for delete using (public.has_workspace_role(workspace_id,array['owner','administrator']::public.membership_role[]));

revoke execute on function public.is_workspace_member(uuid) from public;
revoke execute on function public.has_workspace_role(uuid,public.membership_role[]) from public;

alter view public.property_360 set (security_invoker=true);
alter view public.open_work_exceptions set (security_invoker=true);
alter view public.open_issue_queue set (security_invoker=true);
alter view public.contract_renewal_queue set (security_invoker=true);

-- Final function-grant hardening: these helpers are internal policy primitives, not public RPC endpoints.
revoke execute on function public.is_workspace_member(uuid) from public;
revoke execute on function public.has_workspace_role(uuid,public.membership_role[]) from public;

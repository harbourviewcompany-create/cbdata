-- Tighten Data API exposure for internal workspace helper functions.
revoke execute on function public.is_workspace_member(uuid) from public;
revoke execute on function public.is_workspace_member(uuid) from anon;
revoke execute on function public.has_workspace_role(uuid, public.membership_role[]) from public;
revoke execute on function public.has_workspace_role(uuid, public.membership_role[]) from anon;
revoke execute on function public.refresh_workspace_ops_snapshot(uuid) from public;
revoke execute on function public.refresh_workspace_ops_snapshot(uuid) from anon;

-- Cache auth.uid() once per statement in notification RLS predicates.
drop policy if exists notifications_select_own on public.notifications;
create policy notifications_select_own on public.notifications
for select to authenticated
using ((user_id = (select auth.uid())) and private.is_workspace_member(workspace_id));

drop policy if exists notifications_update_own on public.notifications;
create policy notifications_update_own on public.notifications
for update to authenticated
using ((user_id = (select auth.uid())) and private.is_workspace_member(workspace_id))
with check ((user_id = (select auth.uid())) and private.is_workspace_member(workspace_id));
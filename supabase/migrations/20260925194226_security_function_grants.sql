-- CBData security function grant hardening.
revoke execute on function public.is_workspace_member(uuid) from public;
revoke execute on function public.has_workspace_role(uuid,public.membership_role[]) from public;
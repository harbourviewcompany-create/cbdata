-- security_hardening.sql revoked EXECUTE on these SECURITY DEFINER helper
-- functions from PUBLIC to stop them being exposed as public RPC endpoints.
-- That also blocked every RLS policy that calls them, since Postgres
-- requires the querying role to hold EXECUTE on a function even when the
-- function itself is SECURITY DEFINER. Re-granting to `authenticated`
-- restores policy evaluation for logged-in users.
grant execute on function public.is_workspace_member(uuid) to authenticated;
grant execute on function public.has_workspace_role(uuid, public.membership_role[]) to authenticated;

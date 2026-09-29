grant usage on schema private to service_role;
grant select on private.integration_credentials to service_role;

create or replace function public.lookup_integration_workspace(
  p_provider text,
  p_key_hash text
)
returns uuid
language sql
stable
security invoker
set search_path = ''
as $$
  select c.workspace_id
  from private.integration_credentials as c
  where c.provider = p_provider
    and c.status = 'active'
    and c.key_hash = p_key_hash
  limit 1
$$;

revoke all on function public.lookup_integration_workspace(text, text) from public;
revoke all on function public.lookup_integration_workspace(text, text) from anon;
revoke all on function public.lookup_integration_workspace(text, text) from authenticated;
grant execute on function public.lookup_integration_workspace(text, text) to service_role;

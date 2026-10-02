-- Service-role-only helpers for signed provider webhooks.
-- Webhook signing secrets live in Supabase Vault and are never committed.

create or replace function public.get_service_integration_secret(p_name text)
returns text
language sql
security definer
set search_path=pg_catalog,vault
as $$
  select decrypted_secret
  from vault.decrypted_secrets
  where name=p_name
  order by created_at desc
  limit 1
$$;

revoke all on function public.get_service_integration_secret(text)
  from public,anon,authenticated;
grant execute on function public.get_service_integration_secret(text)
  to service_role;

create or replace function public.lookup_signed_integration_workspace(p_provider text)
returns uuid
language plpgsql
security definer
set search_path=pg_catalog,private
as $$
declare
  v_workspace uuid;
  v_count integer;
begin
  select count(*),min(workspace_id)
    into v_count,v_workspace
  from private.integration_credentials
  where provider=p_provider and status='active';

  if v_count<>1 then
    raise exception 'signed integration workspace mapping unavailable';
  end if;

  return v_workspace;
end
$$;

revoke all on function public.lookup_signed_integration_workspace(text)
  from public,anon,authenticated;
grant execute on function public.lookup_signed_integration_workspace(text)
  to service_role;

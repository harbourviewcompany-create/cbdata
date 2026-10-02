-- Harden private integration credential storage.
alter table private.integration_credentials enable row level security;

revoke all on table private.integration_credentials from public, anon, authenticated;
grant select on table private.integration_credentials to service_role;
grant usage on schema private to service_role;

begin;

do $$
declare
  rls_enabled boolean;
begin
  select c.relrowsecurity
    into rls_enabled
  from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='private' and c.relname='integration_credentials';

  if not coalesce(rls_enabled,false) then
    raise exception 'private.integration_credentials must have RLS enabled';
  end if;

  if has_table_privilege('anon','private.integration_credentials','SELECT')
     or has_table_privilege('authenticated','private.integration_credentials','SELECT')
     or has_table_privilege('authenticated','private.integration_credentials','INSERT')
     or has_table_privilege('authenticated','private.integration_credentials','UPDATE') then
    raise exception 'client roles must not have direct integration credential table access';
  end if;

  if not has_table_privilege('service_role','private.integration_credentials','SELECT') then
    raise exception 'service_role must retain credential lookup access';
  end if;
end $$;

rollback;

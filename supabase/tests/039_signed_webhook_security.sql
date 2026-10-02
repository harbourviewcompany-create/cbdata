begin;

do $$
begin
  if to_regprocedure('public.get_service_integration_secret(text)') is null then
    raise exception 'service integration secret RPC missing';
  end if;

  if to_regprocedure('public.lookup_signed_integration_workspace(text)') is null then
    raise exception 'signed integration workspace lookup missing';
  end if;

  if has_function_privilege('authenticated','public.get_service_integration_secret(text)','EXECUTE')
     or has_function_privilege('anon','public.get_service_integration_secret(text)','EXECUTE') then
    raise exception 'client roles must not read service integration secrets';
  end if;

  if not has_function_privilege('service_role','public.get_service_integration_secret(text)','EXECUTE') then
    raise exception 'service role cannot read integration secret';
  end if;

  if has_function_privilege('authenticated','public.lookup_signed_integration_workspace(text)','EXECUTE') then
    raise exception 'authenticated must not resolve signed integration workspace';
  end if;

  if not has_function_privilege('service_role','public.lookup_signed_integration_workspace(text)','EXECUTE') then
    raise exception 'service role cannot resolve signed integration workspace';
  end if;
end $$;

rollback;

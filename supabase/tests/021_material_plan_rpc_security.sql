do $$
declare
  public_definer boolean;
  private_definer boolean;
  public_auth_exec boolean;
  public_anon_exec boolean;
  private_auth_exec boolean;
  private_anon_exec boolean;
begin
  select p.prosecdef,
         has_function_privilege('authenticated',p.oid,'EXECUTE'),
         has_function_privilege('anon',p.oid,'EXECUTE')
  into public_definer,public_auth_exec,public_anon_exec
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and p.proname='select_material_price_plan'
    and pg_get_function_identity_arguments(p.oid)='p_request_id uuid, p_plan_id uuid';

  if public_definer is distinct from false then
    raise exception 'Public material plan RPC must be SECURITY INVOKER';
  end if;
  if public_auth_exec is distinct from true then
    raise exception 'Authenticated role must execute public material plan RPC';
  end if;
  if public_anon_exec is distinct from false then
    raise exception 'Anon role must not execute public material plan RPC';
  end if;

  select p.prosecdef,
         has_function_privilege('authenticated',p.oid,'EXECUTE'),
         has_function_privilege('anon',p.oid,'EXECUTE')
  into private_definer,private_auth_exec,private_anon_exec
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='private'
    and p.proname='select_material_price_plan'
    and pg_get_function_identity_arguments(p.oid)='p_request_id uuid, p_plan_id uuid';

  if private_definer is distinct from true then
    raise exception 'Private material plan implementation must remain SECURITY DEFINER';
  end if;
  if private_auth_exec is distinct from true then
    raise exception 'Authenticated wrapper path cannot execute private material plan implementation';
  end if;
  if private_anon_exec is distinct from false then
    raise exception 'Anon role must not execute private material plan implementation';
  end if;
end $$;

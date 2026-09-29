begin;
do $$
begin
  if to_regprocedure('public.route_procurement_pursuits(uuid)') is null then
    raise exception 'public procurement pursuit router wrapper missing';
  end if;
  if has_function_privilege('anon','public.route_procurement_pursuits(uuid)','EXECUTE')
     or has_function_privilege('authenticated','public.route_procurement_pursuits(uuid)','EXECUTE') then
    raise exception 'public procurement pursuit router wrapper exposed to clients';
  end if;
  if not has_function_privilege('service_role','public.route_procurement_pursuits(uuid)','EXECUTE') then
    raise exception 'service role cannot call public procurement pursuit router wrapper';
  end if;
end $$;
rollback;

begin;
do $$
begin
 if to_regprocedure('private.route_procurement_pursuits(uuid)') is null then raise exception 'procurement pursuit router missing'; end if;
 if has_function_privilege('anon','private.route_procurement_pursuits(uuid)','EXECUTE')
    or has_function_privilege('authenticated','private.route_procurement_pursuits(uuid)','EXECUTE') then
   raise exception 'procurement pursuit router exposed to clients';
 end if;
 if not has_function_privilege('service_role','private.route_procurement_pursuits(uuid)','EXECUTE') then
   raise exception 'service role cannot execute procurement pursuit router';
 end if;
end $$;
rollback;
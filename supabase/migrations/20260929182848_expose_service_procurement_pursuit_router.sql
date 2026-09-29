create or replace function public.route_procurement_pursuits(p_workspace uuid)
returns table(promoted integer, refreshed integer)
language sql
security invoker
set search_path = ''
as $$
  select * from private.route_procurement_pursuits(p_workspace);
$$;

revoke all on function public.route_procurement_pursuits(uuid) from public, anon, authenticated;
grant execute on function public.route_procurement_pursuits(uuid) to service_role;

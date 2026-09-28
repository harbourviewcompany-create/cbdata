revoke execute on function public.convert_estimate_to_contract(uuid) from anon;
grant execute on function public.convert_estimate_to_contract(uuid) to authenticated;
grant execute on function public.convert_estimate_to_contract(uuid) to service_role;

revoke all on function public.next_actions(uuid,integer) from public;
revoke execute on function public.next_actions(uuid,integer) from anon;
grant execute on function public.next_actions(uuid,integer) to authenticated;
grant execute on function public.next_actions(uuid,integer) to service_role;

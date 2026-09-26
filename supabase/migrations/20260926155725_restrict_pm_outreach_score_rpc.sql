revoke all on function public.compute_outreach_target_score(integer, integer, boolean, boolean, boolean, integer) from public;
revoke all on function public.compute_outreach_target_score(integer, integer, boolean, boolean, boolean, integer) from anon;
grant execute on function public.compute_outreach_target_score(integer, integer, boolean, boolean, boolean, integer) to authenticated;
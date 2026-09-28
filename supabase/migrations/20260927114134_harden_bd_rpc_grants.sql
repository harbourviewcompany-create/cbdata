-- Keep internal BD workflow RPCs out of the anonymous Data API surface.
revoke execute on function public.target_is_reachable(uuid) from public;
revoke execute on function public.target_is_reachable(uuid) from anon;

revoke execute on function public.claim_outreach_target(uuid) from public;
revoke execute on function public.claim_outreach_target(uuid) from anon;

revoke execute on function public.log_bd_outcome(uuid, text) from public;
revoke execute on function public.log_bd_outcome(uuid, text) from anon;

revoke execute on function public.enroll_outreach_target(uuid, uuid) from public;
revoke execute on function public.enroll_outreach_target(uuid, uuid) from anon;

grant execute on function public.target_is_reachable(uuid) to authenticated;
grant execute on function public.claim_outreach_target(uuid) to authenticated;
grant execute on function public.log_bd_outcome(uuid, text) to authenticated;
grant execute on function public.enroll_outreach_target(uuid, uuid) to authenticated;

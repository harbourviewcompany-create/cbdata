-- Harden PM outreach RPCs after production security migration

alter function public.compute_outreach_target_score(
  integer, integer, boolean, boolean, boolean, integer
)
set search_path = pg_catalog, public;

alter function public.refresh_outreach_target_score(uuid)
security invoker
set search_path = pg_catalog, public, auth;

alter function public.refresh_outreach_target_scores_for_list(uuid)
security invoker
set search_path = pg_catalog, public, auth;

alter function public.convert_outreach_target_to_lead(uuid)
security invoker
set search_path = pg_catalog, public, auth;

alter function public.log_outreach_touch(
  uuid, outreach_touch_channel, text, text, outreach_target_status, text, timestamptz
)
security invoker
set search_path = pg_catalog, public, auth;

revoke all on function public.refresh_outreach_target_score(uuid) from public;
revoke all on function public.refresh_outreach_target_score(uuid) from anon;
grant execute on function public.refresh_outreach_target_score(uuid) to authenticated;

revoke all on function public.refresh_outreach_target_scores_for_list(uuid) from public;
revoke all on function public.refresh_outreach_target_scores_for_list(uuid) from anon;
grant execute on function public.refresh_outreach_target_scores_for_list(uuid) to authenticated;

revoke all on function public.convert_outreach_target_to_lead(uuid) from public;
revoke all on function public.convert_outreach_target_to_lead(uuid) from anon;
grant execute on function public.convert_outreach_target_to_lead(uuid) to authenticated;

revoke all on function public.log_outreach_touch(
  uuid, outreach_touch_channel, text, text, outreach_target_status, text, timestamptz
) from public;
revoke all on function public.log_outreach_touch(
  uuid, outreach_touch_channel, text, text, outreach_target_status, text, timestamptz
) from anon;
grant execute on function public.log_outreach_touch(
  uuid, outreach_touch_channel, text, text, outreach_target_status, text, timestamptz
) to authenticated;

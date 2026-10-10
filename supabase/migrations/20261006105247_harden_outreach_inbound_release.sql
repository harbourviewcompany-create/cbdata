create index if not exists outreach_referral_candidates_pursuit_idx
  on public.outreach_referral_candidates(pursuit_id);
create index if not exists outreach_referral_candidates_source_reply_idx
  on public.outreach_referral_candidates(source_reply_id);
create index if not exists outreach_referral_candidates_contact_idx
  on public.outreach_referral_candidates(contact_id);

-- The trigger helpers are not present on all fresh installs. Harden them only
-- when they exist; do not create no-op substitutes or bypass approval checks.
do $guard$
begin
  if to_regprocedure('public.enforce_outreach_draft_approval()') is not null then
    execute 'alter function public.enforce_outreach_draft_approval() set search_path=pg_catalog,public';
  end if;
  if to_regprocedure('public.create_outreach_followups()') is not null then
    execute 'alter function public.create_outreach_followups() set search_path=pg_catalog,public';
  end if;
end
$guard$;

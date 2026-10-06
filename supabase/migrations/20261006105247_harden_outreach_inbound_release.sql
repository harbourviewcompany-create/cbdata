create index if not exists outreach_referral_candidates_pursuit_idx
  on public.outreach_referral_candidates(pursuit_id);
create index if not exists outreach_referral_candidates_source_reply_idx
  on public.outreach_referral_candidates(source_reply_id);
create index if not exists outreach_referral_candidates_contact_idx
  on public.outreach_referral_candidates(contact_id);

alter function public.enforce_outreach_draft_approval() set search_path=pg_catalog,public;
alter function public.create_outreach_followups() set search_path=pg_catalog,public;

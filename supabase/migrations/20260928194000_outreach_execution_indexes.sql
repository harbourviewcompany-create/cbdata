-- Cover outreach execution foreign keys for joins, deletes, and advisor cleanliness.
create index if not exists outreach_drafts_contact_id_idx on public.outreach_drafts(contact_id);
create index if not exists outreach_drafts_created_by_idx on public.outreach_drafts(created_by);
create index if not exists outreach_drafts_outreach_target_id_idx on public.outreach_drafts(outreach_target_id);
create index if not exists outreach_drafts_property_id_idx on public.outreach_drafts(property_id);
create index if not exists outreach_replies_outreach_draft_id_idx on public.outreach_replies(outreach_draft_id);
create index if not exists outreach_replies_outreach_target_id_idx on public.outreach_replies(outreach_target_id);

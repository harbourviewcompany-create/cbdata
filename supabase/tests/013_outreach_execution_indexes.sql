-- Outreach execution FK index regression checks.
do $$
declare n int;
begin
  select count(*) into n
  from pg_indexes
  where schemaname='public'
    and indexname in (
      'outreach_drafts_contact_id_idx',
      'outreach_drafts_created_by_idx',
      'outreach_drafts_outreach_target_id_idx',
      'outreach_drafts_property_id_idx',
      'outreach_replies_outreach_draft_id_idx',
      'outreach_replies_outreach_target_id_idx'
    );
  if n <> 6 then raise exception 'Expected 6 outreach FK indexes, found %', n; end if;
end $$;

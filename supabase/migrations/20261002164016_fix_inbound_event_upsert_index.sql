-- PostgREST ON CONFLICT requires a non-partial unique index matching the
-- declared conflict columns. PostgreSQL unique indexes already allow multiple
-- NULL provider_message_id values, so the partial predicate is unnecessary.

drop index if exists public.outreach_inbound_events_provider_message_uidx;

create unique index outreach_inbound_events_provider_message_uidx
  on public.outreach_inbound_events(workspace_id,provider,provider_message_id);

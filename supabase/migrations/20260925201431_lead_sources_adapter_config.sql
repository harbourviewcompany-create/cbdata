-- Adds adapter configuration columns to lead_sources so each source can be
-- driven by a named ingestion adapter with a field mapping and query params.
alter table public.lead_sources add column adapter text;
alter table public.lead_sources add column field_mapping jsonb;
alter table public.lead_sources add column query_params jsonb;

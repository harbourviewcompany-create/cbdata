insert into public.tender_sources (
  workspace_id, source_key, display_name, source_url, ingestion_mode, enabled, created_at, updated_at
)
select id,
       'oca_link2build',
       'Ottawa Construction Association / Link2Build',
       'https://oca.ca/bids-projects/bid-closing-calendar/',
       'external_watch',
       true,
       now(),
       now()
from public.workspaces
on conflict(workspace_id,source_key) do update
set display_name=excluded.display_name,
    source_url=excluded.source_url,
    ingestion_mode='external_watch',
    enabled=true,
    updated_at=now();

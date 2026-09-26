create table if not exists private.integration_credentials (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  provider text not null,
  key_hash text not null,
  status text not null default 'active' check (status in ('active','revoked')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (workspace_id, provider)
);

revoke all on private.integration_credentials from anon, authenticated;

alter table public.inbound_submissions
  add column if not exists wix_submission_id text;

create unique index if not exists uq_inbound_submissions_workspace_wix_submission
  on public.inbound_submissions (workspace_id, wix_submission_id)
  where wix_submission_id is not null;

insert into public.lead_sources (
  workspace_id, channel, name, region, cadence, status, notes, adapter
)
select
  w.id,
  'inbound',
  'CB Contracting Wix website',
  null,
  'realtime',
  'active',
  'Inbound lead capture from cbcontracting.ca via Wix.',
  'wix'
from public.workspaces w
where w.slug = 'cb-contracting'
  and not exists (
    select 1 from public.lead_sources ls
    where ls.workspace_id = w.id and ls.adapter = 'wix'
  );

insert into private.integration_credentials (workspace_id, provider, key_hash)
select w.id, 'wix', '241e92ee6846f54f98bd6f74a35b7acc47d80b0143898a7285d408720685faf5'
from public.workspaces w
where w.slug = 'cb-contracting'
on conflict (workspace_id, provider)
do update set key_hash = excluded.key_hash, status = 'active', updated_at = now();
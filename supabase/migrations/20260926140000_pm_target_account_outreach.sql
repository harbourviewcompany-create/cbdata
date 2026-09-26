-- CBData: PM target-account outreach vertical slice
-- Extends organizations + outreach_targets so a property-management company
-- can be listed, scored, owned, touched, and converted to a lead.
-- Additive only. Does not replace permit/referral/inbound paths.
-- Migration: 20260926140000_pm_target_account_outreach

-- ---------------------------------------------------------------------------
-- 1) Organization enrichment (PM account profile)
-- ---------------------------------------------------------------------------
-- organization_type already includes 'property_manager'.

alter table public.organizations
  add column if not exists doors_managed integer,
  add column if not exists buildings_managed integer,
  add column if not exists primary_region text,
  add column if not exists service_regions text[],
  add column if not exists hq_city text,
  add column if not exists hq_province text,
  add column if not exists linkedin_url text,
  add column if not exists source_notes text;

comment on column public.organizations.doors_managed is
  'Approximate units under management; used for BD scoring.';
comment on column public.organizations.buildings_managed is
  'Approximate building count under management.';
comment on column public.organizations.primary_region is
  'Primary operating region label (e.g. Metro Vancouver, GTA East).';
comment on column public.organizations.service_regions is
  'Additional regions the PM covers.';

alter table public.organizations
  drop constraint if exists organizations_doors_managed_nonnegative;
alter table public.organizations
  add constraint organizations_doors_managed_nonnegative
  check (doors_managed is null or doors_managed >= 0);

alter table public.organizations
  drop constraint if exists organizations_buildings_managed_nonnegative;
alter table public.organizations
  add constraint organizations_buildings_managed_nonnegative
  check (buildings_managed is null or buildings_managed >= 0);

create index if not exists idx_organizations_workspace_type
  on public.organizations (workspace_id, organization_type);

create index if not exists idx_organizations_workspace_region
  on public.organizations (workspace_id, primary_region);

-- ---------------------------------------------------------------------------
-- 2) Outreach target → real account graph
-- ---------------------------------------------------------------------------
-- Denormalized name/phone/email columns remain for pre-match list import.

alter table public.outreach_targets
  add column if not exists organization_id uuid,
  add column if not exists contact_id uuid,
  add column if not exists owner_user_id uuid,
  add column if not exists region text,
  add column if not exists score numeric,
  add column if not exists score_reason text,
  add column if not exists next_action text,
  add column if not exists next_action_due_at timestamptz,
  add column if not exists priority work_priority not null default 'normal'::work_priority,
  add column if not exists notes text;

comment on column public.outreach_targets.organization_id is
  'Linked organization when known; prefer property_manager type for PM BD.';
comment on column public.outreach_targets.score is
  'v0 priority score (higher = call first). Rule-based; not ML.';
comment on column public.outreach_targets.next_action is
  'Short human instruction, e.g. Call facilities manager, Send intro email.';

alter table public.outreach_targets
  drop constraint if exists outreach_targets_organization_id_fkey;
alter table public.outreach_targets
  add constraint outreach_targets_organization_id_fkey
  foreign key (organization_id) references public.organizations (id) on delete set null;

alter table public.outreach_targets
  drop constraint if exists outreach_targets_contact_id_fkey;
alter table public.outreach_targets
  add constraint outreach_targets_contact_id_fkey
  foreign key (contact_id) references public.contacts (id) on delete set null;

-- Match leads.owner_user_id → auth.users
alter table public.outreach_targets
  drop constraint if exists outreach_targets_owner_user_id_fkey;
alter table public.outreach_targets
  add constraint outreach_targets_owner_user_id_fkey
  foreign key (owner_user_id) references auth.users (id) on delete set null;

alter table public.outreach_targets
  drop constraint if exists outreach_targets_score_range;
alter table public.outreach_targets
  add constraint outreach_targets_score_range
  check (score is null or (score >= 0 and score <= 100));

create index if not exists idx_outreach_targets_organization_id
  on public.outreach_targets (organization_id);

create index if not exists idx_outreach_targets_contact_id
  on public.outreach_targets (contact_id);

create index if not exists idx_outreach_targets_owner_user_id
  on public.outreach_targets (owner_user_id);

create index if not exists idx_outreach_targets_workspace_status_score
  on public.outreach_targets (workspace_id, status, score desc nulls last);

create index if not exists idx_outreach_targets_workspace_next_due
  on public.outreach_targets (workspace_id, next_action_due_at)
  where status in ('queued', 'contacted', 'responded');

create unique index if not exists uq_outreach_targets_list_org
  on public.outreach_targets (outreach_list_id, organization_id)
  where organization_id is not null;

-- ---------------------------------------------------------------------------
-- 3) Tasks can point at an outreach target (next-action queue)
-- ---------------------------------------------------------------------------
alter table public.tasks
  add column if not exists outreach_target_id uuid;

alter table public.tasks
  drop constraint if exists tasks_outreach_target_id_fkey;
alter table public.tasks
  add constraint tasks_outreach_target_id_fkey
  foreign key (outreach_target_id) references public.outreach_targets (id) on delete set null;

create index if not exists idx_tasks_outreach_target_id
  on public.tasks (outreach_target_id);

-- ---------------------------------------------------------------------------
-- 4) v0 score helper (explicit rules)
-- ---------------------------------------------------------------------------
create or replace function public.compute_outreach_target_score(
  p_doors_managed integer,
  p_buildings_managed integer,
  p_has_contact boolean,
  p_has_phone_or_email boolean,
  p_same_primary_region boolean,
  p_linked_property_count integer default 0
)
returns numeric
language sql
immutable
as $$
  select least(100::numeric,
    coalesce(
      case
        when p_doors_managed is null then 10
        when p_doors_managed >= 500 then 40
        when p_doors_managed >= 100 then 30
        when p_doors_managed >= 50 then 20
        when p_doors_managed >= 20 then 12
        else 6
      end
    , 0)
    + coalesce(
      case
        when p_buildings_managed is null then 0
        when p_buildings_managed >= 20 then 15
        when p_buildings_managed >= 5 then 10
        when p_buildings_managed >= 2 then 5
        else 2
      end
    , 0)
    + case when p_has_contact then 15 else 0 end
    + case when p_has_phone_or_email then 15 else 0 end
    + case when p_same_primary_region then 10 else 0 end
    + least(coalesce(p_linked_property_count, 0) * 3, 15)
  );
$$;

comment on function public.compute_outreach_target_score is
  'Rule-based v0 score for PM outreach prioritization. Tune weights in place.';

create or replace function public.refresh_outreach_target_score(p_target_id uuid)
returns numeric
language plpgsql
security definer
set search_path = public
as $$
declare
  v_workspace_id uuid;
  v_org_id uuid;
  v_contact_id uuid;
  v_target_region text;
  v_org_region text;
  v_doors integer;
  v_buildings integer;
  v_has_contact boolean;
  v_has_coord boolean;
  v_same_region boolean;
  v_prop_count integer;
  v_score numeric;
  v_reason text;
  v_snap_phone text;
  v_snap_email text;
begin
  select t.workspace_id, t.organization_id, t.contact_id, t.region, t.phone, t.email
  into v_workspace_id, v_org_id, v_contact_id, v_target_region, v_snap_phone, v_snap_email
  from public.outreach_targets t
  where t.id = p_target_id;

  if v_workspace_id is null then
    raise exception 'outreach_target % not found', p_target_id;
  end if;

  if not public.is_workspace_member(v_workspace_id) then
    raise exception 'not a member of workspace';
  end if;

  v_doors := null;
  v_buildings := null;
  v_org_region := null;

  if v_org_id is not null then
    select o.doors_managed, o.buildings_managed, o.primary_region
    into v_doors, v_buildings, v_org_region
    from public.organizations o
    where o.id = v_org_id;
  end if;

  v_has_contact := (v_contact_id is not null);

  v_has_coord := (
    nullif(v_snap_phone, '') is not null
    or nullif(v_snap_email, '') is not null
    or exists (
      select 1 from public.contacts c
      where c.id = v_contact_id
        and (
          nullif(c.phone, '') is not null
          or nullif(c.mobile, '') is not null
          or nullif(c.email, '') is not null
        )
    )
  );

  v_same_region := (
    v_target_region is not null
    and v_org_region is not null
    and lower(v_target_region) = lower(v_org_region)
  ) or (
    v_target_region is null
    and v_org_region is not null
  );

  select count(*)::integer
  into v_prop_count
  from public.properties p
  where p.workspace_id = v_workspace_id
    and p.management_organization_id = v_org_id
    and p.archived_at is null;

  v_score := public.compute_outreach_target_score(
    v_doors,
    v_buildings,
    coalesce(v_has_contact, false),
    coalesce(v_has_coord, false),
    coalesce(v_same_region, false),
    coalesce(v_prop_count, 0)
  );

  v_reason := format(
    'doors=%s buildings=%s contact=%s coord=%s region_match=%s linked_properties=%s',
    coalesce(v_doors::text, 'n/a'),
    coalesce(v_buildings::text, 'n/a'),
    v_has_contact,
    v_has_coord,
    v_same_region,
    v_prop_count
  );

  update public.outreach_targets
  set
    score = v_score,
    score_reason = v_reason,
    region = coalesce(region, v_org_region),
    updated_at = now()
  where id = p_target_id;

  return v_score;
end;
$$;

create or replace function public.refresh_outreach_target_scores_for_list(p_list_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_workspace_id uuid;
  r record;
  n integer := 0;
begin
  select workspace_id into v_workspace_id
  from public.outreach_lists
  where id = p_list_id;

  if v_workspace_id is null then
    raise exception 'outreach_list % not found', p_list_id;
  end if;

  if not public.is_workspace_member(v_workspace_id) then
    raise exception 'not a member of workspace';
  end if;

  for r in
    select id from public.outreach_targets where outreach_list_id = p_list_id
  loop
    perform public.refresh_outreach_target_score(r.id);
    n := n + 1;
  end loop;

  return n;
end;
$$;

revoke all on function public.compute_outreach_target_score(integer, integer, boolean, boolean, boolean, integer) from public;
revoke all on function public.refresh_outreach_target_score(uuid) from public;
revoke all on function public.refresh_outreach_target_scores_for_list(uuid) from public;
grant execute on function public.compute_outreach_target_score(integer, integer, boolean, boolean, boolean, integer) to authenticated;
grant execute on function public.refresh_outreach_target_score(uuid) to authenticated;
grant execute on function public.refresh_outreach_target_scores_for_list(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 5) Convert target → lead
-- ---------------------------------------------------------------------------
create or replace function public.convert_outreach_target_to_lead(p_target_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_target public.outreach_targets%rowtype;
  v_lead_id uuid;
begin
  select * into v_target
  from public.outreach_targets
  where id = p_target_id
  for update;

  if not found then
    raise exception 'outreach_target % not found', p_target_id;
  end if;

  if not public.is_workspace_member(v_target.workspace_id) then
    raise exception 'not a member of workspace';
  end if;

  if v_target.status = 'do_not_contact' then
    raise exception 'cannot convert do_not_contact target';
  end if;

  if v_target.converted_lead_id is not null then
    return v_target.converted_lead_id;
  end if;

  insert into public.leads (
    workspace_id,
    organization_id,
    contact_id,
    source,
    lead_type,
    status,
    owner_user_id,
    region,
    score,
    source_detail_table,
    source_detail_id
  ) values (
    v_target.workspace_id,
    v_target.organization_id,
    v_target.contact_id,
    'cold_outreach',
    'property_management',
    'new',
    v_target.owner_user_id,
    v_target.region,
    v_target.score,
    'outreach_targets',
    v_target.id
  )
  returning id into v_lead_id;

  update public.outreach_targets
  set
    status = 'converted',
    converted_lead_id = v_lead_id,
    last_touch_at = coalesce(last_touch_at, now()),
    updated_at = now()
  where id = p_target_id;

  return v_lead_id;
end;
$$;

revoke all on function public.convert_outreach_target_to_lead(uuid) from public;
grant execute on function public.convert_outreach_target_to_lead(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 6) Log touch helper (updates last_touch_at + optional status)
-- ---------------------------------------------------------------------------
create or replace function public.log_outreach_touch(
  p_target_id uuid,
  p_channel outreach_touch_channel,
  p_outcome text default null,
  p_notes text default null,
  p_new_status outreach_target_status default null,
  p_next_action text default null,
  p_next_action_due_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_target public.outreach_targets%rowtype;
  v_touch_id uuid;
begin
  select * into v_target
  from public.outreach_targets
  where id = p_target_id
  for update;

  if not found then
    raise exception 'outreach_target % not found', p_target_id;
  end if;

  if not public.is_workspace_member(v_target.workspace_id) then
    raise exception 'not a member of workspace';
  end if;

  insert into public.outreach_touches (
    workspace_id,
    outreach_target_id,
    channel,
    outcome,
    notes,
    occurred_at,
    performed_by
  ) values (
    v_target.workspace_id,
    p_target_id,
    p_channel,
    p_outcome,
    p_notes,
    now(),
    auth.uid()
  )
  returning id into v_touch_id;

  update public.outreach_targets
  set
    last_touch_at = now(),
    status = coalesce(p_new_status, status),
    next_action = coalesce(p_next_action, next_action),
    next_action_due_at = coalesce(p_next_action_due_at, next_action_due_at),
    updated_at = now()
  where id = p_target_id;

  return v_touch_id;
end;
$$;

revoke all on function public.log_outreach_touch(uuid, outreach_touch_channel, text, text, outreach_target_status, text, timestamptz) from public;
grant execute on function public.log_outreach_touch(uuid, outreach_touch_channel, text, text, outreach_target_status, text, timestamptz) to authenticated;

-- ---------------------------------------------------------------------------
-- 7) Operational view: Targets queue
-- ---------------------------------------------------------------------------
create or replace view public.v_outreach_target_queue
with (security_invoker = true)
as
select
  t.id,
  t.workspace_id,
  t.outreach_list_id,
  l.name as list_name,
  t.status,
  t.score,
  t.score_reason,
  t.priority,
  t.region,
  t.next_action,
  t.next_action_due_at,
  t.last_touch_at,
  t.owner_user_id,
  t.organization_id,
  coalesce(o.operating_name, o.legal_name, t.organization_name) as organization_display_name,
  o.organization_type,
  o.doors_managed,
  o.buildings_managed,
  o.website as organization_website,
  t.contact_id,
  coalesce(
    nullif(trim(both from coalesce(c.first_name, '') || ' ' || coalesce(c.last_name, '')), ''),
    t.contact_name
  ) as contact_display_name,
  c.job_title as contact_job_title,
  coalesce(c.phone, c.mobile, t.phone) as contact_phone,
  coalesce(c.email, t.email) as contact_email,
  t.converted_lead_id,
  t.notes,
  t.created_at,
  t.updated_at,
  (
    select count(*)::integer
    from public.properties p
    where p.workspace_id = t.workspace_id
      and p.management_organization_id = t.organization_id
      and p.archived_at is null
  ) as linked_property_count,
  (
    select count(*)::integer
    from public.outreach_touches ot
    where ot.outreach_target_id = t.id
  ) as touch_count
from public.outreach_targets t
left join public.outreach_lists l
  on l.id = t.outreach_list_id
left join public.organizations o
  on o.id = t.organization_id
left join public.contacts c
  on c.id = t.contact_id;

comment on view public.v_outreach_target_queue is
  'BD queue: PM targets with score, owner, next action, and portfolio overlap.';

grant select on public.v_outreach_target_queue to authenticated;

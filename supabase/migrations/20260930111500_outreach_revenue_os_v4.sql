-- Outreach Revenue OS v4
-- Canonical pursuits, reply inbox/classification, reply-driven sequence pausing,
-- executable contact research, revenue linkage, decomposable scoring,
-- message quality, guarded sequence execution, and conversion analytics.
--
-- Additive/reconciling migration. Existing outreach_targets remain the historical
-- source records; outreach_pursuits becomes the canonical account-level operator model.

-- ---------------------------------------------------------------------------
-- 1) Canonical account / pursuit / contact model
-- ---------------------------------------------------------------------------

create or replace function public.outreach_account_key(
  p_organization_id uuid,
  p_organization_name text,
  p_target_id uuid default null
)
returns text
language sql
immutable
parallel safe
as $$
  select case
    when p_organization_id is not null then 'org:' || p_organization_id::text
    when nullif(regexp_replace(lower(coalesce(p_organization_name,'')), '[^a-z0-9]+', '', 'g'),'') is not null
      then 'name:' || regexp_replace(lower(coalesce(p_organization_name,'')), '[^a-z0-9]+', '', 'g')
    else 'target:' || coalesce(p_target_id::text,'unknown')
  end
$$;

create table if not exists public.outreach_pursuits (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  account_key text not null,
  organization_id uuid references public.organizations(id) on delete set null,
  display_name text not null,
  owner_user_id uuid references auth.users(id) on delete set null,
  next_action_owner_user_id uuid references auth.users(id) on delete set null,
  primary_property_id uuid references public.properties(id) on delete set null,
  opportunity_id uuid references public.opportunities(id) on delete set null,
  stage text not null default 'research'
    check (stage in ('research','contact_ready','outreach','engaged','qualified','site_visit','estimating','proposal','negotiation','won','lost','nurture')),
  status text not null default 'active'
    check (status in ('active','paused','won','lost','archived')),
  next_action text,
  next_action_due_at timestamptz,
  estimated_value numeric not null default 0 check (estimated_value >= 0),
  last_activity_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(workspace_id,account_key)
);

create index if not exists outreach_pursuits_workspace_stage_idx
  on public.outreach_pursuits(workspace_id,status,stage,next_action_due_at);
create index if not exists outreach_pursuits_organization_idx
  on public.outreach_pursuits(workspace_id,organization_id);
create index if not exists outreach_pursuits_opportunity_idx
  on public.outreach_pursuits(opportunity_id)
  where opportunity_id is not null;

alter table public.outreach_pursuits enable row level security;
drop policy if exists outreach_pursuits_member_select on public.outreach_pursuits;
drop policy if exists outreach_pursuits_member_insert on public.outreach_pursuits;
drop policy if exists outreach_pursuits_member_update on public.outreach_pursuits;
create policy outreach_pursuits_member_select on public.outreach_pursuits for select to authenticated
  using (private.is_workspace_member(workspace_id));
create policy outreach_pursuits_member_insert on public.outreach_pursuits for insert to authenticated
  with check (private.is_workspace_member(workspace_id));
create policy outreach_pursuits_member_update on public.outreach_pursuits for update to authenticated
  using (private.is_workspace_member(workspace_id))
  with check (private.is_workspace_member(workspace_id));
grant select,insert,update on public.outreach_pursuits to authenticated;

alter table public.outreach_targets
  add column if not exists pursuit_id uuid references public.outreach_pursuits(id) on delete set null;
create index if not exists outreach_targets_pursuit_idx
  on public.outreach_targets(workspace_id,pursuit_id);

insert into public.outreach_pursuits(
  workspace_id,account_key,organization_id,display_name,owner_user_id,
  next_action_owner_user_id,stage,status,next_action,next_action_due_at,last_activity_at
)
select distinct on (
    t.workspace_id,
    public.outreach_account_key(t.organization_id,coalesce(o.operating_name,o.legal_name,t.organization_name),t.id)
  )
  t.workspace_id,
  public.outreach_account_key(t.organization_id,coalesce(o.operating_name,o.legal_name,t.organization_name),t.id),
  t.organization_id,
  coalesce(o.operating_name,o.legal_name,t.organization_name,'Unnamed account'),
  t.owner_user_id,
  t.owner_user_id,
  case
    when t.status::text='responded' then 'engaged'
    when t.status::text='contacted' then 'outreach'
    when t.contact_id is not null then 'contact_ready'
    else 'research'
  end,
  case
    when t.status::text='converted' then 'won'
    when t.status::text='rejected' then 'lost'
    when t.status::text='do_not_contact' then 'paused'
    else 'active'
  end,
  t.next_action,
  t.next_action_due_at,
  t.last_touch_at
from public.outreach_targets t
left join public.organizations o on o.id=t.organization_id
order by
  t.workspace_id,
  public.outreach_account_key(t.organization_id,coalesce(o.operating_name,o.legal_name,t.organization_name),t.id),
  t.score desc nulls last,
  t.last_touch_at desc nulls last,
  t.updated_at desc
on conflict(workspace_id,account_key) do update set
  display_name=excluded.display_name,
  organization_id=coalesce(public.outreach_pursuits.organization_id,excluded.organization_id),
  owner_user_id=coalesce(public.outreach_pursuits.owner_user_id,excluded.owner_user_id),
  next_action_owner_user_id=coalesce(public.outreach_pursuits.next_action_owner_user_id,excluded.next_action_owner_user_id),
  updated_at=now();

update public.outreach_targets t
set pursuit_id=p.id
from public.outreach_pursuits p
left join public.organizations o on o.id=t.organization_id
where p.workspace_id=t.workspace_id
  and p.account_key=public.outreach_account_key(
    t.organization_id,
    coalesce(o.operating_name,o.legal_name,t.organization_name),
    t.id
  )
  and t.pursuit_id is distinct from p.id;

with ranked_property as (
  select
    t.pursuit_id,
    otp.property_id,
    row_number() over(
      partition by t.pursuit_id
      order by coalesce(pi.intelligence_score,0) desc, otp.created_at desc
    ) as rn
  from public.outreach_targets t
  join public.outreach_target_properties otp on otp.outreach_target_id=t.id
  left join public.property_intelligence pi
    on pi.workspace_id=t.workspace_id and pi.property_id=otp.property_id
  where t.pursuit_id is not null
)
update public.outreach_pursuits p
set primary_property_id=r.property_id,updated_at=now()
from ranked_property r
where r.pursuit_id=p.id and r.rn=1 and p.primary_property_id is null;

create or replace function public.derive_outreach_contact_role(
  p_job_title text,
  p_relationship_type text default null
)
returns text
language sql
immutable
parallel safe
as $$
  select case
    when coalesce(p_relationship_type,'') ~* '(procurement|purchas|buyer|sourcing|contract|supply)' or coalesce(p_job_title,'') ~* '(procurement|purchas|buyer|sourcing|contract|supply chain)' then 'procurement'
    when coalesce(p_relationship_type,'') ~* '(operations|facilit|maintenance)' or coalesce(p_job_title,'') ~* '(operations|facilit|maintenance|building manager)' then 'operations'
    when coalesce(p_relationship_type,'') ~* '(property|site)' or coalesce(p_job_title,'') ~* '(property manager|site manager|community manager)' then 'property_manager'
    when coalesce(p_relationship_type,'') ~* '(owner|decision|principal|president|executive)' or coalesce(p_job_title,'') ~* '(owner|principal|president|chief|vice president|vp|executive director|managing director|director)' then 'decision_maker'
    else 'other'
  end
$$;

create table if not exists public.outreach_pursuit_contacts (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  pursuit_id uuid not null references public.outreach_pursuits(id) on delete cascade,
  contact_id uuid not null references public.contacts(id) on delete cascade,
  buying_role text not null default 'other'
    check (buying_role in ('decision_maker','operations','procurement','property_manager','site_contact','influencer','other')),
  is_primary boolean not null default false,
  status text not null default 'active' check (status in ('active','inactive','invalid')),
  evidence_url text,
  evidence_confidence text check (evidence_confidence is null or evidence_confidence in ('low','medium','high')),
  last_verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(pursuit_id,contact_id,buying_role)
);

create index if not exists outreach_pursuit_contacts_pursuit_idx
  on public.outreach_pursuit_contacts(workspace_id,pursuit_id,buying_role,status);
create index if not exists outreach_pursuit_contacts_contact_idx
  on public.outreach_pursuit_contacts(contact_id);

alter table public.outreach_pursuit_contacts enable row level security;
drop policy if exists outreach_pursuit_contacts_member_select on public.outreach_pursuit_contacts;
drop policy if exists outreach_pursuit_contacts_member_insert on public.outreach_pursuit_contacts;
drop policy if exists outreach_pursuit_contacts_member_update on public.outreach_pursuit_contacts;
create policy outreach_pursuit_contacts_member_select on public.outreach_pursuit_contacts for select to authenticated
  using (private.is_workspace_member(workspace_id));
create policy outreach_pursuit_contacts_member_insert on public.outreach_pursuit_contacts for insert to authenticated
  with check (private.is_workspace_member(workspace_id));
create policy outreach_pursuit_contacts_member_update on public.outreach_pursuit_contacts for update to authenticated
  using (private.is_workspace_member(workspace_id))
  with check (private.is_workspace_member(workspace_id));
grant select,insert,update on public.outreach_pursuit_contacts to authenticated;

insert into public.outreach_pursuit_contacts(
  workspace_id,pursuit_id,contact_id,buying_role,is_primary,evidence_url,evidence_confidence,last_verified_at
)
select distinct
  t.workspace_id,
  t.pursuit_id,
  c.id,
  public.derive_outreach_contact_role(c.job_title,null),
  true,
  c.source_url,
  c.source_confidence,
  c.source_verified_at
from public.outreach_targets t
join public.contacts c on c.id=t.contact_id
where t.pursuit_id is not null
on conflict(pursuit_id,contact_id,buying_role) do update set
  is_primary=public.outreach_pursuit_contacts.is_primary or excluded.is_primary,
  evidence_url=coalesce(excluded.evidence_url,public.outreach_pursuit_contacts.evidence_url),
  evidence_confidence=coalesce(excluded.evidence_confidence,public.outreach_pursuit_contacts.evidence_confidence),
  last_verified_at=coalesce(excluded.last_verified_at,public.outreach_pursuit_contacts.last_verified_at),
  updated_at=now();

insert into public.outreach_pursuit_contacts(
  workspace_id,pursuit_id,contact_id,buying_role,is_primary,evidence_url,evidence_confidence,last_verified_at
)
select distinct
  p.workspace_id,
  p.id,
  c.id,
  public.derive_outreach_contact_role(c.job_title,oc.relationship_type),
  oc.is_primary,
  c.source_url,
  c.source_confidence,
  c.source_verified_at
from public.outreach_pursuits p
join public.organization_contacts oc
  on oc.workspace_id=p.workspace_id and oc.organization_id=p.organization_id
join public.contacts c on c.id=oc.contact_id
where p.organization_id is not null
on conflict(pursuit_id,contact_id,buying_role) do update set
  is_primary=public.outreach_pursuit_contacts.is_primary or excluded.is_primary,
  evidence_url=coalesce(excluded.evidence_url,public.outreach_pursuit_contacts.evidence_url),
  evidence_confidence=coalesce(excluded.evidence_confidence,public.outreach_pursuit_contacts.evidence_confidence),
  last_verified_at=coalesce(excluded.last_verified_at,public.outreach_pursuit_contacts.last_verified_at),
  updated_at=now();

create or replace function public.assign_outreach_target_pursuit()
returns trigger
language plpgsql
security invoker
set search_path=public
as $$
declare
  v_name text;
  v_key text;
  v_pursuit uuid;
begin
  select coalesce(o.operating_name,o.legal_name,new.organization_name,'Unnamed account')
    into v_name
  from (select 1) x
  left join public.organizations o on o.id=new.organization_id;

  v_key:=public.outreach_account_key(new.organization_id,v_name,new.id);

  insert into public.outreach_pursuits(
    workspace_id,account_key,organization_id,display_name,owner_user_id,next_action_owner_user_id,
    next_action,next_action_due_at,last_activity_at
  )
  values(
    new.workspace_id,v_key,new.organization_id,v_name,new.owner_user_id,new.owner_user_id,
    new.next_action,new.next_action_due_at,new.last_touch_at
  )
  on conflict(workspace_id,account_key) do update set
    display_name=excluded.display_name,
    organization_id=coalesce(public.outreach_pursuits.organization_id,excluded.organization_id),
    owner_user_id=coalesce(public.outreach_pursuits.owner_user_id,excluded.owner_user_id),
    next_action_owner_user_id=coalesce(public.outreach_pursuits.next_action_owner_user_id,excluded.next_action_owner_user_id),
    updated_at=now()
  returning id into v_pursuit;

  new.pursuit_id:=v_pursuit;
  return new;
end
$$;

drop trigger if exists trg_assign_outreach_target_pursuit on public.outreach_targets;
create trigger trg_assign_outreach_target_pursuit
before insert or update of organization_id,organization_name
on public.outreach_targets
for each row execute function public.assign_outreach_target_pursuit();

create or replace function public.sync_target_pursuit_contact()
returns trigger
language plpgsql
security invoker
set search_path=public
as $$
declare
  c public.contacts%rowtype;
begin
  if new.pursuit_id is null or new.contact_id is null then return new; end if;
  select * into c from public.contacts where id=new.contact_id;
  if not found then return new; end if;

  insert into public.outreach_pursuit_contacts(
    workspace_id,pursuit_id,contact_id,buying_role,is_primary,evidence_url,evidence_confidence,last_verified_at
  )
  values(
    new.workspace_id,new.pursuit_id,c.id,public.derive_outreach_contact_role(c.job_title,null),true,
    c.source_url,c.source_confidence,c.source_verified_at
  )
  on conflict(pursuit_id,contact_id,buying_role) do update set
    is_primary=true,
    evidence_url=coalesce(excluded.evidence_url,public.outreach_pursuit_contacts.evidence_url),
    evidence_confidence=coalesce(excluded.evidence_confidence,public.outreach_pursuit_contacts.evidence_confidence),
    last_verified_at=coalesce(excluded.last_verified_at,public.outreach_pursuit_contacts.last_verified_at),
    updated_at=now();

  return new;
end
$$;

drop trigger if exists trg_sync_target_pursuit_contact on public.outreach_targets;
create trigger trg_sync_target_pursuit_contact
after insert or update of contact_id,pursuit_id
on public.outreach_targets
for each row execute function public.sync_target_pursuit_contact();

create or replace function public.sync_organization_contact_to_pursuits()
returns trigger
language plpgsql
security invoker
set search_path=public
as $$
declare c public.contacts%rowtype;
begin
  select * into c from public.contacts where id=new.contact_id;
  if not found then return new; end if;

  insert into public.outreach_pursuit_contacts(
    workspace_id,pursuit_id,contact_id,buying_role,is_primary,evidence_url,evidence_confidence,last_verified_at
  )
  select
    p.workspace_id,p.id,c.id,public.derive_outreach_contact_role(c.job_title,new.relationship_type),
    new.is_primary,c.source_url,c.source_confidence,c.source_verified_at
  from public.outreach_pursuits p
  where p.workspace_id=new.workspace_id and p.organization_id=new.organization_id
  on conflict(pursuit_id,contact_id,buying_role) do update set
    is_primary=public.outreach_pursuit_contacts.is_primary or excluded.is_primary,
    evidence_url=coalesce(excluded.evidence_url,public.outreach_pursuit_contacts.evidence_url),
    evidence_confidence=coalesce(excluded.evidence_confidence,public.outreach_pursuit_contacts.evidence_confidence),
    last_verified_at=coalesce(excluded.last_verified_at,public.outreach_pursuit_contacts.last_verified_at),
    updated_at=now();

  return new;
end
$$;

drop trigger if exists trg_sync_organization_contact_to_pursuits on public.organization_contacts;
create trigger trg_sync_organization_contact_to_pursuits
after insert or update of contact_id,relationship_type,is_primary
on public.organization_contacts
for each row execute function public.sync_organization_contact_to_pursuits();

create or replace view public.v_outreach_pursuit_committee
with (security_invoker=true) as
select
  p.workspace_id,
  p.id as pursuit_id,
  count(distinct pc.contact_id) filter(where pc.status='active')::int as contact_count,
  bool_or(pc.status='active' and pc.buying_role='decision_maker') as has_decision_maker,
  bool_or(pc.status='active' and pc.buying_role='operations') as has_operations,
  bool_or(pc.status='active' and pc.buying_role='procurement') as has_procurement,
  bool_or(pc.status='active' and pc.buying_role in ('property_manager','site_contact')) as has_property_contact,
  (
    (case when bool_or(pc.status='active' and pc.buying_role='decision_maker') then 25 else 0 end) +
    (case when bool_or(pc.status='active' and pc.buying_role='operations') then 25 else 0 end) +
    (case when bool_or(pc.status='active' and pc.buying_role='procurement') then 25 else 0 end) +
    (case when bool_or(pc.status='active' and pc.buying_role in ('property_manager','site_contact')) then 25 else 0 end)
  )::int as contact_coverage_score
from public.outreach_pursuits p
left join public.outreach_pursuit_contacts pc on pc.pursuit_id=p.id
group by p.workspace_id,p.id;
grant select on public.v_outreach_pursuit_committee to authenticated;

-- ---------------------------------------------------------------------------
-- 2) Reply inbox + automatic classification + immediate sequence pause
-- ---------------------------------------------------------------------------

alter table public.outreach_replies
  add column if not exists pursuit_id uuid references public.outreach_pursuits(id) on delete set null,
  add column if not exists body text,
  add column if not exists classification_confidence numeric,
  add column if not exists classification_reason text,
  add column if not exists needs_response boolean not null default true,
  add column if not exists handled_at timestamptz,
  add column if not exists handled_by uuid references auth.users(id) on delete set null;

create index if not exists outreach_replies_pursuit_inbox_idx
  on public.outreach_replies(workspace_id,pursuit_id,needs_response,received_at desc);
create unique index if not exists outreach_replies_provider_message_uidx
  on public.outreach_replies(workspace_id,provider,provider_message_id)
  where provider_message_id is not null;

update public.outreach_replies r
set pursuit_id=t.pursuit_id
from public.outreach_targets t
where t.id=r.outreach_target_id and r.pursuit_id is null;

alter table public.outreach_replies
  drop constraint if exists outreach_replies_classification_check;
alter table public.outreach_replies
  add constraint outreach_replies_classification_check
  check (classification in (
    'interested','referral','request_quote','request_call','site_visit_request','send_information',
    'under_contract','future_renewal','not_interested','wrong_person','out_of_office','bounce',
    'unsubscribe','other'
  ));

create or replace function public.classify_outreach_reply_text(p_body text)
returns table(classification text,confidence numeric,reason text)
language plpgsql
immutable
parallel safe
as $$
declare b text:=lower(coalesce(p_body,''));
begin
  if b ~ '(unsubscribe|remove me|do not contact|stop (emailing|contacting)|opt[ -]?out)' then
    return query select 'unsubscribe'::text,0.99::numeric,'Explicit unsubscribe / do-not-contact language'::text;
  elsif b ~ '(delivery status notification|undeliverable|message not delivered|mailbox unavailable|address not found|recipient rejected|550[ -])' then
    return query select 'bounce'::text,0.99::numeric,'Delivery failure language'::text;
  elsif b ~ '(out of office|automatic reply|auto.?reply|away from (the )?office|on vacation)' then
    return query select 'out_of_office'::text,0.98::numeric,'Automatic absence language'::text;
  elsif b ~ '(not interested|no thank|no thanks|not looking|do not need|don''t need|we''re good)' then
    return query select 'not_interested'::text,0.96::numeric,'Explicit negative intent'::text;
  elsif b ~ '(not the right person|wrong person|i don''t handle|i do not handle|not responsible for)' then
    return query select 'wrong_person'::text,0.95::numeric,'Contact says they do not own the decision'::text;
  elsif b ~ '(please contact|you should contact|reach out to|speak (with|to)|the right person is|copying|cc''?ing)' then
    return query select 'referral'::text,0.90::numeric,'Reply routes CB Contracting to another contact'::text;
  elsif b ~ '((send|provide|share|need|want|looking for).{0,40}(quote|pricing|estimate|proposal|bid)|(quote|pricing|estimate|proposal|bid).{0,40}(send|provide|share|need|want))' then
    return query select 'request_quote'::text,0.94::numeric,'Explicit request for pricing / quote / proposal'::text;
  elsif b ~ '(site visit|site walk|walkthrough|walk through|come (by|out)|visit the (site|property)|meet (at|on) site)' then
    return query select 'site_visit_request'::text,0.92::numeric,'Explicit site meeting / walkthrough request'::text;
  elsif b ~ '(call me|give me a call|phone me|can we (talk|speak)|schedule a call|set up a call)' then
    return query select 'request_call'::text,0.92::numeric,'Explicit call request'::text;
  elsif b ~ '((send|share).{0,30}(information|details|capabilities|brochure|company info)|tell me more)' then
    return query select 'send_information'::text,0.88::numeric,'Asked for company information or capabilities'::text;
  elsif b ~ '(under contract|existing vendor|current contractor|already have (a )?(vendor|contractor)|contract is in place)' then
    return query select 'under_contract'::text,0.90::numeric,'Existing vendor / incumbent contract stated'::text;
  elsif b ~ '(renewal|renews|expires|contract end|next (spring|summer|fall|winter|year)|later this year)' then
    return query select 'future_renewal'::text,0.80::numeric,'Future contract or renewal timing mentioned'::text;
  elsif b ~ '(interested|sounds good|let''s discuss|lets discuss|would like to|happy to (talk|chat|meet)|open to|yes[, .])' then
    return query select 'interested'::text,0.84::numeric,'Positive commercial intent'::text;
  else
    return query select 'other'::text,0.55::numeric,'No high-confidence deterministic intent pattern'::text;
  end if;
end
$$;
revoke all on function public.classify_outreach_reply_text(text) from public,anon;
grant execute on function public.classify_outreach_reply_text(text) to authenticated,service_role;

create table if not exists public.outreach_suppressions (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  contact_id uuid references public.contacts(id) on delete set null,
  email text,
  phone text,
  reason text not null check (reason in ('unsubscribe','bounce','do_not_contact','manual','duplicate')),
  source_reply_id uuid references public.outreach_replies(id) on delete set null,
  active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  released_at timestamptz,
  notes text,
  check (contact_id is not null or nullif(btrim(coalesce(email,'')),'') is not null or nullif(btrim(coalesce(phone,'')),'') is not null)
);
create index if not exists outreach_suppressions_lookup_idx
  on public.outreach_suppressions(workspace_id,active,contact_id,email,phone);

alter table public.outreach_suppressions enable row level security;
drop policy if exists outreach_suppressions_member_select on public.outreach_suppressions;
drop policy if exists outreach_suppressions_member_insert on public.outreach_suppressions;
drop policy if exists outreach_suppressions_member_update on public.outreach_suppressions;
create policy outreach_suppressions_member_select on public.outreach_suppressions for select to authenticated
  using (private.is_workspace_member(workspace_id));
create policy outreach_suppressions_member_insert on public.outreach_suppressions for insert to authenticated
  with check (private.is_workspace_member(workspace_id));
create policy outreach_suppressions_member_update on public.outreach_suppressions for update to authenticated
  using (private.is_workspace_member(workspace_id))
  with check (private.is_workspace_member(workspace_id));
grant select,insert,update on public.outreach_suppressions to authenticated;

alter table public.outreach_enrollments
  add column if not exists paused_at timestamptz,
  add column if not exists paused_reason text,
  add column if not exists last_guard_check_at timestamptz;

-- ---------------------------------------------------------------------------
-- 3) Outreach -> opportunity -> estimate -> won linkage
-- ---------------------------------------------------------------------------

create or replace function public.ensure_outreach_opportunity(
  p_pursuit_id uuid,
  p_reply_id uuid default null,
  p_estimated_value numeric default 0
)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare
  p public.outreach_pursuits%rowtype;
  r public.outreach_replies%rowtype;
  v_id uuid;
  v_stage public.opportunity_stage:='qualified';
  v_owner uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select * into p from public.outreach_pursuits where id=p_pursuit_id for update;
  if not found then raise exception 'pursuit not found'; end if;
  if not private.is_workspace_member(p.workspace_id) then raise exception 'not a member of workspace'; end if;
  if p.organization_id is null then raise exception 'Link an organization before creating an opportunity'; end if;

  if p.opportunity_id is not null then return p.opportunity_id; end if;

  if p_reply_id is not null then
    select * into r from public.outreach_replies
    where id=p_reply_id and pursuit_id=p.id and workspace_id=p.workspace_id;
    if r.classification='request_quote' then v_stage:='estimating';
    elsif r.classification='site_visit_request' then v_stage:='site_visit';
    else v_stage:='qualified';
    end if;
  end if;

  v_owner:=coalesce(p.next_action_owner_user_id,p.owner_user_id,auth.uid());

  insert into public.opportunities(
    workspace_id,organization_id,property_id,name,stage,status,owner_user_id,
    estimated_value,probability,notes
  )
  values(
    p.workspace_id,p.organization_id,p.primary_property_id,
    p.display_name || ' — outreach opportunity',
    v_stage,'open',v_owner,greatest(coalesce(p_estimated_value,0),0),
    case v_stage when 'estimating' then 55 when 'site_visit' then 45 else 30 end,
    'Created from CBData Outreach pursuit ' || p.id::text ||
      case when p_reply_id is not null then ' / reply ' || p_reply_id::text else '' end
  )
  returning id into v_id;

  update public.outreach_pursuits
  set opportunity_id=v_id,
      stage=v_stage::text,
      estimated_value=greatest(coalesce(p_estimated_value,0),estimated_value),
      next_action=case v_stage when 'estimating' then 'Build estimate' when 'site_visit' then 'Book site visit' else 'Qualify opportunity' end,
      next_action_due_at=now()+interval '1 day',
      next_action_owner_user_id=v_owner,
      last_activity_at=now(),
      updated_at=now()
  where id=p.id;

  return v_id;
end
$$;
revoke all on function public.ensure_outreach_opportunity(uuid,uuid,numeric) from public,anon;
grant execute on function public.ensure_outreach_opportunity(uuid,uuid,numeric) to authenticated;

create or replace function public.link_estimate_to_outreach_pursuit(
  p_pursuit_id uuid,
  p_estimate_id uuid
)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare
  p public.outreach_pursuits%rowtype;
  e public.estimates%rowtype;
  v_opp uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into p from public.outreach_pursuits where id=p_pursuit_id for update;
  if not found or not private.is_workspace_member(p.workspace_id) then raise exception 'pursuit unavailable'; end if;

  select * into e from public.estimates where id=p_estimate_id;
  if not found or e.workspace_id<>p.workspace_id then raise exception 'estimate unavailable'; end if;
  if p.organization_id is null or e.organization_id<>p.organization_id then
    raise exception 'estimate must belong to the pursuit organization';
  end if;

  v_opp:=p.opportunity_id;
  if v_opp is null then v_opp:=public.ensure_outreach_opportunity(p.id,null,coalesce(e.total,0)); end if;

  if e.opportunity_id is not null and e.opportunity_id<>v_opp then
    raise exception 'estimate is already linked to another opportunity';
  end if;

  update public.estimates set opportunity_id=v_opp,updated_at=now() where id=e.id;
  update public.outreach_pursuits
    set stage=case when stage in ('research','contact_ready','outreach','engaged','qualified','site_visit') then 'estimating' else stage end,
        next_action='Advance estimate',
        next_action_due_at=now()+interval '1 day',
        last_activity_at=now(),
        updated_at=now()
  where id=p.id;
  return e.id;
end
$$;
revoke all on function public.link_estimate_to_outreach_pursuit(uuid,uuid) from public,anon;
grant execute on function public.link_estimate_to_outreach_pursuit(uuid,uuid) to authenticated;

create or replace function public.sync_outreach_pursuit_from_opportunity()
returns trigger
language plpgsql
security invoker
set search_path=public
as $$
begin
  update public.outreach_pursuits
  set
    stage=case
      when new.status::text='won' then 'won'
      when new.status::text='lost' then 'lost'
      else new.stage::text
    end,
    status=case
      when new.status::text='won' then 'won'
      when new.status::text='lost' then 'lost'
      else status
    end,
    estimated_value=greatest(coalesce(new.estimated_value,0),estimated_value),
    next_action=case
      when new.status::text='won' then 'Handoff won work to operations'
      when new.status::text='lost' then 'Capture loss reason / nurture timing'
      else next_action
    end,
    next_action_due_at=case
      when new.status::text in ('won','lost') then now()
      else next_action_due_at
    end,
    last_activity_at=now(),
    updated_at=now()
  where opportunity_id=new.id;
  return new;
end
$$;

drop trigger if exists trg_sync_outreach_pursuit_from_opportunity on public.opportunities;
create trigger trg_sync_outreach_pursuit_from_opportunity
after insert or update of stage,status,estimated_value
on public.opportunities
for each row execute function public.sync_outreach_pursuit_from_opportunity();

create or replace function public.sync_outreach_opportunity_from_estimate()
returns trigger
language plpgsql
security invoker
set search_path=public
as $$
begin
  if new.opportunity_id is null then return new; end if;

  if new.status::text='accepted' then
    update public.opportunities
    set stage='won',status='won',estimated_value=greatest(estimated_value,coalesce(new.total,0)),
        probability=100,closed_at=coalesce(closed_at,now()),updated_at=now()
    where id=new.opportunity_id and workspace_id=new.workspace_id and status::text<>'lost';
  elsif new.status::text='sent' then
    update public.opportunities
    set stage='proposal',estimated_value=greatest(estimated_value,coalesce(new.total,0)),updated_at=now()
    where id=new.opportunity_id and workspace_id=new.workspace_id
      and stage::text in ('new','qualified','site_visit','estimating');
  elsif new.status::text='draft' then
    update public.opportunities
    set stage='estimating',estimated_value=greatest(estimated_value,coalesce(new.total,0)),updated_at=now()
    where id=new.opportunity_id and workspace_id=new.workspace_id
      and stage::text in ('new','qualified','site_visit');
  end if;

  return new;
end
$$;

drop trigger if exists trg_sync_outreach_opportunity_from_estimate on public.estimates;
create trigger trg_sync_outreach_opportunity_from_estimate
after insert or update of status,opportunity_id,total
on public.estimates
for each row execute function public.sync_outreach_opportunity_from_estimate();

-- ---------------------------------------------------------------------------
-- 4) Message quality scoring and approval guard
-- ---------------------------------------------------------------------------

alter table public.outreach_drafts
  add column if not exists quality_score integer not null default 0 check (quality_score between 0 and 100),
  add column if not exists quality_notes jsonb not null default '{}'::jsonb;

create or replace function public.score_outreach_draft_quality()
returns trigger
language plpgsql
security invoker
set search_path=public
as $$
declare
  v_score integer:=35;
  v_contact_verified boolean:=false;
  v_property_evidence boolean:=false;
  v_signal_evidence boolean:=false;
  v_good_length boolean:=false;
  v_flags jsonb:=coalesce(new.quality_flags,'[]'::jsonb);
  v_evidence_count integer:=0;
begin
  v_contact_verified:=coalesce(new.evidence->>'contact_confidence','')='high'
    or nullif(new.evidence->>'contact_source','') is not null;
  v_property_evidence:=nullif(new.evidence->>'property_id','') is not null
    or nullif(new.evidence->>'property_name','') is not null;
  v_signal_evidence:=nullif(new.evidence->>'signal','') is not null
    and coalesce(new.evidence->>'signal_confidence','') in ('medium','high');

  if v_contact_verified then v_score:=v_score+20; v_evidence_count:=v_evidence_count+1; end if;
  if v_property_evidence then v_score:=v_score+15; v_evidence_count:=v_evidence_count+1; end if;
  if v_signal_evidence then v_score:=v_score+15; v_evidence_count:=v_evidence_count+1; end if;
  if nullif(new.strategy,'') is not null then v_score:=v_score+5; end if;

  v_good_length:=case
    when new.channel='email' then length(new.body) between 80 and 900
    when new.channel='linkedin' then length(new.body) between 40 and 500
    when new.channel='sms' then length(new.body) between 25 and 420
    else length(new.body) between 25 and 1000
  end;
  if v_good_length then v_score:=v_score+10; else v_score:=v_score-10; end if;

  if length(new.body)-length(replace(new.body,'?','')) <= 2 then v_score:=v_score+5; end if;
  if new.body ~* '(just following up|touching base|circling back)' then v_score:=v_score-15; end if;
  if new.body ~* 'snow.{0,30}grounds.{0,30}(janitorial|clean)' then v_score:=v_score-20; end if;
  if jsonb_array_length(v_flags)>0 then v_score:=v_score-(jsonb_array_length(v_flags)*15); end if;

  new.quality_score:=least(100,greatest(0,v_score));
  new.quality_passed:=new.quality_score>=70 and jsonb_array_length(v_flags)=0;
  new.quality_notes:=jsonb_build_object(
    'evidence_count',v_evidence_count,
    'contact_verified',v_contact_verified,
    'property_evidence',v_property_evidence,
    'signal_evidence',v_signal_evidence,
    'length_ok',v_good_length,
    'strategy',new.strategy,
    'quality_flags',v_flags
  );
  return new;
end
$$;

drop trigger if exists trg_score_outreach_draft_quality on public.outreach_drafts;
create trigger trg_score_outreach_draft_quality
before insert or update of body,evidence,channel,strategy,quality_flags
on public.outreach_drafts
for each row execute function public.score_outreach_draft_quality();

update public.outreach_drafts set body=body;

create or replace function public.approve_outreach_draft(p_draft_id uuid)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare d public.outreach_drafts%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select * into d
  from public.outreach_drafts
  where id=p_draft_id
  for update;

  if not found then raise exception 'draft not found'; end if;
  if not private.is_workspace_member(d.workspace_id) then raise exception 'not a member of workspace'; end if;
  if d.state <> 'draft' then
    raise exception 'invalid outreach draft transition: % -> approved', d.state using errcode='22023';
  end if;
  if not d.quality_passed or d.quality_score<70 then
    raise exception 'outreach quality gate failed: score %, flags %',d.quality_score,d.quality_flags::text
      using errcode='22023';
  end if;

  update public.outreach_drafts
  set state='approved',approved_at=now(),updated_at=now()
  where id=p_draft_id;

  update public.outreach_targets
  set next_action='Send approved outreach',next_action_due_at=now(),updated_at=now()
  where id=d.outreach_target_id;

  update public.outreach_pursuits p
  set next_action='Send approved outreach',next_action_due_at=now(),
      next_action_owner_user_id=coalesce(p.next_action_owner_user_id,p.owner_user_id,auth.uid()),
      stage=case when p.stage in ('research','contact_ready') then 'outreach' else p.stage end,
      last_activity_at=now(),updated_at=now()
  from public.outreach_targets t
  where t.id=d.outreach_target_id and p.id=t.pursuit_id;

  return p_draft_id;
end
$$;
revoke all on function public.approve_outreach_draft(uuid) from public,anon;
grant execute on function public.approve_outreach_draft(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 5) Automatic reply ingestion, classification, pursuit update and pause
-- ---------------------------------------------------------------------------

create or replace function public.ingest_outreach_reply(
  p_target_id uuid,
  p_body text,
  p_channel text default 'email',
  p_provider text default null,
  p_provider_message_id text default null,
  p_provider_thread_id text default null,
  p_classification_override text default null,
  p_renewal_date date default null,
  p_referred_contact text default null,
  p_raw_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare
  t public.outreach_targets%rowtype;
  c public.contacts%rowtype;
  p public.outreach_pursuits%rowtype;
  cls record;
  v_id uuid;
  v_existing uuid;
  v_classification text;
  v_confidence numeric;
  v_reason text;
  v_status public.outreach_target_status:='responded';
  v_next text;
  v_due timestamptz;
  v_needs_response boolean:=true;
  v_touch_channel public.outreach_touch_channel;
  v_draft_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if nullif(btrim(coalesce(p_body,'')),'') is null then raise exception 'reply body is required'; end if;
  if p_channel not in ('email','linkedin','call','voicemail','sms','other') then
    raise exception 'unsupported reply channel %',p_channel using errcode='22023';
  end if;

  select * into t from public.outreach_targets where id=p_target_id for update;
  if not found then raise exception 'target not found'; end if;
  if not private.is_workspace_member(t.workspace_id) then raise exception 'not a member of workspace'; end if;
  select * into c from public.contacts where id=t.contact_id;
  select * into p from public.outreach_pursuits where id=t.pursuit_id for update;

  if p_provider_message_id is not null then
    select id into v_existing
    from public.outreach_replies
    where workspace_id=t.workspace_id
      and provider is not distinct from p_provider
      and provider_message_id=p_provider_message_id
    limit 1;
    if v_existing is not null then return v_existing; end if;
  end if;

  select * into cls from public.classify_outreach_reply_text(p_body);
  v_classification:=coalesce(nullif(p_classification_override,''),cls.classification);
  v_confidence:=case when nullif(p_classification_override,'') is not null then 1 else cls.confidence end;
  v_reason:=case when nullif(p_classification_override,'') is not null then 'Operator override' else cls.reason end;

  if v_classification not in (
    'interested','referral','request_quote','request_call','site_visit_request','send_information',
    'under_contract','future_renewal','not_interested','wrong_person','out_of_office','bounce','unsubscribe','other'
  ) then raise exception 'unsupported reply classification %',v_classification using errcode='22023'; end if;

  case v_classification
    when 'interested' then v_next:='Reply and book discovery/site walk'; v_due:=now()+interval '1 day';
    when 'referral' then v_next:='Contact referred decision-maker'; v_due:=now()+interval '1 day';
    when 'request_quote' then v_next:='Build estimate / quote'; v_due:=now()+interval '1 day';
    when 'request_call' then v_next:='Call requested contact'; v_due:=now()+interval '1 day';
    when 'site_visit_request' then v_next:='Book site visit'; v_due:=now()+interval '1 day';
    when 'send_information' then v_next:='Send relevant capability information'; v_due:=now()+interval '1 day';
    when 'under_contract' then v_next:='Capture incumbent and renewal timing'; v_due:=now()+interval '30 days';
    when 'future_renewal' then v_next:='Re-enter before contract renewal'; v_due:=coalesce(p_renewal_date::timestamptz-interval '90 days',now()+interval '90 days');
    when 'wrong_person' then v_next:='Research correct decision-maker'; v_due:=now()+interval '1 day';
    when 'out_of_office' then v_next:='Retry after out-of-office window'; v_due:=now()+interval '7 days'; v_needs_response:=false;
    when 'bounce' then v_next:='Repair contact data'; v_due:=now()+interval '1 day'; v_status:='queued'; v_needs_response:=false;
    when 'unsubscribe' then v_next:='Do not contact'; v_due:=null; v_status:='do_not_contact'; v_needs_response:=false;
    when 'not_interested' then v_next:='Closed / nurture only if appropriate'; v_due:=null; v_status:='rejected'; v_needs_response:=false;
    else v_next:='Review reply and set next action'; v_due:=now()+interval '1 day';
  end case;

  select d.id into v_draft_id
  from public.outreach_drafts d
  where d.outreach_target_id=t.id and d.state='sent'
    and (p_provider_thread_id is null or d.provider_thread_id=p_provider_thread_id or d.provider_thread_id is null)
  order by d.sent_at desc nulls last,d.created_at desc
  limit 1;

  insert into public.outreach_replies(
    workspace_id,pursuit_id,outreach_target_id,outreach_draft_id,channel,
    provider,provider_message_id,provider_thread_id,classification,classification_confidence,
    classification_reason,summary,body,renewal_date,referred_contact,raw_metadata,needs_response
  )
  values(
    t.workspace_id,t.pursuit_id,t.id,v_draft_id,p_channel,
    p_provider,p_provider_message_id,p_provider_thread_id,v_classification,v_confidence,
    v_reason,left(regexp_replace(p_body,'[[:space:]]+',' ','g'),500),p_body,p_renewal_date,
    coalesce(p_referred_contact,
      case when v_classification in ('referral','wrong_person')
        then substring(p_body from '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}')
      end
    ),
    coalesce(p_raw_metadata,'{}'::jsonb) || jsonb_build_object('auto_classified',p_classification_override is null),
    v_needs_response
  )
  returning id into v_id;

  -- Any reply stops the automated cadence immediately. It may only resume after
  -- a human handles the reply and explicitly chooses to resume.
  update public.outreach_enrollments
  set status='paused',paused_at=now(),paused_reason='reply:'||v_classification,last_guard_check_at=now()
  where outreach_target_id=t.id and workspace_id=t.workspace_id and status='active';

  if v_classification in ('bounce','unsubscribe') then
    if not exists(
      select 1 from public.outreach_suppressions s
      where s.workspace_id=t.workspace_id and s.active
        and (
          (t.contact_id is not null and s.contact_id=t.contact_id)
          or (nullif(coalesce(c.email,t.email),'') is not null and lower(coalesce(s.email,''))=lower(coalesce(c.email,t.email)))
        )
    ) then
      insert into public.outreach_suppressions(
        workspace_id,contact_id,email,phone,reason,source_reply_id,created_by,notes
      )
      values(
        t.workspace_id,t.contact_id,coalesce(c.email,t.email),coalesce(c.phone,c.mobile,t.phone),
        v_classification,v_id,auth.uid(),v_reason
      );
    end if;
  end if;

  v_touch_channel:=case p_channel
    when 'email' then 'email'::public.outreach_touch_channel
    when 'sms' then 'sms'::public.outreach_touch_channel
    when 'call' then 'call'::public.outreach_touch_channel
    when 'voicemail' then 'call'::public.outreach_touch_channel
    else 'other'::public.outreach_touch_channel
  end;

  perform public.log_outreach_touch(t.id,v_touch_channel,v_classification,left(p_body,1000),v_status,v_next,v_due);

  if t.pursuit_id is not null then
    update public.outreach_pursuits
    set
      stage=case
        when v_classification in ('interested','request_call','send_information','referral') and stage in ('research','contact_ready','outreach') then 'engaged'
        when v_classification='site_visit_request' then 'site_visit'
        when v_classification='request_quote' then 'estimating'
        when v_classification in ('not_interested','unsubscribe') then 'lost'
        when v_classification in ('under_contract','future_renewal','out_of_office') then 'nurture'
        else stage
      end,
      status=case
        when v_classification in ('not_interested','unsubscribe') then 'lost'
        when v_classification in ('under_contract','future_renewal','out_of_office') then 'paused'
        else 'active'
      end,
      next_action=v_next,
      next_action_due_at=v_due,
      next_action_owner_user_id=coalesce(next_action_owner_user_id,owner_user_id,auth.uid()),
      last_activity_at=now(),
      updated_at=now()
    where id=t.pursuit_id;

    if v_classification in ('request_quote','site_visit_request') and p.organization_id is not null then
      perform public.ensure_outreach_opportunity(t.pursuit_id,v_id,0);
    end if;
  end if;

  return v_id;
end
$$;
revoke all on function public.ingest_outreach_reply(uuid,text,text,text,text,text,text,date,text,jsonb) from public,anon;
grant execute on function public.ingest_outreach_reply(uuid,text,text,text,text,text,text,date,text,jsonb) to authenticated;

-- Backwards-compatible manual classification route now inherits pause/suppression behavior.
create or replace function public.classify_outreach_reply(
  p_target_id uuid,
  p_classification text,
  p_summary text default null,
  p_channel text default 'email',
  p_renewal_date date default null,
  p_referred_contact text default null,
  p_provider text default null,
  p_provider_message_id text default null,
  p_provider_thread_id text default null
)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
begin
  return public.ingest_outreach_reply(
    p_target_id,
    coalesce(nullif(p_summary,''),'Reply logged by operator'),
    p_channel,
    p_provider,
    p_provider_message_id,
    p_provider_thread_id,
    p_classification,
    p_renewal_date,
    p_referred_contact,
    jsonb_build_object('legacy_manual_classification',true)
  );
end
$$;
revoke all on function public.classify_outreach_reply(uuid,text,text,text,date,text,text,text,text) from public,anon;
grant execute on function public.classify_outreach_reply(uuid,text,text,text,date,text,text,text,text) to authenticated;

create or replace function public.handle_outreach_reply(
  p_reply_id uuid,
  p_resolution text default 'handled',
  p_resume_sequence boolean default false
)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare
  r public.outreach_replies%rowtype;
  t public.outreach_targets%rowtype;
  v_blocked boolean;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into r from public.outreach_replies where id=p_reply_id for update;
  if not found or not private.is_workspace_member(r.workspace_id) then raise exception 'reply unavailable'; end if;
  select * into t from public.outreach_targets where id=r.outreach_target_id;

  update public.outreach_replies
  set needs_response=false,handled_at=now(),handled_by=auth.uid(),
      raw_metadata=raw_metadata||jsonb_build_object('resolution',coalesce(nullif(p_resolution,''),'handled'))
  where id=r.id;

  if p_resume_sequence then
    select exists(
      select 1 from public.outreach_suppressions s
      where s.workspace_id=r.workspace_id and s.active
        and ((t.contact_id is not null and s.contact_id=t.contact_id)
          or (nullif(t.email,'') is not null and lower(coalesce(s.email,''))=lower(t.email)))
    ) or exists(
      select 1 from public.outreach_replies x
      where x.outreach_target_id=t.id and x.needs_response and x.handled_at is null and x.id<>r.id
    ) or t.status::text in ('do_not_contact','converted','rejected')
    into v_blocked;

    if not v_blocked then
      update public.outreach_enrollments
      set status='active',
          next_run_at=greatest(now()+interval '1 day',coalesce(t.next_action_due_at,now()+interval '1 day')),
          paused_at=null,paused_reason=null,last_guard_check_at=now()
      where outreach_target_id=t.id and workspace_id=r.workspace_id and status='paused'
        and coalesce(paused_reason,'') like 'reply:%';
    end if;
  end if;

  update public.outreach_pursuits p
  set
    next_action=case when r.classification in ('not_interested','unsubscribe') then 'Closed' else p.next_action end,
    last_activity_at=now(),
    updated_at=now()
  where p.id=r.pursuit_id;

  return r.id;
end
$$;
revoke all on function public.handle_outreach_reply(uuid,text,boolean) from public,anon;
grant execute on function public.handle_outreach_reply(uuid,text,boolean) to authenticated;

create or replace view public.v_outreach_reply_inbox
with (security_invoker=true) as
select
  r.workspace_id,
  r.id as reply_id,
  r.pursuit_id,
  r.outreach_target_id,
  p.display_name as organization_display_name,
  coalesce(nullif(trim(coalesce(c.first_name,'')||' '||coalesce(c.last_name,'')),''),t.contact_name) as contact_display_name,
  coalesce(c.email,t.email) as contact_email,
  c.job_title as contact_job_title,
  r.channel,
  r.received_at,
  r.classification,
  r.classification_confidence,
  r.classification_reason,
  r.summary,
  r.body,
  r.renewal_date,
  r.referred_contact,
  r.needs_response,
  r.handled_at,
  r.handled_by,
  p.stage as pursuit_stage,
  p.next_action,
  p.next_action_due_at,
  p.opportunity_id,
  exists(
    select 1 from public.outreach_enrollments e
    where e.outreach_target_id=t.id and e.status='paused'
  ) as sequence_paused
from public.outreach_replies r
join public.outreach_targets t on t.id=r.outreach_target_id
left join public.outreach_pursuits p on p.id=r.pursuit_id
left join public.contacts c on c.id=t.contact_id;
grant select on public.v_outreach_reply_inbox to authenticated;

-- ---------------------------------------------------------------------------
-- 6) Executable buying-committee / contact researcher
-- ---------------------------------------------------------------------------

create or replace function public.queue_contact_research_task(p_task_id uuid)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare e public.contact_enrichment_tasks%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into e from public.contact_enrichment_tasks where id=p_task_id for update;
  if not found or not private.is_workspace_member(e.workspace_id) then raise exception 'research task unavailable'; end if;
  update public.contact_enrichment_tasks
  set status='queued',next_attempt_at=now(),last_error=null,
      researcher_metadata=coalesce(researcher_metadata,'{}'::jsonb)||jsonb_build_object('queued_by',auth.uid(),'queued_at',now()),
      updated_at=now()
  where id=e.id;
  return e.id;
end
$$;
revoke all on function public.queue_contact_research_task(uuid) from public,anon;
grant execute on function public.queue_contact_research_task(uuid) to authenticated;

create or replace function public.accept_contact_research_candidate(p_task_id uuid)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare
  e public.contact_enrichment_tasks%rowtype;
  v_contact uuid;
  v_first text;
  v_last text;
  v_pursuit uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into e from public.contact_enrichment_tasks where id=p_task_id for update;
  if not found or not private.is_workspace_member(e.workspace_id) then raise exception 'research task unavailable'; end if;
  if e.status not in ('found','verified') or e.confidence<>'high' or e.evidence_url is null or e.candidate_name is null then
    raise exception 'candidate is not eligible for verified promotion';
  end if;

  v_first:=split_part(trim(e.candidate_name),' ',1);
  v_last:=nullif(trim(substr(trim(e.candidate_name),length(v_first)+2)),'');

  select c.id into v_contact
  from public.contacts c
  left join public.organization_contacts oc on oc.contact_id=c.id and oc.organization_id=e.organization_id
  where c.workspace_id=e.workspace_id
    and (
      (nullif(e.candidate_email,'') is not null and lower(coalesce(c.email,''))=lower(e.candidate_email))
      or (lower(c.first_name)=lower(v_first) and lower(coalesce(c.last_name,''))=lower(coalesce(v_last,'')) and oc.id is not null)
    )
  limit 1;

  if v_contact is null then
    insert into public.contacts(
      workspace_id,first_name,last_name,job_title,email,phone,status,
      source_url,source_label,source_confidence,source_verified_at
    )
    values(
      e.workspace_id,v_first,coalesce(v_last,''),e.candidate_title,e.candidate_email,e.candidate_phone,'active',
      e.evidence_url,e.evidence_label,'high',now()
    )
    returning id into v_contact;
  else
    update public.contacts set
      job_title=coalesce(e.candidate_title,job_title),
      email=coalesce(e.candidate_email,email),
      phone=coalesce(e.candidate_phone,phone),
      source_url=e.evidence_url,source_label=e.evidence_label,source_confidence='high',
      source_verified_at=now(),updated_at=now()
    where id=v_contact;
  end if;

  if e.organization_id is not null and not exists(
    select 1 from public.organization_contacts oc
    where oc.workspace_id=e.workspace_id and oc.organization_id=e.organization_id and oc.contact_id=v_contact
  ) then
    insert into public.organization_contacts(workspace_id,organization_id,contact_id,relationship_type,is_primary)
    values(e.workspace_id,e.organization_id,v_contact,e.missing_role,false);
  end if;

  select t.pursuit_id into v_pursuit from public.outreach_targets t where t.id=e.outreach_target_id;
  if v_pursuit is not null then
    insert into public.outreach_pursuit_contacts(
      workspace_id,pursuit_id,contact_id,buying_role,is_primary,evidence_url,evidence_confidence,last_verified_at
    )
    values(e.workspace_id,v_pursuit,v_contact,e.missing_role,false,e.evidence_url,'high',now())
    on conflict(pursuit_id,contact_id,buying_role) do update set
      evidence_url=excluded.evidence_url,evidence_confidence='high',last_verified_at=now(),status='active',updated_at=now();
  end if;

  update public.contact_enrichment_tasks
  set status='verified',verified_at=now(),updated_at=now()
  where id=e.id;

  return v_contact;
end
$$;
revoke all on function public.accept_contact_research_candidate(uuid) from public,anon;
grant execute on function public.accept_contact_research_candidate(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 7) Decomposable scoring and score-improvement recommendations
-- ---------------------------------------------------------------------------

create or replace view public.v_outreach_score_breakdown
with (security_invoker=true) as
with ranked as (
  select
    t.pursuit_id,
    e.*,
    c.source_confidence,
    public.is_named_outreach_person(e.contact_display_name) as named_person,
    row_number() over(
      partition by t.pursuit_id
      order by
        case when e.status='responded' then 0 when e.contact_email is not null then 1 else 2 end,
        e.contact_confidence_score desc,
        e.outreach_readiness_score desc,
        coalesce(e.score,0) desc,
        t.updated_at desc
    ) as rn
  from public.v_outreach_execution_queue e
  join public.outreach_targets t on t.id=e.id
  left join public.contacts c on c.id=t.contact_id
  where t.pursuit_id is not null
),
touch_stats as (
  select t.pursuit_id,
    count(*) filter(where d.state='sent')::int as sent_count
  from public.outreach_targets t
  left join public.outreach_drafts d on d.outreach_target_id=t.id
  where t.pursuit_id is not null
  group by t.pursuit_id
),
reply_stats as (
  select pursuit_id,count(*)::int as reply_count
  from public.outreach_replies
  where pursuit_id is not null
  group by pursuit_id
),
base as (
  select
    r.workspace_id,
    r.pursuit_id,
    r.id as primary_target_id,
    r.organization_display_name,
    r.outreach_readiness_score,
    r.contact_confidence_score,
    r.property_count,
    r.high_signal_property_count,
    r.open_signal_count,
    r.service_fit,
    r.contact_display_name,
    r.contact_email,
    r.source_confidence,
    r.named_person,
    coalesce(pc.contact_coverage_score,0) committee_coverage,
    coalesce(ts.sent_count,0) sent_count,
    coalesce(rs.reply_count,0) reply_count,
    least(25,
      case when r.property_count>0 then 5 else 0 end +
      least(12,r.high_signal_property_count*4) +
      least(8,coalesce(array_length(r.service_fit,1),0)*4)
    )::int fit_score,
    least(25,
      least(20,r.open_signal_count*6) +
      case when r.next_action_due_at is not null and r.next_action_due_at<=now() then 5 else 0 end
    )::int timing_score,
    least(20,
      case when r.source_confidence::text='high' then 8 else 0 end +
      case when r.high_signal_property_count>0 then 6 else 0 end +
      case when r.open_signal_count>0 then 6 else 0 end
    )::int evidence_score,
    least(15,
      case when r.named_person then 5 else 0 end +
      case when nullif(r.contact_email,'') is not null then 5 else 0 end +
      case when r.source_confidence::text='high' then 5 else 0 end
    )::int contact_score,
    least(10,round(coalesce(pc.contact_coverage_score,0)/10.0)::int)::int committee_score,
    least(5,
      case when coalesce(ts.sent_count,0)>0 then 2 else 0 end +
      case when coalesce(rs.reply_count,0)>0 then 3 else 0 end
    )::int relationship_score
  from ranked r
  left join public.v_outreach_pursuit_committee pc on pc.pursuit_id=r.pursuit_id
  left join touch_stats ts on ts.pursuit_id=r.pursuit_id
  left join reply_stats rs on rs.pursuit_id=r.pursuit_id
  where r.rn=1
)
select
  b.*,
  least(100,b.fit_score+b.timing_score+b.evidence_score+b.contact_score+b.committee_score+b.relationship_score)::int as total_score,
  array_remove(array[
    case when b.fit_score<20 then 'Add/verify a strong-fit property or service scope (up to +5)' end,
    case when b.timing_score<15 then 'Add a verified buying signal or due trigger (up to +10)' end,
    case when b.evidence_score<15 then 'Attach stronger contact/property/signal evidence (up to +5)' end,
    case when b.contact_score<15 then 'Verify a named direct contact and source (+5 to +10)' end,
    case when b.committee_score<8 then 'Fill buying-committee gaps (+2 to +8)' end,
    case when b.relationship_score<5 and b.sent_count=0 then 'Start a quality-controlled first touch (+2)' end
  ],null)::text[] as improvement_recommendations
from base b;
grant select on public.v_outreach_score_breakdown to authenticated;

-- ---------------------------------------------------------------------------
-- 8) Safe sequence executor: suppression, reply, duplicate and recent-touch guard
-- ---------------------------------------------------------------------------

create or replace view public.v_outreach_sequence_safety
with (security_invoker=true) as
with base as (
  select
    e.id as enrollment_id,
    e.workspace_id,
    e.outreach_target_id,
    e.sequence_id,
    e.status,
    e.current_step_order,
    e.next_run_at,
    t.pursuit_id,
    t.status as target_status,
    t.contact_id,
    q.contact_email,
    t.last_touch_at,
    row_number() over(
      partition by e.workspace_id,coalesce(t.pursuit_id,t.id)
      order by e.next_run_at,e.created_at,e.id
    ) as pursuit_active_rank,
    exists(
      select 1 from public.outreach_replies r
      where r.outreach_target_id=t.id and r.needs_response and r.handled_at is null
    ) as has_unhandled_reply,
    exists(
      select 1 from public.outreach_suppressions s
      where s.workspace_id=e.workspace_id and s.active
        and (
          (t.contact_id is not null and s.contact_id=t.contact_id)
          or (nullif(q.contact_email,'') is not null and lower(coalesce(s.email,''))=lower(q.contact_email))
        )
    ) as is_suppressed
  from public.outreach_enrollments e
  join public.outreach_targets t on t.id=e.outreach_target_id
  left join public.v_outreach_target_queue q on q.id=t.id
  where e.status='active'
)
select
  b.*,
  (b.next_run_at<=now()) as due_now,
  case
    when b.target_status::text in ('do_not_contact','converted','rejected') then 'closed_target'
    when b.is_suppressed then 'suppressed'
    when b.has_unhandled_reply then 'unhandled_reply'
    when b.pursuit_active_rank>1 then 'duplicate_pursuit_enrollment'
    when b.last_touch_at is not null and b.last_touch_at>now()-interval '20 hours' and b.current_step_order>1 then 'recent_manual_touch'
    when not public.target_is_reachable(b.outreach_target_id) then 'unreachable_contact'
    else null
  end as block_reason,
  case
    when b.target_status::text in ('do_not_contact','converted','rejected') then false
    when b.is_suppressed or b.has_unhandled_reply or b.pursuit_active_rank>1 then false
    when b.last_touch_at is not null and b.last_touch_at>now()-interval '20 hours' and b.current_step_order>1 then false
    when not public.target_is_reachable(b.outreach_target_id) then false
    else true
  end as safe_to_execute
from base b;
grant select on public.v_outreach_sequence_safety to authenticated;

create or replace function public.run_safe_due_sequences(
  p_workspace_id uuid,
  p_limit integer default 50
)
returns jsonb
language plpgsql
security invoker
set search_path=public
as $$
declare
  v_paused integer:=0;
  v_eligible integer:=0;
  v_processed integer:=0;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not private.is_workspace_member(p_workspace_id) then raise exception 'not a member of workspace'; end if;

  update public.outreach_enrollments e
  set status='paused',paused_at=now(),paused_reason=s.block_reason,last_guard_check_at=now()
  from public.v_outreach_sequence_safety s
  where s.enrollment_id=e.id and s.workspace_id=p_workspace_id
    and s.due_now and not s.safe_to_execute;
  get diagnostics v_paused=row_count;

  select count(*)::int into v_eligible
  from public.v_outreach_sequence_safety s
  where s.workspace_id=p_workspace_id and s.due_now and s.safe_to_execute;

  if v_eligible>0 then
    v_processed:=public.process_due_sequence_steps(
      p_workspace_id,
      least(greatest(coalesce(p_limit,50),1),v_eligible)
    );
  end if;

  update public.outreach_enrollments
  set last_guard_check_at=now()
  where workspace_id=p_workspace_id and status='active' and next_run_at<=now();

  return jsonb_build_object(
    'eligible',v_eligible,
    'processed',v_processed,
    'paused',v_paused
  );
end
$$;
revoke all on function public.run_safe_due_sequences(uuid,integer) from public,anon;
grant execute on function public.run_safe_due_sequences(uuid,integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 9) Canonical pursuit queue, full timeline and conversion analytics
-- ---------------------------------------------------------------------------

create or replace view public.v_outreach_pursuit_queue
with (security_invoker=true) as
with primary_row as (
  select
    t.pursuit_id,
    e.*,
    row_number() over(
      partition by t.pursuit_id
      order by
        case when exists(
          select 1 from public.outreach_replies r
          where r.outreach_target_id=t.id and r.needs_response and r.handled_at is null
        ) then 0 else 1 end,
        e.contact_confidence_score desc,
        e.outreach_readiness_score desc,
        coalesce(e.score,0) desc,
        t.updated_at desc
    ) rn
  from public.v_outreach_execution_queue e
  join public.outreach_targets t on t.id=e.id
  where t.pursuit_id is not null
),
reply_stats as (
  select
    pursuit_id,
    count(*)::int reply_count,
    count(*) filter(where needs_response and handled_at is null)::int needs_response_count,
    max(received_at) latest_reply_at
  from public.outreach_replies
  where pursuit_id is not null
  group by pursuit_id
),
latest_reply as (
  select distinct on (pursuit_id)
    pursuit_id,id,classification,classification_confidence,summary,body,received_at,needs_response
  from public.outreach_replies
  where pursuit_id is not null
  order by pursuit_id,received_at desc
)
select
  p.workspace_id,
  p.id as pursuit_id,
  pr.id as primary_target_id,
  p.display_name as organization_display_name,
  p.organization_id,
  p.owner_user_id,
  p.next_action_owner_user_id,
  p.primary_property_id,
  p.opportunity_id,
  p.stage,
  p.status as pursuit_status,
  coalesce(p.next_action,pr.next_action) as next_action,
  coalesce(p.next_action_due_at,pr.next_action_due_at) as next_action_due_at,
  p.estimated_value,
  p.last_activity_at,
  pr.contact_display_name,
  pr.contact_email,
  pr.contact_phone,
  pr.contact_job_title,
  pr.property_count,
  pr.high_signal_property_count,
  pr.open_signal_count,
  pr.why_now,
  pr.service_fit,
  pr.recommended_action as target_recommended_action,
  pr.latest_draft_id,
  pr.latest_draft_state,
  pr.latest_draft_subject,
  pr.latest_draft_body,
  pr.latest_draft_channel,
  coalesce(d.quality_score,0) latest_draft_quality_score,
  coalesce(d.quality_passed,false) latest_draft_quality_passed,
  d.quality_notes as latest_draft_quality_notes,
  coalesce(pc.contact_count,0) contact_count,
  coalesce(pc.contact_coverage_score,0) contact_coverage_score,
  coalesce(pc.has_decision_maker,false) has_decision_maker,
  coalesce(pc.has_operations,false) has_operations,
  coalesce(pc.has_procurement,false) has_procurement,
  coalesce(pc.has_property_contact,false) has_property_contact,
  sb.fit_score,sb.timing_score,sb.evidence_score,sb.contact_score,sb.committee_score,sb.relationship_score,
  sb.total_score,sb.improvement_recommendations,
  coalesce(rs.reply_count,0) reply_count,
  coalesce(rs.needs_response_count,0) needs_response_count,
  rs.latest_reply_at,
  lr.id as latest_reply_id,
  lr.classification as latest_reply_classification,
  lr.classification_confidence as latest_reply_confidence,
  lr.summary as latest_reply_summary,
  lr.body as latest_reply_body,
  lr.needs_response as latest_reply_needs_response,
  case
    when coalesce(rs.needs_response_count,0)>0 then 'handle_reply'
    when p.opportunity_id is not null and p.stage='estimating' then 'advance_estimate'
    else pr.recommended_action
  end as recommended_action,
  least(100,
    coalesce(sb.total_score,0)
    + case when coalesce(rs.needs_response_count,0)>0 then 15 else 0 end
    + case when coalesce(p.next_action_due_at,pr.next_action_due_at)<=now() then 5 else 0 end
  )::int as command_score
from public.outreach_pursuits p
join primary_row pr on pr.pursuit_id=p.id and pr.rn=1
left join public.outreach_drafts d on d.id=pr.latest_draft_id
left join public.v_outreach_pursuit_committee pc on pc.pursuit_id=p.id
left join public.v_outreach_score_breakdown sb on sb.pursuit_id=p.id
left join reply_stats rs on rs.pursuit_id=p.id
left join latest_reply lr on lr.pursuit_id=p.id
where p.status not in ('archived');
grant select on public.v_outreach_pursuit_queue to authenticated;

create or replace function public.get_outreach_pursuit_command_queue(p_limit integer default 30)
returns setof public.v_outreach_pursuit_queue
language sql
security invoker
set search_path=public
as $$
  select *
  from public.v_outreach_pursuit_queue
  where pursuit_status in ('active','paused')
  order by
    case when needs_response_count>0 then 0 else 1 end,
    command_score desc,
    next_action_due_at asc nulls last
  limit least(greatest(coalesce(p_limit,30),1),100)
$$;
revoke all on function public.get_outreach_pursuit_command_queue(integer) from public,anon;
grant execute on function public.get_outreach_pursuit_command_queue(integer) to authenticated;

create or replace view public.v_outreach_timeline
with (security_invoker=true) as
select
  t.workspace_id,t.pursuit_id,ot.id as event_id,'touch'::text as event_type,
  initcap(replace(coalesce(ot.outcome,'touch'),'_',' ')) as title,
  ot.notes as detail,ot.occurred_at,ot.performed_by as actor_user_id,
  jsonb_build_object('channel',ot.channel,'target_id',ot.outreach_target_id) as metadata
from public.outreach_touches ot
join public.outreach_targets t on t.id=ot.outreach_target_id
where t.pursuit_id is not null
union all
select
  d.workspace_id,t.pursuit_id,d.id,'draft_'||d.state,
  case when d.state='sent' then 'Message sent' when d.state='approved' then 'Message approved' else 'Draft generated' end,
  coalesce(d.subject,d.body),coalesce(d.sent_at,d.approved_at,d.generated_at,d.created_at),d.created_by,
  jsonb_build_object('channel',d.channel,'objective',d.objective,'strategy',d.strategy,'quality_score',d.quality_score,'evidence',d.evidence)
from public.outreach_drafts d
join public.outreach_targets t on t.id=d.outreach_target_id
where t.pursuit_id is not null
union all
select
  r.workspace_id,r.pursuit_id,r.id,'reply',
  'Reply: '||replace(r.classification,'_',' '),
  coalesce(r.summary,r.body),r.received_at,r.handled_by,
  jsonb_build_object('channel',r.channel,'confidence',r.classification_confidence,'needs_response',r.needs_response,'referred_contact',r.referred_contact)
from public.outreach_replies r
where r.pursuit_id is not null
union all
select
  e.workspace_id,t.pursuit_id,e.id,'research',
  'Contact research: '||replace(e.missing_role,'_',' '),
  coalesce(e.candidate_name||case when e.candidate_title is not null then ' — '||e.candidate_title else '' end,e.research_query),
  coalesce(e.verified_at,e.last_attempt_at,e.created_at),null::uuid,
  jsonb_build_object('status',e.status,'confidence',e.confidence,'evidence_url',e.evidence_url,'priority',e.research_priority_score)
from public.contact_enrichment_tasks e
join public.outreach_targets t on t.id=e.outreach_target_id
where t.pursuit_id is not null
union all
select
  o.workspace_id,p.id,o.id,'opportunity',
  'Opportunity: '||replace(o.stage::text,'_',' '),
  o.name,o.updated_at,o.owner_user_id,
  jsonb_build_object('status',o.status,'estimated_value',o.estimated_value,'probability',o.probability)
from public.opportunities o
join public.outreach_pursuits p on p.opportunity_id=o.id
union all
select
  e.workspace_id,p.id,e.id,'estimate',
  'Estimate '||e.estimate_number||': '||e.status::text,
  null::text,e.updated_at,e.created_by,
  jsonb_build_object('status',e.status,'total',e.total,'margin',e.estimated_margin)
from public.estimates e
join public.outreach_pursuits p on p.opportunity_id=e.opportunity_id
union all
select
  c.workspace_id,p.id,c.id,'contract',
  'Contract '||c.contract_number||': '||c.status::text,
  c.name,c.updated_at,null::uuid,
  jsonb_build_object('status',c.status,'contract_value',c.contract_value)
from public.contracts c
join public.outreach_pursuits p on p.opportunity_id=c.opportunity_id;
grant select on public.v_outreach_timeline to authenticated;

create or replace view public.v_outreach_conversion_facts
with (security_invoker=true) as
with latest_sent as (
  select distinct on (t.pursuit_id)
    t.pursuit_id,d.strategy,d.objective,d.channel,d.evidence,d.contact_id,d.property_id,d.sent_at
  from public.outreach_drafts d
  join public.outreach_targets t on t.id=d.outreach_target_id
  where t.pursuit_id is not null and d.state='sent'
  order by t.pursuit_id,d.sent_at desc nulls last,d.created_at desc
),
message_stats as (
  select t.pursuit_id,
    count(*) filter(where d.state='sent')::int sent_count
  from public.outreach_targets t
  left join public.outreach_drafts d on d.outreach_target_id=t.id
  where t.pursuit_id is not null
  group by t.pursuit_id
),
reply_stats as (
  select pursuit_id,
    count(*)::int reply_count,
    count(*) filter(where classification in ('interested','referral','request_quote','request_call','site_visit_request','send_information'))::int positive_reply_count
  from public.outreach_replies
  where pursuit_id is not null
  group by pursuit_id
),
estimate_stats as (
  select opportunity_id,
    count(*)::int estimate_count,
    coalesce(sum(total),0) estimate_value,
    coalesce(max(total) filter(where status='accepted'),0) accepted_estimate_value
  from public.estimates
  where opportunity_id is not null
  group by opportunity_id
),
contract_stats as (
  select opportunity_id,
    coalesce(sum(contract_value),0) contract_value
  from public.contracts
  where opportunity_id is not null
  group by opportunity_id
)
select
  p.workspace_id,
  p.id as pursuit_id,
  p.display_name as target_name,
  prop.name as property_name,
  coalesce(ls.evidence->>'service_angle',
    case
      when pi.snow_scope is not null then 'snow and ice'
      when pi.grounds_scope is not null then 'grounds maintenance'
      when pi.janitorial_scope is not null then 'common-area cleaning'
      else 'property services'
    end
  ) as service,
  coalesce(ls.evidence->>'contact_role','unknown') as contact_role,
  coalesce(ls.strategy,'unclassified')||' / '||coalesce(ls.objective,'unknown')||' / '||coalesce(ls.channel,'unknown') as message,
  coalesce(ms.sent_count,0) sent_count,
  coalesce(rs.reply_count,0) reply_count,
  coalesce(rs.positive_reply_count,0) positive_reply_count,
  p.opportunity_id,
  o.status as opportunity_status,
  o.stage as opportunity_stage,
  coalesce(o.estimated_value,0) opportunity_value,
  coalesce(es.estimate_count,0) estimate_count,
  coalesce(es.estimate_value,0) estimate_value,
  case when o.status::text='won'
    then greatest(coalesce(cs.contract_value,0),coalesce(es.accepted_estimate_value,0),coalesce(o.estimated_value,0))
    else 0 end as won_value
from public.outreach_pursuits p
left join public.properties prop on prop.id=p.primary_property_id
left join public.property_intelligence pi
  on pi.workspace_id=p.workspace_id and pi.property_id=p.primary_property_id
left join latest_sent ls on ls.pursuit_id=p.id
left join message_stats ms on ms.pursuit_id=p.id
left join reply_stats rs on rs.pursuit_id=p.id
left join public.opportunities o on o.id=p.opportunity_id
left join estimate_stats es on es.opportunity_id=p.opportunity_id
left join contract_stats cs on cs.opportunity_id=p.opportunity_id;
grant select on public.v_outreach_conversion_facts to authenticated;

create or replace view public.v_outreach_conversion_analytics
with (security_invoker=true) as
with dims as (
  select
    f.workspace_id,'target'::text as dimension,f.target_name as dimension_key,
    f.pursuit_id,f.sent_count,f.reply_count,f.positive_reply_count,f.opportunity_id,
    f.estimate_count,f.opportunity_value,f.won_value
  from public.v_outreach_conversion_facts f
  union all
  select
    f.workspace_id,'property',coalesce(f.property_name,'Unassigned property'),
    f.pursuit_id,f.sent_count,f.reply_count,f.positive_reply_count,f.opportunity_id,
    f.estimate_count,f.opportunity_value,f.won_value
  from public.v_outreach_conversion_facts f
  union all
  select
    f.workspace_id,'service',coalesce(f.service,'Unclassified service'),
    f.pursuit_id,f.sent_count,f.reply_count,f.positive_reply_count,f.opportunity_id,
    f.estimate_count,f.opportunity_value,f.won_value
  from public.v_outreach_conversion_facts f
  union all
  select
    f.workspace_id,'contact_role',coalesce(f.contact_role,'unknown'),
    f.pursuit_id,f.sent_count,f.reply_count,f.positive_reply_count,f.opportunity_id,
    f.estimate_count,f.opportunity_value,f.won_value
  from public.v_outreach_conversion_facts f
  union all
  select
    f.workspace_id,'message',coalesce(f.message,'unclassified'),
    f.pursuit_id,f.sent_count,f.reply_count,f.positive_reply_count,f.opportunity_id,
    f.estimate_count,f.opportunity_value,f.won_value
  from public.v_outreach_conversion_facts f
)
select
  workspace_id,dimension,dimension_key,
  count(distinct pursuit_id)::int as pursuits,
  sum(sent_count)::int as sent,
  sum(reply_count)::int as replies,
  sum(positive_reply_count)::int as positive_replies,
  count(distinct opportunity_id) filter(where opportunity_id is not null)::int as opportunities,
  sum(estimate_count)::int as estimates,
  sum(opportunity_value) as pipeline_value,
  sum(won_value) as won_value,
  case when sum(sent_count)>0 then round(sum(reply_count)::numeric*100/sum(sent_count),1) else 0 end as reply_rate
from dims
group by workspace_id,dimension,dimension_key;
grant select on public.v_outreach_conversion_analytics to authenticated;

-- ---------------------------------------------------------------------------
-- 10) Keep pursuit next-action state synchronized with target activity
-- ---------------------------------------------------------------------------

create or replace function public.sync_outreach_pursuit_from_target()
returns trigger
language plpgsql
security invoker
set search_path=public
as $$
begin
  if new.pursuit_id is null then return new; end if;
  update public.outreach_pursuits p
  set
    owner_user_id=coalesce(p.owner_user_id,new.owner_user_id),
    next_action_owner_user_id=coalesce(p.next_action_owner_user_id,new.owner_user_id),
    next_action=case
      when p.next_action_due_at is null
        or (new.next_action_due_at is not null and new.next_action_due_at<=p.next_action_due_at)
      then coalesce(new.next_action,p.next_action)
      else p.next_action
    end,
    next_action_due_at=case
      when p.next_action_due_at is null then new.next_action_due_at
      when new.next_action_due_at is null then p.next_action_due_at
      else least(p.next_action_due_at,new.next_action_due_at)
    end,
    last_activity_at=greatest(coalesce(p.last_activity_at,'epoch'::timestamptz),coalesce(new.last_touch_at,'epoch'::timestamptz)),
    stage=case
      when new.status::text='responded' and p.stage in ('research','contact_ready','outreach') then 'engaged'
      when new.status::text='contacted' and p.stage in ('research','contact_ready') then 'outreach'
      when new.contact_id is not null and p.stage='research' then 'contact_ready'
      else p.stage
    end,
    updated_at=now()
  where p.id=new.pursuit_id;
  return new;
end
$$;

drop trigger if exists trg_sync_outreach_pursuit_from_target on public.outreach_targets;
create trigger trg_sync_outreach_pursuit_from_target
after insert or update of owner_user_id,next_action,next_action_due_at,last_touch_at,status,contact_id
on public.outreach_targets
for each row execute function public.sync_outreach_pursuit_from_target();

-- Ensure current reply rows have the correct default inbox state.
update public.outreach_replies
set needs_response=false
where handled_at is not null
   or classification in ('out_of_office','bounce','unsubscribe','not_interested');

-- Function grants are explicit; views rely on security_invoker + underlying RLS.
grant execute on function public.outreach_account_key(uuid,text,uuid) to authenticated,service_role;
grant execute on function public.derive_outreach_contact_role(text,text) to authenticated,service_role;

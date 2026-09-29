-- Tender Bid OS v2: amendments, clarifications, supplier RFQs, commercial controls,
-- reusable compliance vault, approvals, risks, readiness gates and post-award call-ups.

alter table public.tender_requirements
  add column if not exists evidence_required boolean not null default false,
  add column if not exists source_reference text;

alter table public.tender_records
  add column if not exists award_value numeric,
  add column if not exists award_date date,
  add column if not exists award_supplier_name text,
  add column if not exists debrief_requested_at timestamptz,
  add column if not exists debrief_notes text,
  add column if not exists commercial_model_required boolean not null default true;

create table if not exists public.tender_amendments (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  tender_record_id uuid not null references public.tender_records(id) on delete cascade,
  amendment_number integer not null default 0,
  title text not null,
  change_summary text,
  changed_fields jsonb not null default '{}'::jsonb,
  source_url text,
  fingerprint text,
  observed_at timestamptz not null default now(),
  effective_at timestamptz,
  acknowledged_at timestamptz,
  acknowledged_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique(tender_record_id, fingerprint)
);

create table if not exists public.tender_clarifications (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  tender_record_id uuid not null references public.tender_records(id) on delete cascade,
  question text not null,
  response_text text,
  status text not null default 'draft' check (status in ('draft','sent','answered','closed')),
  blocking boolean not null default true,
  due_at timestamptz,
  sent_at timestamptz,
  answered_at timestamptz,
  source_url text,
  owner_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.tender_supplier_quotes (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  tender_record_id uuid not null references public.tender_records(id) on delete cascade,
  supplier_name text not null,
  supplier_contact_name text,
  supplier_email text,
  supplier_phone text,
  status text not null default 'invited' check (status in ('invited','sent','received','shortlisted','accepted','rejected')),
  currency text not null default 'CAD',
  product_cost numeric not null default 0,
  freight_cost numeric not null default 0,
  deposits_cost numeric not null default 0,
  handling_cost numeric not null default 0,
  financing_cost numeric not null default 0,
  contingency_cost numeric not null default 0,
  landed_cost numeric generated always as (
    coalesce(product_cost,0)+coalesce(freight_cost,0)+coalesce(deposits_cost,0)+
    coalesce(handling_cost,0)+coalesce(financing_cost,0)+coalesce(contingency_cost,0)
  ) stored,
  minimum_order text,
  lead_time text,
  emergency_delivery boolean,
  delivery_verified boolean not null default false,
  valid_until date,
  quote_reference text,
  evidence_url text,
  notes text,
  sent_at timestamptz,
  received_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.tender_supplier_quote_lines (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  tender_record_id uuid not null references public.tender_records(id) on delete cascade,
  quote_id uuid not null references public.tender_supplier_quotes(id) on delete cascade,
  item_code text,
  description text not null,
  quantity numeric not null default 1,
  unit text not null default 'unit',
  unit_cost numeric not null default 0,
  freight_per_unit numeric not null default 0,
  deposit_per_unit numeric not null default 0,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.tender_cost_models (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  tender_record_id uuid not null references public.tender_records(id) on delete cascade,
  scenario_name text not null default 'Base',
  status text not null default 'draft' check (status in ('draft','approved','obsolete')),
  currency text not null default 'CAD',
  volume_low numeric,
  volume_expected numeric,
  volume_high numeric,
  cost_low numeric,
  cost_expected numeric not null default 0,
  cost_high numeric,
  minimum_margin numeric not null default 0.10 check (minimum_margin >= 0 and minimum_margin < 1),
  target_margin numeric not null default 0.20 check (target_margin >= 0 and target_margin < 1),
  price_floor numeric,
  target_price numeric,
  max_competitive_price numeric,
  working_capital_required numeric,
  payment_lag_days integer,
  assumptions text,
  approved_at timestamptz,
  approved_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(tender_record_id, scenario_name)
);

create table if not exists public.tender_risks (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  tender_record_id uuid not null references public.tender_records(id) on delete cascade,
  title text not null,
  category text not null default 'commercial',
  probability integer not null default 3 check (probability between 1 and 5),
  impact integer not null default 3 check (impact between 1 and 5),
  mitigation text,
  owner_user_id uuid references auth.users(id) on delete set null,
  status text not null default 'open' check (status in ('open','mitigated','accepted','closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.tender_approvals (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  tender_record_id uuid not null references public.tender_records(id) on delete cascade,
  approval_type text not null check (approval_type in ('compliance','commercial','final')),
  status text not null default 'approved' check (status in ('approved','rejected','withdrawn')),
  note text,
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique(tender_record_id, approval_type)
);

create table if not exists public.supplier_document_vault (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  document_type text not null,
  title text not null,
  status text not null default 'active' check (status in ('active','expiring','expired','draft')),
  issuer text,
  reference_number text,
  issued_on date,
  expires_on date,
  evidence_url text,
  storage_path text,
  notes text,
  owner_user_id uuid references auth.users(id) on delete set null,
  last_verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(workspace_id, document_type, title)
);

create table if not exists public.tender_callups (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  tender_record_id uuid not null references public.tender_records(id) on delete cascade,
  callup_number text not null,
  issued_at timestamptz,
  due_at timestamptz,
  delivered_at timestamptz,
  status text not null default 'issued' check (status in ('issued','accepted','in_fulfillment','delivered','invoiced','paid','cancelled')),
  revenue numeric not null default 0,
  direct_cost numeric not null default 0,
  gross_profit numeric generated always as (coalesce(revenue,0)-coalesce(direct_cost,0)) stored,
  invoice_number text,
  invoice_sent_at timestamptz,
  paid_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(tender_record_id, callup_number)
);


alter table public.tender_supplier_quotes
  add column if not exists service_region text,
  add column if not exists distance_km numeric,
  add column if not exists capacity_score integer check (capacity_score between 1 and 5),
  add column if not exists reliability_score integer check (reliability_score between 1 and 5),
  add column if not exists emergency_score integer check (emergency_score between 1 and 5),
  add column if not exists local_fulfillment_score numeric generated always as (
    case
      when capacity_score is null and reliability_score is null and emergency_score is null then null
      else round((
        coalesce(capacity_score,0)::numeric * 0.35 +
        coalesce(reliability_score,0)::numeric * 0.35 +
        coalesce(emergency_score,0)::numeric * 0.30
      ) * 20, 1)
    end
  ) stored;

create table if not exists public.tender_portal_snapshots (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  tender_record_id uuid not null references public.tender_records(id) on delete cascade,
  portal_name text not null,
  capture_method text not null default 'authenticated_manual' check (capture_method in ('authenticated_manual','authenticated_automation','public','import')),
  response_status text,
  response_deadline_at timestamptz,
  source_url text,
  content_hash text,
  raw_payload jsonb not null default '{}'::jsonb,
  notes text,
  captured_by uuid references auth.users(id) on delete set null,
  captured_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique(tender_record_id, portal_name, content_hash)
);

create table if not exists public.tender_line_items (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  tender_record_id uuid not null references public.tender_records(id) on delete cascade,
  portal_snapshot_id uuid references public.tender_portal_snapshots(id) on delete set null,
  item_number text not null,
  description text not null,
  specification text,
  quantity numeric,
  unit text,
  mandatory boolean not null default true,
  source_reference text,
  response_value text,
  unit_price numeric,
  extended_price numeric generated always as (
    case when quantity is null or unit_price is null then null else quantity * unit_price end
  ) stored,
  status text not null default 'pending' check (status in ('pending','priced','complete','not_applicable')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(tender_record_id, item_number)
);

create table if not exists public.tender_price_years (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  tender_record_id uuid not null references public.tender_records(id) on delete cascade,
  cost_model_id uuid not null references public.tender_cost_models(id) on delete cascade,
  year_number integer not null check (year_number between 1 and 10),
  projected_cost numeric not null default 0,
  escalation_rate numeric not null default 0,
  bid_price numeric not null default 0,
  projected_margin numeric generated always as (
    case when bid_price <= 0 then null else (bid_price - projected_cost) / bid_price end
  ) stored,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(cost_model_id, year_number)
);

create table if not exists public.tender_debriefs (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  tender_record_id uuid not null references public.tender_records(id) on delete cascade,
  requested_at timestamptz,
  received_at timestamptz,
  winning_supplier text,
  winning_value numeric,
  result_summary text,
  strengths text,
  gaps text,
  lessons_learned text,
  next_rebid_date date,
  source_url text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(tender_record_id)
);

create index if not exists idx_tender_amendments_tender_observed on public.tender_amendments(tender_record_id, observed_at desc);
create index if not exists idx_tender_clarifications_tender_status on public.tender_clarifications(tender_record_id, status, blocking);
create index if not exists idx_tender_supplier_quotes_tender_status on public.tender_supplier_quotes(tender_record_id, status, landed_cost);
create index if not exists idx_tender_quote_lines_quote on public.tender_supplier_quote_lines(quote_id);
create index if not exists idx_tender_cost_models_tender_status on public.tender_cost_models(tender_record_id, status);
create index if not exists idx_tender_risks_tender_status on public.tender_risks(tender_record_id, status);
create index if not exists idx_tender_approvals_tender on public.tender_approvals(tender_record_id, approval_type, status);
create index if not exists idx_supplier_document_vault_expiry on public.supplier_document_vault(workspace_id, expires_on);
create index if not exists idx_tender_callups_tender_status on public.tender_callups(tender_record_id, status);
create index if not exists idx_tender_portal_snapshots_tender on public.tender_portal_snapshots(tender_record_id, captured_at desc);
create index if not exists idx_tender_line_items_tender_status on public.tender_line_items(tender_record_id, status);
create index if not exists idx_tender_price_years_model on public.tender_price_years(cost_model_id, year_number);
create index if not exists idx_tender_debriefs_rebid on public.tender_debriefs(workspace_id, next_rebid_date);


do $$
declare t text;
begin
  foreach t in array array[
    'tender_amendments','tender_clarifications','tender_supplier_quotes',
    'tender_supplier_quote_lines','tender_cost_models','tender_risks',
    'tender_approvals','supplier_document_vault','tender_callups',
    'tender_portal_snapshots','tender_line_items','tender_price_years','tender_debriefs'
  ]
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('alter table public.%I force row level security', t);
    execute format('drop policy if exists %I_select on public.%I', t, t);
    execute format('create policy %I_select on public.%I for select to authenticated using (public.is_workspace_member(workspace_id))', t, t);
    execute format('drop policy if exists %I_insert on public.%I', t, t);
    execute format('create policy %I_insert on public.%I for insert to authenticated with check (public.is_workspace_member(workspace_id))', t, t);
    execute format('drop policy if exists %I_update on public.%I', t, t);
    execute format('create policy %I_update on public.%I for update to authenticated using (public.is_workspace_member(workspace_id)) with check (public.is_workspace_member(workspace_id))', t, t);
    execute format('drop policy if exists %I_delete on public.%I', t, t);
    execute format('create policy %I_delete on public.%I for delete to authenticated using (public.is_workspace_member(workspace_id))', t, t);
    execute format('grant select,insert,update,delete on public.%I to authenticated', t);
  end loop;
end $$;

create or replace function private.capture_tender_amendment()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  changes jsonb := '{}'::jsonb;
  summary_parts text[] := array[]::text[];
  next_number integer;
  fp text;
begin
  if old.title is distinct from new.title then
    changes := changes || jsonb_build_object('title',jsonb_build_object('from',old.title,'to',new.title));
    summary_parts := array_append(summary_parts,'title');
  end if;
  if old.closing_date is distinct from new.closing_date then
    changes := changes || jsonb_build_object('closing_date',jsonb_build_object('from',old.closing_date,'to',new.closing_date));
    summary_parts := array_append(summary_parts,'closing date');
  end if;
  if old.published_date is distinct from new.published_date then
    changes := changes || jsonb_build_object('published_date',jsonb_build_object('from',old.published_date,'to',new.published_date));
    summary_parts := array_append(summary_parts,'published date');
  end if;
  if old.category is distinct from new.category then
    changes := changes || jsonb_build_object('category',jsonb_build_object('from',old.category,'to',new.category));
    summary_parts := array_append(summary_parts,'category');
  end if;
  if old.response_mode is distinct from new.response_mode then
    changes := changes || jsonb_build_object('response_mode',jsonb_build_object('from',old.response_mode,'to',new.response_mode));
    summary_parts := array_append(summary_parts,'response mode');
  end if;
  if old.registration_required is distinct from new.registration_required then
    changes := changes || jsonb_build_object('registration_required',jsonb_build_object('from',old.registration_required,'to',new.registration_required));
    summary_parts := array_append(summary_parts,'registration requirement');
  end if;
  if old.source_url is distinct from new.source_url then
    changes := changes || jsonb_build_object('source_url',jsonb_build_object('from',old.source_url,'to',new.source_url));
    summary_parts := array_append(summary_parts,'source URL');
  end if;
  if (old.raw_payload->>'detail_excerpt') is distinct from (new.raw_payload->>'detail_excerpt') then
    changes := changes || jsonb_build_object(
      'source_detail',
      jsonb_build_object(
        'from_fingerprint',md5(coalesce(old.raw_payload->>'detail_excerpt','')),
        'to_fingerprint',md5(coalesce(new.raw_payload->>'detail_excerpt',''))
      )
    );
    summary_parts := array_append(summary_parts,'source detail');
  end if;

  if changes = '{}'::jsonb then
    return new;
  end if;

  select coalesce(max(a.amendment_number),0)+1 into next_number
  from public.tender_amendments a
  where a.tender_record_id=new.id;

  fp := md5(new.id::text || ':' || changes::text);

  insert into public.tender_amendments(
    workspace_id,tender_record_id,amendment_number,title,change_summary,changed_fields,source_url,fingerprint,observed_at
  ) values (
    new.workspace_id,new.id,next_number,
    'Detected amendment '||next_number,
    'Changed: '||array_to_string(summary_parts,', '),
    changes,new.source_url,fp,now()
  ) on conflict(tender_record_id,fingerprint) do nothing;

  return new;
end;
$$;

revoke all on function private.capture_tender_amendment() from public, anon, authenticated;

drop trigger if exists tender_records_capture_amendment on public.tender_records;
create trigger tender_records_capture_amendment
after update of title,closing_date,published_date,category,response_mode,registration_required,source_url,raw_payload
on public.tender_records
for each row
execute function private.capture_tender_amendment();

insert into public.tender_amendments(
  workspace_id,tender_record_id,amendment_number,title,change_summary,changed_fields,source_url,fingerprint,observed_at,acknowledged_at
)
select
  t.workspace_id,t.id,0,'Baseline snapshot','Baseline captured when Bid OS v2 was enabled',
  jsonb_build_object(
    'title',t.title,
    'closing_date',t.closing_date,
    'published_date',t.published_date,
    'category',t.category,
    'response_mode',t.response_mode,
    'registration_required',t.registration_required
  ),
  t.source_url,md5(t.id::text||':baseline-v2'),now(),now()
from public.tender_records t
on conflict(tender_record_id,fingerprint) do nothing;

create or replace view public.v_tender_bid_readiness
with (security_invoker = true)
as
select
  t.id as tender_record_id,
  t.workspace_id,
  coalesce(req.mandatory_requirement_gaps,0) as mandatory_requirement_gaps,
  coalesce(req.evidence_gaps,0) as evidence_gaps,
  coalesce(am.unacknowledged_amendments,0) as unacknowledged_amendments,
  coalesce(cl.blocking_clarifications,0) as blocking_clarifications,
  coalesce(q.supplier_quotes_received,0) as supplier_quotes_received,
  coalesce(q.accepted_supplier_quotes,0) as accepted_supplier_quotes,
  coalesce(li.line_item_gaps,0) as line_item_gaps,
  coalesce(risk.high_open_risks,0) as high_open_risks,
  coalesce(cm.commercial_model_approved,false) as commercial_model_approved,
  coalesce(ap.compliance_approved,false) as compliance_approved,
  coalesce(ap.commercial_approved,false) as commercial_approved,
  coalesce(ap.final_approved,false) as final_approved,
  t.estimate_id is not null as estimate_linked,
  (
    coalesce(req.mandatory_requirement_gaps,0)=0
    and coalesce(req.evidence_gaps,0)=0
    and coalesce(am.unacknowledged_amendments,0)=0
    and coalesce(cl.blocking_clarifications,0)=0
    and coalesce(li.line_item_gaps,0)=0
    and coalesce(risk.high_open_risks,0)=0
    and t.estimate_id is not null
    and (not t.commercial_model_required or coalesce(cm.commercial_model_approved,false))
    and coalesce(ap.compliance_approved,false)
    and coalesce(ap.commercial_approved,false)
    and coalesce(ap.final_approved,false)
  ) as ready_to_submit
from public.tender_records t
left join lateral (
  select
    count(*) filter (where r.mandatory and r.status not in ('complete','not_applicable'))::integer as mandatory_requirement_gaps,
    count(*) filter (
      where r.mandatory and r.evidence_required and r.status='complete'
        and nullif(trim(coalesce(r.evidence_url,'')),'') is null
    )::integer as evidence_gaps
  from public.tender_requirements r
  where r.tender_record_id=t.id and r.workspace_id=t.workspace_id
) req on true
left join lateral (
  select count(*) filter (where a.amendment_number>0 and a.acknowledged_at is null)::integer as unacknowledged_amendments
  from public.tender_amendments a
  where a.tender_record_id=t.id and a.workspace_id=t.workspace_id
) am on true
left join lateral (
  select count(*) filter (where c.blocking and c.status not in ('answered','closed'))::integer as blocking_clarifications
  from public.tender_clarifications c
  where c.tender_record_id=t.id and c.workspace_id=t.workspace_id
) cl on true
left join lateral (
  select
    count(*) filter (where q.status in ('received','shortlisted','accepted'))::integer as supplier_quotes_received,
    count(*) filter (where q.status='accepted')::integer as accepted_supplier_quotes
  from public.tender_supplier_quotes q
  where q.tender_record_id=t.id and q.workspace_id=t.workspace_id
) q on true
left join lateral (
  select count(*) filter (
    where li.mandatory and li.status not in ('complete','not_applicable')
  )::integer as line_item_gaps
  from public.tender_line_items li
  where li.tender_record_id=t.id and li.workspace_id=t.workspace_id
) li on true
left join lateral (
  select bool_or(cm.status='approved') as commercial_model_approved
  from public.tender_cost_models cm
  where cm.tender_record_id=t.id and cm.workspace_id=t.workspace_id
) cm on true
left join lateral (
  select count(*) filter (where r.status='open' and (r.probability*r.impact)>=15)::integer as high_open_risks
  from public.tender_risks r
  where r.tender_record_id=t.id and r.workspace_id=t.workspace_id
) risk on true
left join lateral (
  select
    bool_or(a.approval_type='compliance' and a.status='approved') as compliance_approved,
    bool_or(a.approval_type='commercial' and a.status='approved') as commercial_approved,
    bool_or(a.approval_type='final' and a.status='approved') as final_approved
  from public.tender_approvals a
  where a.tender_record_id=t.id and a.workspace_id=t.workspace_id
) ap on true;

grant select on public.v_tender_bid_readiness to authenticated;

-- Seed reusable compliance document categories for CB Contracting without inventing evidence.
insert into public.supplier_document_vault(workspace_id,document_type,title,status,notes)
select w.id,x.document_type,x.title,'draft','Add verified evidence before relying on this document in a bid.'
from public.workspaces w
cross join (values
  ('insurance','Commercial General Liability certificate'),
  ('workers_comp','WSIB / workers compensation clearance'),
  ('corporate','Corporate registration / legal entity evidence'),
  ('tax','CRA Business Number / tax registration evidence'),
  ('safety','Health and safety program / policy'),
  ('references','Government / institutional project references')
) as x(document_type,title)
on conflict(workspace_id,document_type,title) do nothing;

-- CBData canonical schema/security source of truth.
-- Production migration: 20260925194028_canonical_schema_security
-- Generated from the applied production schema after verification.
-- Do not edit production directly; create a new migration for changes.
create extension if not exists "uuid-ossp" with schema extensions;

create type public.activity_status as enum ('planned','completed','cancelled');
create type public.activity_type as enum ('call','email','meeting','site_visit','note','task','other');
create type public.assignment_status as enum ('assigned','accepted','declined','completed','cancelled');
create type public.assignment_type as enum ('crew','employee','contractor','equipment');
create type public.communication_direction as enum ('inbound','outbound','internal');
create type public.communication_type as enum ('email','call','sms','meeting','letter','other');
create type public.contract_status as enum ('draft','pending_signature','active','suspended','expired','terminated','renewal_pending');
create type public.crew_status as enum ('active','inactive');
create type public.document_type as enum ('contract','proposal','estimate','insurance','receipt','site_plan','report','other');
create type public.employment_status as enum ('active','inactive','terminated');
create type public.employment_type as enum ('employee','contractor');
create type public.equipment_status as enum ('available','assigned','maintenance','retired');
create type public.estimate_status as enum ('draft','sent','accepted','rejected','expired','superseded');
create type public.expense_status as enum ('draft','submitted','approved','rejected','paid');
create type public.inspection_result as enum ('pass','warning','fail','not_applicable');
create type public.inspection_status as enum ('scheduled','in_progress','completed','cancelled');
create type public.invoice_status as enum ('draft','issued','partially_paid','paid','void','overdue');
create type public.issue_severity as enum ('low','medium','high','critical');
create type public.issue_status as enum ('open','in_progress','blocked','resolved','closed');
create type public.issue_type as enum ('service_failure','quality','customer_complaint','damage','safety','equipment','access','weather','scope','billing','staffing','other');
create type public.membership_role as enum ('owner','administrator','operations_manager','operations_supervisor','sales_manager','sales_rep','field_supervisor','field_worker','finance','read_only');
create type public.opportunity_stage as enum ('new','qualified','site_visit','estimating','proposal','negotiation','won','lost');
create type public.opportunity_status as enum ('open','won','lost','on_hold');
create type public.organization_type as enum ('prospect','customer','property_manager','condo_corporation','owner','vendor','subcontractor','supplier','partner','other');
create type public.pricing_model as enum ('fixed','unit','hourly','event','seasonal','recurring','other');
create type public.property_status as enum ('prospect','active','inactive','archived');
create type public.proposal_status as enum ('draft','sent','accepted','rejected','expired','superseded');
create type public.record_status as enum ('active','inactive','archived');
create type public.schedule_type as enum ('recurring','one_time','event_triggered');
create type public.system_event_status as enum ('pending','processing','processed','failed','dead_letter');
create type public.task_status as enum ('open','in_progress','completed','cancelled');
create type public.task_type as enum ('follow_up','renewal','operations','issue','inspection','billing','administrative','other');
create type public.unit_type as enum ('flat','hour','visit','square_foot','linear_foot','each','season','event','other');
create type public.work_order_source as enum ('contract_schedule','manual','issue','emergency','estimate','other');
create type public.work_order_status as enum ('draft','scheduled','assigned','en_route','in_progress','paused','completed','needs_review','approved','cancelled');
create type public.work_priority as enum ('low','normal','high','urgent','emergency');
create type public.workspace_status as enum ('active','suspended','archived');

CREATE OR REPLACE FUNCTION public.touch_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$ begin new.updated_at=now(); return new; end $function$;


create table public.activities (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  activity_type activity_type not null,
  subject pg_catalog.text not null,
  description pg_catalog.text,
  organization_id pg_catalog.uuid,
  contact_id pg_catalog.uuid,
  property_id pg_catalog.uuid,
  opportunity_id pg_catalog.uuid,
  assigned_user_id pg_catalog.uuid,
  scheduled_at pg_catalog.timestamptz,
  completed_at pg_catalog.timestamptz,
  status activity_status not null default 'planned'::activity_status,
  created_at pg_catalog.timestamptz not null default now(),
  contract_id pg_catalog.uuid
);

create table public.audit_events (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid,
  actor_user_id pg_catalog.uuid,
  entity_type pg_catalog.text not null,
  entity_id pg_catalog.uuid not null,
  action pg_catalog.text not null,
  old_values pg_catalog.jsonb,
  new_values pg_catalog.jsonb,
  occurred_at pg_catalog.timestamptz not null default now(),
  request_id pg_catalog.uuid
);

create table public.buildings (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  property_id pg_catalog.uuid not null,
  name pg_catalog.text not null,
  building_number pg_catalog.text,
  building_type pg_catalog.text,
  floors pg_catalog.int4,
  notes pg_catalog.text,
  created_at pg_catalog.timestamptz not null default now(),
  updated_at pg_catalog.timestamptz not null default now()
);

create table public.communications (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  communication_type communication_type not null,
  organization_id pg_catalog.uuid,
  contact_id pg_catalog.uuid,
  property_id pg_catalog.uuid,
  opportunity_id pg_catalog.uuid,
  contract_id pg_catalog.uuid,
  issue_id pg_catalog.uuid,
  direction communication_direction not null,
  subject pg_catalog.text,
  body pg_catalog.text,
  occurred_at pg_catalog.timestamptz not null,
  external_message_id pg_catalog.text,
  created_by pg_catalog.uuid,
  created_at pg_catalog.timestamptz not null default now()
);

create table public.contacts (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  first_name pg_catalog.text not null,
  last_name pg_catalog.text not null,
  job_title pg_catalog.text,
  email pg_catalog.text,
  phone pg_catalog.text,
  mobile pg_catalog.text,
  status record_status not null default 'active'::record_status,
  notes pg_catalog.text,
  created_at pg_catalog.timestamptz not null default now(),
  updated_at pg_catalog.timestamptz not null default now()
);

create table public.contract_services (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  contract_id pg_catalog.uuid not null,
  service_definition_id pg_catalog.uuid not null,
  scope_description pg_catalog.text not null,
  pricing_model pricing_model not null,
  contract_price pg_catalog.numeric not null default 0,
  quantity pg_catalog.numeric,
  unit pg_catalog.text,
  start_date pg_catalog.date not null,
  end_date pg_catalog.date,
  active pg_catalog.bool not null default true,
  created_at pg_catalog.timestamptz not null default now(),
  updated_at pg_catalog.timestamptz not null default now()
);

create table public.contractors (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  organization_id pg_catalog.uuid not null,
  status record_status not null default 'active'::record_status,
  insurance_expiry pg_catalog.date,
  insurance_document_id pg_catalog.uuid,
  notes pg_catalog.text
);

create table public.contracts (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  contract_number pg_catalog.text not null,
  organization_id pg_catalog.uuid not null,
  property_id pg_catalog.uuid not null,
  opportunity_id pg_catalog.uuid,
  proposal_id pg_catalog.uuid,
  name pg_catalog.text not null,
  status contract_status not null default 'draft'::contract_status,
  start_date pg_catalog.date not null,
  end_date pg_catalog.date,
  contract_value pg_catalog.numeric not null default 0,
  billing_frequency pg_catalog.text,
  renewal_type pg_catalog.text,
  signed_document_id pg_catalog.uuid,
  created_at pg_catalog.timestamptz not null default now(),
  updated_at pg_catalog.timestamptz not null default now(),
  terminated_at pg_catalog.timestamptz
);

create table public.crew_members (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  crew_id pg_catalog.uuid not null,
  employee_id pg_catalog.uuid not null,
  start_date pg_catalog.date not null,
  end_date pg_catalog.date
);

create table public.crews (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  name pg_catalog.text not null,
  crew_type pg_catalog.text,
  supervisor_employee_id pg_catalog.uuid,
  status crew_status not null default 'active'::crew_status
);

create table public.documents (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  entity_type pg_catalog.text not null,
  entity_id pg_catalog.uuid not null,
  document_type document_type not null default 'other'::document_type,
  file_name pg_catalog.text not null,
  storage_path pg_catalog.text not null,
  mime_type pg_catalog.text,
  file_size pg_catalog.int8,
  uploaded_by pg_catalog.uuid,
  created_at pg_catalog.timestamptz not null default now()
);

create table public.employees (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  user_id pg_catalog.uuid,
  first_name pg_catalog.text not null,
  last_name pg_catalog.text not null,
  employment_status employment_status not null default 'active'::employment_status,
  employment_type employment_type not null default 'employee'::employment_type,
  phone pg_catalog.text,
  email pg_catalog.text,
  hire_date pg_catalog.date,
  termination_date pg_catalog.date,
  cost_rate pg_catalog.numeric,
  notes pg_catalog.text,
  created_at pg_catalog.timestamptz not null default now(),
  updated_at pg_catalog.timestamptz not null default now()
);

create table public.equipment (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  name pg_catalog.text not null,
  equipment_type pg_catalog.text not null,
  asset_number pg_catalog.text not null,
  serial_number pg_catalog.text,
  status equipment_status not null default 'available'::equipment_status,
  purchase_date pg_catalog.date,
  purchase_cost pg_catalog.numeric,
  operating_cost_rate pg_catalog.numeric,
  current_location pg_catalog.text,
  notes pg_catalog.text
);

create table public.estimate_items (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  estimate_id pg_catalog.uuid not null,
  service_definition_id pg_catalog.uuid,
  description pg_catalog.text not null,
  quantity pg_catalog.numeric not null default 1,
  unit pg_catalog.text,
  unit_price pg_catalog.numeric not null default 0,
  estimated_labor_cost pg_catalog.numeric not null default 0,
  estimated_material_cost pg_catalog.numeric not null default 0,
  estimated_equipment_cost pg_catalog.numeric not null default 0,
  estimated_subcontractor_cost pg_catalog.numeric not null default 0,
  line_total pg_catalog.numeric not null default 0,
  sort_order pg_catalog.int4 not null default 0
);

create table public.estimates (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  estimate_number pg_catalog.text not null,
  opportunity_id pg_catalog.uuid,
  organization_id pg_catalog.uuid not null,
  property_id pg_catalog.uuid,
  status estimate_status not null default 'draft'::estimate_status,
  valid_until pg_catalog.date,
  estimated_start_date pg_catalog.date,
  subtotal pg_catalog.numeric not null default 0,
  tax pg_catalog.numeric not null default 0,
  total pg_catalog.numeric not null default 0,
  estimated_direct_cost pg_catalog.numeric not null default 0,
  estimated_gross_profit pg_catalog.numeric not null default 0,
  estimated_margin pg_catalog.numeric not null default 0,
  created_by pg_catalog.uuid,
  created_at pg_catalog.timestamptz not null default now(),
  updated_at pg_catalog.timestamptz not null default now()
);

create table public.expenses (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  work_order_id pg_catalog.uuid,
  property_id pg_catalog.uuid,
  employee_id pg_catalog.uuid,
  expense_type pg_catalog.text not null,
  description pg_catalog.text not null,
  amount pg_catalog.numeric not null,
  expense_date pg_catalog.date not null,
  receipt_document_id pg_catalog.uuid,
  status expense_status not null default 'draft'::expense_status,
  created_at pg_catalog.timestamptz not null default now()
);

create table public.inspection_items (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  inspection_id pg_catalog.uuid not null,
  criterion pg_catalog.text not null,
  result inspection_result not null,
  notes pg_catalog.text,
  issue_id pg_catalog.uuid
);

create table public.inspections (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  property_id pg_catalog.uuid not null,
  work_order_id pg_catalog.uuid,
  contract_id pg_catalog.uuid,
  inspection_type pg_catalog.text not null,
  status inspection_status not null default 'scheduled'::inspection_status,
  inspector_id pg_catalog.uuid,
  scheduled_at pg_catalog.timestamptz,
  started_at pg_catalog.timestamptz,
  completed_at pg_catalog.timestamptz,
  overall_result inspection_result,
  notes pg_catalog.text
);

create table public.invoice_items (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  invoice_id pg_catalog.uuid not null,
  contract_service_id pg_catalog.uuid,
  work_order_id pg_catalog.uuid,
  description pg_catalog.text not null,
  quantity pg_catalog.numeric not null default 1,
  unit_price pg_catalog.numeric not null default 0,
  total pg_catalog.numeric not null default 0
);

create table public.invoices (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  invoice_number pg_catalog.text not null,
  organization_id pg_catalog.uuid not null,
  property_id pg_catalog.uuid,
  contract_id pg_catalog.uuid,
  status invoice_status not null default 'draft'::invoice_status,
  invoice_date pg_catalog.date not null,
  due_date pg_catalog.date,
  subtotal pg_catalog.numeric not null default 0,
  tax pg_catalog.numeric not null default 0,
  total pg_catalog.numeric not null default 0,
  external_accounting_id pg_catalog.text,
  created_at pg_catalog.timestamptz not null default now()
);

create table public.issues (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  property_id pg_catalog.uuid not null,
  work_order_id pg_catalog.uuid,
  contract_id pg_catalog.uuid,
  issue_type issue_type not null,
  severity issue_severity not null default 'medium'::issue_severity,
  status issue_status not null default 'open'::issue_status,
  title pg_catalog.text not null,
  description pg_catalog.text not null,
  reported_by pg_catalog.uuid,
  assigned_to pg_catalog.uuid,
  reported_at pg_catalog.timestamptz not null default now(),
  due_at pg_catalog.timestamptz,
  resolved_at pg_catalog.timestamptz,
  resolution_notes pg_catalog.text,
  customer_visible pg_catalog.bool not null default false,
  created_at pg_catalog.timestamptz not null default now(),
  updated_at pg_catalog.timestamptz not null default now()
);

create table public.leads (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  organization_id pg_catalog.uuid,
  contact_id pg_catalog.uuid,
  property_id pg_catalog.uuid,
  source pg_catalog.text,
  lead_type pg_catalog.text,
  status pg_catalog.text not null default 'new'::text,
  owner_user_id pg_catalog.uuid,
  created_at pg_catalog.timestamptz not null default now(),
  qualified_at pg_catalog.timestamptz,
  disqualified_at pg_catalog.timestamptz
);

create table public.material_usage (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  work_order_id pg_catalog.uuid,
  property_id pg_catalog.uuid,
  material_name pg_catalog.text not null,
  quantity pg_catalog.numeric not null,
  unit pg_catalog.text not null,
  unit_cost pg_catalog.numeric not null,
  total_cost pg_catalog.numeric not null,
  created_at pg_catalog.timestamptz not null default now()
);

create table public.notes (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  entity_type pg_catalog.text not null,
  entity_id pg_catalog.uuid not null,
  body pg_catalog.text not null,
  created_by pg_catalog.uuid,
  created_at pg_catalog.timestamptz not null default now()
);

create table public.opportunities (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  organization_id pg_catalog.uuid not null,
  property_id pg_catalog.uuid,
  name pg_catalog.text not null,
  stage opportunity_stage not null default 'new'::opportunity_stage,
  status opportunity_status not null default 'open'::opportunity_status,
  owner_user_id pg_catalog.uuid,
  estimated_value pg_catalog.numeric not null default 0,
  estimated_start_date pg_catalog.date,
  estimated_close_date pg_catalog.date,
  probability pg_catalog.numeric,
  lost_reason pg_catalog.text,
  notes pg_catalog.text,
  created_at pg_catalog.timestamptz not null default now(),
  updated_at pg_catalog.timestamptz not null default now(),
  closed_at pg_catalog.timestamptz
);

create table public.organization_contacts (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  organization_id pg_catalog.uuid not null,
  contact_id pg_catalog.uuid not null,
  relationship_type pg_catalog.text not null,
  is_primary pg_catalog.bool not null default false,
  start_date pg_catalog.date,
  end_date pg_catalog.date
);

create table public.organizations (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  legal_name pg_catalog.text not null,
  operating_name pg_catalog.text,
  organization_type organization_type not null,
  status record_status not null default 'active'::record_status,
  website pg_catalog.text,
  phone pg_catalog.text,
  email pg_catalog.text,
  notes pg_catalog.text,
  created_at pg_catalog.timestamptz not null default now(),
  updated_at pg_catalog.timestamptz not null default now(),
  archived_at pg_catalog.timestamptz
);

create table public.payments (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  invoice_id pg_catalog.uuid not null,
  payment_date pg_catalog.date not null,
  amount pg_catalog.numeric not null,
  payment_method pg_catalog.text,
  external_reference pg_catalog.text,
  created_at pg_catalog.timestamptz not null default now()
);

create table public.photos (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  entity_type pg_catalog.text not null,
  entity_id pg_catalog.uuid not null,
  storage_path pg_catalog.text not null,
  photo_type pg_catalog.text not null default 'general'::text,
  captured_at pg_catalog.timestamptz,
  uploaded_by pg_catalog.uuid,
  latitude pg_catalog.numeric,
  longitude pg_catalog.numeric,
  created_at pg_catalog.timestamptz not null default now()
);

create table public.properties (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  name pg_catalog.text not null,
  address_line_1 pg_catalog.text not null,
  address_line_2 pg_catalog.text,
  city pg_catalog.text not null,
  province pg_catalog.text,
  postal_code pg_catalog.text,
  country pg_catalog.text not null default 'Canada'::text,
  latitude pg_catalog.numeric,
  longitude pg_catalog.numeric,
  property_type pg_catalog.text not null,
  status property_status not null default 'prospect'::property_status,
  owner_organization_id pg_catalog.uuid,
  primary_customer_organization_id pg_catalog.uuid,
  management_organization_id pg_catalog.uuid,
  access_notes pg_catalog.text,
  site_notes pg_catalog.text,
  created_at pg_catalog.timestamptz not null default now(),
  updated_at pg_catalog.timestamptz not null default now(),
  archived_at pg_catalog.timestamptz
);

create table public.property_contacts (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  property_id pg_catalog.uuid not null,
  contact_id pg_catalog.uuid not null,
  relationship_type pg_catalog.text not null,
  is_primary pg_catalog.bool not null default false,
  emergency_contact pg_catalog.bool not null default false,
  notes pg_catalog.text
);

create table public.proposals (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  estimate_id pg_catalog.uuid not null,
  version pg_catalog.int4 not null,
  status proposal_status not null default 'draft'::proposal_status,
  sent_at pg_catalog.timestamptz,
  accepted_at pg_catalog.timestamptz,
  rejected_at pg_catalog.timestamptz,
  document_id pg_catalog.uuid,
  created_at pg_catalog.timestamptz not null default now()
);

create table public.service_definitions (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  name pg_catalog.text not null,
  category pg_catalog.text not null,
  description pg_catalog.text,
  unit_type unit_type not null default 'flat'::unit_type,
  default_duration_minutes pg_catalog.int4,
  active pg_catalog.bool not null default true,
  created_at pg_catalog.timestamptz not null default now(),
  updated_at pg_catalog.timestamptz not null default now()
);

create table public.service_schedules (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  contract_service_id pg_catalog.uuid not null,
  schedule_type schedule_type not null,
  frequency pg_catalog.text,
  day_of_week pg_catalog.int4,
  day_of_month pg_catalog.int4,
  start_time pg_catalog.time,
  duration_minutes pg_catalog.int4,
  season_start pg_catalog.date,
  season_end pg_catalog.date,
  weather_trigger pg_catalog.bool not null default false,
  instructions pg_catalog.text,
  active pg_catalog.bool not null default true,
  created_at pg_catalog.timestamptz not null default now(),
  updated_at pg_catalog.timestamptz not null default now()
);

create table public.subcontractor_costs (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  work_order_id pg_catalog.uuid,
  contractor_id pg_catalog.uuid not null,
  description pg_catalog.text not null,
  cost pg_catalog.numeric not null,
  invoice_reference pg_catalog.text,
  created_at pg_catalog.timestamptz not null default now()
);

create table public.system_events (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid,
  event_type pg_catalog.text not null,
  entity_type pg_catalog.text not null,
  entity_id pg_catalog.uuid not null,
  payload pg_catalog.jsonb not null default '{}'::jsonb,
  status system_event_status not null default 'pending'::system_event_status,
  occurred_at pg_catalog.timestamptz not null default now(),
  processed_at pg_catalog.timestamptz,
  attempt_count pg_catalog.int4 not null default 0,
  last_error pg_catalog.text
);

create table public.tasks (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  title pg_catalog.text not null,
  description pg_catalog.text,
  task_type task_type not null default 'administrative'::task_type,
  status task_status not null default 'open'::task_status,
  priority work_priority not null default 'normal'::work_priority,
  assigned_to pg_catalog.uuid,
  organization_id pg_catalog.uuid,
  property_id pg_catalog.uuid,
  opportunity_id pg_catalog.uuid,
  contract_id pg_catalog.uuid,
  work_order_id pg_catalog.uuid,
  issue_id pg_catalog.uuid,
  due_at pg_catalog.timestamptz,
  completed_at pg_catalog.timestamptz,
  created_by pg_catalog.uuid,
  created_at pg_catalog.timestamptz not null default now()
);

create table public.time_entries (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  employee_id pg_catalog.uuid not null,
  work_order_id pg_catalog.uuid,
  started_at pg_catalog.timestamptz not null,
  ended_at pg_catalog.timestamptz,
  hours pg_catalog.numeric not null,
  cost_rate pg_catalog.numeric not null,
  total_cost pg_catalog.numeric not null,
  approved pg_catalog.bool not null default false,
  created_at pg_catalog.timestamptz not null default now()
);

create table public.user_profiles (
  id pg_catalog.uuid not null,
  display_name pg_catalog.text,
  first_name pg_catalog.text,
  last_name pg_catalog.text,
  phone pg_catalog.text,
  created_at pg_catalog.timestamptz not null default now(),
  updated_at pg_catalog.timestamptz not null default now()
);

create table public.work_order_assignments (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  work_order_id pg_catalog.uuid not null,
  assignment_type assignment_type not null,
  employee_id pg_catalog.uuid,
  crew_id pg_catalog.uuid,
  contractor_id pg_catalog.uuid,
  equipment_id pg_catalog.uuid,
  assigned_at pg_catalog.timestamptz not null default now(),
  unassigned_at pg_catalog.timestamptz,
  status assignment_status not null default 'assigned'::assignment_status
);

create table public.work_order_tasks (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  work_order_id pg_catalog.uuid not null,
  description pg_catalog.text not null,
  sequence pg_catalog.int4 not null default 0,
  required pg_catalog.bool not null default true,
  status pg_catalog.text not null default 'open'::text,
  completed_by pg_catalog.uuid,
  completed_at pg_catalog.timestamptz,
  notes pg_catalog.text
);

create table public.work_orders (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  work_order_number pg_catalog.text not null,
  property_id pg_catalog.uuid not null,
  contract_id pg_catalog.uuid,
  contract_service_id pg_catalog.uuid,
  source_type work_order_source not null default 'manual'::work_order_source,
  priority work_priority not null default 'normal'::work_priority,
  status work_order_status not null default 'draft'::work_order_status,
  scheduled_start pg_catalog.timestamptz,
  scheduled_end pg_catalog.timestamptz,
  estimated_duration_minutes pg_catalog.int4,
  actual_duration_minutes pg_catalog.int4,
  description pg_catalog.text not null,
  site_instructions pg_catalog.text,
  created_by pg_catalog.uuid,
  created_at pg_catalog.timestamptz not null default now(),
  updated_at pg_catalog.timestamptz not null default now(),
  completed_at pg_catalog.timestamptz,
  cancelled_at pg_catalog.timestamptz
);

create table public.work_visits (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  work_order_id pg_catalog.uuid not null,
  started_at pg_catalog.timestamptz not null,
  ended_at pg_catalog.timestamptz,
  latitude pg_catalog.numeric,
  longitude pg_catalog.numeric,
  notes pg_catalog.text,
  completion_status work_order_status not null default 'in_progress'::work_order_status,
  created_by pg_catalog.uuid
);

create table public.workspace_memberships (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  user_id pg_catalog.uuid not null,
  role membership_role not null default 'read_only'::membership_role,
  status record_status not null default 'active'::record_status,
  created_at pg_catalog.timestamptz not null default now(),
  updated_at pg_catalog.timestamptz not null default now()
);


CREATE OR REPLACE FUNCTION public.has_workspace_role(p_workspace_id uuid, p_roles membership_role[])
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ select exists(select 1 from public.workspace_memberships m where m.workspace_id=p_workspace_id and m.user_id=auth.uid() and m.status='active' and m.role=any(p_roles)) $function$;


CREATE OR REPLACE FUNCTION public.is_workspace_member(p_workspace_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ select exists(select 1 from public.workspace_memberships m where m.workspace_id=p_workspace_id and m.user_id=auth.uid() and m.status='active') $function$;


create table public.workspaces (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  name pg_catalog.text not null,
  slug pg_catalog.text not null,
  status workspace_status not null default 'active'::workspace_status,
  created_at pg_catalog.timestamptz not null default now(),
  updated_at pg_catalog.timestamptz not null default now()
);


alter table public.activities add constraint activities_pkey PRIMARY KEY (id);
alter table public.audit_events add constraint audit_events_pkey PRIMARY KEY (id);
alter table public.buildings add constraint buildings_floors_check CHECK (((floors IS NULL) OR (floors > 0)));
alter table public.buildings add constraint buildings_pkey PRIMARY KEY (id);
alter table public.communications add constraint communications_pkey PRIMARY KEY (id);
alter table public.contacts add constraint contacts_pkey PRIMARY KEY (id);
alter table public.contract_services add constraint contract_services_check CHECK (((end_date IS NULL) OR (end_date >= start_date)));
alter table public.contract_services add constraint contract_services_contract_price_check CHECK ((contract_price >= (0)::numeric));
alter table public.contract_services add constraint contract_services_pkey PRIMARY KEY (id);
alter table public.contract_services add constraint contract_services_quantity_check CHECK (((quantity IS NULL) OR (quantity >= (0)::numeric)));
alter table public.contractors add constraint contractors_pkey PRIMARY KEY (id);
alter table public.contractors add constraint contractors_workspace_id_organization_id_key UNIQUE (workspace_id, organization_id);
alter table public.contracts add constraint contracts_check CHECK (((end_date IS NULL) OR (end_date >= start_date)));
alter table public.contracts add constraint contracts_contract_value_check CHECK ((contract_value >= (0)::numeric));
alter table public.contracts add constraint contracts_pkey PRIMARY KEY (id);
alter table public.contracts add constraint contracts_workspace_id_contract_number_key UNIQUE (workspace_id, contract_number);
alter table public.crew_members add constraint crew_members_check CHECK (((end_date IS NULL) OR (end_date >= start_date)));
alter table public.crew_members add constraint crew_members_crew_id_employee_id_start_date_key UNIQUE (crew_id, employee_id, start_date);
alter table public.crew_members add constraint crew_members_pkey PRIMARY KEY (id);
alter table public.crews add constraint crews_pkey PRIMARY KEY (id);
alter table public.crews add constraint crews_workspace_id_name_key UNIQUE (workspace_id, name);
alter table public.documents add constraint documents_file_size_check CHECK (((file_size IS NULL) OR (file_size >= 0)));
alter table public.documents add constraint documents_pkey PRIMARY KEY (id);
alter table public.employees add constraint employees_cost_rate_check CHECK (((cost_rate IS NULL) OR (cost_rate >= (0)::numeric)));
alter table public.employees add constraint employees_pkey PRIMARY KEY (id);
alter table public.equipment add constraint equipment_operating_cost_rate_check CHECK (((operating_cost_rate IS NULL) OR (operating_cost_rate >= (0)::numeric)));
alter table public.equipment add constraint equipment_pkey PRIMARY KEY (id);
alter table public.equipment add constraint equipment_purchase_cost_check CHECK (((purchase_cost IS NULL) OR (purchase_cost >= (0)::numeric)));
alter table public.equipment add constraint equipment_workspace_id_asset_number_key UNIQUE (workspace_id, asset_number);
alter table public.estimate_items add constraint estimate_items_check CHECK (((quantity >= (0)::numeric) AND (unit_price >= (0)::numeric) AND (line_total >= (0)::numeric)));
alter table public.estimate_items add constraint estimate_items_pkey PRIMARY KEY (id);
alter table public.estimates add constraint estimates_check CHECK (((subtotal >= (0)::numeric) AND (tax >= (0)::numeric) AND (total >= (0)::numeric) AND (estimated_direct_cost >= (0)::numeric)));
alter table public.estimates add constraint estimates_pkey PRIMARY KEY (id);
alter table public.estimates add constraint estimates_workspace_id_estimate_number_key UNIQUE (workspace_id, estimate_number);
alter table public.expenses add constraint expenses_amount_check CHECK ((amount >= (0)::numeric));
alter table public.expenses add constraint expenses_pkey PRIMARY KEY (id);
alter table public.inspection_items add constraint inspection_items_pkey PRIMARY KEY (id);
alter table public.inspections add constraint inspections_check CHECK (((completed_at IS NULL) OR (started_at IS NULL) OR (completed_at >= started_at)));
alter table public.inspections add constraint inspections_pkey PRIMARY KEY (id);
alter table public.invoice_items add constraint invoice_items_check CHECK (((quantity >= (0)::numeric) AND (unit_price >= (0)::numeric) AND (total >= (0)::numeric)));
alter table public.invoice_items add constraint invoice_items_pkey PRIMARY KEY (id);
alter table public.invoices add constraint invoices_check CHECK (((subtotal >= (0)::numeric) AND (tax >= (0)::numeric) AND (total >= (0)::numeric)));
alter table public.invoices add constraint invoices_check1 CHECK (((due_date IS NULL) OR (due_date >= invoice_date)));
alter table public.invoices add constraint invoices_pkey PRIMARY KEY (id);
alter table public.invoices add constraint invoices_workspace_id_invoice_number_key UNIQUE (workspace_id, invoice_number);
alter table public.issues add constraint issues_check CHECK (((status = ANY (ARRAY['resolved'::issue_status, 'closed'::issue_status])) = (resolved_at IS NOT NULL)));
alter table public.issues add constraint issues_pkey PRIMARY KEY (id);
alter table public.leads add constraint leads_pkey PRIMARY KEY (id);
alter table public.material_usage add constraint material_usage_check CHECK (((quantity >= (0)::numeric) AND (unit_cost >= (0)::numeric) AND (total_cost >= (0)::numeric)));
alter table public.material_usage add constraint material_usage_pkey PRIMARY KEY (id);
alter table public.notes add constraint notes_pkey PRIMARY KEY (id);
alter table public.opportunities add constraint opportunities_estimated_value_check CHECK ((estimated_value >= (0)::numeric));
alter table public.opportunities add constraint opportunities_pkey PRIMARY KEY (id);
alter table public.opportunities add constraint opportunities_probability_check CHECK (((probability IS NULL) OR ((probability >= (0)::numeric) AND (probability <= (1)::numeric))));
alter table public.organization_contacts add constraint organization_contacts_organization_id_contact_id_relationsh_key UNIQUE (organization_id, contact_id, relationship_type);
alter table public.organization_contacts add constraint organization_contacts_pkey PRIMARY KEY (id);
alter table public.organizations add constraint organizations_pkey PRIMARY KEY (id);
alter table public.payments add constraint payments_amount_check CHECK ((amount > (0)::numeric));
alter table public.payments add constraint payments_pkey PRIMARY KEY (id);
alter table public.photos add constraint photos_pkey PRIMARY KEY (id);
alter table public.properties add constraint properties_latitude_check CHECK (((latitude IS NULL) OR ((latitude >= ('-90'::integer)::numeric) AND (latitude <= (90)::numeric))));
alter table public.properties add constraint properties_longitude_check CHECK (((longitude IS NULL) OR ((longitude >= ('-180'::integer)::numeric) AND (longitude <= (180)::numeric))));
alter table public.properties add constraint properties_pkey PRIMARY KEY (id);
alter table public.property_contacts add constraint property_contacts_pkey PRIMARY KEY (id);
alter table public.property_contacts add constraint property_contacts_property_id_contact_id_relationship_type_key UNIQUE (property_id, contact_id, relationship_type);
alter table public.proposals add constraint proposals_estimate_id_version_key UNIQUE (estimate_id, version);
alter table public.proposals add constraint proposals_pkey PRIMARY KEY (id);
alter table public.proposals add constraint proposals_version_check CHECK ((version > 0));
alter table public.service_definitions add constraint service_definitions_default_duration_minutes_check CHECK (((default_duration_minutes IS NULL) OR (default_duration_minutes > 0)));
alter table public.service_definitions add constraint service_definitions_pkey PRIMARY KEY (id);
alter table public.service_definitions add constraint service_definitions_workspace_id_name_key UNIQUE (workspace_id, name);
alter table public.service_schedules add constraint service_schedules_day_of_month_check CHECK (((day_of_month IS NULL) OR ((day_of_month >= 1) AND (day_of_month <= 31))));
alter table public.service_schedules add constraint service_schedules_day_of_week_check CHECK (((day_of_week IS NULL) OR ((day_of_week >= 0) AND (day_of_week <= 6))));
alter table public.service_schedules add constraint service_schedules_duration_minutes_check CHECK (((duration_minutes IS NULL) OR (duration_minutes > 0)));
alter table public.service_schedules add constraint service_schedules_pkey PRIMARY KEY (id);
alter table public.subcontractor_costs add constraint subcontractor_costs_cost_check CHECK ((cost >= (0)::numeric));
alter table public.subcontractor_costs add constraint subcontractor_costs_pkey PRIMARY KEY (id);
alter table public.system_events add constraint system_events_attempt_count_check CHECK ((attempt_count >= 0));
alter table public.system_events add constraint system_events_pkey PRIMARY KEY (id);
alter table public.tasks add constraint tasks_pkey PRIMARY KEY (id);
alter table public.time_entries add constraint time_entries_check CHECK (((hours >= (0)::numeric) AND (cost_rate >= (0)::numeric) AND (total_cost >= (0)::numeric)));
alter table public.time_entries add constraint time_entries_check1 CHECK (((ended_at IS NULL) OR (ended_at >= started_at)));
alter table public.time_entries add constraint time_entries_pkey PRIMARY KEY (id);
alter table public.user_profiles add constraint user_profiles_pkey PRIMARY KEY (id);
alter table public.work_order_assignments add constraint work_order_assignments_pkey PRIMARY KEY (id);
alter table public.work_order_tasks add constraint work_order_tasks_pkey PRIMARY KEY (id);
alter table public.work_orders add constraint work_orders_actual_duration_minutes_check CHECK (((actual_duration_minutes IS NULL) OR (actual_duration_minutes >= 0)));
alter table public.work_orders add constraint work_orders_check CHECK (((scheduled_end IS NULL) OR (scheduled_start IS NULL) OR (scheduled_end >= scheduled_start)));
alter table public.work_orders add constraint work_orders_estimated_duration_minutes_check CHECK (((estimated_duration_minutes IS NULL) OR (estimated_duration_minutes > 0)));
alter table public.work_orders add constraint work_orders_pkey PRIMARY KEY (id);
alter table public.work_orders add constraint work_orders_workspace_id_work_order_number_key UNIQUE (workspace_id, work_order_number);
alter table public.work_visits add constraint work_visits_check CHECK (((ended_at IS NULL) OR (ended_at >= started_at)));
alter table public.work_visits add constraint work_visits_pkey PRIMARY KEY (id);
alter table public.workspace_memberships add constraint workspace_memberships_pkey PRIMARY KEY (id);
alter table public.workspace_memberships add constraint workspace_memberships_workspace_id_user_id_key UNIQUE (workspace_id, user_id);
alter table public.workspaces add constraint workspaces_pkey PRIMARY KEY (id);
alter table public.workspaces add constraint workspaces_slug_key UNIQUE (slug);

CREATE INDEX idx_assignments_work_order ON public.work_order_assignments USING btree (workspace_id, work_order_id, status);
CREATE INDEX idx_audit_entity ON public.audit_events USING btree (workspace_id, entity_type, entity_id, occurred_at DESC);
CREATE INDEX idx_buildings_property ON public.buildings USING btree (workspace_id, property_id);
CREATE INDEX idx_contacts_ws_name ON public.contacts USING btree (workspace_id, last_name, first_name);
CREATE INDEX idx_contract_services_contract ON public.contract_services USING btree (workspace_id, contract_id, active);
CREATE INDEX idx_contracts_property ON public.contracts USING btree (workspace_id, property_id, status);
CREATE INDEX idx_contracts_renewal ON public.contracts USING btree (workspace_id, end_date) WHERE (status = ANY (ARRAY['active'::contract_status, 'renewal_pending'::contract_status]));
CREATE INDEX idx_estimates_status ON public.estimates USING btree (workspace_id, status);
CREATE INDEX idx_inspections_property ON public.inspections USING btree (workspace_id, property_id, status);
CREATE INDEX idx_invoice_items_work_order ON public.invoice_items USING btree (workspace_id, work_order_id);
CREATE INDEX idx_invoices_ar ON public.invoices USING btree (workspace_id, status, due_date);
CREATE INDEX idx_issues_queue ON public.issues USING btree (workspace_id, status, severity, due_at);
CREATE INDEX idx_opps_stage ON public.opportunities USING btree (workspace_id, stage, status);
CREATE INDEX idx_org_ws_name ON public.organizations USING btree (workspace_id, operating_name, legal_name);
CREATE INDEX idx_properties_ws_city ON public.properties USING btree (workspace_id, city);
CREATE INDEX idx_properties_ws_postal ON public.properties USING btree (workspace_id, postal_code);
CREATE INDEX idx_properties_ws_status ON public.properties USING btree (workspace_id, status);
CREATE INDEX idx_schedules_service ON public.service_schedules USING btree (workspace_id, contract_service_id, active);
CREATE INDEX idx_system_queue ON public.system_events USING btree (status, occurred_at);
CREATE INDEX idx_tasks_due ON public.tasks USING btree (workspace_id, status, due_at);
CREATE INDEX idx_time_work_order ON public.time_entries USING btree (workspace_id, work_order_id);
CREATE INDEX idx_work_orders_property ON public.work_orders USING btree (workspace_id, property_id, status);
CREATE INDEX idx_work_orders_schedule ON public.work_orders USING btree (workspace_id, scheduled_start, status);

create policy workspace_member_insert on public.activities for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.activities for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.activities for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.audit_events for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.audit_events for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.audit_events for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.buildings for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.buildings for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.buildings for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.communications for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.communications for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.communications for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.contacts for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.contacts for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.contacts for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.contract_services for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.contract_services for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.contract_services for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.contractors for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.contractors for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.contractors for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.contracts for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.contracts for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.contracts for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.crew_members for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.crew_members for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.crew_members for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.crews for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.crews for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.crews for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.documents for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.documents for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.documents for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.employees for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.employees for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.employees for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.equipment for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.equipment for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.equipment for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.estimate_items for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.estimate_items for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.estimate_items for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.estimates for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.estimates for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.estimates for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.expenses for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.expenses for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.expenses for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.inspection_items for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.inspection_items for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.inspection_items for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.inspections for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.inspections for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.inspections for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.invoice_items for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.invoice_items for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.invoice_items for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.invoices for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.invoices for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.invoices for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.issues for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.issues for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.issues for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.leads for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.leads for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.leads for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.material_usage for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.material_usage for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.material_usage for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.notes for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.notes for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.notes for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.opportunities for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.opportunities for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.opportunities for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.organization_contacts for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.organization_contacts for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.organization_contacts for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.organizations for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.organizations for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.organizations for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.payments for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.payments for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.payments for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.photos for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.photos for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.photos for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.properties for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.properties for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.properties for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.property_contacts for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.property_contacts for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.property_contacts for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.proposals for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.proposals for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.proposals for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.service_definitions for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.service_definitions for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.service_definitions for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.service_schedules for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.service_schedules for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.service_schedules for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.subcontractor_costs for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.subcontractor_costs for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.subcontractor_costs for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.system_events for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.system_events for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.system_events for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.tasks for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.tasks for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.tasks for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.time_entries for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.time_entries for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.time_entries for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.work_order_assignments for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.work_order_assignments for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.work_order_assignments for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.work_order_tasks for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.work_order_tasks for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.work_order_tasks for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.work_orders for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.work_orders for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.work_orders for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.work_visits for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.work_visits for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.work_visits for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy membership_select on public.workspace_memberships for select using (is_workspace_member(workspace_id));

CREATE TRIGGER trg_buildings_updated BEFORE UPDATE ON public.buildings FOR EACH ROW EXECUTE FUNCTION touch_updated_at()
CREATE TRIGGER trg_contacts_updated BEFORE UPDATE ON public.contacts FOR EACH ROW EXECUTE FUNCTION touch_updated_at()
CREATE TRIGGER trg_contract_services_updated BEFORE UPDATE ON public.contract_services FOR EACH ROW EXECUTE FUNCTION touch_updated_at()
CREATE TRIGGER trg_contracts_updated BEFORE UPDATE ON public.contracts FOR EACH ROW EXECUTE FUNCTION touch_updated_at()
CREATE TRIGGER trg_employees_updated BEFORE UPDATE ON public.employees FOR EACH ROW EXECUTE FUNCTION touch_updated_at()
CREATE TRIGGER trg_estimates_updated BEFORE UPDATE ON public.estimates FOR EACH ROW EXECUTE FUNCTION touch_updated_at()
CREATE TRIGGER trg_issues_updated BEFORE UPDATE ON public.issues FOR EACH ROW EXECUTE FUNCTION touch_updated_at()
CREATE TRIGGER trg_opportunities_updated BEFORE UPDATE ON public.opportunities FOR EACH ROW EXECUTE FUNCTION touch_updated_at()
CREATE TRIGGER trg_org_updated BEFORE UPDATE ON public.organizations FOR EACH ROW EXECUTE FUNCTION touch_updated_at()
CREATE TRIGGER trg_properties_updated BEFORE UPDATE ON public.properties FOR EACH ROW EXECUTE FUNCTION touch_updated_at()
CREATE TRIGGER trg_services_updated BEFORE UPDATE ON public.service_definitions FOR EACH ROW EXECUTE FUNCTION touch_updated_at()
CREATE TRIGGER trg_schedules_updated BEFORE UPDATE ON public.service_schedules FOR EACH ROW EXECUTE FUNCTION touch_updated_at()
CREATE TRIGGER trg_profiles_updated BEFORE UPDATE ON public.user_profiles FOR EACH ROW EXECUTE FUNCTION touch_updated_at()
CREATE TRIGGER trg_work_orders_updated BEFORE UPDATE ON public.work_orders FOR EACH ROW EXECUTE FUNCTION touch_updated_at()
CREATE TRIGGER trg_memberships_updated BEFORE UPDATE ON public.workspace_memberships FOR EACH ROW EXECUTE FUNCTION touch_updated_at()
CREATE TRIGGER trg_workspaces_updated BEFORE UPDATE ON public.workspaces FOR EACH ROW EXECUTE FUNCTION touch_updated_at()

create or replace view public.contract_renewal_queue as  SELECT id,
    workspace_id,
    contract_number,
    organization_id,
    property_id,
    opportunity_id,
    proposal_id,
    name,
    status,
    start_date,
    end_date,
    contract_value,
    billing_frequency,
    renewal_type,
    signed_document_id,
    created_at,
    updated_at,
    terminated_at
   FROM contracts
  WHERE ((status = ANY (ARRAY['active'::contract_status, 'renewal_pending'::contract_status])) AND (end_date IS NOT NULL));;
create or replace view public.open_issue_queue as  SELECT id,
    workspace_id,
    property_id,
    work_order_id,
    contract_id,
    issue_type,
    severity,
    status,
    title,
    description,
    reported_by,
    assigned_to,
    reported_at,
    due_at,
    resolved_at,
    resolution_notes,
    customer_visible,
    created_at,
    updated_at
   FROM issues
  WHERE (status = ANY (ARRAY['open'::issue_status, 'in_progress'::issue_status, 'blocked'::issue_status]))
  ORDER BY
        CASE severity
            WHEN 'critical'::issue_severity THEN 1
            WHEN 'high'::issue_severity THEN 2
            WHEN 'medium'::issue_severity THEN 3
            ELSE 4
        END, due_at;;
create or replace view public.open_work_exceptions as  SELECT id,
    workspace_id,
    work_order_number,
    property_id,
    contract_id,
    contract_service_id,
    source_type,
    priority,
    status,
    scheduled_start,
    scheduled_end,
    estimated_duration_minutes,
    actual_duration_minutes,
    description,
    site_instructions,
    created_by,
    created_at,
    updated_at,
    completed_at,
    cancelled_at
   FROM work_orders
  WHERE (status = ANY (ARRAY['draft'::work_order_status, 'scheduled'::work_order_status, 'assigned'::work_order_status, 'en_route'::work_order_status, 'in_progress'::work_order_status, 'paused'::work_order_status, 'needs_review'::work_order_status]));;
create or replace view public.property_360 as  SELECT p.id,
    p.workspace_id,
    p.name,
    p.address_line_1,
    p.city,
    p.province,
    p.postal_code,
    p.status,
    o.operating_name AS customer_name,
    count(DISTINCT c.id) FILTER (WHERE (c.status = 'active'::contract_status)) AS active_contracts,
    count(DISTINCT w.id) FILTER (WHERE (w.status <> ALL (ARRAY['completed'::work_order_status, 'approved'::work_order_status, 'cancelled'::work_order_status]))) AS open_work_orders,
    count(DISTINCT i.id) FILTER (WHERE (i.status = ANY (ARRAY['open'::issue_status, 'in_progress'::issue_status, 'blocked'::issue_status]))) AS open_issues
   FROM ((((properties p
     LEFT JOIN organizations o ON ((o.id = p.primary_customer_organization_id)))
     LEFT JOIN contracts c ON ((c.property_id = p.id)))
     LEFT JOIN work_orders w ON ((w.property_id = p.id)))
     LEFT JOIN issues i ON ((i.property_id = p.id)))
  GROUP BY p.id, o.operating_name;;create table public.organizations (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  legal_name pg_catalog.text not null,
  operating_name pg_catalog.text,
  organization_type organization_type not null,
  status record_status not null default 'active'::record_status,
  website pg_catalog.text,
  phone pg_catalog.text,
  email pg_catalog.text,
  notes pg_catalog.text,
  created_at pg_catalog.timestamptz not null default now(),
  updated_at pg_catalog.timestamptz not null default now(),
  archived_at pg_catalog.timestamptz
);

create table public.payments (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  invoice_id pg_catalog.uuid not null,
  payment_date pg_catalog.date not null,
  amount pg_catalog.numeric not null,
  payment_method pg_catalog.text,
  external_reference pg_catalog.text,
  created_at pg_catalog.timestamptz not null default now()
);

create table public.photos (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  entity_type pg_catalog.text not null,
  entity_id pg_catalog.uuid not null,
  storage_path pg_catalog.text not null,
  photo_type pg_catalog.text not null default 'general'::text,
  captured_at pg_catalog.timestamptz,
  uploaded_by pg_catalog.uuid,
  latitude pg_catalog.numeric,
  longitude pg_catalog.numeric,
  created_at pg_catalog.timestamptz not null default now()
);

create table public.properties (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  name pg_catalog.text not null,
  address_line_1 pg_catalog.text not null,
  address_line_2 pg_catalog.text,
  city pg_catalog.text not null,
  province pg_catalog.text,
  postal_code pg_catalog.text,
  country pg_catalog.text not null default 'Canada'::text,
  latitude pg_catalog.numeric,
  longitude pg_catalog.numeric,
  property_type pg_catalog.text not null,
  status property_status not null default 'prospect'::property_status,
  owner_organization_id pg_catalog.uuid,
  primary_customer_organization_id pg_catalog.uuid,
  management_organization_id pg_catalog.uuid,
  access_notes pg_catalog.text,
  site_notes pg_catalog.text,
  created_at pg_catalog.timestamptz not null default now(),
  updated_at pg_catalog.timestamptz not null default now(),
  archived_at pg_catalog.timestamptz
);

create table public.property_contacts (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  property_id pg_catalog.uuid not null,
  contact_id pg_catalog.uuid not null,
  relationship_type pg_catalog.text not null,
  is_primary pg_catalog.bool not null default false,
  emergency_contact pg_catalog.bool not null default false,
  notes pg_catalog.text
);

create table public.proposals (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  estimate_id pg_catalog.uuid not null,
  version pg_catalog.int4 not null,
  status proposal_status not null default 'draft'::proposal_status,
  sent_at pg_catalog.timestamptz,
  accepted_at pg_catalog.timestamptz,
  rejected_at pg_catalog.timestamptz,
  document_id pg_catalog.uuid,
  created_at pg_catalog.timestamptz not null default now()
);

create table public.service_definitions (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  name pg_catalog.text not null,
  category pg_catalog.text not null,
  description pg_catalog.text,
  unit_type unit_type not null default 'flat'::unit_type,
  default_duration_minutes pg_catalog.int4,
  active pg_catalog.bool not null default true,
  created_at pg_catalog.timestamptz not null default now(),
  updated_at pg_catalog.timestamptz not null default now()
);

create table public.service_schedules (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  contract_service_id pg_catalog.uuid not null,
  schedule_type schedule_type not null,
  frequency pg_catalog.text,
  day_of_week pg_catalog.int4,
  day_of_month pg_catalog.int4,
  start_time pg_catalog.time,
  duration_minutes pg_catalog.int4,
  season_start pg_catalog.date,
  season_end pg_catalog.date,
  weather_trigger pg_catalog.bool not null default false,
  instructions pg_catalog.text,
  active pg_catalog.bool not null default true,
  created_at pg_catalog.timestamptz not null default now(),
  updated_at pg_catalog.timestamptz not null default now()
);

create table public.subcontractor_costs (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  work_order_id pg_catalog.uuid,
  contractor_id pg_catalog.uuid not null,
  description pg_catalog.text not null,
  cost pg_catalog.numeric not null,
  invoice_reference pg_catalog.text,
  created_at pg_catalog.timestamptz not null default now()
);

create table public.system_events (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid,
  event_type pg_catalog.text not null,
  entity_type pg_catalog.text not null,
  entity_id pg_catalog.uuid not null,
  payload pg_catalog.jsonb not null default '{}'::jsonb,
  status system_event_status not null default 'pending'::system_event_status,
  occurred_at pg_catalog.timestamptz not null default now(),
  processed_at pg_catalog.timestamptz,
  attempt_count pg_catalog.int4 not null default 0,
  last_error pg_catalog.text
);

create table public.tasks (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  title pg_catalog.text not null,
  description pg_catalog.text,
  task_type task_type not null default 'administrative'::task_type,
  status task_status not null default 'open'::task_status,
  priority work_priority not null default 'normal'::work_priority,
  assigned_to pg_catalog.uuid,
  organization_id pg_catalog.uuid,
  property_id pg_catalog.uuid,
  opportunity_id pg_catalog.uuid,
  contract_id pg_catalog.uuid,
  work_order_id pg_catalog.uuid,
  issue_id pg_catalog.uuid,
  due_at pg_catalog.timestamptz,
  completed_at pg_catalog.timestamptz,
  created_by pg_catalog.uuid,
  created_at pg_catalog.timestamptz not null default now()
);

create table public.time_entries (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  employee_id pg_catalog.uuid not null,
  work_order_id pg_catalog.uuid,
  started_at pg_catalog.timestamptz not null,
  ended_at pg_catalog.timestamptz,
  hours pg_catalog.numeric not null,
  cost_rate pg_catalog.numeric not null,
  total_cost pg_catalog.numeric not null,
  approved pg_catalog.bool not null default false,
  created_at pg_catalog.timestamptz not null default now()
);

create table public.user_profiles (
  id pg_catalog.uuid not null,
  display_name pg_catalog.text,
  first_name pg_catalog.text,
  last_name pg_catalog.text,
  phone pg_catalog.text,
  created_at pg_catalog.timestamptz not null default now(),
  updated_at pg_catalog.timestamptz not null default now()
);

create table public.work_order_assignments (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  work_order_id pg_catalog.uuid not null,
  assignment_type assignment_type not null,
  employee_id pg_catalog.uuid,
  crew_id pg_catalog.uuid,
  contractor_id pg_catalog.uuid,
  equipment_id pg_catalog.uuid,
  assigned_at pg_catalog.timestamptz not null default now(),
  unassigned_at pg_catalog.timestamptz,
  status assignment_status not null default 'assigned'::assignment_status
);

create table public.work_order_tasks (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  work_order_id pg_catalog.uuid not null,
  description pg_catalog.text not null,
  sequence pg_catalog.int4 not null default 0,
  required pg_catalog.bool not null default true,
  status pg_catalog.text not null default 'open'::text,
  completed_by pg_catalog.uuid,
  completed_at pg_catalog.timestamptz,
  notes pg_catalog.text
);

create table public.work_orders (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  work_order_number pg_catalog.text not null,
  property_id pg_catalog.uuid not null,
  contract_id pg_catalog.uuid,
  contract_service_id pg_catalog.uuid,
  source_type work_order_source not null default 'manual'::work_order_source,
  priority work_priority not null default 'normal'::work_priority,
  status work_order_status not null default 'draft'::work_order_status,
  scheduled_start pg_catalog.timestamptz,
  scheduled_end pg_catalog.timestamptz,
  estimated_duration_minutes pg_catalog.int4,
  actual_duration_minutes pg_catalog.int4,
  description pg_catalog.text not null,
  site_instructions pg_catalog.text,
  created_by pg_catalog.uuid,
  created_at pg_catalog.timestamptz not null default now(),
  updated_at pg_catalog.timestamptz not null default now(),
  completed_at pg_catalog.timestamptz,
  cancelled_at pg_catalog.timestamptz
);

create table public.work_visits (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  work_order_id pg_catalog.uuid not null,
  started_at pg_catalog.timestamptz not null,
  ended_at pg_catalog.timestamptz,
  latitude pg_catalog.numeric,
  longitude pg_catalog.numeric,
  notes pg_catalog.text,
  completion_status work_order_status not null default 'in_progress'::work_order_status,
  created_by pg_catalog.uuid
);

create table public.workspace_memberships (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  workspace_id pg_catalog.uuid not null,
  user_id pg_catalog.uuid not null,
  role membership_role not null default 'read_only'::membership_role,
  status record_status not null default 'active'::record_status,
  created_at pg_catalog.timestamptz not null default now(),
  updated_at pg_catalog.timestamptz not null default now()
);

create table public.workspaces (
  id pg_catalog.uuid not null default uuid_generate_v4(),
  name pg_catalog.text not null,
  slug pg_catalog.text not null,
  status workspace_status not null default 'active'::workspace_status,
  created_at pg_catalog.timestamptz not null default now(),
  updated_at pg_catalog.timestamptz not null default now()
);

alter table public.activities add constraint activities_pkey PRIMARY KEY (id);
alter table public.audit_events add constraint audit_events_pkey PRIMARY KEY (id);
alter table public.buildings add constraint buildings_floors_check CHECK (((floors IS NULL) OR (floors > 0)));
alter table public.buildings add constraint buildings_pkey PRIMARY KEY (id);
alter table public.communications add constraint communications_pkey PRIMARY KEY (id);
alter table public.contacts add constraint contacts_pkey PRIMARY KEY (id);
alter table public.contract_services add constraint contract_services_check CHECK (((end_date IS NULL) OR (end_date >= start_date)));
alter table public.contract_services add constraint contract_services_contract_price_check CHECK ((contract_price >= (0)::numeric));
alter table public.contract_services add constraint contract_services_pkey PRIMARY KEY (id);
alter table public.contract_services add constraint contract_services_quantity_check CHECK (((quantity IS NULL) OR (quantity >= (0)::numeric)));
alter table public.contractors add constraint contractors_pkey PRIMARY KEY (id);
alter table public.contractors add constraint contractors_workspace_id_organization_id_key UNIQUE (workspace_id, organization_id);
alter table public.contracts add constraint contracts_check CHECK (((end_date IS NULL) OR (end_date >= start_date)));
alter table public.contracts add constraint contracts_contract_value_check CHECK ((contract_value >= (0)::numeric));
alter table public.contracts add constraint contracts_pkey PRIMARY KEY (id);
alter table public.contracts add constraint contracts_workspace_id_contract_number_key UNIQUE (workspace_id, contract_number);
alter table public.crew_members add constraint crew_members_check CHECK (((end_date IS NULL) OR (end_date >= start_date)));
alter table public.crew_members add constraint crew_members_crew_id_employee_id_start_date_key UNIQUE (crew_id, employee_id, start_date);
alter table public.crew_members add constraint crew_members_pkey PRIMARY KEY (id);
alter table public.crews add constraint crews_pkey PRIMARY KEY (id);
alter table public.crews add constraint crews_workspace_id_name_key UNIQUE (workspace_id, name);
alter table public.documents add constraint documents_file_size_check CHECK (((file_size IS NULL) OR (file_size >= 0)));
alter table public.documents add constraint documents_pkey PRIMARY KEY (id);
alter table public.employees add constraint employees_cost_rate_check CHECK (((cost_rate IS NULL) OR (cost_rate >= (0)::numeric)));
alter table public.employees add constraint employees_pkey PRIMARY KEY (id);
alter table public.equipment add constraint equipment_operating_cost_rate_check CHECK (((operating_cost_rate IS NULL) OR (operating_cost_rate >= (0)::numeric)));
alter table public.equipment add constraint equipment_pkey PRIMARY KEY (id);
alter table public.equipment add constraint equipment_purchase_cost_check CHECK (((purchase_cost IS NULL) OR (purchase_cost >= (0)::numeric)));
alter table public.equipment add constraint equipment_workspace_id_asset_number_key UNIQUE (workspace_id, asset_number);
alter table public.estimate_items add constraint estimate_items_check CHECK (((quantity >= (0)::numeric) AND (unit_price >= (0)::numeric) AND (line_total >= (0)::numeric)));
alter table public.estimate_items add constraint estimate_items_pkey PRIMARY KEY (id);
alter table public.estimates add constraint estimates_check CHECK (((subtotal >= (0)::numeric) AND (tax >= (0)::numeric) AND (total >= (0)::numeric) AND (estimated_direct_cost >= (0)::numeric)));
alter table public.estimates add constraint estimates_pkey PRIMARY KEY (id);
alter table public.estimates add constraint estimates_workspace_id_estimate_number_key UNIQUE (workspace_id, estimate_number);
alter table public.expenses add constraint expenses_amount_check CHECK ((amount >= (0)::numeric));
alter table public.expenses add constraint expenses_pkey PRIMARY KEY (id);
alter table public.inspection_items add constraint inspection_items_pkey PRIMARY KEY (id);
alter table public.inspections add constraint inspections_check CHECK (((completed_at IS NULL) OR (started_at IS NULL) OR (completed_at >= started_at)));
alter table public.inspections add constraint inspections_pkey PRIMARY KEY (id);
alter table public.invoice_items add constraint invoice_items_check CHECK (((quantity >= (0)::numeric) AND (unit_price >= (0)::numeric) AND (total >= (0)::numeric)));
alter table public.invoice_items add constraint invoice_items_pkey PRIMARY KEY (id);
alter table public.invoices add constraint invoices_check CHECK (((subtotal >= (0)::numeric) AND (tax >= (0)::numeric) AND (total >= (0)::numeric)));
alter table public.invoices add constraint invoices_check1 CHECK (((due_date IS NULL) OR (due_date >= invoice_date)));
alter table public.invoices add constraint invoices_pkey PRIMARY KEY (id);
alter table public.invoices add constraint invoices_workspace_id_invoice_number_key UNIQUE (workspace_id, invoice_number);
alter table public.issues add constraint issues_check CHECK (((status = ANY (ARRAY['resolved'::issue_status, 'closed'::issue_status])) = (resolved_at IS NOT NULL)));
alter table public.issues add constraint issues_pkey PRIMARY KEY (id);
alter table public.leads add constraint leads_pkey PRIMARY KEY (id);
alter table public.material_usage add constraint material_usage_check CHECK (((quantity >= (0)::numeric) AND (unit_cost >= (0)::numeric) AND (total_cost >= (0)::numeric)));
alter table public.material_usage add constraint material_usage_pkey PRIMARY KEY (id);
alter table public.notes add constraint notes_pkey PRIMARY KEY (id);
alter table public.opportunities add constraint opportunities_estimated_value_check CHECK ((estimated_value >= (0)::numeric));
alter table public.opportunities add constraint opportunities_pkey PRIMARY KEY (id);
alter table public.opportunities add constraint opportunities_probability_check CHECK (((probability IS NULL) OR ((probability >= (0)::numeric) AND (probability <= (1)::numeric))));
alter table public.organization_contacts add constraint organization_contacts_organization_id_contact_id_relationsh_key UNIQUE (organization_id, contact_id, relationship_type);
alter table public.organization_contacts add constraint organization_contacts_pkey PRIMARY KEY (id);
alter table public.organizations add constraint organizations_pkey PRIMARY KEY (id);
alter table public.payments add constraint payments_amount_check CHECK ((amount > (0)::numeric));
alter table public.payments add constraint payments_pkey PRIMARY KEY (id);
alter table public.photos add constraint photos_pkey PRIMARY KEY (id);
alter table public.properties add constraint properties_latitude_check CHECK (((latitude IS NULL) OR ((latitude >= ('-90'::integer)::numeric) AND (latitude <= (90)::numeric))));
alter table public.properties add constraint properties_longitude_check CHECK (((longitude IS NULL) OR ((longitude >= ('-180'::integer)::numeric) AND (longitude <= (180)::numeric))));
alter table public.properties add constraint properties_pkey PRIMARY KEY (id);
alter table public.property_contacts add constraint property_contacts_pkey PRIMARY KEY (id);
alter table public.property_contacts add constraint property_contacts_property_id_contact_id_relationship_type_key UNIQUE (property_id, contact_id, relationship_type);
alter table public.proposals add constraint proposals_estimate_id_version_key UNIQUE (estimate_id, version);
alter table public.proposals add constraint proposals_pkey PRIMARY KEY (id);
alter table public.proposals add constraint proposals_version_check CHECK ((version > 0));
alter table public.service_definitions add constraint service_definitions_default_duration_minutes_check CHECK (((default_duration_minutes IS NULL) OR (default_duration_minutes > 0)));
alter table public.service_definitions add constraint service_definitions_pkey PRIMARY KEY (id);
alter table public.service_definitions add constraint service_definitions_workspace_id_name_key UNIQUE (workspace_id, name);
alter table public.service_schedules add constraint service_schedules_day_of_month_check CHECK (((day_of_month IS NULL) OR ((day_of_month >= 1) AND (day_of_month <= 31))));
alter table public.service_schedules add constraint service_schedules_day_of_week_check CHECK (((day_of_week IS NULL) OR ((day_of_week >= 0) AND (day_of_week <= 6))));
alter table public.service_schedules add constraint service_schedules_duration_minutes_check CHECK (((duration_minutes IS NULL) OR (duration_minutes > 0)));
alter table public.service_schedules add constraint service_schedules_pkey PRIMARY KEY (id);
alter table public.subcontractor_costs add constraint subcontractor_costs_cost_check CHECK ((cost >= (0)::numeric));
alter table public.subcontractor_costs add constraint subcontractor_costs_pkey PRIMARY KEY (id);
alter table public.system_events add constraint system_events_attempt_count_check CHECK ((attempt_count >= 0));
alter table public.system_events add constraint system_events_pkey PRIMARY KEY (id);
alter table public.tasks add constraint tasks_pkey PRIMARY KEY (id);
alter table public.time_entries add constraint time_entries_check CHECK (((hours >= (0)::numeric) AND (cost_rate >= (0)::numeric) AND (total_cost >= (0)::numeric)));
alter table public.time_entries add constraint time_entries_check1 CHECK (((ended_at IS NULL) OR (ended_at >= started_at)));
alter table public.time_entries add constraint time_entries_pkey PRIMARY KEY (id);
alter table public.user_profiles add constraint user_profiles_pkey PRIMARY KEY (id);
alter table public.work_order_assignments add constraint work_order_assignments_pkey PRIMARY KEY (id);
alter table public.work_order_tasks add constraint work_order_tasks_pkey PRIMARY KEY (id);
alter table public.work_orders add constraint work_orders_actual_duration_minutes_check CHECK (((actual_duration_minutes IS NULL) OR (actual_duration_minutes >= 0)));
alter table public.work_orders add constraint work_orders_check CHECK (((scheduled_end IS NULL) OR (scheduled_start IS NULL) OR (scheduled_end >= scheduled_start)));
alter table public.work_orders add constraint work_orders_estimated_duration_minutes_check CHECK (((estimated_duration_minutes IS NULL) OR (estimated_duration_minutes > 0)));
alter table public.work_orders add constraint work_orders_pkey PRIMARY KEY (id);
alter table public.work_orders add constraint work_orders_workspace_id_work_order_number_key UNIQUE (workspace_id, work_order_number);
alter table public.work_visits add constraint work_visits_check CHECK (((ended_at IS NULL) OR (ended_at >= started_at)));
alter table public.work_visits add constraint work_visits_pkey PRIMARY KEY (id);
alter table public.workspace_memberships add constraint workspace_memberships_pkey PRIMARY KEY (id);
alter table public.workspace_memberships add constraint workspace_memberships_workspace_id_user_id_key UNIQUE (workspace_id, user_id);
alter table public.workspaces add constraint workspaces_pkey PRIMARY KEY (id);
alter table public.workspaces add constraint workspaces_slug_key UNIQUE (slug);

CREATE INDEX idx_assignments_work_order ON public.work_order_assignments USING btree (workspace_id, work_order_id, status);
CREATE INDEX idx_audit_entity ON public.audit_events USING btree (workspace_id, entity_type, entity_id, occurred_at DESC);
CREATE INDEX idx_buildings_property ON public.buildings USING btree (workspace_id, property_id);
CREATE INDEX idx_contacts_ws_name ON public.contacts USING btree (workspace_id, last_name, first_name);
CREATE INDEX idx_contract_services_contract ON public.contract_services USING btree (workspace_id, contract_id, active);
CREATE INDEX idx_contracts_property ON public.contracts USING btree (workspace_id, property_id, status);
CREATE INDEX idx_contracts_renewal ON public.contracts USING btree (workspace_id, end_date) WHERE (status = ANY (ARRAY['active'::contract_status, 'renewal_pending'::contract_status]));
CREATE INDEX idx_estimates_status ON public.estimates USING btree (workspace_id, status);
CREATE INDEX idx_inspections_property ON public.inspections USING btree (workspace_id, property_id, status);
CREATE INDEX idx_invoice_items_work_order ON public.invoice_items USING btree (workspace_id, work_order_id);
CREATE INDEX idx_invoices_ar ON public.invoices USING btree (workspace_id, status, due_date);
CREATE INDEX idx_issues_queue ON public.issues USING btree (workspace_id, status, severity, due_at);
CREATE INDEX idx_opps_stage ON public.opportunities USING btree (workspace_id, stage, status);
CREATE INDEX idx_org_ws_name ON public.organizations USING btree (workspace_id, operating_name, legal_name);
CREATE INDEX idx_properties_ws_city ON public.properties USING btree (workspace_id, city);
CREATE INDEX idx_properties_ws_postal ON public.properties USING btree (workspace_id, postal_code);
CREATE INDEX idx_properties_ws_status ON public.properties USING btree (workspace_id, status);
CREATE INDEX idx_schedules_service ON public.service_schedules USING btree (workspace_id, contract_service_id, active);
CREATE INDEX idx_system_queue ON public.system_events USING btree (status, occurred_at);
CREATE INDEX idx_tasks_due ON public.tasks USING btree (workspace_id, status, due_at);
CREATE INDEX idx_time_work_order ON public.time_entries USING btree (workspace_id, work_order_id);
CREATE INDEX idx_work_orders_property ON public.work_orders USING btree (workspace_id, property_id, status);
CREATE INDEX idx_work_orders_schedule ON public.work_orders USING btree (workspace_id, scheduled_start, status);

create policy workspace_member_insert on public.activities for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.activities for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.activities for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.audit_events for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.audit_events for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.audit_events for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.buildings for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.buildings for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.buildings for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.communications for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.communications for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.communications for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.contacts for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.contacts for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.contacts for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.contract_services for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.contract_services for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.contract_services for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.contractors for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.contractors for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.contractors for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.contracts for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.contracts for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.contracts for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.crew_members for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.crew_members for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.crew_members for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.crews for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.crews for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.crews for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.documents for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.documents for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.documents for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.employees for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.employees for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.employees for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.equipment for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.equipment for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.equipment for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.estimate_items for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.estimate_items for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.estimate_items for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.estimates for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.estimates for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.estimates for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.expenses for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.expenses for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.expenses for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.inspection_items for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.inspection_items for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.inspection_items for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.inspections for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.inspections for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.inspections for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.invoice_items for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.invoice_items for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.invoice_items for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.invoices for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.invoices for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.invoices for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.issues for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.issues for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.issues for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.leads for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.leads for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.leads for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.material_usage for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.material_usage for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.material_usage for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.notes for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.notes for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.notes for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.opportunities for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.opportunities for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.opportunities for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.organization_contacts for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.organization_contacts for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.organization_contacts for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.organizations for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.organizations for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.organizations for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.payments for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.payments for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.payments for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.photos for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.photos for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.photos for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.properties for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.properties for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.properties for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.property_contacts for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.property_contacts for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.property_contacts for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.proposals for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.proposals for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.proposals for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.service_definitions for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.service_definitions for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.service_definitions for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.service_schedules for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.service_schedules for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.service_schedules for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.subcontractor_costs for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.subcontractor_costs for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.subcontractor_costs for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.system_events for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.system_events for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.system_events for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.tasks for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.tasks for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.tasks for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.time_entries for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.time_entries for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.time_entries for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.work_order_assignments for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.work_order_assignments for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.work_order_assignments for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.work_order_tasks for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.work_order_tasks for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.work_order_tasks for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.work_orders for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.work_orders for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.work_orders for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy workspace_member_insert on public.work_visits for insert with check (is_workspace_member(workspace_id));
create policy workspace_member_select on public.work_visits for select using (is_workspace_member(workspace_id));
create policy workspace_member_update on public.work_visits for update using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy membership_select on public.workspace_memberships for select using (is_workspace_member(workspace_id));

CREATE TRIGGER trg_buildings_updated BEFORE UPDATE ON public.buildings FOR EACH ROW EXECUTE FUNCTION touch_updated_at()
CREATE TRIGGER trg_contacts_updated BEFORE UPDATE ON public.contacts FOR EACH ROW EXECUTE FUNCTION touch_updated_at()
CREATE TRIGGER trg_contract_services_updated BEFORE UPDATE ON public.contract_services FOR EACH ROW EXECUTE FUNCTION touch_updated_at()
CREATE TRIGGER trg_contracts_updated BEFORE UPDATE ON public.contracts FOR EACH ROW EXECUTE FUNCTION touch_updated_at()
CREATE TRIGGER trg_employees_updated BEFORE UPDATE ON public.employees FOR EACH ROW EXECUTE FUNCTION touch_updated_at()
CREATE TRIGGER trg_estimates_updated BEFORE UPDATE ON public.estimates FOR EACH ROW EXECUTE FUNCTION touch_updated_at()
CREATE TRIGGER trg_issues_updated BEFORE UPDATE ON public.issues FOR EACH ROW EXECUTE FUNCTION touch_updated_at()
CREATE TRIGGER trg_opportunities_updated BEFORE UPDATE ON public.opportunities FOR EACH ROW EXECUTE FUNCTION touch_updated_at()
CREATE TRIGGER trg_org_updated BEFORE UPDATE ON public.organizations FOR EACH ROW EXECUTE FUNCTION touch_updated_at()
CREATE TRIGGER trg_properties_updated BEFORE UPDATE ON public.properties FOR EACH ROW EXECUTE FUNCTION touch_updated_at()
CREATE TRIGGER trg_services_updated BEFORE UPDATE ON public.service_definitions FOR EACH ROW EXECUTE FUNCTION touch_updated_at()
CREATE TRIGGER trg_schedules_updated BEFORE UPDATE ON public.service_schedules FOR EACH ROW EXECUTE FUNCTION touch_updated_at()
CREATE TRIGGER trg_profiles_updated BEFORE UPDATE ON public.user_profiles FOR EACH ROW EXECUTE FUNCTION touch_updated_at()
CREATE TRIGGER trg_work_orders_updated BEFORE UPDATE ON public.work_orders FOR EACH ROW EXECUTE FUNCTION touch_updated_at()
CREATE TRIGGER trg_memberships_updated BEFORE UPDATE ON public.workspace_memberships FOR EACH ROW EXECUTE FUNCTION touch_updated_at()
CREATE TRIGGER trg_workspaces_updated BEFORE UPDATE ON public.workspaces FOR EACH ROW EXECUTE FUNCTION touch_updated_at()

create or replace view public.contract_renewal_queue as  SELECT id,
    workspace_id,
    contract_number,
    organization_id,
    property_id,
    opportunity_id,
    proposal_id,
    name,
    status,
    start_date,
    end_date,
    contract_value,
    billing_frequency,
    renewal_type,
    signed_document_id,
    created_at,
    updated_at,
    terminated_at
   FROM contracts
  WHERE ((status = ANY (ARRAY['active'::contract_status, 'renewal_pending'::contract_status])) AND (end_date IS NOT NULL));;
create or replace view public.open_issue_queue as  SELECT id,
    workspace_id,
    property_id,
    work_order_id,
    contract_id,
    issue_type,
    severity,
    status,
    title,
    description,
    reported_by,
    assigned_to,
    reported_at,
    due_at,
    resolved_at,
    resolution_notes,
    customer_visible,
    created_at,
    updated_at
   FROM issues
  WHERE (status = ANY (ARRAY['open'::issue_status, 'in_progress'::issue_status, 'blocked'::issue_status]))
  ORDER BY
        CASE severity
            WHEN 'critical'::issue_severity THEN 1
            WHEN 'high'::issue_severity THEN 2
            WHEN 'medium'::issue_severity THEN 3
            ELSE 4
        END, due_at;;
create or replace view public.open_work_exceptions as  SELECT id,
    workspace_id,
    work_order_number,
    property_id,
    contract_id,
    contract_service_id,
    source_type,
    priority,
    status,
    scheduled_start,
    scheduled_end,
    estimated_duration_minutes,
    actual_duration_minutes,
    description,
    site_instructions,
    created_by,
    created_at,
    updated_at,
    completed_at,
    cancelled_at
   FROM work_orders
  WHERE (status = ANY (ARRAY['draft'::work_order_status, 'scheduled'::work_order_status, 'assigned'::work_order_status, 'en_route'::work_order_status, 'in_progress'::work_order_status, 'paused'::work_order_status, 'needs_review'::work_order_status]));;
create or replace view public.property_360 as  SELECT p.id,
    p.workspace_id,
    p.name,
    p.address_line_1,
    p.city,
    p.province,
    p.postal_code,
    p.status,
    o.operating_name AS customer_name,
    count(DISTINCT c.id) FILTER (WHERE (c.status = 'active'::contract_status)) AS active_contracts,
    count(DISTINCT w.id) FILTER (WHERE (w.status <> ALL (ARRAY['completed'::work_order_status, 'approved'::work_order_status, 'cancelled'::work_order_status]))) AS open_work_orders,
    count(DISTINCT i.id) FILTER (WHERE (i.status = ANY (ARRAY['open'::issue_status, 'in_progress'::issue_status, 'blocked'::issue_status]))) AS open_issues
   FROM ((((properties p
     LEFT JOIN organizations o ON ((o.id = p.primary_customer_organization_id)))
     LEFT JOIN contracts c ON ((c.property_id = p.id)))
     LEFT JOIN work_orders w ON ((w.property_id = p.id)))
     LEFT JOIN issues i ON ((i.property_id = p.id)))
  GROUP BY p.id, o.operating_name;;


-- Foreign keys are applied after all referenced primary/unique constraints exist.
alter table public.activities add constraint activities_assigned_user_id_fkey FOREIGN KEY (assigned_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.activities add constraint activities_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE SET NULL;
alter table public.activities add constraint activities_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES contracts(id) ON DELETE SET NULL;
alter table public.activities add constraint activities_opportunity_id_fkey FOREIGN KEY (opportunity_id) REFERENCES opportunities(id) ON DELETE SET NULL;
alter table public.activities add constraint activities_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL;
alter table public.activities add constraint activities_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE SET NULL;
alter table public.activities add constraint activities_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.audit_events add constraint audit_events_actor_user_id_fkey FOREIGN KEY (actor_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.audit_events add constraint audit_events_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE SET NULL;
alter table public.buildings add constraint buildings_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE CASCADE;
alter table public.buildings add constraint buildings_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.communications add constraint communications_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE SET NULL;
alter table public.communications add constraint communications_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES contracts(id) ON DELETE SET NULL;
alter table public.communications add constraint communications_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.communications add constraint communications_issue_id_fkey FOREIGN KEY (issue_id) REFERENCES issues(id) ON DELETE SET NULL;
alter table public.communications add constraint communications_opportunity_id_fkey FOREIGN KEY (opportunity_id) REFERENCES opportunities(id) ON DELETE SET NULL;
alter table public.communications add constraint communications_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL;
alter table public.communications add constraint communications_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE SET NULL;
alter table public.communications add constraint communications_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.contacts add constraint contacts_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.contract_services add constraint contract_services_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES contracts(id) ON DELETE CASCADE;
alter table public.contract_services add constraint contract_services_service_definition_id_fkey FOREIGN KEY (service_definition_id) REFERENCES service_definitions(id) ON DELETE RESTRICT;
alter table public.contract_services add constraint contract_services_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.contractors add constraint contractors_insurance_document_id_fkey FOREIGN KEY (insurance_document_id) REFERENCES documents(id) ON DELETE SET NULL;
alter table public.contractors add constraint contractors_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE RESTRICT;
alter table public.contractors add constraint contractors_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.contracts add constraint contracts_opportunity_id_fkey FOREIGN KEY (opportunity_id) REFERENCES opportunities(id) ON DELETE SET NULL;
alter table public.contracts add constraint contracts_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE RESTRICT;
alter table public.contracts add constraint contracts_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE RESTRICT;
alter table public.contracts add constraint contracts_proposal_id_fkey FOREIGN KEY (proposal_id) REFERENCES proposals(id) ON DELETE SET NULL;
alter table public.contracts add constraint contracts_signed_document_id_fkey FOREIGN KEY (signed_document_id) REFERENCES documents(id) ON DELETE SET NULL;
alter table public.contracts add constraint contracts_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.crew_members add constraint crew_members_crew_id_fkey FOREIGN KEY (crew_id) REFERENCES crews(id) ON DELETE CASCADE;
alter table public.crew_members add constraint crew_members_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE;
alter table public.crew_members add constraint crew_members_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.crews add constraint crews_supervisor_employee_id_fkey FOREIGN KEY (supervisor_employee_id) REFERENCES employees(id) ON DELETE SET NULL;
alter table public.crews add constraint crews_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.documents add constraint documents_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.documents add constraint documents_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.employees add constraint employees_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.employees add constraint employees_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.equipment add constraint equipment_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.estimate_items add constraint estimate_items_estimate_id_fkey FOREIGN KEY (estimate_id) REFERENCES estimates(id) ON DELETE CASCADE;
alter table public.estimate_items add constraint estimate_items_service_definition_id_fkey FOREIGN KEY (service_definition_id) REFERENCES service_definitions(id) ON DELETE SET NULL;
alter table public.estimate_items add constraint estimate_items_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.estimates add constraint estimates_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.estimates add constraint estimates_opportunity_id_fkey FOREIGN KEY (opportunity_id) REFERENCES opportunities(id) ON DELETE SET NULL;
alter table public.estimates add constraint estimates_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE RESTRICT;
alter table public.estimates add constraint estimates_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE SET NULL;
alter table public.estimates add constraint estimates_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.expenses add constraint expenses_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE SET NULL;
alter table public.expenses add constraint expenses_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE SET NULL;
alter table public.expenses add constraint expenses_receipt_document_id_fkey FOREIGN KEY (receipt_document_id) REFERENCES documents(id) ON DELETE SET NULL;
alter table public.expenses add constraint expenses_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES work_orders(id) ON DELETE SET NULL;
alter table public.expenses add constraint expenses_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.inspection_items add constraint inspection_items_inspection_id_fkey FOREIGN KEY (inspection_id) REFERENCES inspections(id) ON DELETE CASCADE;
alter table public.inspection_items add constraint inspection_items_issue_id_fkey FOREIGN KEY (issue_id) REFERENCES issues(id) ON DELETE SET NULL;
alter table public.inspection_items add constraint inspection_items_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.inspections add constraint inspections_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES contracts(id) ON DELETE SET NULL;
alter table public.inspections add constraint inspections_inspector_id_fkey FOREIGN KEY (inspector_id) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.inspections add constraint inspections_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE RESTRICT;
alter table public.inspections add constraint inspections_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES work_orders(id) ON DELETE SET NULL;
alter table public.inspections add constraint inspections_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.invoice_items add constraint invoice_items_contract_service_id_fkey FOREIGN KEY (contract_service_id) REFERENCES contract_services(id) ON DELETE SET NULL;
alter table public.invoice_items add constraint invoice_items_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE;
alter table public.invoice_items add constraint invoice_items_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES work_orders(id) ON DELETE SET NULL;
alter table public.invoice_items add constraint invoice_items_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.invoices add constraint invoices_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES contracts(id) ON DELETE SET NULL;
alter table public.invoices add constraint invoices_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE RESTRICT;
alter table public.invoices add constraint invoices_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE SET NULL;
alter table public.invoices add constraint invoices_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.issues add constraint issues_assigned_to_fkey FOREIGN KEY (assigned_to) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.issues add constraint issues_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES contracts(id) ON DELETE SET NULL;
alter table public.issues add constraint issues_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE RESTRICT;
alter table public.issues add constraint issues_reported_by_fkey FOREIGN KEY (reported_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.issues add constraint issues_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES work_orders(id) ON DELETE SET NULL;
alter table public.issues add constraint issues_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.leads add constraint leads_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE SET NULL;
alter table public.leads add constraint leads_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL;
alter table public.leads add constraint leads_owner_user_id_fkey FOREIGN KEY (owner_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.leads add constraint leads_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE SET NULL;
alter table public.leads add constraint leads_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.material_usage add constraint material_usage_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE SET NULL;
alter table public.material_usage add constraint material_usage_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES work_orders(id) ON DELETE SET NULL;
alter table public.material_usage add constraint material_usage_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.notes add constraint notes_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.notes add constraint notes_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.opportunities add constraint opportunities_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE RESTRICT;
alter table public.opportunities add constraint opportunities_owner_user_id_fkey FOREIGN KEY (owner_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.opportunities add constraint opportunities_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE SET NULL;
alter table public.opportunities add constraint opportunities_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.organization_contacts add constraint organization_contacts_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE CASCADE;
alter table public.organization_contacts add constraint organization_contacts_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;
alter table public.organization_contacts add constraint organization_contacts_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.organizations add constraint organizations_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.payments add constraint payments_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE RESTRICT;
alter table public.payments add constraint payments_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.photos add constraint photos_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.photos add constraint photos_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.properties add constraint properties_management_organization_id_fkey FOREIGN KEY (management_organization_id) REFERENCES organizations(id) ON DELETE SET NULL;
alter table public.properties add constraint properties_owner_organization_id_fkey FOREIGN KEY (owner_organization_id) REFERENCES organizations(id) ON DELETE SET NULL;
alter table public.properties add constraint properties_primary_customer_organization_id_fkey FOREIGN KEY (primary_customer_organization_id) REFERENCES organizations(id) ON DELETE SET NULL;
alter table public.properties add constraint properties_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.property_contacts add constraint property_contacts_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE CASCADE;
alter table public.property_contacts add constraint property_contacts_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE CASCADE;
alter table public.property_contacts add constraint property_contacts_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.proposals add constraint proposals_document_id_fkey FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE SET NULL;
alter table public.proposals add constraint proposals_estimate_id_fkey FOREIGN KEY (estimate_id) REFERENCES estimates(id) ON DELETE RESTRICT;
alter table public.proposals add constraint proposals_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.service_definitions add constraint service_definitions_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.service_schedules add constraint service_schedules_contract_service_id_fkey FOREIGN KEY (contract_service_id) REFERENCES contract_services(id) ON DELETE CASCADE;
alter table public.service_schedules add constraint service_schedules_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.subcontractor_costs add constraint subcontractor_costs_contractor_id_fkey FOREIGN KEY (contractor_id) REFERENCES contractors(id) ON DELETE RESTRICT;
alter table public.subcontractor_costs add constraint subcontractor_costs_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES work_orders(id) ON DELETE SET NULL;
alter table public.subcontractor_costs add constraint subcontractor_costs_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.system_events add constraint system_events_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE SET NULL;
alter table public.tasks add constraint tasks_assigned_to_fkey FOREIGN KEY (assigned_to) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.tasks add constraint tasks_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES contracts(id) ON DELETE SET NULL;
alter table public.tasks add constraint tasks_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.tasks add constraint tasks_issue_id_fkey FOREIGN KEY (issue_id) REFERENCES issues(id) ON DELETE SET NULL;
alter table public.tasks add constraint tasks_opportunity_id_fkey FOREIGN KEY (opportunity_id) REFERENCES opportunities(id) ON DELETE SET NULL;
alter table public.tasks add constraint tasks_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL;
alter table public.tasks add constraint tasks_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE SET NULL;
alter table public.tasks add constraint tasks_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES work_orders(id) ON DELETE SET NULL;
alter table public.tasks add constraint tasks_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.time_entries add constraint time_entries_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE RESTRICT;
alter table public.time_entries add constraint time_entries_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES work_orders(id) ON DELETE SET NULL;
alter table public.time_entries add constraint time_entries_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.user_profiles add constraint user_profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.work_order_assignments add constraint work_order_assignments_contractor_id_fkey FOREIGN KEY (contractor_id) REFERENCES contractors(id) ON DELETE SET NULL;
alter table public.work_order_assignments add constraint work_order_assignments_crew_id_fkey FOREIGN KEY (crew_id) REFERENCES crews(id) ON DELETE SET NULL;
alter table public.work_order_assignments add constraint work_order_assignments_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE SET NULL;
alter table public.work_order_assignments add constraint work_order_assignments_equipment_id_fkey FOREIGN KEY (equipment_id) REFERENCES equipment(id) ON DELETE SET NULL;
alter table public.work_order_assignments add constraint work_order_assignments_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES work_orders(id) ON DELETE CASCADE;
alter table public.work_order_assignments add constraint work_order_assignments_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.work_order_tasks add constraint work_order_tasks_completed_by_fkey FOREIGN KEY (completed_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.work_order_tasks add constraint work_order_tasks_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES work_orders(id) ON DELETE CASCADE;
alter table public.work_order_tasks add constraint work_order_tasks_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.work_orders add constraint work_orders_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES contracts(id) ON DELETE SET NULL;
alter table public.work_orders add constraint work_orders_contract_service_id_fkey FOREIGN KEY (contract_service_id) REFERENCES contract_services(id) ON DELETE SET NULL;
alter table public.work_orders add constraint work_orders_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.work_orders add constraint work_orders_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE RESTRICT;
alter table public.work_orders add constraint work_orders_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.work_visits add constraint work_visits_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.work_visits add constraint work_visits_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES work_orders(id) ON DELETE CASCADE;
alter table public.work_visits add constraint work_visits_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.workspace_memberships add constraint workspace_memberships_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.workspace_memberships add constraint workspace_memberships_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE;
alter table public.activities add constraint activities_assigned_user_id_fkey FOREIGN KEY (assigned_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.activities add constraint activities_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE SET NULL;
alter table public.activities add constraint activities_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES contracts(id) ON DELETE SET NULL;
alter table public.activities add constraint activities_opportunity_id_fkey FOREIGN KEY (opportunity_id) REFERENCES opportunities(id) ON DELETE SET NULL;
alter table public.activities add constraint activities_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL;
alter table public.activities add constraint activities_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE SET NULL;
alter table public.activities add constraint activities_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.audit_events add constraint audit_events_actor_user_id_fkey FOREIGN KEY (actor_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.audit_events add constraint audit_events_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE SET NULL;
alter table public.buildings add constraint buildings_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE CASCADE;
alter table public.buildings add constraint buildings_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.communications add constraint communications_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE SET NULL;
alter table public.communications add constraint communications_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES contracts(id) ON DELETE SET NULL;
alter table public.communications add constraint communications_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.communications add constraint communications_issue_id_fkey FOREIGN KEY (issue_id) REFERENCES issues(id) ON DELETE SET NULL;
alter table public.communications add constraint communications_opportunity_id_fkey FOREIGN KEY (opportunity_id) REFERENCES opportunities(id) ON DELETE SET NULL;
alter table public.communications add constraint communications_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL;
alter table public.communications add constraint communications_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE SET NULL;
alter table public.communications add constraint communications_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.contacts add constraint contacts_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.contract_services add constraint contract_services_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES contracts(id) ON DELETE CASCADE;
alter table public.contract_services add constraint contract_services_service_definition_id_fkey FOREIGN KEY (service_definition_id) REFERENCES service_definitions(id) ON DELETE RESTRICT;
alter table public.contract_services add constraint contract_services_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.contractors add constraint contractors_insurance_document_id_fkey FOREIGN KEY (insurance_document_id) REFERENCES documents(id) ON DELETE SET NULL;
alter table public.contractors add constraint contractors_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE RESTRICT;
alter table public.contractors add constraint contractors_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.contracts add constraint contracts_opportunity_id_fkey FOREIGN KEY (opportunity_id) REFERENCES opportunities(id) ON DELETE SET NULL;
alter table public.contracts add constraint contracts_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE RESTRICT;
alter table public.contracts add constraint contracts_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE RESTRICT;
alter table public.contracts add constraint contracts_proposal_id_fkey FOREIGN KEY (proposal_id) REFERENCES proposals(id) ON DELETE SET NULL;
alter table public.contracts add constraint contracts_signed_document_id_fkey FOREIGN KEY (signed_document_id) REFERENCES documents(id) ON DELETE SET NULL;
alter table public.contracts add constraint contracts_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.crew_members add constraint crew_members_crew_id_fkey FOREIGN KEY (crew_id) REFERENCES crews(id) ON DELETE CASCADE;
alter table public.crew_members add constraint crew_members_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE;
alter table public.crew_members add constraint crew_members_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.crews add constraint crews_supervisor_employee_id_fkey FOREIGN KEY (supervisor_employee_id) REFERENCES employees(id) ON DELETE SET NULL;
alter table public.crews add constraint crews_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.documents add constraint documents_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.documents add constraint documents_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.employees add constraint employees_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.employees add constraint employees_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.equipment add constraint equipment_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.estimate_items add constraint estimate_items_estimate_id_fkey FOREIGN KEY (estimate_id) REFERENCES estimates(id) ON DELETE CASCADE;
alter table public.estimate_items add constraint estimate_items_service_definition_id_fkey FOREIGN KEY (service_definition_id) REFERENCES service_definitions(id) ON DELETE SET NULL;
alter table public.estimate_items add constraint estimate_items_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.estimates add constraint estimates_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.estimates add constraint estimates_opportunity_id_fkey FOREIGN KEY (opportunity_id) REFERENCES opportunities(id) ON DELETE SET NULL;
alter table public.estimates add constraint estimates_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE RESTRICT;
alter table public.estimates add constraint estimates_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE SET NULL;
alter table public.estimates add constraint estimates_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.expenses add constraint expenses_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE SET NULL;
alter table public.expenses add constraint expenses_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE SET NULL;
alter table public.expenses add constraint expenses_receipt_document_id_fkey FOREIGN KEY (receipt_document_id) REFERENCES documents(id) ON DELETE SET NULL;
alter table public.expenses add constraint expenses_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES work_orders(id) ON DELETE SET NULL;
alter table public.expenses add constraint expenses_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.inspection_items add constraint inspection_items_inspection_id_fkey FOREIGN KEY (inspection_id) REFERENCES inspections(id) ON DELETE CASCADE;
alter table public.inspection_items add constraint inspection_items_issue_id_fkey FOREIGN KEY (issue_id) REFERENCES issues(id) ON DELETE SET NULL;
alter table public.inspection_items add constraint inspection_items_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.inspections add constraint inspections_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES contracts(id) ON DELETE SET NULL;
alter table public.inspections add constraint inspections_inspector_id_fkey FOREIGN KEY (inspector_id) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.inspections add constraint inspections_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE RESTRICT;
alter table public.inspections add constraint inspections_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES work_orders(id) ON DELETE SET NULL;
alter table public.inspections add constraint inspections_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.invoice_items add constraint invoice_items_contract_service_id_fkey FOREIGN KEY (contract_service_id) REFERENCES contract_services(id) ON DELETE SET NULL;
alter table public.invoice_items add constraint invoice_items_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE;
alter table public.invoice_items add constraint invoice_items_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES work_orders(id) ON DELETE SET NULL;
alter table public.invoice_items add constraint invoice_items_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.invoices add constraint invoices_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES contracts(id) ON DELETE SET NULL;
alter table public.invoices add constraint invoices_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE RESTRICT;
alter table public.invoices add constraint invoices_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE SET NULL;
alter table public.invoices add constraint invoices_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.issues add constraint issues_assigned_to_fkey FOREIGN KEY (assigned_to) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.issues add constraint issues_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES contracts(id) ON DELETE SET NULL;
alter table public.issues add constraint issues_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE RESTRICT;
alter table public.issues add constraint issues_reported_by_fkey FOREIGN KEY (reported_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.issues add constraint issues_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES work_orders(id) ON DELETE SET NULL;
alter table public.issues add constraint issues_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.leads add constraint leads_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE SET NULL;
alter table public.leads add constraint leads_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL;
alter table public.leads add constraint leads_owner_user_id_fkey FOREIGN KEY (owner_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.leads add constraint leads_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE SET NULL;
alter table public.leads add constraint leads_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.material_usage add constraint material_usage_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE SET NULL;
alter table public.material_usage add constraint material_usage_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES work_orders(id) ON DELETE SET NULL;
alter table public.material_usage add constraint material_usage_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.notes add constraint notes_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.notes add constraint notes_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.opportunities add constraint opportunities_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE RESTRICT;
alter table public.opportunities add constraint opportunities_owner_user_id_fkey FOREIGN KEY (owner_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.opportunities add constraint opportunities_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE SET NULL;
alter table public.opportunities add constraint opportunities_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.organization_contacts add constraint organization_contacts_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE CASCADE;
alter table public.organization_contacts add constraint organization_contacts_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;
alter table public.organization_contacts add constraint organization_contacts_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.organizations add constraint organizations_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.payments add constraint payments_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE RESTRICT;
alter table public.payments add constraint payments_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.photos add constraint photos_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.photos add constraint photos_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.properties add constraint properties_management_organization_id_fkey FOREIGN KEY (management_organization_id) REFERENCES organizations(id) ON DELETE SET NULL;
alter table public.properties add constraint properties_owner_organization_id_fkey FOREIGN KEY (owner_organization_id) REFERENCES organizations(id) ON DELETE SET NULL;
alter table public.properties add constraint properties_primary_customer_organization_id_fkey FOREIGN KEY (primary_customer_organization_id) REFERENCES organizations(id) ON DELETE SET NULL;
alter table public.properties add constraint properties_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.property_contacts add constraint property_contacts_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE CASCADE;
alter table public.property_contacts add constraint property_contacts_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE CASCADE;
alter table public.property_contacts add constraint property_contacts_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.proposals add constraint proposals_document_id_fkey FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE SET NULL;
alter table public.proposals add constraint proposals_estimate_id_fkey FOREIGN KEY (estimate_id) REFERENCES estimates(id) ON DELETE RESTRICT;
alter table public.proposals add constraint proposals_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.service_definitions add constraint service_definitions_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.service_schedules add constraint service_schedules_contract_service_id_fkey FOREIGN KEY (contract_service_id) REFERENCES contract_services(id) ON DELETE CASCADE;
alter table public.service_schedules add constraint service_schedules_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.subcontractor_costs add constraint subcontractor_costs_contractor_id_fkey FOREIGN KEY (contractor_id) REFERENCES contractors(id) ON DELETE RESTRICT;
alter table public.subcontractor_costs add constraint subcontractor_costs_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES work_orders(id) ON DELETE SET NULL;
alter table public.subcontractor_costs add constraint subcontractor_costs_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.system_events add constraint system_events_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE SET NULL;
alter table public.tasks add constraint tasks_assigned_to_fkey FOREIGN KEY (assigned_to) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.tasks add constraint tasks_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES contracts(id) ON DELETE SET NULL;
alter table public.tasks add constraint tasks_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.tasks add constraint tasks_issue_id_fkey FOREIGN KEY (issue_id) REFERENCES issues(id) ON DELETE SET NULL;
alter table public.tasks add constraint tasks_opportunity_id_fkey FOREIGN KEY (opportunity_id) REFERENCES opportunities(id) ON DELETE SET NULL;
alter table public.tasks add constraint tasks_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL;
alter table public.tasks add constraint tasks_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE SET NULL;
alter table public.tasks add constraint tasks_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES work_orders(id) ON DELETE SET NULL;
alter table public.tasks add constraint tasks_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.time_entries add constraint time_entries_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE RESTRICT;
alter table public.time_entries add constraint time_entries_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES work_orders(id) ON DELETE SET NULL;
alter table public.time_entries add constraint time_entries_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.user_profiles add constraint user_profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.work_order_assignments add constraint work_order_assignments_contractor_id_fkey FOREIGN KEY (contractor_id) REFERENCES contractors(id) ON DELETE SET NULL;
alter table public.work_order_assignments add constraint work_order_assignments_crew_id_fkey FOREIGN KEY (crew_id) REFERENCES crews(id) ON DELETE SET NULL;
alter table public.work_order_assignments add constraint work_order_assignments_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE SET NULL;
alter table public.work_order_assignments add constraint work_order_assignments_equipment_id_fkey FOREIGN KEY (equipment_id) REFERENCES equipment(id) ON DELETE SET NULL;
alter table public.work_order_assignments add constraint work_order_assignments_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES work_orders(id) ON DELETE CASCADE;
alter table public.work_order_assignments add constraint work_order_assignments_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.work_order_tasks add constraint work_order_tasks_completed_by_fkey FOREIGN KEY (completed_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.work_order_tasks add constraint work_order_tasks_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES work_orders(id) ON DELETE CASCADE;
alter table public.work_order_tasks add constraint work_order_tasks_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.work_orders add constraint work_orders_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES contracts(id) ON DELETE SET NULL;
alter table public.work_orders add constraint work_orders_contract_service_id_fkey FOREIGN KEY (contract_service_id) REFERENCES contract_services(id) ON DELETE SET NULL;
alter table public.work_orders add constraint work_orders_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.work_orders add constraint work_orders_property_id_fkey FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE RESTRICT;
alter table public.work_orders add constraint work_orders_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.work_visits add constraint work_visits_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table public.work_visits add constraint work_visits_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES work_orders(id) ON DELETE CASCADE;
alter table public.work_visits add constraint work_visits_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT;
alter table public.workspace_memberships add constraint workspace_memberships_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.workspace_memberships add constraint workspace_memberships_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE;
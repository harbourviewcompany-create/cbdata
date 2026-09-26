-- Backfills a migration that was missing from version control: production
-- had RLS enabled and forced on all 52 public tables, but the tracked
-- migrations only explicitly did so for workspaces, user_profiles, and the
-- 7 business-development-engine tables. The other 43 tables (including
-- properties, contracts, work_orders, organizations, workspace_memberships)
-- had RLS turned on directly against production with no corresponding
-- migration file, so `supabase db push` from a clean checkout of this repo
-- would not have reproduced the current security posture. These statements
-- are idempotent against the already-enabled production state; their
-- purpose is to make the migration history match reality.
alter table public.activities enable row level security;
alter table public.activities force row level security;
alter table public.audit_events enable row level security;
alter table public.audit_events force row level security;
alter table public.buildings enable row level security;
alter table public.buildings force row level security;
alter table public.communications enable row level security;
alter table public.communications force row level security;
alter table public.contacts enable row level security;
alter table public.contacts force row level security;
alter table public.contract_services enable row level security;
alter table public.contract_services force row level security;
alter table public.contractors enable row level security;
alter table public.contractors force row level security;
alter table public.contracts enable row level security;
alter table public.contracts force row level security;
alter table public.crew_members enable row level security;
alter table public.crew_members force row level security;
alter table public.crews enable row level security;
alter table public.crews force row level security;
alter table public.documents enable row level security;
alter table public.documents force row level security;
alter table public.employees enable row level security;
alter table public.employees force row level security;
alter table public.equipment enable row level security;
alter table public.equipment force row level security;
alter table public.estimate_items enable row level security;
alter table public.estimate_items force row level security;
alter table public.estimates enable row level security;
alter table public.estimates force row level security;
alter table public.expenses enable row level security;
alter table public.expenses force row level security;
alter table public.inspection_items enable row level security;
alter table public.inspection_items force row level security;
alter table public.inspections enable row level security;
alter table public.inspections force row level security;
alter table public.invoice_items enable row level security;
alter table public.invoice_items force row level security;
alter table public.invoices enable row level security;
alter table public.invoices force row level security;
alter table public.issues enable row level security;
alter table public.issues force row level security;
alter table public.material_usage enable row level security;
alter table public.material_usage force row level security;
alter table public.notes enable row level security;
alter table public.notes force row level security;
alter table public.opportunities enable row level security;
alter table public.opportunities force row level security;
alter table public.organization_contacts enable row level security;
alter table public.organization_contacts force row level security;
alter table public.organizations enable row level security;
alter table public.organizations force row level security;
alter table public.payments enable row level security;
alter table public.payments force row level security;
alter table public.permit_records enable row level security;
alter table public.permit_records force row level security;
alter table public.photos enable row level security;
alter table public.photos force row level security;
alter table public.properties enable row level security;
alter table public.properties force row level security;
alter table public.property_contacts enable row level security;
alter table public.property_contacts force row level security;
alter table public.proposals enable row level security;
alter table public.proposals force row level security;
alter table public.service_definitions enable row level security;
alter table public.service_definitions force row level security;
alter table public.service_schedules enable row level security;
alter table public.service_schedules force row level security;
alter table public.subcontractor_costs enable row level security;
alter table public.subcontractor_costs force row level security;
alter table public.system_events enable row level security;
alter table public.system_events force row level security;
alter table public.tasks enable row level security;
alter table public.tasks force row level security;
alter table public.time_entries enable row level security;
alter table public.time_entries force row level security;
alter table public.work_order_assignments enable row level security;
alter table public.work_order_assignments force row level security;
alter table public.work_order_tasks enable row level security;
alter table public.work_order_tasks force row level security;
alter table public.work_orders enable row level security;
alter table public.work_orders force row level security;
alter table public.work_visits enable row level security;
alter table public.work_visits force row level security;
alter table public.workspace_memberships enable row level security;
alter table public.workspace_memberships force row level security;

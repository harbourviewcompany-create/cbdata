# CBData

CBData is the operational system of record for CB Contracting.

## Current foundation

The canonical PostgreSQL model is multi-tenant at the workspace level and covers:

- organizations, contacts and properties
- sales, estimates and proposals
- contracts, services and schedules
- work orders, field visits and assignments
- employees, crews, contractors and equipment
- issues and inspections
- operational costs and finance
- documents, photos and communications
- tasks, audit events and system events
- operational views for Property 360, work exceptions, issue queue and renewals

Production migration:

`20260925160000_canonical_schema_security`

Database security:

- workspace-scoped rows carry `workspace_id`
- RLS is enabled and forced on workspace-scoped tables
- membership is checked through security-definer functions
- audit/system event records are retained as operational control surfaces
- no production customer/property/financial fixture data is seeded

## Repository layout

`supabase/migrations/` — canonical migrations  
`supabase/tests/` — database-level verification  
`docs/` — operating-model and schema documentation

## Command center

Dashboard metrics read `workspace_ops_snapshots` (trigger-maintained).
Next actions come from `public.next_actions(workspace_id, limit)` with per-arm
limits and deep links to record pages.

Active workspace is stored on `user_profiles.active_workspace_id`.
Invoices are unique per work order. Completing a work order requires an assignment.

## Rule

Schema changes must be made through a new migration and verified with database-level tests before frontend work depends on them.
CI runs `npm run typecheck`, `npm run build`, and `supabase test db`.

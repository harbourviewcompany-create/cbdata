-- Regression: requireWorkspaceRole (src/lib/authz.ts) reads workspace_memberships
-- through RLS. membership_select lets EVERY active member read EVERY membership
-- row in their workspace, so the app query must be scoped to the caller with
-- user_id = auth.uid(). This test pins that contract:
--   1. RLS still exposes all rows in the caller's workspace (why scoping is required)
--   2. the scoped query returns exactly one row per member, with the right role
--   3. non-members and inactive members get zero rows
--   4. (workspace_id, user_id) stays unique, so "exactly one row" is achievable
-- Fixtures live in one transaction and are rolled back.

begin;

insert into auth.users (id, email) values
  ('a0000000-0000-4000-8000-000000000001', 'ms-owner@test.invalid'),
  ('a0000000-0000-4000-8000-000000000002', 'ms-field@test.invalid'),
  ('a0000000-0000-4000-8000-000000000003', 'ms-finance@test.invalid'),
  ('a0000000-0000-4000-8000-000000000004', 'ms-inactive@test.invalid'),
  ('a0000000-0000-4000-8000-000000000005', 'ms-outsider@test.invalid'),
  ('a0000000-0000-4000-8000-000000000006', 'ms-other-ws@test.invalid');

insert into public.workspaces (id, name, slug) values
  ('b0000000-0000-4000-8000-000000000001', 'Membership scoping WS 1', 'ms-scoping-ws-1'),
  ('b0000000-0000-4000-8000-000000000002', 'Membership scoping WS 2', 'ms-scoping-ws-2');

insert into public.workspace_memberships (workspace_id, user_id, role, status) values
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001', 'owner', 'active'),
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000002', 'field_worker', 'active'),
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000003', 'finance', 'active'),
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000004', 'sales_rep', 'inactive'),
  ('b0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000006', 'owner', 'active');

-- Uniqueness must hold or "exactly one row" cannot be guaranteed.
do $$
begin
  begin
    insert into public.workspace_memberships (workspace_id, user_id, role, status)
    values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000002', 'owner', 'active');
    raise exception 'duplicate (workspace_id, user_id) membership was accepted';
  exception when unique_violation then
    null;
  end;
end $$;

do $$
declare
  ws1 constant uuid := 'b0000000-0000-4000-8000-000000000001';
  visible integer;
  got text[];
  uid uuid;
begin
  -- Scoped selects below mirror the query in requireWorkspaceRole.
  -- Each active member: unscoped read sees all 4 rows in WS1 (RLS leak the app must scope around),
  -- scoped read sees exactly their own single row.
  uid := 'a0000000-0000-4000-8000-000000000002';
  perform set_config('request.jwt.claim.sub', uid::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  select count(*) into visible from public.workspace_memberships where workspace_id = ws1;
  if visible <> 4 then
    raise exception 'expected members to see all 4 WS1 membership rows via RLS, saw %', visible;
  end if;
  select coalesce(array_agg(role::text order by role::text), '{}') into got
  from public.workspace_memberships
  where workspace_id = ws1 and user_id = auth.uid() and status = 'active';
  if got <> array['field_worker'] then
    raise exception 'field worker scoped roles wrong: %', got;
  end if;
  reset role;

  uid := 'a0000000-0000-4000-8000-000000000001';
  perform set_config('request.jwt.claim.sub', uid::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  select coalesce(array_agg(role::text order by role::text), '{}') into got
  from public.workspace_memberships
  where workspace_id = ws1 and user_id = auth.uid() and status = 'active';
  if got <> array['owner'] then raise exception 'owner scoped roles wrong: %', got; end if;
  reset role;

  uid := 'a0000000-0000-4000-8000-000000000003';
  perform set_config('request.jwt.claim.sub', uid::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  select coalesce(array_agg(role::text order by role::text), '{}') into got
  from public.workspace_memberships
  where workspace_id = ws1 and user_id = auth.uid() and status = 'active';
  if got <> array['finance'] then raise exception 'finance scoped roles wrong: %', got; end if;
  reset role;

  -- Inactive member: RLS may show rows, but the scoped active query must be empty.
  uid := 'a0000000-0000-4000-8000-000000000004';
  perform set_config('request.jwt.claim.sub', uid::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  select coalesce(array_agg(role::text order by role::text), '{}') into got
  from public.workspace_memberships
  where workspace_id = ws1 and user_id = auth.uid() and status = 'active';
  if cardinality(got) <> 0 then raise exception 'inactive member got roles: %', got; end if;
  reset role;

  -- Outsider: no membership anywhere; sees nothing in WS1 at all.
  uid := 'a0000000-0000-4000-8000-000000000005';
  perform set_config('request.jwt.claim.sub', uid::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  select count(*) into visible from public.workspace_memberships where workspace_id = ws1;
  if visible <> 0 then raise exception 'outsider can read % WS1 membership rows', visible; end if;
  select coalesce(array_agg(role::text order by role::text), '{}') into got
  from public.workspace_memberships
  where workspace_id = ws1 and user_id = auth.uid() and status = 'active';
  if cardinality(got) <> 0 then raise exception 'outsider got roles: %', got; end if;
  reset role;

  -- Member of a different workspace: no cross-workspace visibility or role.
  uid := 'a0000000-0000-4000-8000-000000000006';
  perform set_config('request.jwt.claim.sub', uid::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  select count(*) into visible from public.workspace_memberships where workspace_id = ws1;
  if visible <> 0 then raise exception 'WS2 owner can read % WS1 membership rows', visible; end if;
  select coalesce(array_agg(role::text order by role::text), '{}') into got
  from public.workspace_memberships
  where workspace_id = ws1 and user_id = auth.uid() and status = 'active';
  if cardinality(got) <> 0 then raise exception 'WS2 owner got WS1 roles: %', got; end if;
  reset role;
end $$;

do $$ begin raise notice 'Workspace membership scoping checks passed'; end $$;

rollback;

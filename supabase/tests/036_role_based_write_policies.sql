-- Regression: write policies on procurement (tender_*, supplier_*, source registration map)
-- and outreach_* tables must be role-based, not member-only (see migration
-- 20260930120000_role_based_write_policies_procurement_outreach). App-level gates in
-- src/lib/authz.ts are bypassable through the Supabase API unless RLS enforces the same roles.
-- Fixtures are created in one transaction and rolled back.

begin;

-- 1) Structural guard: no member-only write policy may exist on these tables.
--    A new tender_/supplier_/outreach_ table needs private.has_workspace_role write policies.
do $$
declare bad text;
begin
  select string_agg(tablename || '.' || policyname || ' (' || cmd || ')', ', ') into bad
  from pg_policies
  where schemaname = 'public'
    and cmd <> 'SELECT'
    and (tablename like 'tender\_%' or tablename like 'supplier\_%'
         or tablename = 'procurement_source_registration_map' or tablename like 'outreach\_%')
    and (coalesce(qual,'') || coalesce(with_check,'')) not like '%has_workspace_role%';
  if bad is not null then
    raise exception 'member-only write policies found (use private.has_workspace_role): %', bad;
  end if;

  -- ALL policies would also cover SELECT and re-open the problem; forbid on these tables.
  if exists (
    select 1 from pg_policies
    where schemaname = 'public' and cmd = 'ALL'
      and (tablename like 'tender\_%' or tablename like 'supplier\_%' or tablename like 'outreach\_%')
  ) then
    raise exception 'ALL-command policy found on procurement/outreach table; split into select + role-based writes';
  end if;
end $$;

-- 2) Behavioural check per role.
insert into auth.users (id, email) values
  ('c0000000-0000-4000-8000-000000000001', 'rw-owner@test.invalid'),
  ('c0000000-0000-4000-8000-000000000002', 'rw-salesrep@test.invalid'),
  ('c0000000-0000-4000-8000-000000000003', 'rw-salesmgr@test.invalid'),
  ('c0000000-0000-4000-8000-000000000004', 'rw-fieldworker@test.invalid'),
  ('c0000000-0000-4000-8000-000000000005', 'rw-finance@test.invalid'),
  ('c0000000-0000-4000-8000-000000000006', 'rw-readonly@test.invalid'),
  ('c0000000-0000-4000-8000-000000000007', 'rw-opsmgr@test.invalid');

insert into public.workspaces (id, name, slug) values
  ('d0000000-0000-4000-8000-000000000001', 'Role write policies WS', 'rw-policies-ws');

insert into public.workspace_memberships (workspace_id, user_id, role, status) values
  ('d0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', 'owner', 'active'),
  ('d0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000002', 'sales_rep', 'active'),
  ('d0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000003', 'sales_manager', 'active'),
  ('d0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000004', 'field_worker', 'active'),
  ('d0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000005', 'finance', 'active'),
  ('d0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000006', 'read_only', 'active'),
  ('d0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000007', 'operations_manager', 'active');

-- Seed rows as the table owner (bypasses RLS).
insert into public.tender_records (id, workspace_id, source, external_id, title) values
  ('e0000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000001', 'test', 'RW-1', 'Role write policy tender');
insert into public.tender_risks (id, workspace_id, tender_record_id, title) values
  ('e0000000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000001', 'seed risk'),
  ('e0000000-0000-4000-8000-000000000003', 'd0000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000001', 'seed risk 2');
insert into public.outreach_lists (id, workspace_id, name) values
  ('e0000000-0000-4000-8000-000000000004', 'd0000000-0000-4000-8000-000000000001', 'seed list');

do $$
declare
  ws constant uuid := 'd0000000-0000-4000-8000-000000000001';
  t  constant uuid := 'e0000000-0000-4000-8000-000000000001';
  r_ok uuid; r_del uuid;
  u uuid; who text; role_ok boolean; del_ok boolean; out_ok boolean;
  n integer; inserted boolean;
  cases text[][] := array[
    -- user, label, may write tender/supplier, may delete tender, may write outreach
    ['c0000000-0000-4000-8000-000000000001','owner','t','t','t'],
    ['c0000000-0000-4000-8000-000000000007','operations_manager','t','t','f'],
    ['c0000000-0000-4000-8000-000000000003','sales_manager','t','t','t'],
    ['c0000000-0000-4000-8000-000000000002','sales_rep','t','f','t'],
    ['c0000000-0000-4000-8000-000000000004','field_worker','f','f','f'],
    ['c0000000-0000-4000-8000-000000000005','finance','f','f','f'],
    ['c0000000-0000-4000-8000-000000000006','read_only','f','f','f']
  ];
  i integer;
begin
  for i in 1 .. array_length(cases, 1) loop
    u := cases[i][1]::uuid; who := cases[i][2];
    role_ok := cases[i][3] = 't'; del_ok := cases[i][4] = 't'; out_ok := cases[i][5] = 't';

    perform set_config('request.jwt.claim.sub', u::text, true);
    perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';

    -- every member can still READ (SELECT policies untouched)
    select count(*) into n from public.tender_risks where workspace_id = ws;
    if n <> 2 then raise exception '% cannot read tender_risks (saw %)', who, n; end if;

    -- INSERT tender_risks
    begin
      insert into public.tender_risks (workspace_id, tender_record_id, title) values (ws, t, 'by ' || who);
      inserted := true;
    exception when insufficient_privilege then inserted := false;
    end;
    if inserted <> role_ok then raise exception '% tender insert: expected %, got %', who, role_ok, inserted; end if;

    -- UPDATE tender_risks (RLS filters rows silently: 0 rows updated when denied)
    update public.tender_risks set title = 'edited by ' || who where id = 'e0000000-0000-4000-8000-000000000002';
    get diagnostics n = row_count;
    if (n = 1) <> role_ok then raise exception '% tender update: expected %, rows=%', who, role_ok, n; end if;

    -- DELETE tender_risks
    delete from public.tender_risks where id = 'e0000000-0000-4000-8000-000000000003';
    get diagnostics n = row_count;
    if (n = 1) <> del_ok then raise exception '% tender delete: expected %, rows=%', who, del_ok, n; end if;

    -- outreach_lists write
    update public.outreach_lists set name = 'edited by ' || who where id = 'e0000000-0000-4000-8000-000000000004';
    get diagnostics n = row_count;
    if (n = 1) <> out_ok then raise exception '% outreach update: expected %, rows=%', who, out_ok, n; end if;

    execute 'reset role';

    -- reset fixtures so the next role is tested against identical data
    delete from public.tender_risks where title like 'by %';
    insert into public.tender_risks (id, workspace_id, tender_record_id, title)
      values ('e0000000-0000-4000-8000-000000000003', ws, t, 'seed risk 2')
      on conflict (id) do nothing;
  end loop;
end $$;

do $$ begin raise notice 'Role-based write policy checks passed'; end $$;

rollback;

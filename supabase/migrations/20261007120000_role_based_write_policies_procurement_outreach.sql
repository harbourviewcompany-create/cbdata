-- Role-based WRITE policies for procurement (tender_*, supplier_*, procurement source
-- registration map) and outreach_* tables.
--
-- Problem: write policies on these tables were `is_workspace_member(workspace_id)`, so
-- any active member (including field_worker, finance, read_only) could insert/update/
-- delete through the Supabase API, bypassing the role checks in the Next.js server
-- actions (src/lib/authz.ts ROLES). This aligns RLS with those app-level roles:
--
--   tender_*, supplier_*, procurement_source_registration_map
--       INSERT / UPDATE : owner, administrator, operations_manager, sales_manager, sales_rep
--       DELETE          : owner, administrator, operations_manager, sales_manager
--   outreach_*
--       INSERT / UPDATE : owner, administrator, sales_manager, sales_rep
--       DELETE          : owner, administrator, sales_manager
--
-- SELECT policies are untouched. Service-role callers (edge functions) and SECURITY
-- DEFINER RPCs bypass RLS and are unaffected. Policies are ALTERed in place so names
-- are preserved (some are still named workspace_member_*; the name is historical).
-- Tables with an `ALL` member policy are split into SELECT(member) + role-based writes,
-- because altering an ALL policy would also narrow reads.
--
-- Also (step 1): 20260927202000_harden_workspace_rpc_surface revoked EXECUTE on
-- public.is_workspace_member from authenticated, but policies created afterwards (tender_*,
-- supplier_*, canadabuys_runs, procurement_source_*) still call the unqualified
-- (public) function. A policy's function is executed with the caller's privileges, so
-- in a schema rebuilt from these migrations every such read/write fails with
-- "permission denied for function is_workspace_member". Step 1 re-points those policies
-- at private.is_workspace_member (which public.is_workspace_member merely wraps), so
-- behaviour is identical where the grant exists and correct where it does not.
--
-- Rollback: see docs/rollback/20261007120000_role_based_write_policies.sql
-- Guard: supabase/tests/036_role_based_write_policies.sql fails if a write policy on
-- these tables reverts to member-only.

-- Step 1: qualify unqualified is_workspace_member() calls in policies as private.*
do $$
declare
  r record;
  q text;
  c text;
begin
  for r in
    select schemaname, tablename, policyname, cmd, qual, with_check
    from pg_policies
    where schemaname = 'public'
      and (coalesce(qual,'') || ' ' || coalesce(with_check,'')) ~ '(^|[^.a-z_])is_workspace_member\('
  loop
    q := regexp_replace(coalesce(r.qual,''),       '(^|[^.a-z_])is_workspace_member\(', '\1private.is_workspace_member(', 'g');
    c := regexp_replace(coalesce(r.with_check,''), '(^|[^.a-z_])is_workspace_member\(', '\1private.is_workspace_member(', 'g');
    if r.cmd = 'INSERT' then
      execute format('alter policy %I on %I.%I with check (%s)', r.policyname, r.schemaname, r.tablename, c);
    elsif r.cmd = 'SELECT' or r.cmd = 'DELETE' then
      execute format('alter policy %I on %I.%I using (%s)', r.policyname, r.schemaname, r.tablename, q);
    elsif r.cmd = 'UPDATE' or r.cmd = 'ALL' then
      if r.with_check is null then
        execute format('alter policy %I on %I.%I using (%s)', r.policyname, r.schemaname, r.tablename, q);
      else
        execute format('alter policy %I on %I.%I using (%s) with check (%s)', r.policyname, r.schemaname, r.tablename, q, c);
      end if;
    end if;
  end loop;
end $$;

-- Step 2: role-based write policies
do $$
declare
  proc_write  text := $r$private.has_workspace_role(workspace_id, array['owner','administrator','operations_manager','sales_manager','sales_rep']::public.membership_role[])$r$;
  proc_delete text := $r$private.has_workspace_role(workspace_id, array['owner','administrator','operations_manager','sales_manager']::public.membership_role[])$r$;
  out_write   text := $r$private.has_workspace_role(workspace_id, array['owner','administrator','sales_manager','sales_rep']::public.membership_role[])$r$;
  out_delete  text := $r$private.has_workspace_role(workspace_id, array['owner','administrator','sales_manager']::public.membership_role[])$r$;
  r record;
  w text;
  d text;
  expr text;
begin
  for r in
    select p.tablename, p.policyname, p.cmd, coalesce(p.qual,'') as qual, coalesce(p.with_check,'') as wc
    from pg_policies p
    where p.schemaname = 'public'
      and p.cmd <> 'SELECT'
      and (
        p.tablename like 'tender\_%' or p.tablename like 'supplier\_%'
        or p.tablename = 'procurement_source_registration_map'
        or p.tablename like 'outreach\_%'
      )
    order by p.tablename, p.policyname
  loop
    if r.tablename like 'outreach\_%' then w := out_write; d := out_delete;
    else w := proc_write; d := proc_delete; end if;

    -- Only touch policies that are plain member checks; leave anything already role-based
    -- or custom alone (and say so) rather than guessing.
    expr := r.qual || ' ' || r.wc;
    if expr like '%has_workspace_role%' then continue; end if;
    if expr not like '%is_workspace_member(workspace_id)%' then
      raise notice 'SKIP %.% (%): not a plain member policy: %', r.tablename, r.policyname, r.cmd, expr;
      continue;
    end if;

    if r.cmd = 'ALL' then
      execute format('drop policy %I on public.%I', r.policyname, r.tablename);
      execute format('create policy %I on public.%I for select using (private.is_workspace_member(workspace_id))',
        r.tablename || '_select_member', r.tablename);
      execute format('create policy %I on public.%I for insert with check (%s)', r.tablename || '_insert_role', r.tablename, w);
      execute format('create policy %I on public.%I for update using (%s) with check (%s)', r.tablename || '_update_role', r.tablename, w, w);
      execute format('create policy %I on public.%I for delete using (%s)', r.tablename || '_delete_role', r.tablename, d);
    elsif r.cmd = 'INSERT' then
      execute format('alter policy %I on public.%I with check (%s)', r.policyname, r.tablename, w);
    elsif r.cmd = 'UPDATE' then
      execute format('alter policy %I on public.%I using (%s) with check (%s)', r.policyname, r.tablename, w, w);
    elsif r.cmd = 'DELETE' then
      execute format('alter policy %I on public.%I using (%s)', r.policyname, r.tablename, d);
    end if;
  end loop;
end $$;

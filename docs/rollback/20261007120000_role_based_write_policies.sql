-- MANUAL rollback for 20261007120000_role_based_write_policies_procurement_outreach.
-- Restores member-only write policies (the pre-migration behaviour) on the same tables.
-- Not in supabase/migrations on purpose: run it deliberately (SQL editor / psql), and
-- then add a forward migration if the revert is meant to be permanent.
do $$
declare r record; m text := 'private.is_workspace_member(workspace_id)';
begin
  for r in
    select p.tablename, p.policyname, p.cmd
    from pg_policies p
    where p.schemaname='public' and p.cmd<>'SELECT'
      and (coalesce(p.qual,'')||coalesce(p.with_check,'')) like '%has_workspace_role%'
      and (p.tablename like 'tender\_%' or p.tablename like 'supplier\_%'
           or p.tablename = 'procurement_source_registration_map' or p.tablename like 'outreach\_%')
  loop
    if r.policyname like '%\_insert\_role' or r.policyname like '%\_update\_role' or r.policyname like '%\_delete\_role' then
      -- policies created by the split of former ALL policies: rebuild a single ALL member policy below
      execute format('drop policy %I on public.%I', r.policyname, r.tablename);
    elsif r.cmd='INSERT' then execute format('alter policy %I on public.%I with check (%s)', r.policyname, r.tablename, m);
    elsif r.cmd='UPDATE' then execute format('alter policy %I on public.%I using (%s) with check (%s)', r.policyname, r.tablename, m, m);
    elsif r.cmd='DELETE' then execute format('alter policy %I on public.%I using (%s)', r.policyname, r.tablename, m);
    end if;
  end loop;
end $$;

drop policy if exists tender_pursuit_intelligence_select_member on public.tender_pursuit_intelligence;
create policy tender_pursuit_intelligence_member on public.tender_pursuit_intelligence
  using (private.is_workspace_member(workspace_id)) with check (private.is_workspace_member(workspace_id));
drop policy if exists tender_subtrade_opportunities_select_member on public.tender_subtrade_opportunities;
create policy tender_subtrade_member on public.tender_subtrade_opportunities
  using (private.is_workspace_member(workspace_id)) with check (private.is_workspace_member(workspace_id));

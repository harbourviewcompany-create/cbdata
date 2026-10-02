begin;

do $$
begin
  if to_regclass('public.outreach_work_sources') is null then
    raise exception 'outreach_work_sources missing';
  end if;
  if to_regclass('public.outreach_work_scout_runs') is null then
    raise exception 'outreach_work_scout_runs missing';
  end if;
  if to_regclass('public.v_outreach_work_source_health') is null then
    raise exception 'work source health view missing';
  end if;

  if position('consecutive_failures' in pg_get_viewdef(
    'public.v_outreach_work_source_health'::regclass,true
  ))=0 then
    raise exception 'work source health view lost failure-state logic';
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='public'
      and tablename='outreach_work_sources'
      and policyname='outreach_work_sources_member_select'
  ) then
    raise exception 'work source select RLS missing';
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='public'
      and tablename='outreach_work_sources'
      and policyname='outreach_work_sources_sales_update'
      and coalesce(qual,'') like '%has_workspace_role%'
      and coalesce(with_check,'') like '%has_workspace_role%'
  ) then
    raise exception 'work source update RLS is not sales-role gated';
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='public'
      and tablename='outreach_work_scout_runs'
      and policyname='outreach_work_scout_runs_member_select'
  ) then
    raise exception 'work scout run select RLS missing';
  end if;

  if exists (
    select 1 from pg_policies
    where schemaname='public'
      and tablename='outreach_work_sources'
      and cmd in ('INSERT','ALL')
  ) then
    raise exception 'Work Lead source insert RLS should fail closed';
  end if;
  if exists (
    select 1 from pg_policies
    where schemaname='public'
      and tablename='outreach_work_scout_runs'
      and cmd in ('INSERT','UPDATE','DELETE','ALL')
  ) then
    raise exception 'Work Lead scout run mutation RLS should fail closed';
  end if;
  if not has_table_privilege('authenticated','public.outreach_work_sources','SELECT') then
    raise exception 'authenticated cannot read Work Lead source health';
  end if;
  if not has_table_privilege('authenticated','public.outreach_work_sources','UPDATE') then
    raise exception 'authenticated cannot manage source enable state through RLS';
  end if;

  if not exists (
    select 1 from pg_indexes
    where schemaname='public'
      and tablename='outreach_work_scout_runs'
      and indexname='outreach_work_scout_runs_workspace_started_idx'
  ) then
    raise exception 'work scout run history index missing';
  end if;
end $$;

rollback;

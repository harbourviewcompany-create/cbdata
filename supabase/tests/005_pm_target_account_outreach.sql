-- Database-level verification for PM target-account outreach
-- (20260926140000_pm_target_account_outreach).
begin;
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'organizations' and column_name = 'doors_managed'
  ) then
    raise exception 'organizations.doors_managed missing';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'organizations' and column_name = 'primary_region'
  ) then
    raise exception 'organizations.primary_region missing';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'outreach_targets' and column_name = 'organization_id'
  ) then
    raise exception 'outreach_targets.organization_id missing';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'outreach_targets' and column_name = 'score'
  ) then
    raise exception 'outreach_targets.score missing';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'outreach_targets' and column_name = 'next_action'
  ) then
    raise exception 'outreach_targets.next_action missing';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'tasks' and column_name = 'outreach_target_id'
  ) then
    raise exception 'tasks.outreach_target_id missing';
  end if;

  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'convert_outreach_target_to_lead'
  ) then
    raise exception 'convert_outreach_target_to_lead missing';
  end if;

  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'refresh_outreach_target_score'
  ) then
    raise exception 'refresh_outreach_target_score missing';
  end if;

  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'log_outreach_touch'
  ) then
    raise exception 'log_outreach_touch missing';
  end if;

  if not exists (
    select 1 from information_schema.views
    where table_schema = 'public' and table_name = 'v_outreach_target_queue'
  ) then
    raise exception 'v_outreach_target_queue missing';
  end if;

  if public.compute_outreach_target_score(200, 8, true, true, true, 2) < 50 then
    raise exception 'compute_outreach_target_score unexpectedly low for strong PM profile';
  end if;

  if public.compute_outreach_target_score(null, null, false, false, false, 0) > 20 then
    raise exception 'compute_outreach_target_score unexpectedly high for empty profile';
  end if;

  raise notice 'PM target-account outreach verification passed';
end $$;
rollback;

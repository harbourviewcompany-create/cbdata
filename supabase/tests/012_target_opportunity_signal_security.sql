-- Opportunity-signal security and integrity regression checks.
do $$
declare
  idx text;
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='target_opportunity_signals'
      and policyname='workspace_member_select'
      and roles @> array['authenticated']::name[]
  ) then
    raise exception 'target_opportunity_signals authenticated workspace policy missing';
  end if;

  if exists (
    select 1 from information_schema.role_table_grants
    where table_schema='public' and table_name='target_opportunity_signals'
      and grantee='anon'
  ) then
    raise exception 'anon still has privileges on target_opportunity_signals';
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid='public.target_opportunity_signals'::regclass
      and conname='target_opportunity_signals_signal_type_check'
      and pg_get_constraintdef(oid) like '%acquisition%'
      and pg_get_constraintdef(oid) like '%management_change%'
  ) then
    raise exception 'opportunity signal taxonomy missing acquisition/management_change';
  end if;

  select indexdef into idx from pg_indexes
  where schemaname='public' and indexname='target_opportunity_signals_source_ref_uidx';
  if idx is null or idx not like '%property_id%' or idx not like '%signal_type%' then
    raise exception 'opportunity signal dedupe index is not property-aware';
  end if;

  if (
    select count(*) from pg_constraint
    where conrelid='public.target_opportunity_signals'::regclass
      and contype='f'
      and conname in (
        'target_opportunity_signals_workspace_id_fkey',
        'target_opportunity_signals_organization_id_fkey',
        'target_opportunity_signals_property_id_fkey',
        'target_opportunity_signals_target_id_fkey'
      )
  ) <> 4 then
    raise exception 'opportunity signal foreign-key integrity incomplete';
  end if;

  if not exists (
    select 1 from pg_indexes
    where schemaname='public' and indexname='idx_tender_properties_workspace_id'
  ) then
    raise exception 'tender_properties workspace FK index missing';
  end if;
end $$;

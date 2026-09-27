begin;

do $$
begin
  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'target_is_reachable'
  ) then
    raise exception 'target_is_reachable missing';
  end if;

  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'claim_outreach_target'
  ) then
    raise exception 'claim_outreach_target missing';
  end if;

  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'log_bd_outcome'
  ) then
    raise exception 'log_bd_outcome missing';
  end if;

  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'enroll_outreach_target'
  ) then
    raise exception 'enroll_outreach_target missing';
  end if;

  raise notice 'BD operating loop verification passed';
end $$;

rollback;

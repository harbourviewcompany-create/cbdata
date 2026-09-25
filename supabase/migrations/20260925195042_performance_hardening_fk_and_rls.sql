-- Performance hardening for CBData's multi-tenant operational workload.
--
-- 1. Avoid per-row auth.uid() evaluation in the self-profile policies.
-- 2. Cover every public foreign key that lacks a covering index. This matters
--    for joins, parent deletes/updates, and the workspace-scoped operational
--    access patterns used throughout CBData.

alter policy profile_self_select on public.user_profiles
  using (id = (select auth.uid()));

alter policy profile_self_insert on public.user_profiles
  with check (id = (select auth.uid()));

alter policy profile_self_update on public.user_profiles
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

do $$
declare
  r record;
  idx_name text;
begin
  for r in
    select
      c.oid as constraint_oid,
      c.conrelid::regclass::text as table_name,
      c.conkey,
      string_agg(format('%I', a.attname), ', ' order by u.ord) as columns
    from pg_constraint c
    join unnest(c.conkey) with ordinality as u(attnum, ord) on true
    join pg_attribute a
      on a.attrelid = c.conrelid
     and a.attnum = u.attnum
    where c.contype = 'f'
      and c.connamespace = 'public'::regnamespace
      and not exists (
        select 1
        from pg_index i
        where i.indrelid = c.conrelid
          and i.indisvalid
          and i.indpred is null
          and (
            select array_agg(x order by ordinality)
            from unnest(i.indkey) with ordinality as z(x, ordinality)
            where ordinality <= array_length(c.conkey, 1)
          ) = c.conkey
      )
    group by c.oid, c.conrelid, c.conkey
  loop
    idx_name := left('idx_fk_' || replace(r.table_name, '.', '_') || '_' || md5(r.constraint_oid::text), 63);
    execute format(
      'create index if not exists %I on %s (%s)',
      idx_name,
      r.table_name,
      r.columns
    );
  end loop;
end $$;

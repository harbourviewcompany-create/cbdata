-- Performance/security regression checks for the canonical CBData schema.

-- Every public foreign key must have a valid, non-partial covering index.
do $$
declare
  missing_count integer;
begin
  select count(*) into missing_count
  from pg_constraint c
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
    );

  if missing_count <> 0 then
    raise exception 'Found % public foreign keys without covering indexes', missing_count;
  end if;
end $$;

-- Self-profile RLS policies must use the initplan-safe auth.uid() form.
do $$
declare
  bad_count integer;
begin
  select count(*) into bad_count
  from pg_policies
  where schemaname = 'public'
    and tablename = 'user_profiles'
    and policyname in ('profile_self_select','profile_self_insert','profile_self_update')
    and (
      coalesce(qual,'') like '%auth.uid()%'
      and lower(coalesce(qual,'')) not like '%select auth.uid()%'
      or coalesce(with_check,'') like '%auth.uid()%'
      and lower(coalesce(with_check,'')) not like '%select auth.uid()%'
    );

  if bad_count <> 0 then
    raise exception 'Found % user_profiles policies using row-by-row auth.uid()', bad_count;
  end if;
end $$;

do $ begin raise notice 'CBData performance/security regression checks passed'; end $;

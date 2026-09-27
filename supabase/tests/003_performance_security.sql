-- performance/security regression checks

DO $$
DECLARE
  bad_count integer;
BEGIN
  SELECT count(*) INTO bad_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'user_profiles'
    AND (
      qual LIKE '%auth.uid()%' OR
      with_check LIKE '%auth.uid()%'
    );

  IF bad_count <> 0 THEN
    RAISE EXCEPTION 'Found % user_profiles policies using row-by-row auth.uid()', bad_count;
  END IF;
END $$;

DO $$
BEGIN
  RAISE NOTICE 'CBData performance/security regression checks passed';
END $$;
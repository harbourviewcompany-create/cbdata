do $$
declare
  v_token text;
begin
  if to_regprocedure('public.verify_procurement_scout_cron_token(text)') is null then
    raise exception 'cron token verifier is missing';
  end if;
  if has_function_privilege('anon', 'public.verify_procurement_scout_cron_token(text)', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.verify_procurement_scout_cron_token(text)', 'EXECUTE') then
    raise exception 'cron token verifier is exposed to clients';
  end if;
  if not has_function_privilege('service_role', 'public.verify_procurement_scout_cron_token(text)', 'EXECUTE') then
    raise exception 'Edge service role cannot verify cron token';
  end if;
  select decrypted_secret into v_token from vault.decrypted_secrets
    where name = 'cbdata_procurement_scout_cron_token';
  if length(coalesce(v_token, '')) <> 64
     or not public.verify_procurement_scout_cron_token(v_token)
     or public.verify_procurement_scout_cron_token('wrong-token') then
    raise exception 'Vault-backed cron token verification failed';
  end if;
  if (select count(*) from cron.job
       where jobname in ('cbdata-canadabuys-scout', 'cbdata-regional-tender-scout') and active) <> 2 then
    raise exception 'both procurement scout jobs must be active';
  end if;
end;
$$;

-- Schedule CB Contracting procurement discovery without storing a token in source.
-- The Edge handlers validate user JWTs or this Vault-backed cron token themselves.
create extension if not exists pg_net with schema extensions;

do $$
begin
  if not exists (select 1 from vault.secrets where name = 'cbdata_procurement_scout_cron_token') then
    perform vault.create_secret(
      encode(extensions.gen_random_bytes(32), 'hex'),
      'cbdata_procurement_scout_cron_token',
      'Authenticates scheduled CBData procurement scout requests'
    );
  end if;
end;
$$;

create or replace function public.verify_procurement_scout_cron_token(p_token text)
returns boolean language sql stable security definer set search_path = ''
as $$
  select coalesce(
    (select decrypted_secret = p_token
       from vault.decrypted_secrets
      where name = 'cbdata_procurement_scout_cron_token'
      limit 1), false
  ) and length(coalesce(p_token, '')) = 64;
$$;

revoke all on function public.verify_procurement_scout_cron_token(text) from public, anon, authenticated;
grant execute on function public.verify_procurement_scout_cron_token(text) to service_role;

-- pg_net queues the HTTP request; the run tables record actual completion/failure.
select cron.schedule(
  'cbdata-canadabuys-scout', '0 11 * * *',
  $job$
    select net.http_post(
      url := 'https://nzjwhmqrsxztnpdppbub.supabase.co/functions/v1/canadabuys-scout',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-cbdata-cron-token', (select decrypted_secret from vault.decrypted_secrets
                                   where name = 'cbdata_procurement_scout_cron_token')
      ),
      body := '{"workspace_id":"431aa13d-3e7c-41e3-9686-e840b8ea5b7c"}'::jsonb,
      timeout_milliseconds := 180000
    );
  $job$
);

select cron.schedule(
  'cbdata-regional-tender-scout', '20 11 * * *',
  $job$
    select net.http_post(
      url := 'https://nzjwhmqrsxztnpdppbub.supabase.co/functions/v1/regional-tender-scout',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-cbdata-cron-token', (select decrypted_secret from vault.decrypted_secrets
                                   where name = 'cbdata_procurement_scout_cron_token')
      ),
      body := '{"workspace_id":"431aa13d-3e7c-41e3-9686-e840b8ea5b7c"}'::jsonb,
      timeout_milliseconds := 180000
    );
  $job$
);

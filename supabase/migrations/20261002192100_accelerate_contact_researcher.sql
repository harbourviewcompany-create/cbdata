-- Increase contact-research throughput while preserving the existing authenticated worker.
do $$
declare
  v_jobid bigint;
begin
  select jobid into v_jobid
  from cron.job
  where jobname='cbdata-contact-researcher'
  limit 1;

  if v_jobid is null then
    raise exception 'cbdata-contact-researcher cron job is missing';
  end if;

  perform cron.alter_job(
    v_jobid,
    schedule => '17 * * * *',
    command => $job$
      select net.http_post(
        url := 'https://nzjwhmqrsxztnpdppbub.supabase.co/functions/v1/contact-researcher',
        headers := jsonb_build_object(
          'Content-Type','application/json',
          'x-cbdata-cron-token',
          (select decrypted_secret
             from vault.decrypted_secrets
            where name='cbdata_procurement_scout_cron_token')
        ),
        body := '{"workspace_id":"431aa13d-3e7c-41e3-9686-e840b8ea5b7c","limit":20}'::jsonb,
        timeout_milliseconds := 180000
      );
    $job$
  );
end $$;

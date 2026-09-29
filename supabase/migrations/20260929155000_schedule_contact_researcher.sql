-- Schedule contact researcher after daily procurement discovery.
do $$ begin perform cron.unschedule('cbdata-contact-researcher'); exception when others then null; end $$;
select cron.schedule(
 'cbdata-contact-researcher','45 12 * * *',
 $job$
 select net.http_post(
  url := 'https://nzjwhmqrsxztnpdppbub.supabase.co/functions/v1/contact-researcher',
  headers := jsonb_build_object('Content-Type','application/json','x-cbdata-cron-token',
   (select decrypted_secret from vault.decrypted_secrets where name='cbdata_procurement_scout_cron_token')),
  body := '{"workspace_id":"431aa13d-3e7c-41e3-9686-e840b8ea5b7c","limit":10}'::jsonb,
  timeout_milliseconds := 180000
 ));

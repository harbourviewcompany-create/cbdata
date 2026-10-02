-- Increase contact-research throughput without changing the existing secure cron command.
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

  perform cron.alter_job(v_jobid, schedule => '17 */3 * * *');
end $$;

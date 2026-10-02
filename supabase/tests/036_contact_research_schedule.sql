begin;

do $$
declare
  v_schedule text;
begin
  select schedule into v_schedule
  from cron.job
  where jobname='cbdata-contact-researcher'
  limit 1;

  if v_schedule is distinct from '17 * * * *' then
    raise exception 'contact researcher cadence regression: %', v_schedule;
  end if;
end $$;

rollback;

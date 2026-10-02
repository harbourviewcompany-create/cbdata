begin;

do $$
declare
  v_schedule text;
  v_command text;
begin
  select schedule,command
    into v_schedule,v_command
  from cron.job
  where jobname='cbdata-contact-researcher'
  limit 1;

  if v_schedule is distinct from '17 * * * *' then
    raise exception 'contact researcher cadence regression: %', v_schedule;
  end if;

  if position('"limit":20' in coalesce(v_command,''))=0 then
    raise exception 'contact researcher batch size regression';
  end if;
end $$;

rollback;

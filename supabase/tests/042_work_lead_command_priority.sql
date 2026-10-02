begin;

do $$
declare
  v_view text;
  v_byng integer;
  v_mbc integer;
begin
  v_view:=pg_get_viewdef('public.v_outreach_pursuit_queue'::regclass,true);

  if position('work_lead_rollup' in v_view)=0
     or position('best_work_lead_score' in v_view)=0
     or position('nearest_work_lead_deadline' in v_view)=0 then
    raise exception 'Work Lead priority rollup missing from pursuit queue';
  end if;

  if position('needs_response_count' in v_view)=0 then
    raise exception 'reply priority was lost from pursuit queue';
  end if;

  select command_score into v_byng
  from public.v_outreach_pursuit_queue
  where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
    and organization_display_name='The Byng Group';

  if v_byng is not null and v_byng < 55 then
    raise exception 'high-scoring active Byng Work Lead is under-prioritized: %',v_byng;
  end if;

  select command_score into v_mbc
  from public.v_outreach_pursuit_queue
  where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
    and organization_display_name='McDonald Brothers Construction Inc.';

  if v_mbc is not null and v_mbc < 90 then
    raise exception 'near-deadline MBC Work Lead is under-prioritized: %',v_mbc;
  end if;

  if exists (
    select 1
    from public.v_outreach_pursuit_queue
    where best_work_lead_score >= 80
      and latest_draft_state in ('draft','approved')
      and latest_draft_quality_passed
      and command_score < total_score + 15
  ) then
    raise exception 'ready high-score Work Lead is missing command-score uplift';
  end if;
end $$;

rollback;

begin;

do $$
declare
  v_view text;
  v_count integer;
begin
  v_view:=pg_get_viewdef('public.v_outreach_pursuit_queue'::regclass,true);

  if position('count(DISTINCT (l.source_key' in v_view)=0 then
    raise exception 'Work Lead rollup is not deduplicated by source/opportunity signature';
  end if;

  select active_work_lead_count into v_count
  from public.v_outreach_pursuit_queue
  where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
    and organization_display_name='The Byng Group';

  if v_count is not null and v_count<>1 then
    raise exception 'Byng duplicate Work Lead count regression: %',v_count;
  end if;

  select active_work_lead_count into v_count
  from public.v_outreach_pursuit_queue
  where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
    and organization_display_name='Pinecrest Construction';

  if v_count is not null and v_count<>1 then
    raise exception 'Pinecrest duplicate Work Lead count regression: %',v_count;
  end if;

  select active_work_lead_count into v_count
  from public.v_outreach_pursuit_queue
  where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
    and organization_display_name='McDonald Brothers Construction Inc.';

  if v_count is not null and v_count<2 then
    raise exception 'distinct MBC Work Leads were incorrectly collapsed: %',v_count;
  end if;
end $$;

rollback;

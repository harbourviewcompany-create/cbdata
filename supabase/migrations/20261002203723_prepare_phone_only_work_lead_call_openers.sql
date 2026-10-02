-- Prepare email outreach when a verified personal email exists.
-- For verified phone-only operations/procurement contacts, prepare one manual call opener instead.
CREATE OR REPLACE FUNCTION public.prepare_work_lead_draft(p_task_id uuid, p_contact_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  e public.contact_enrichment_tasks%rowtype;
  t public.outreach_targets%rowtype;
  c public.contacts%rowtype;
  l public.outreach_work_leads%rowtype;
  v_existing uuid;
  v_existing_state text;
  v_id uuid;
  v_first text;
  v_service text;
  v_subject text;
  v_body text;
  v_objective text;
  v_channel text;
  v_next_action text;
begin
  if current_user not in ('service_role','postgres') then raise exception 'service role required'; end if;

  select * into e from public.contact_enrichment_tasks where id=p_task_id and status='verified';
  if not found then return null; end if;

  select * into t from public.outreach_targets where id=e.outreach_target_id and workspace_id=e.workspace_id;
  if not found then return null; end if;

  select * into c from public.contacts
  where id=p_contact_id and workspace_id=e.workspace_id
    and status='active' and source_confidence='high'
    and (nullif(email,'') is not null or nullif(phone,'') is not null);
  if not found then return null; end if;

  if nullif(c.email,'') is not null then
    v_channel:='email';
  elsif nullif(c.phone,'') is not null and e.missing_role in ('operations','procurement') then
    v_channel:='call';
  else
    return null;
  end if;

  select * into l
  from public.outreach_work_leads
  where workspace_id=e.workspace_id
    and outreach_target_id=t.id
    and status='promoted'
    and conversion_score >= 78
    and (deadline_at is null or deadline_at >= now())
  order by conversion_score desc,deadline_at nulls last,last_seen_at desc
  limit 1;
  if not found then return null; end if;

  v_first:=coalesce(nullif(c.first_name,''),'there');
  v_service:=case
    when cardinality(l.service_fit)>0 then
      array_to_string(l.service_fit[1:least(2,cardinality(l.service_fit))],' / ')
    else 'contracting and maintenance'
  end;

  v_objective:=case
    when l.response_mode in ('vendor_registration','subcontractor_application') then 'vendor_registration'
    when l.response_mode='formal_bid' then 'quote'
    else 'introduction'
  end;

  v_subject:=left(
    case
      when v_channel='call' then 'Call opener — '||l.buyer_name
      when l.response_mode='formal_bid' then l.opportunity_title || ' — subcontractor coverage'
      when l.response_mode='vendor_registration' then 'CB Contracting — bidder / trade list'
      when l.response_mode='subcontractor_application' then 'CB Contracting — subcontractor coverage'
      else l.opportunity_title || ' — CB Contracting'
    end,140
  );

  if v_channel='call' then
    v_body:='Hi '||v_first||', Tyler with CB Contracting. '||
      case
        when l.response_mode='formal_bid' then
          'I saw '||l.opportunity_title||'. We handle '||v_service||
          ' work in the Ottawa area, and I’m calling to see where you still need subcontractor coverage or pricing.'
        when l.response_mode='subcontractor_application' then
          'I saw that '||l.buyer_name||' is adding subcontractors. We take on '||v_service||
          ' work across Ottawa, and I’m calling to see where you need extra coverage or quick pricing right now.'
        when l.response_mode='vendor_registration' then
          'I saw the trade/vendor route with '||l.buyer_name||'. We take on '||v_service||
          ' work in Ottawa, and I’m calling to get CB Contracting to the right person for upcoming scopes.'
        else
          'I came across '||l.opportunity_title||'. We take on '||v_service||
          ' work in Ottawa and can price smaller scopes quickly.'
      end||
      ' Do you handle subcontractor assignments or pricing? If so, what active scope can I review today?';
  else
    v_body:='Hi '||v_first||','||E'\n\n'||
    case
      when l.response_mode='formal_bid' then
        'I’m Tyler with CB Contracting. I saw '||l.opportunity_title||
        ' and wanted to check where you still need subcontractor coverage. We can review '||
        v_service||' scope in the Ottawa area and turn pricing around quickly on work that fits us.'||
        E'\n\nAre there any packages still open for pricing? If so, send over the relevant scope, drawings, and bidder requirements and I’ll review them.'
      when l.response_mode='subcontractor_application' then
        'I’m Tyler with CB Contracting. I saw that '||l.buyer_name||
        ' is adding subcontractors. We take on '||v_service||
        ' work across Ottawa, including smaller repair and renovation scopes where quick pricing and reliable scheduling matter.'||
        E'\n\nAre you the right person for subcontractor assignments and pricing? If you have something active, send the scope, photos, or address and I’ll review it.'
      when l.response_mode='vendor_registration' then
        'I’m Tyler with CB Contracting. I saw the trade/vendor registration route with '||l.buyer_name||
        '. We take on '||v_service||' work in the Ottawa area and I’d like to get CB Contracting onto the right bidder list.'||
        E'\n\nAre you the right person for that, and is there an upcoming job we should review first?'
      else
        'I’m Tyler with CB Contracting. I came across '||l.opportunity_title||
        '. We take on '||v_service||' work in the Ottawa area and can price smaller scopes quickly.'||
        E'\n\nIs this something you handle, and is there a current job where it would make sense for us to provide pricing?'
    end||
    E'\n\nTyler\nCB Contracting';
  end if;

  v_next_action:=case
    when v_channel='call' then 'Use verified Work Lead call opener for '||l.opportunity_title
    else 'Review Work Lead draft for '||l.opportunity_title
  end;

  select d.id,d.state into v_existing,v_existing_state
  from public.outreach_drafts d
  where d.workspace_id=e.workspace_id
    and d.outreach_target_id=t.id
    and d.contact_id=c.id
    and d.channel=v_channel
    and d.state in ('draft','approved')
    and d.evidence->>'work_lead_id'=l.id::text
  order by d.created_at desc limit 1;

  if v_existing is not null and v_existing_state='approved' then return v_existing; end if;

  if v_existing is not null then
    update public.outreach_drafts
    set objective=v_objective,subject=v_subject,body=v_body,
        evidence=evidence || jsonb_build_object(
          'signal',l.opportunity_title,
          'signal_confidence','high',
          'contact_source',c.source_url,
          'contact_confidence',c.source_confidence,
          'message_version','work_lead_conversion_v4'
        ),
        quality_notes=coalesce(quality_notes,'{}'::jsonb) ||
          jsonb_build_object('send_mode','manual_review_required','auto_send',false),
        updated_at=now()
    where id=v_existing;
    return v_existing;
  end if;

  insert into public.outreach_drafts(
    workspace_id,outreach_target_id,contact_id,channel,objective,subject,body,
    evidence,state,strategy,quality_flags,quality_passed,quality_score,quality_notes,created_by
  )
  values(
    e.workspace_id,t.id,c.id,v_channel,v_objective,v_subject,v_body,
    jsonb_build_object(
      'work_lead_id',l.id,'source_url',l.source_url,'source_label',l.source_label,
      'opportunity_title',l.opportunity_title,'response_mode',l.response_mode,
      'service_fit',l.service_fit,'conversion_score',l.conversion_score,
      'signal',l.opportunity_title,'signal_confidence','high',
      'contact_source',c.source_url,'contact_confidence',c.source_confidence,
      'contact_research_task_id',e.id,'generated_from_verified_data',true,
      'message_version','work_lead_conversion_v4'
    ),
    'draft','work_lead_trigger','[]'::jsonb,true,94,
    jsonb_build_object(
      'reason','Verified named contact + active high-scoring work lead',
      'send_mode','manual_review_required','auto_send',false
    ),
    null
  )
  returning id into v_id;

  update public.outreach_targets
  set contact_id=coalesce(contact_id,c.id),
      next_action=case when l.conversion_score >= coalesce(score,0)
        then v_next_action else next_action end,
      next_action_due_at=case when l.conversion_score >= coalesce(score,0)
        then now() else next_action_due_at end,
      updated_at=now()
  where id=t.id;

  update public.outreach_pursuits
  set next_action=v_next_action,
      next_action_due_at=now(),
      stage=case when stage='research' then 'contact_ready' else stage end,
      updated_at=now()
  where id=t.pursuit_id and workspace_id=e.workspace_id
    and l.conversion_score >= coalesce(t.score,0);

  return v_id;
end
$function$;

revoke all on function public.prepare_work_lead_draft(uuid,uuid) from public,anon,authenticated;
grant execute on function public.prepare_work_lead_draft(uuid,uuid) to service_role;

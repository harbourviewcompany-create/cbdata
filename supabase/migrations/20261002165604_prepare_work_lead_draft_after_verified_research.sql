create or replace function public.prepare_work_lead_draft(
  p_task_id uuid,
  p_contact_id uuid
)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare
  e public.contact_enrichment_tasks%rowtype;
  t public.outreach_targets%rowtype;
  c public.contacts%rowtype;
  l public.outreach_work_leads%rowtype;
  v_existing uuid;
  v_id uuid;
  v_first text;
  v_service text;
  v_subject text;
  v_body text;
  v_objective text;
  v_cta text;
begin
  if current_user not in ('service_role','postgres') then raise exception 'service role required'; end if;

  select * into e from public.contact_enrichment_tasks where id=p_task_id and status='verified';
  if not found then return null; end if;

  select * into t from public.outreach_targets where id=e.outreach_target_id and workspace_id=e.workspace_id;
  if not found then return null; end if;

  select * into c from public.contacts
  where id=p_contact_id and workspace_id=e.workspace_id and status='active'
    and source_confidence='high' and nullif(email,'') is not null;
  if not found then return null; end if;

  select * into l from public.outreach_work_leads
  where workspace_id=e.workspace_id and outreach_target_id=t.id and status='promoted'
    and conversion_score >= 78 and (deadline_at is null or deadline_at >= now())
  order by conversion_score desc, deadline_at nulls last, last_seen_at desc
  limit 1;
  if not found then return null; end if;

  select d.id into v_existing
  from public.outreach_drafts d
  where d.workspace_id=e.workspace_id and d.outreach_target_id=t.id and d.contact_id=c.id
    and d.channel='email' and d.state in ('draft','approved')
    and d.evidence->>'work_lead_id'=l.id::text
  order by d.created_at desc limit 1;
  if v_existing is not null then return v_existing; end if;

  v_first:=coalesce(nullif(c.first_name,''),'there');
  v_service:=coalesce(l.service_fit[1],'contracting');
  v_objective:=case
    when l.response_mode in ('vendor_registration','subcontractor_application') then 'vendor_registration'
    when l.response_mode='formal_bid' then 'quote'
    else 'introduction'
  end;

  v_cta:=case
    when l.response_mode='formal_bid' then
      'Are you the right person for trade coverage or subcontractor pricing on this scope, or should I send our information to someone else?'
    when l.response_mode='subcontractor_application' then
      'Is there an upcoming job where you need coverage or pricing, or should I send our trade information to someone else on your team?'
    when l.response_mode='vendor_registration' then
      'What is the best way to get CB Contracting onto your bidder or vendor list for relevant work?'
    else
      'Is this something you handle, and is there a current job where it would make sense for us to provide pricing?'
  end;

  v_subject:=left(
    case
      when l.response_mode='formal_bid' then l.opportunity_title || ' — CB Contracting'
      when l.response_mode in ('vendor_registration','subcontractor_application') then 'CB Contracting — ' || l.buyer_name
      else l.opportunity_title || ' — CB Contracting'
    end,140
  );

  v_body:='Hi '||v_first||','||E'\n\n'||
    'I’m Tyler with CB Contracting. '||
    case
      when l.response_mode='formal_bid' then
        'I saw '||l.opportunity_title||' and we handle '||v_service||' work in the Ottawa area.'
      when l.response_mode='subcontractor_application' then
        'I saw that '||l.buyer_name||' is looking for subcontractor support. We handle '||v_service||' work in the Ottawa area.'
      when l.response_mode='vendor_registration' then
        'I saw the contractor/vendor registration route with '||l.buyer_name||'. We handle '||v_service||' work in the Ottawa area.'
      else
        'I came across '||l.opportunity_title||'. We handle '||v_service||' work in the Ottawa area.'
    end||
    E'\n\n'||v_cta||
    E'\n\nTyler\nCB Contracting';

  insert into public.outreach_drafts(
    workspace_id,outreach_target_id,contact_id,channel,objective,subject,body,
    evidence,state,strategy,quality_flags,quality_passed,quality_score,quality_notes,created_by
  )
  values(
    e.workspace_id,t.id,c.id,'email',v_objective,v_subject,v_body,
    jsonb_build_object(
      'work_lead_id',l.id,'source_url',l.source_url,'source_label',l.source_label,
      'opportunity_title',l.opportunity_title,'response_mode',l.response_mode,
      'service_fit',l.service_fit,'conversion_score',l.conversion_score,
      'contact_source',c.source_url,'contact_confidence',c.source_confidence,
      'contact_research_task_id',e.id,'generated_from_verified_data',true
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
        then 'Review Work Lead draft for '||l.opportunity_title else next_action end,
      next_action_due_at=case when l.conversion_score >= coalesce(score,0)
        then now() else next_action_due_at end,
      updated_at=now()
  where id=t.id;

  update public.outreach_pursuits
  set next_action='Review Work Lead draft for '||l.opportunity_title,
      next_action_due_at=now(),
      stage=case when stage='research' then 'contact_ready' else stage end,
      updated_at=now()
  where id=t.pursuit_id and workspace_id=e.workspace_id
    and l.conversion_score >= coalesce(t.score,0);

  return v_id;
end
$$;

revoke all on function public.prepare_work_lead_draft(uuid,uuid) from public,anon,authenticated;
grant execute on function public.prepare_work_lead_draft(uuid,uuid) to service_role;

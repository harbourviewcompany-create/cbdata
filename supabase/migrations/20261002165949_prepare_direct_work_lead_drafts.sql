create or replace function public.prepare_direct_work_lead_draft(p_lead_id uuid)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare
  l public.outreach_work_leads%rowtype;
  t public.outreach_targets%rowtype;
  v_existing uuid;
  v_id uuid;
  v_service text;
  v_greeting text;
  v_subject text;
  v_body text;
  v_objective text;
  v_cta text;
begin
  if current_user not in ('service_role','postgres') then
    raise exception 'service role required';
  end if;

  select * into l
  from public.outreach_work_leads
  where id=p_lead_id
    and status='promoted'
    and conversion_score >= 78
    and nullif(contact_email,'') is not null
    and (deadline_at is null or deadline_at >= now());

  if not found then return null; end if;

  if exists (
    select 1
    from public.outreach_work_leads higher
    where higher.workspace_id=l.workspace_id
      and higher.outreach_target_id=l.outreach_target_id
      and higher.status='promoted'
      and (higher.deadline_at is null or higher.deadline_at >= now())
      and (
        higher.conversion_score > l.conversion_score
        or (
          higher.conversion_score=l.conversion_score
          and coalesce(higher.deadline_at,'9999-12-31'::timestamptz)
              < coalesce(l.deadline_at,'9999-12-31'::timestamptz)
        )
      )
  ) then
    return null;
  end if;

  select * into t
  from public.outreach_targets
  where id=l.outreach_target_id and workspace_id=l.workspace_id;

  if not found then return null; end if;

  select d.id into v_existing
  from public.outreach_drafts d
  where d.workspace_id=l.workspace_id
    and d.outreach_target_id=t.id
    and d.channel='email'
    and d.state in ('draft','approved')
    and d.evidence->>'work_lead_id'=l.id::text
  order by d.created_at desc
  limit 1;

  if v_existing is not null then return v_existing; end if;

  v_service:=coalesce(l.service_fit[1],'contracting');
  v_greeting:=case
    when nullif(l.contact_name,'') is not null then split_part(l.contact_name,' ',1)
    when l.response_mode='formal_bid' then 'estimating team'
    else l.buyer_name||' team'
  end;

  v_objective:=case
    when l.response_mode in ('vendor_registration','subcontractor_application') then 'vendor_registration'
    when l.response_mode='formal_bid' then 'quote'
    else 'introduction'
  end;

  v_cta:=case
    when l.response_mode='formal_bid' then
      'Are you the right contact for trade coverage or subcontractor pricing on this scope, and is there a package or bidder requirement we should review before pricing?'
    when l.response_mode='subcontractor_application' then
      'Is there an upcoming job where you need coverage or pricing, or should I send our trade information to someone else on your team?'
    when l.response_mode='vendor_registration' then
      'What is the best way to get CB Contracting onto your bidder or vendor list for relevant work?'
    else
      'Is there a current job where it would make sense for us to provide pricing?'
  end;

  v_subject:=left(
    case
      when l.response_mode='formal_bid' then l.opportunity_title || ' — CB Contracting'
      else 'CB Contracting — '||l.buyer_name
    end,140
  );

  v_body:='Hi '||v_greeting||','||E'\n\n'||
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
    l.workspace_id,t.id,t.contact_id,'email',v_objective,v_subject,v_body,
    jsonb_build_object(
      'work_lead_id',l.id,
      'source_url',l.source_url,
      'source_label',l.source_label,
      'opportunity_title',l.opportunity_title,
      'response_mode',l.response_mode,
      'service_fit',l.service_fit,
      'conversion_score',l.conversion_score,
      'direct_response_email',l.contact_email,
      'direct_response_phone',l.contact_phone,
      'generated_from_official_source_contact',true
    ),
    'draft','work_lead_direct','[]'::jsonb,true,91,
    jsonb_build_object(
      'reason','Official source provides direct response contact',
      'send_mode','manual_review_required',
      'auto_send',false
    ),
    null
  )
  returning id into v_id;

  if l.conversion_score >= coalesce(t.score,0) then
    update public.outreach_targets
    set next_action='Review Work Lead draft for '||l.opportunity_title,
        next_action_due_at=now(),
        updated_at=now()
    where id=t.id;

    update public.outreach_pursuits
    set next_action='Review Work Lead draft for '||l.opportunity_title,
        next_action_due_at=now(),
        stage=case when stage='research' then 'contact_ready' else stage end,
        updated_at=now()
    where id=t.pursuit_id and workspace_id=l.workspace_id;
  end if;

  return v_id;
end
$$;

revoke all on function public.prepare_direct_work_lead_draft(uuid) from public,anon,authenticated;
grant execute on function public.prepare_direct_work_lead_draft(uuid) to service_role;

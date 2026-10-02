-- Use the named unique constraint to avoid OUT-parameter ambiguity in PL/pgSQL.\ncreate or replace function private.promote_outreach_work_lead_core(p_lead_id uuid)
returns table(outreach_target_id uuid,pursuit_id uuid,organization_id uuid)
language plpgsql
security definer
set search_path=''
as $$
declare
  v_lead public.outreach_work_leads%rowtype;
  v_org uuid;
  v_list uuid;
  v_target uuid;
  v_pursuit uuid;
  v_norm text;
  v_is_service boolean;
  v_next text;
  v_priority public.work_priority;
begin
  select * into v_lead
  from public.outreach_work_leads
  where id=p_lead_id
  for update;

  if not found then raise exception 'work lead not found'; end if;

  v_is_service := coalesce(auth.jwt()->>'role','')='service_role';
  if not v_is_service then
    if auth.uid() is null or not private.has_workspace_role(
      v_lead.workspace_id,
      array['owner','administrator','sales_manager','sales_rep']::public.membership_role[]
    ) then
      raise exception 'insufficient outreach role';
    end if;
  end if;

  if v_lead.deadline_at is not null and v_lead.deadline_at < now() then
    update public.outreach_work_leads set status='expired',updated_at=now() where id=v_lead.id;
    raise exception 'work lead is expired';
  end if;
  if v_lead.status='dismissed' then raise exception 'work lead is dismissed'; end if;

  v_norm := regexp_replace(lower(coalesce(v_lead.buyer_name,'')), '[^a-z0-9]+', '', 'g');
  select o.id into v_org
  from public.organizations o
  where o.workspace_id=v_lead.workspace_id
    and regexp_replace(lower(coalesce(o.operating_name,o.legal_name,'')), '[^a-z0-9]+', '', 'g')=v_norm
  order by (o.operating_name is not null) desc,o.updated_at desc
  limit 1;

  if v_org is null then
    insert into public.organizations(
      workspace_id,legal_name,operating_name,organization_type,status,
      primary_region,phone,email,source_notes
    )
    values(
      v_lead.workspace_id,v_lead.buyer_name,v_lead.buyer_name,
      'prospect'::public.organization_type,'active'::public.record_status,
      v_lead.region,v_lead.contact_phone,v_lead.contact_email,
      'Created from CBData Work Leads: ' || v_lead.source_label
    )
    returning id into v_org;
  else
    update public.organizations
    set phone=coalesce(phone,v_lead.contact_phone),
        email=coalesce(email,v_lead.contact_email),
        primary_region=coalesce(primary_region,v_lead.region),
        updated_at=now()
    where id=v_org;
  end if;

  select l.id into v_list
  from public.outreach_lists l
  where l.workspace_id=v_lead.workspace_id
    and (l.criteria->>'segment'='gc_subcontractor'
         or l.name='Ottawa general contractors (subcontractor partnerships)')
  order by (l.criteria->>'segment'='gc_subcontractor') desc,l.created_at
  limit 1;

  if v_list is null then
    insert into public.outreach_lists(workspace_id,name,criteria,created_by)
    values(
      v_lead.workspace_id,'Ottawa general contractors (subcontractor partnerships)',
      jsonb_build_object('region','Ottawa, ON','segment','gc_subcontractor','engine','outreach_work_leads'),
      auth.uid()
    )
    returning id into v_list;
  end if;

  select t.id into v_target
  from public.outreach_targets t
  where t.outreach_list_id=v_list and t.organization_id=v_org
  limit 1;

  v_priority := case
    when v_lead.conversion_score >= 88 then 'urgent'::public.work_priority
    when v_lead.conversion_score >= 72 then 'high'::public.work_priority
    else 'normal'::public.work_priority end;

  v_next := case
    when nullif(v_lead.contact_phone,'') is not null then
      'WORK LEAD: Call ' || v_lead.buyer_name || ' about ' || v_lead.opportunity_title || ' and ask for the scope, site walk, or quote path.'
    when nullif(v_lead.contact_email,'') is not null then
      'WORK LEAD: Email ' || v_lead.buyer_name || ' about ' || v_lead.opportunity_title || ' and ask for the scope, site walk, or quote path.'
    else
      'WORK LEAD: Research the operations/project/estimating contact at ' || v_lead.buyer_name || ', then approach them about ' || v_lead.opportunity_title || '.'
  end;

  if v_target is null then
    insert into public.outreach_targets(
      workspace_id,outreach_list_id,organization_id,organization_name,
      region,score,score_reason,next_action,next_action_due_at,priority,notes,
      company_phone,company_email,company_website,status
    )
    values(
      v_lead.workspace_id,v_list,v_org,v_lead.buyer_name,
      v_lead.region,v_lead.conversion_score,
      'Work lead ' || round(v_lead.conversion_score)::text || '/100 · ' ||
        array_to_string(v_lead.service_fit,', ') || ' · source ' || v_lead.source_label,
      v_next,now(),v_priority,
      coalesce(v_lead.description,'') || E'\nSource: ' || v_lead.source_url,
      v_lead.contact_phone,v_lead.contact_email,v_lead.source_url,'queued'::public.outreach_target_status
    )
    returning public.outreach_targets.id,public.outreach_targets.pursuit_id into v_target,v_pursuit;
  else
    update public.outreach_targets
    set score=greatest(coalesce(score,0),v_lead.conversion_score),
        score_reason='Work lead ' || round(v_lead.conversion_score)::text || '/100 · ' ||
          array_to_string(v_lead.service_fit,', ') || ' · source ' || v_lead.source_label,
        next_action=v_next,next_action_due_at=now(),priority=v_priority,
        company_phone=coalesce(company_phone,v_lead.contact_phone),
        company_email=coalesce(company_email,v_lead.contact_email),
        notes=concat_ws(E'\n',nullif(notes,''),'Active work lead: ' || v_lead.opportunity_title || ' · ' || v_lead.source_url),
        updated_at=now()
    where id=v_target
    returning public.outreach_targets.pursuit_id into v_pursuit;
  end if;

  if v_pursuit is null then
    select t.pursuit_id into v_pursuit from public.outreach_targets t where t.id=v_target;
  end if;

  if v_pursuit is not null then
    update public.outreach_pursuits
    set next_action=v_next,next_action_due_at=now(),
        stage=case when stage='research' and (v_lead.contact_email is not null or v_lead.contact_phone is not null)
                   then 'contact_ready' else stage end,
        updated_at=now()
    where id=v_pursuit and workspace_id=v_lead.workspace_id;
  end if;

  if not exists (
    select 1 from public.target_opportunity_signals s
    where s.workspace_id=v_lead.workspace_id and s.target_id=v_target
      and s.source_url=v_lead.source_url and s.title=v_lead.opportunity_title
  ) then
    insert into public.target_opportunity_signals(
      workspace_id,organization_id,target_id,signal_type,title,service_fit,
      source_url,source_label,source_confidence,published_at,deadline_at,status,
      buyer_contact_name,buyer_contact_email,reference_number,notes
    )
    values(
      v_lead.workspace_id,v_org,v_target,'procurement',v_lead.opportunity_title,v_lead.service_fit,
      v_lead.source_url,v_lead.source_label,'high',v_lead.published_at,v_lead.deadline_at,'open',
      v_lead.contact_name,v_lead.contact_email,v_lead.external_id,
      'Private/subcontract/service work lead. Response mode: ' || v_lead.response_mode
    );
  end if;

  insert into public.contact_enrichment_tasks(
    workspace_id,outreach_target_id,organization_id,missing_role,priority_score,status,
    research_query,research_priority_score,research_priority_reason,research_urgency_rank
  )
  select
    v_lead.workspace_id,v_target,v_org,x.role,round(v_lead.conversion_score)::int,'queued',
    v_lead.buyer_name || ' Ottawa ' ||
      case x.role when 'operations' then 'operations project manager estimator'
                  else 'owner president director construction' end ||
      ' contact email phone',
    round(v_lead.conversion_score)::int,
    'Active Work Lead: ' || v_lead.opportunity_title,
    case when v_lead.deadline_at is not null and v_lead.deadline_at <= now()+interval '7 days' then 100
         else round(v_lead.speed_score)::int end
  from (values ('operations'::text),('decision_maker'::text)) x(role)
  on conflict on constraint contact_enrichment_tasks_workspace_id_outreach_target_id_mi_key do update set
    priority_score=greatest(public.contact_enrichment_tasks.priority_score,excluded.priority_score),
    research_priority_score=greatest(public.contact_enrichment_tasks.research_priority_score,excluded.research_priority_score),
    research_priority_reason=excluded.research_priority_reason,
    research_urgency_rank=greatest(public.contact_enrichment_tasks.research_urgency_rank,excluded.research_urgency_rank),
    status=case when public.contact_enrichment_tasks.status='dismissed' then public.contact_enrichment_tasks.status else 'queued' end,
    next_attempt_at=case when public.contact_enrichment_tasks.status='dismissed' then public.contact_enrichment_tasks.next_attempt_at else now() end,
    updated_at=now();

  update public.outreach_work_leads
  set status='promoted',matched_organization_id=v_org,outreach_target_id=v_target,pursuit_id=v_pursuit,
      promoted_at=coalesce(promoted_at,now()),updated_at=now()
  where id=v_lead.id;

  return query select v_target,v_pursuit,v_org;
end
$$;


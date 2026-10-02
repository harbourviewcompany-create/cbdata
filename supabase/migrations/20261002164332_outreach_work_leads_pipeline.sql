-- Outreach Work Leads: turn private/subcontractor/service work into executable outreach.
create table if not exists public.outreach_work_leads (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  source_key text not null,
  external_id text not null,
  source_label text not null,
  buyer_name text not null,
  opportunity_title text not null,
  opportunity_type text not null default 'service_request'
    check (opportunity_type in (
      'subcontractor_call','subcontractor_network','service_request',
      'maintenance','renovation','vendor_network','private_tender','other'
    )),
  response_mode text not null default 'direct_outreach'
    check (response_mode in ('direct_outreach','subcontractor_application','vendor_registration','formal_bid')),
  description text,
  region text,
  source_url text not null,
  contact_name text,
  contact_email text,
  contact_phone text,
  published_at timestamptz,
  deadline_at timestamptz,
  service_fit text[] not null default '{}'::text[],
  fit_score numeric not null default 0 check (fit_score between 0 and 100),
  speed_score numeric not null default 0 check (speed_score between 0 and 100),
  conversion_score numeric not null default 0 check (conversion_score between 0 and 100),
  status text not null default 'new'
    check (status in ('new','promoted','watch','dismissed','expired')),
  matched_organization_id uuid references public.organizations(id) on delete set null,
  outreach_target_id uuid references public.outreach_targets(id) on delete set null,
  pursuit_id uuid references public.outreach_pursuits(id) on delete set null,
  raw_payload jsonb not null default '{}'::jsonb,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  promoted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(workspace_id,source_key,external_id)
);

create index if not exists outreach_work_leads_inbox_idx
  on public.outreach_work_leads(workspace_id,status,conversion_score desc,deadline_at);
create index if not exists outreach_work_leads_org_idx
  on public.outreach_work_leads(workspace_id,matched_organization_id);
create index if not exists outreach_work_leads_target_idx
  on public.outreach_work_leads(workspace_id,outreach_target_id);

alter table public.outreach_work_leads enable row level security;
drop policy if exists outreach_work_leads_member_select on public.outreach_work_leads;
drop policy if exists outreach_work_leads_sales_insert on public.outreach_work_leads;
drop policy if exists outreach_work_leads_sales_update on public.outreach_work_leads;

create policy outreach_work_leads_member_select
on public.outreach_work_leads for select to authenticated
using (private.is_workspace_member(workspace_id));

create policy outreach_work_leads_sales_insert
on public.outreach_work_leads for insert to authenticated
with check (
  private.has_workspace_role(
    workspace_id,
    array['owner','administrator','sales_manager','sales_rep']::public.membership_role[]
  )
);

create policy outreach_work_leads_sales_update
on public.outreach_work_leads for update to authenticated
using (
  private.has_workspace_role(
    workspace_id,
    array['owner','administrator','sales_manager','sales_rep']::public.membership_role[]
  )
)
with check (
  private.has_workspace_role(
    workspace_id,
    array['owner','administrator','sales_manager','sales_rep']::public.membership_role[]
  )
);

grant select,insert,update on public.outreach_work_leads to authenticated;

create or replace view public.v_outreach_work_lead_inbox
with (security_invoker=true) as
select
  l.*,
  case
    when l.status='promoted' then 'in_outreach'
    when l.status in ('dismissed','expired') then 'archive'
    when l.deadline_at is not null and l.deadline_at < now() then 'archive'
    when l.conversion_score >= 78
      and (nullif(l.contact_email,'') is not null or nullif(l.contact_phone,'') is not null)
      then 'contact_now'
    when l.conversion_score >= 68 then 'research_contact'
    when l.conversion_score >= 52 then 'review'
    else 'watch'
  end as inbox_bucket,
  case
    when l.status='promoted' then 'Continue from the linked outreach pursuit'
    when l.deadline_at is not null and l.deadline_at < now() then 'Archive expired work lead'
    when nullif(l.contact_phone,'') is not null
      then 'Call ' || l.buyer_name || ' about ' || l.opportunity_title || ' and ask for the scope, site walk, or quote path.'
    when nullif(l.contact_email,'') is not null
      then 'Email ' || l.buyer_name || ' about ' || l.opportunity_title || ' and ask for the scope, site walk, or quote path.'
    else 'Find the operations, project, or estimating contact at ' || l.buyer_name || ' and make a direct approach about ' || l.opportunity_title || '.'
  end as recommended_next_action
from public.outreach_work_leads l
where l.status <> 'expired';

grant select on public.v_outreach_work_lead_inbox to authenticated;

create or replace function private.promote_outreach_work_lead_core(p_lead_id uuid)
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
    returning id,pursuit_id into v_target,v_pursuit;
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
  on conflict(workspace_id,outreach_target_id,missing_role) do update set
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

revoke all on function private.promote_outreach_work_lead_core(uuid) from public,anon;
grant execute on function private.promote_outreach_work_lead_core(uuid) to authenticated,service_role;

create or replace function public.promote_outreach_work_lead(p_lead_id uuid)
returns table(outreach_target_id uuid,pursuit_id uuid,organization_id uuid)
language sql security invoker set search_path=''
as $$ select * from private.promote_outreach_work_lead_core(p_lead_id); $$;
revoke all on function public.promote_outreach_work_lead(uuid) from public,anon;
grant execute on function public.promote_outreach_work_lead(uuid) to authenticated;

create or replace function private.route_outreach_work_leads(p_workspace uuid,p_limit integer default 20)
returns table(promoted integer,considered integer)
language plpgsql security definer set search_path=''
as $$
declare r record; v_promoted integer:=0; v_considered integer:=0;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then raise exception 'service role required'; end if;

  update public.outreach_work_leads set status='expired',updated_at=now()
  where workspace_id=p_workspace and status in ('new','watch')
    and deadline_at is not null and deadline_at < now();

  for r in
    select id from public.outreach_work_leads
    where workspace_id=p_workspace and status in ('new','watch')
      and conversion_score >= 68 and (deadline_at is null or deadline_at >= now())
    order by conversion_score desc,deadline_at nulls last,last_seen_at desc
    limit greatest(1,least(coalesce(p_limit,20),50))
  loop
    v_considered:=v_considered+1;
    begin
      perform private.promote_outreach_work_lead_core(r.id);
      v_promoted:=v_promoted+1;
    exception when others then
      update public.outreach_work_leads
      set raw_payload=coalesce(raw_payload,'{}'::jsonb) ||
          jsonb_build_object('route_error',sqlerrm,'route_error_at',now()),updated_at=now()
      where id=r.id;
    end;
  end loop;
  return query select v_promoted,v_considered;
end
$$;

revoke all on function private.route_outreach_work_leads(uuid,integer) from public,anon,authenticated;
grant execute on function private.route_outreach_work_leads(uuid,integer) to service_role;

create or replace function public.route_outreach_work_leads(p_workspace uuid,p_limit integer default 20)
returns table(promoted integer,considered integer)
language sql security invoker set search_path=''
as $$ select * from private.route_outreach_work_leads(p_workspace,p_limit); $$;
revoke all on function public.route_outreach_work_leads(uuid,integer) from public,anon,authenticated;
grant execute on function public.route_outreach_work_leads(uuid,integer) to service_role;

select cron.schedule(
  'cbdata-outreach-work-scout','40 11 * * *',
  $job$
    select net.http_post(
      url := 'https://nzjwhmqrsxztnpdppbub.supabase.co/functions/v1/outreach-work-scout',
      headers := jsonb_build_object(
        'Content-Type','application/json',
        'x-cbdata-cron-token',
        (select decrypted_secret from vault.decrypted_secrets where name='cbdata_procurement_scout_cron_token')
      ),
      body := '{"workspace_id":"431aa13d-3e7c-41e3-9686-e840b8ea5b7c"}'::jsonb,
      timeout_milliseconds := 180000
    );
  $job$
);

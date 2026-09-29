-- Automated contact researcher control plane.
alter table public.contact_enrichment_tasks
 add column if not exists attempt_count integer not null default 0,
 add column if not exists next_attempt_at timestamptz,
 add column if not exists last_error text,
 add column if not exists researcher_metadata jsonb not null default '{}'::jsonb;
create index if not exists contact_enrichment_tasks_due_idx on public.contact_enrichment_tasks(workspace_id,status,next_attempt_at,priority_score desc);

create or replace function public.refresh_contact_research_queue(p_workspace uuid)
returns integer language plpgsql security invoker set search_path=public,private as $$
begin
 if current_user not in ('service_role','postgres') then raise exception 'service role required'; end if;
 return private.refresh_contact_enrichment_queue(p_workspace);
end $$;
revoke all on function public.refresh_contact_research_queue(uuid) from public,anon,authenticated;
grant execute on function public.refresh_contact_research_queue(uuid) to service_role;

create or replace function public.promote_verified_contact_candidate(p_task_id uuid)
returns uuid language plpgsql security invoker set search_path=public as $$
declare e public.contact_enrichment_tasks%rowtype; v_contact uuid; v_first text; v_last text;
begin
 if current_user not in ('service_role','postgres') then raise exception 'service role required'; end if;
 select * into e from public.contact_enrichment_tasks where id=p_task_id for update;
 if not found then raise exception 'task not found'; end if;
 if e.status not in ('found','verified') or e.confidence <> 'high' or e.evidence_url is null or e.candidate_name is null then
   raise exception 'candidate is not eligible for verified promotion';
 end if;
 v_first:=split_part(trim(e.candidate_name),' ',1);
 v_last:=nullif(trim(substr(trim(e.candidate_name),length(v_first)+2)),'');
 select c.id into v_contact from public.contacts c join public.organization_contacts oc on oc.contact_id=c.id
 where oc.workspace_id=e.workspace_id and oc.organization_id=e.organization_id
 and (lower(coalesce(c.email,''))=lower(coalesce(e.candidate_email,'__none__'))
      or (lower(c.first_name)=lower(v_first) and lower(coalesce(c.last_name,''))=lower(coalesce(v_last,'')))) limit 1;
 if v_contact is null then
   insert into public.contacts(workspace_id,first_name,last_name,job_title,email,phone,status,source_url,source_label,source_confidence,source_verified_at)
   values(e.workspace_id,v_first,v_last,e.candidate_title,e.candidate_email,e.candidate_phone,'active',e.evidence_url,e.evidence_label,'high',now())
   returning id into v_contact;
   insert into public.organization_contacts(workspace_id,organization_id,contact_id,relationship_type,is_primary)
   values(e.workspace_id,e.organization_id,v_contact,e.missing_role,false) on conflict do nothing;
 else
   update public.contacts set job_title=coalesce(candidate_title,job_title),email=coalesce(candidate_email,email),phone=coalesce(candidate_phone,phone),
    source_url=e.evidence_url,source_label=e.evidence_label,source_confidence='high',source_verified_at=now(),updated_at=now()
   where id=v_contact;
 end if;
 update public.contact_enrichment_tasks set status='verified',verified_at=now(),updated_at=now() where id=e.id;
 return v_contact;
end $$;
revoke all on function public.promote_verified_contact_candidate(uuid) from public,anon,authenticated;
grant execute on function public.promote_verified_contact_candidate(uuid) to service_role;

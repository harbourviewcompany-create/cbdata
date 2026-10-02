create or replace function public.promote_verified_contact_candidate(p_task_id uuid)
returns uuid
language plpgsql
set search_path to 'public'
as $$
declare
  e public.contact_enrichment_tasks%rowtype;
  v_contact uuid;
  v_first text;
  v_last text;
begin
  if current_user not in ('service_role','postgres') then
    raise exception 'service role required';
  end if;

  select * into e
  from public.contact_enrichment_tasks
  where id=p_task_id
  for update;

  if not found then raise exception 'task not found'; end if;
  if e.status not in ('found','verified')
     or e.confidence <> 'high'
     or e.evidence_url is null
     or e.candidate_name is null then
    raise exception 'candidate is not eligible for verified promotion';
  end if;

  v_first:=split_part(trim(e.candidate_name),' ',1);
  v_last:=nullif(trim(substr(trim(e.candidate_name),length(v_first)+2)),'');

  select c.id into v_contact
  from public.contacts c
  join public.organization_contacts oc on oc.contact_id=c.id
  where oc.workspace_id=e.workspace_id
    and oc.organization_id=e.organization_id
    and (
      lower(coalesce(c.email,''))=lower(coalesce(e.candidate_email,'__none__'))
      or (
        lower(c.first_name)=lower(v_first)
        and lower(coalesce(c.last_name,''))=lower(coalesce(v_last,''))
      )
    )
  limit 1;

  if v_contact is null then
    insert into public.contacts(
      workspace_id,first_name,last_name,job_title,email,phone,status,
      source_url,source_label,source_confidence,source_verified_at
    )
    values(
      e.workspace_id,v_first,v_last,e.candidate_title,e.candidate_email,e.candidate_phone,'active',
      e.evidence_url,e.evidence_label,'high',now()
    )
    returning id into v_contact;
  else
    update public.contacts
    set job_title=coalesce(e.candidate_title,job_title),
        email=coalesce(e.candidate_email,email),
        phone=coalesce(e.candidate_phone,phone),
        source_url=e.evidence_url,
        source_label=e.evidence_label,
        source_confidence='high',
        source_verified_at=now(),
        updated_at=now()
    where id=v_contact;
  end if;

  insert into public.organization_contacts(
    workspace_id,organization_id,contact_id,relationship_type,is_primary
  )
  values(
    e.workspace_id,e.organization_id,v_contact,e.missing_role,false
  )
  on conflict (organization_id,contact_id,relationship_type) do nothing;

  update public.contact_enrichment_tasks
  set status='verified',verified_at=now(),updated_at=now()
  where id=e.id;

  return v_contact;
end
$$;

revoke all on function public.promote_verified_contact_candidate(uuid) from public,anon,authenticated;
grant execute on function public.promote_verified_contact_candidate(uuid) to service_role;

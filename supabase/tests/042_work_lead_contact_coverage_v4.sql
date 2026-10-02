begin;

do $$
declare
  v_promote text;
  v_prepare text;
begin
  v_promote:=pg_get_functiondef('public.promote_verified_contact_candidate(uuid)'::regprocedure);
  v_prepare:=pg_get_functiondef('public.prepare_work_lead_draft(uuid,uuid)'::regprocedure);

  if position('e.candidate_name is null' in lower(v_promote))=0 then
    raise exception 'verified contact promotion no longer requires a named person';
  end if;

  -- Email is intentionally optional: verified phone-only contacts support call outreach
  -- without assigning shared/generic mailboxes to an individual.
  if position('e.candidate_email is null' in lower(v_promote))>0 then
    raise exception 'verified contact promotion incorrectly requires personal email';
  end if;

  if position(
    'onconflict(organization_id,contact_id,relationship_type)donothing'
    in regexp_replace(lower(v_promote),'[[:space:]]+','','g')
  )=0 then
    raise exception 'multi-role verified contact linking regressed';
  end if;

  if has_function_privilege(
    'authenticated','public.promote_verified_contact_candidate(uuid)','EXECUTE'
  ) then
    raise exception 'authenticated can execute service-only verified contact promotion';
  end if;

  if exists (
    select 1 from public.organizations
    where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
      and legal_name='Dynamic Building Improvements Inc.'
  ) and not exists (
    select 1
    from public.organization_contacts oc
    join public.organizations o on o.id=oc.organization_id
    join public.contacts c on c.id=oc.contact_id
    where o.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
      and o.legal_name='Dynamic Building Improvements Inc.'
      and c.first_name='Jon'
      and c.last_name='Black'
      and c.email is null
      and c.phone='613-746-9888'
      and c.source_confidence='high'
      and oc.relationship_type='decision_maker'
  ) then
    raise exception 'verified phone-only decision-maker path missing';
  end if;

  if exists (
    select 1 from public.organizations
    where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
      and legal_name='Dynamic Building Improvements Inc.'
  ) and not exists (
    select 1
    from public.organization_contacts oc
    join public.organizations o on o.id=oc.organization_id
    join public.contacts c on c.id=oc.contact_id
    where o.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
      and o.legal_name='Dynamic Building Improvements Inc.'
      and c.first_name='Nick'
      and c.last_name='Buchanan'
      and c.email is null
      and c.phone='613-746-9888'
      and c.source_confidence='high'
      and oc.relationship_type='operations'
  ) then
    raise exception 'verified phone-only operations path missing';
  end if;

  if position('v_channel:=''call''' in replace(lower(v_prepare),' ',''))=0
     or position('e.missing_rolein(''operations'',''procurement'')' in replace(lower(v_prepare),' ',''))=0 then
    raise exception 'phone-only Work Lead call opener routing missing';
  end if;

  if exists (
    select 1
    from public.outreach_drafts d
    left join public.contacts c on c.id=d.contact_id
    where d.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
      and d.channel='call'
      and d.evidence->>'message_version'='work_lead_conversion_v4'
      and (
        d.quality_passed is false
        or d.quality_score<70
        or c.phone is null
      )
  ) then
    raise exception 'v4 phone-only call opener failed quality or reachability guard';
  end if;

  if (
    select count(*)
    from public.organizations
    where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
      and legal_name in (
        'Dynamic Building Improvements Inc.',
        'CertaPro Painters of Ottawa',
        '613PAINTING'
      )
  )=3 and (
    select count(distinct o.legal_name)
    from public.outreach_drafts d
    join public.outreach_targets t on t.id=d.outreach_target_id
    join public.organizations o on o.id=t.organization_id
    where d.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
      and d.channel='call'
      and d.evidence->>'message_version'='work_lead_conversion_v4'
      and o.legal_name in (
        'Dynamic Building Improvements Inc.',
        'CertaPro Painters of Ottawa',
        '613PAINTING'
      )
  )<>3 then
    raise exception 'expected named call openers are missing';
  end if;

  if exists (
    select 1
    from public.organization_contacts oc
    join public.organizations o on o.id=oc.organization_id
    join public.contacts c on c.id=oc.contact_id
    where o.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
      and o.legal_name in ('CertaPro Painters of Ottawa','613PAINTING')
      and c.first_name in ('Mit','Dipkumar','Katrina','Megan')
      and c.email is not null
  ) then
    raise exception 'generic company mailbox was assigned to a named phone-only contact';
  end if;

  if exists (
    select 1
    from public.outreach_work_sources
    where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
      and source_key='certapro_ottawa_subcontractors'
  ) and not exists (
    select 1
    from public.outreach_work_sources
    where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
      and source_key='certapro_ottawa_subcontractors'
      and source_url='https://app.careerplug.com/jobs/1951264/apps/new'
  ) then
    raise exception 'CertaPro active Work Lead source URL is stale';
  end if;

end $$;

rollback;

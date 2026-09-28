-- Enrich the existing Frastell PM target from public company contact information.
-- No portfolio-size claim is inserted; doors/buildings remain null until sourced.

do $$
declare
  t record;
  v_org uuid;
  v_contact uuid;
begin
  select * into t from public.outreach_targets
  where organization_name ilike '%frastell%' order by created_at limit 1;
  if t.id is null then return; end if;

  select id into v_org from public.organizations
  where workspace_id=t.workspace_id
    and (lower(coalesce(operating_name,''))='frastell property management'
      or lower(coalesce(legal_name,''))='frastell property management inc.')
  limit 1;

  if v_org is null then
    insert into public.organizations (
      workspace_id,legal_name,operating_name,organization_type,status,
      website,phone,hq_address_line_1,hq_city,hq_province,primary_region,notes
    ) values (
      t.workspace_id,'Frastell Property Management Inc.','Frastell Property Management',
      'property_manager','active','https://www.frastell.com','416-499-3333',
      '22 St. Clair Ave E, Ste 1602','Toronto','ON','Ottawa',
      'Public company contact; Ottawa operations confirmed on Frastell staff page.'
    ) returning id into v_org;
  else
    update public.organizations set website=coalesce(website,'https://www.frastell.com'),
      phone=coalesce(phone,'416-499-3333'),primary_region=coalesce(primary_region,'Ottawa'),
      updated_at=now() where id=v_org;
  end if;

  if t.contact_id is null then
    insert into public.contacts (
      workspace_id,first_name,last_name,job_title,email,phone,status
    ) values (
      t.workspace_id,'Michael I.','Lopez','Director of Operations, New Development',
      'mlopez@frastell.com','416-499-3333','active'
    ) returning id into v_contact;

    insert into public.organization_contacts (
      workspace_id,organization_id,contact_id,relationship_type,is_primary
    ) values (t.workspace_id,v_org,v_contact,'decision_maker',true);
  else
    v_contact:=t.contact_id;
  end if;

  update public.outreach_targets set
    organization_id=v_org,contact_id=v_contact,
    organization_name='Frastell Property Management',
    contact_name=case when t.contact_id is null then 'Michael I. Lopez' else contact_name end,
    phone=coalesce(nullif(phone,''),'416-499-3333'),
    email=coalesce(nullif(email,''),'mlopez@frastell.com'),
    company_phone='416-499-3333',company_website='https://www.frastell.com',
    company_address='22 St. Clair Ave E, Ste 1602, Toronto, ON M4T 2S3',
    region=coalesce(region,'Ottawa'),
    next_action=coalesce(next_action,'Intro call — confirm Ottawa portfolio and service gaps'),
    updated_at=now()
  where id=t.id;

  update public.outreach_targets ot set
    score=public.compute_outreach_target_score(
      o.doors_managed,o.buildings_managed,ot.contact_id is not null,
      coalesce(nullif(ot.phone,''),nullif(ot.email,'')) is not null,
      lower(coalesce(ot.region,''))=lower(coalesce(o.primary_region,'')),0),
    score_reason=format(
      'doors=%s buildings=%s contact=%s coord=%s region_match=%s linked_properties=0',
      coalesce(o.doors_managed::text,'n/a'),coalesce(o.buildings_managed::text,'n/a'),
      ot.contact_id is not null,
      coalesce(nullif(ot.phone,''),nullif(ot.email,'')) is not null,
      lower(coalesce(ot.region,''))=lower(coalesce(o.primary_region,''))
    )
  from public.organizations o where ot.id=t.id and o.id=v_org;
end $$;
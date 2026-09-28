do $$
declare
  v_contact_id uuid;
begin
  select id into v_contact_id
  from public.contacts
  where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
    and lower(first_name)='raquel' and lower(last_name)='black'
  limit 1;

  if v_contact_id is null then
    insert into public.contacts (
      id, workspace_id, first_name, last_name, job_title, email, phone, phone_extension,
      status, source_url, source_label, source_confidence, source_verified_at
    ) values (
      extensions.uuid_generate_v4(),
      '431aa13d-3e7c-41e3-9686-e840b8ea5b7c',
      'Raquel','Black','Executive Director','execdir@templeisraelottawa.com','613-224-1802','4',
      'active','https://www.templeisraelottawa.ca/who-we-are.html',
      'Temple Israel of Ottawa — Who We Are','high',now()
    )
    returning id into v_contact_id;
  end if;

  insert into public.organization_contacts (
    id, workspace_id, organization_id, contact_id, relationship_type, is_primary
  )
  select extensions.uuid_generate_v4(),'431aa13d-3e7c-41e3-9686-e840b8ea5b7c',
         '2be2974b-57b5-40f1-a1ea-5f3bce7859e6',v_contact_id,'executive_administration',true
  where not exists (
    select 1 from public.organization_contacts
    where organization_id='2be2974b-57b5-40f1-a1ea-5f3bce7859e6' and contact_id=v_contact_id
  );

  update public.outreach_targets
  set contact_id=v_contact_id, contact_name='Raquel Black', phone='613-224-1802 ext. 4',
      email='execdir@templeisraelottawa.com', updated_at=now()
  where organization_name='Temple Israel of Ottawa';
end $$;
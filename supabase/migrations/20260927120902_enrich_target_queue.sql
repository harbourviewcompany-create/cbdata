alter table public.organizations
  add column if not exists hq_address_line_1 text,
  add column if not exists hq_address_line_2 text,
  add column if not exists hq_postal_code text,
  add column if not exists main_fax text;

alter table public.contacts
  add column if not exists linkedin_url text,
  add column if not exists phone_extension text;

alter table public.outreach_targets
  add column if not exists company_phone text,
  add column if not exists company_email text,
  add column if not exists company_website text,
  add column if not exists company_address text;

drop view if exists public.v_outreach_target_queue;

create view public.v_outreach_target_queue
with (security_invoker = true)
as
select
  t.id,
  t.workspace_id,
  t.outreach_list_id,
  l.name as list_name,
  t.status,
  t.score,
  t.score_reason,
  t.priority,
  coalesce(t.region, o.primary_region) as region,
  t.next_action,
  t.next_action_due_at,
  t.last_touch_at,
  t.owner_user_id,
  t.organization_id,
  coalesce(o.operating_name, o.legal_name, t.organization_name) as organization_display_name,
  o.organization_type,
  o.doors_managed,
  o.buildings_managed,
  coalesce(o.website, t.company_website) as organization_website,
  coalesce(o.phone, t.company_phone, t.phone) as organization_phone,
  coalesce(o.email, t.company_email, t.email) as organization_email,
  coalesce(o.hq_address_line_1, t.company_address, t.property_address) as organization_address,
  t.contact_id,
  coalesce(
    nullif(trim(both from coalesce(c.first_name, '') || ' ' || coalesce(c.last_name, '')), ''),
    t.contact_name
  ) as contact_display_name,
  c.job_title as contact_job_title,
  coalesce(c.phone, c.mobile, t.phone, o.phone, t.company_phone) as contact_phone,
  coalesce(c.email, t.email, o.email, t.company_email) as contact_email,
  t.converted_lead_id,
  t.notes,
  t.created_at,
  t.updated_at,
  (
    select count(*)::integer
    from public.properties p
    where p.workspace_id = t.workspace_id
      and p.management_organization_id = t.organization_id
      and p.archived_at is null
  ) as linked_property_count,
  (
    select count(*)::integer
    from public.outreach_touches ot
    where ot.outreach_target_id = t.id
  ) as touch_count
from public.outreach_targets t
left join public.outreach_lists l on l.id = t.outreach_list_id
left join public.organizations o on o.id = t.organization_id
left join public.contacts c on c.id = t.contact_id;

grant select on public.v_outreach_target_queue to authenticated;

do $$
declare
  r record;
  v_org uuid;
  v_contact uuid;
begin
  for r in
    select t.*
    from public.outreach_targets t
    where t.organization_name ilike '%nesbitt%'
  loop
    if r.organization_id is not null then
      v_org := r.organization_id;
      update public.organizations
      set
        operating_name = coalesce(nullif(operating_name, ''), 'Nesbitt Property Management'),
        legal_name = coalesce(nullif(legal_name, ''), 'Nesbitt Property Management Inc.'),
        website = coalesce(website, 'https://www.nesbittproperty.com'),
        phone = coalesce(phone, '613-744-8719'),
        hq_address_line_1 = coalesce(hq_address_line_1, '118 Noel St'),
        hq_city = coalesce(hq_city, 'Ottawa'),
        hq_province = coalesce(hq_province, 'ON'),
        hq_postal_code = coalesce(hq_postal_code, 'K1M 2A5'),
        primary_region = coalesce(primary_region, 'Ottawa'),
        main_fax = coalesce(main_fax, '613-842-0480'),
        notes = coalesce(notes, 'Residential PM. Public listing used to seed the target account.'),
        updated_at = now()
      where id = v_org;
    else
      insert into public.organizations (
        workspace_id, legal_name, operating_name, organization_type, status,
        website, phone, email,
        hq_address_line_1, hq_city, hq_province, hq_postal_code,
        primary_region, main_fax, notes
      ) values (
        r.workspace_id,
        'Nesbitt Property Management Inc.',
        'Nesbitt Property Management',
        'property_manager',
        'active',
        'https://www.nesbittproperty.com',
        '613-744-8719',
        null,
        '118 Noel St',
        'Ottawa',
        'ON',
        'K1M 2A5',
        'Ottawa',
        '613-842-0480',
        'Residential PM. Public listing used to seed the target account.'
      )
      returning id into v_org;
    end if;

    if r.contact_id is null then
      insert into public.contacts (
        workspace_id, first_name, last_name, job_title, phone, email, status
      ) values (
        r.workspace_id, 'David', 'Nesbitt', 'Property Manager',
        '613-744-8719', null, 'active'
      )
      returning id into v_contact;

      insert into public.organization_contacts (
        workspace_id, organization_id, contact_id, relationship_type, is_primary
      ) values (
        r.workspace_id, v_org, v_contact, 'property_manager', true
      );
    else
      v_contact := r.contact_id;
    end if;

    update public.outreach_targets
    set
      organization_id = v_org,
      contact_id = v_contact,
      organization_name = 'Nesbitt Property Management',
      contact_name = 'David Nesbitt',
      phone = coalesce(nullif(phone, ''), '613-744-8719'),
      company_phone = '613-744-8719',
      company_website = 'https://www.nesbittproperty.com',
      company_address = '118 Noel St, Ottawa, ON K1M 2A5',
      property_address = coalesce(property_address, '118 Noel St, Ottawa, ON K1M 2A5'),
      region = coalesce(region, 'Ottawa'),
      next_action = coalesce(next_action, 'Intro call — confirm decision maker and portfolio'),
      notes = coalesce(notes, 'Ottawa residential PM. Office 118 Noel St. Main 613-744-8719.'),
      updated_at = now()
    where id = r.id;
  end loop;
end $$;

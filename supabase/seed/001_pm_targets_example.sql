-- Example seed: one outreach list + sample PM companies for a single region.
-- Replace :workspace_id and :owner_user_id before running, or set via psql vars:
--   psql ... -v workspace_id='...' -v owner_user_id='...' -f 001_pm_targets_example.sql
--
-- This is NOT production customer data. Names are illustrative placeholders.
-- Safe to run only in a non-production workspace.

-- Example invocation with literals (edit these two UUIDs):
-- \set workspace_id '00000000-0000-0000-0000-000000000001'
-- \set owner_user_id '00000000-0000-0000-0000-000000000002'

do $$
declare
  w uuid := nullif(current_setting('app.workspace_id', true), '')::uuid;
  owner uuid := nullif(current_setting('app.owner_user_id', true), '')::uuid;
  list_id uuid;
  org_id uuid;
  contact_id uuid;
  target_id uuid;
  region text := 'Metro Vancouver';
  pm record;
  pms text[][] := array[
    array['Harbour Ridge Property Management Ltd.', 'Harbour Ridge PM', '120', '8', 'Jordan', 'Lee', 'Operations Manager', 'jordan.lee@example-pm.test', '604-555-0101'],
    array['Pacific Door Property Group Inc.', 'Pacific Door', '340', '22', 'Sam', 'Nguyen', 'Regional Manager', 'sam.nguyen@example-pm.test', '604-555-0102'],
    array['Cedar Lane Residential Management', 'Cedar Lane RM', '85', '6', 'Avery', 'Chen', 'Facilities Lead', 'avery.chen@example-pm.test', '604-555-0103'],
    array['Northshore Strata Services Ltd.', 'Northshore Strata', '210', '15', 'Riley', 'Patel', 'Account Manager', 'riley.patel@example-pm.test', '604-555-0104'],
    array['False Creek Living Management', 'False Creek Living', '55', '4', 'Casey', 'Brooks', 'Property Manager', 'casey.brooks@example-pm.test', '604-555-0105'],
    array['Burnaby Central Property Care', 'Burnaby Central', '150', '11', 'Morgan', 'Singh', 'Ops Coordinator', 'morgan.singh@example-pm.test', '604-555-0106'],
    array['Westside Unit Turnovers Inc.', 'Westside Unit', '40', '3', 'Quinn', 'Martinez', 'Owner', 'quinn.martinez@example-pm.test', '604-555-0107'],
    array['East Van Multi-Family Partners', 'East Van MFP', '500', '30', 'Taylor', 'Kim', 'Director of Ops', 'taylor.kim@example-pm.test', '604-555-0108'],
    array['Capilano Crest Management Co.', 'Capilano Crest', '95', '7', 'Jamie', 'Wong', 'Property Manager', 'jamie.wong@example-pm.test', '604-555-0109'],
    array['Fraser Belt Housing Services', 'Fraser Belt', '180', '12', 'Drew', 'Ali', 'Facilities Manager', 'drew.ali@example-pm.test', '604-555-0110'],
    array['Kitsilano Block Management', 'Kits Block', '70', '5', 'Alex', 'Brown', 'Site Lead', 'alex.brown@example-pm.test', '604-555-0111'],
    array['Richmond River Property Advisors', 'Richmond River', '260', '18', 'Parker', 'Davis', 'Regional PM', 'parker.davis@example-pm.test', '604-555-0112'],
    array['Surrey Gate Residential Ops', 'Surrey Gate', '320', '20', 'Cameron', 'Wilson', 'Operations Manager', 'cameron.wilson@example-pm.test', '604-555-0113'],
    array['Coquitlam Ridge Management Ltd.', 'Coquitlam Ridge', '110', '9', 'Harper', 'Clark', 'Account Manager', 'harper.clark@example-pm.test', '604-555-0114'],
    array['New West Heritage Property Care', 'NW Heritage', '45', '3', 'Reese', 'Lewis', 'Property Manager', 'reese.lewis@example-pm.test', '604-555-0115'],
    array['Port Moody Lakeside PM', 'Lakeside PM', '60', '4', 'Rowan', 'Young', 'Ops Lead', 'rowan.young@example-pm.test', '604-555-0116'],
    array['Delta Commons Management Group', 'Delta Commons', '140', '10', 'Finley', 'Hall', 'Facilities', 'finley.hall@example-pm.test', '604-555-0117'],
    array['Langley Prairie Property Services', 'Langley Prairie', '200', '14', 'Sawyer', 'Allen', 'Regional Manager', 'sawyer.allen@example-pm.test', '604-555-0118'],
    array['Abbotsford Valley Housing Mgmt', 'AV Housing', '175', '13', 'Blake', 'Scott', 'Property Manager', 'blake.scott@example-pm.test', '604-555-0119'],
    array['Tri-Cities Unit Ready Services', 'Tri-Cities Ready', '90', '6', 'Hayden', 'Green', 'Coordinator', 'hayden.green@example-pm.test', '604-555-0120'],
    array['Seawall Strata Professionals', 'Seawall Strata', '230', '16', 'Emerson', 'Adams', 'Account Lead', 'emerson.adams@example-pm.test', '604-555-0121'],
    array['Mountain View Rental Ops Ltd.', 'Mountain View RO', '125', '9', 'Kendall', 'Baker', 'Ops Manager', 'kendall.baker@example-pm.test', '604-555-0122'],
    array['Parkside Multi-Res Management', 'Parkside MR', '300', '19', 'Peyton', 'Nelson', 'Director', 'peyton.nelson@example-pm.test', '604-555-0123'],
    array['Harbourview Adjacent PM Group', 'HV Adjacent', '80', '5', 'Skyler', 'Carter', 'PM', 'skyler.carter@example-pm.test', '604-555-0124'],
    array['Oakridge Portfolio Services Inc.', 'Oakridge Portfolio', '400', '25', 'Dakota', 'Mitchell', 'Regional Ops', 'dakota.mitchell@example-pm.test', '604-555-0125'],
    array['Broadway Corridor Living Mgmt', 'Broadway Corridor', '160', '11', 'Phoenix', 'Perez', 'Facilities Mgr', 'phoenix.perez@example-pm.test', '604-555-0126'],
    array['Commercial Drive Housing Partners', 'Commercial Drive HP', '50', '4', 'River', 'Roberts', 'Owner-Operator', 'river.roberts@example-pm.test', '604-555-0127'],
    array['UBC Area Student Housing Ops', 'UBC Area SHO', '220', '8', 'Sage', 'Turner', 'Operations', 'sage.turner@example-pm.test', '604-555-0128'],
    array['North Van Waterfront PM Ltd.', 'NV Waterfront', '135', '10', 'Cameron', 'Phillips', 'Account Manager', 'c.phillips@example-pm.test', '604-555-0129'],
    array['South Slope Residential Care Co.', 'South Slope RC', '100', '7', 'Jamie', 'Campbell', 'Property Manager', 'j.campbell@example-pm.test', '604-555-0130']
  ];
begin
  if w is null then
    raise exception 'Set app.workspace_id: select set_config(''app.workspace_id'', ''<uuid>'', false)';
  end if;

  insert into public.outreach_lists (workspace_id, name, criteria, created_by)
  values (
    w,
    'PM – ' || region,
    jsonb_build_object('region', region, 'organization_type', 'property_manager'),
    owner
  )
  returning id into list_id;

  foreach pm slice 1 in array pms
  loop
    insert into public.organizations (
      workspace_id,
      legal_name,
      operating_name,
      organization_type,
      status,
      email,
      phone,
      doors_managed,
      buildings_managed,
      primary_region,
      hq_city,
      hq_province,
      source_notes
    ) values (
      w,
      pm[1],
      pm[2],
      'property_manager',
      'active',
      pm[8],
      pm[9],
      pm[3]::integer,
      pm[4]::integer,
      region,
      'Vancouver',
      'BC',
      'seed:001_pm_targets_example'
    )
    returning id into org_id;

    insert into public.contacts (
      workspace_id,
      first_name,
      last_name,
      job_title,
      email,
      phone,
      status
    ) values (
      w,
      pm[5],
      pm[6],
      pm[7],
      pm[8],
      pm[9],
      'active'
    )
    returning id into contact_id;

    insert into public.organization_contacts (
      workspace_id,
      organization_id,
      contact_id,
      relationship_type,
      is_primary
    ) values (
      w,
      org_id,
      contact_id,
      'decision_maker',
      true
    );

    insert into public.outreach_targets (
      workspace_id,
      outreach_list_id,
      organization_id,
      contact_id,
      organization_name,
      contact_name,
      phone,
      email,
      status,
      owner_user_id,
      region,
      next_action,
      next_action_due_at,
      priority
    ) values (
      w,
      list_id,
      org_id,
      contact_id,
      pm[2],
      pm[5] || ' ' || pm[6],
      pm[9],
      pm[8],
      'queued',
      owner,
      region,
      'Intro call – confirm decision maker and service gaps',
      now() + interval '3 days',
      'normal'
    )
    returning id into target_id;

    perform public.refresh_outreach_target_score(target_id);
  end loop;

  raise notice 'Seeded list % with % PM targets in workspace %', list_id, array_length(pms, 1), w;
end $$;

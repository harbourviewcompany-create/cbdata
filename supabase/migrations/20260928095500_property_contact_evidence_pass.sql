-- Property-level contact evidence pass
-- Sources verified 2026-09-28:
-- CHEO senior leadership: https://www.cheo.on.ca/en/about-us/senior-leadership.aspx
-- Glebe Centre Resident Handbook 2024/2025: https://glebecentre.ca/wp-content/uploads/2024/07/Resident-Handbook-June-25-2024.pdf
-- Perley Support Services: https://www.perleyhealth.ca/manager-ps-mm--l
-- Ashbury leadership / operations: https://ashbury.ca/about-us/

DO $$
DECLARE
  ws uuid := '431aa13d-3e7c-41e3-9686-e840b8ea5b7c';
  org_id uuid;
  prop_id uuid;
  contact_id uuid;
BEGIN
  -- CHEO: current senior leader with explicit Facilities, Strategic Sourcing and campus-renewal portfolio.
  SELECT id INTO org_id FROM organizations
    WHERE workspace_id=ws AND coalesce(operating_name,legal_name)='CHEO'
    LIMIT 1;
  IF org_id IS NOT NULL THEN
    SELECT id INTO contact_id FROM contacts
      WHERE workspace_id=ws AND first_name='Nathalie' AND last_name='Fauvel'
      LIMIT 1;
    IF contact_id IS NULL THEN
      INSERT INTO contacts (
        workspace_id, first_name, last_name, job_title, status,
        source_url, source_label, source_confidence, source_verified_at
      ) VALUES (
        ws, 'Nathalie', 'Fauvel',
        'Senior Vice-President of Corporate Services, Capital Programs and Chief Financial Officer',
        'active',
        'https://www.cheo.on.ca/en/about-us/senior-leadership.aspx',
        'CHEO senior leadership',
        'high', now()
      ) RETURNING id INTO contact_id;
    END IF;

    INSERT INTO organization_contacts (
      workspace_id, organization_id, contact_id, relationship_type, is_primary
    )
    SELECT ws, org_id, contact_id, 'facilities_capital_strategic_sourcing', true
    WHERE NOT EXISTS (
      SELECT 1 FROM organization_contacts
      WHERE workspace_id=ws AND organization_id=org_id AND contact_id=contact_id
    );

    SELECT property_id INTO prop_id FROM v_property_intelligence
      WHERE workspace_id=ws AND primary_customer_organization_id=org_id
      ORDER BY intelligence_score DESC NULLS LAST
      LIMIT 1;
    IF prop_id IS NOT NULL THEN
      INSERT INTO property_contacts (
        workspace_id, property_id, contact_id, relationship_type, is_primary, notes
      )
      SELECT ws, prop_id, contact_id, 'facilities_capital_strategic_sourcing', true,
        'CHEO senior leadership source explicitly assigns Facilities, Strategic Sourcing and campus renewal to this role.'
      WHERE NOT EXISTS (
        SELECT 1 FROM property_contacts
        WHERE workspace_id=ws AND property_id=prop_id AND contact_id=contact_id
      );
    END IF;

    UPDATE outreach_targets
      SET contact_id=coalesce(contact_id, contact_id),
          contact_name=coalesce(contact_name, 'Nathalie Fauvel'),
          updated_at=now()
      WHERE workspace_id=ws AND organization_id=org_id AND contact_id IS NULL;
  END IF;

  -- Glebe Centre: Director of Environmental Services is a direct operational fit for property services.
  SELECT id INTO org_id FROM organizations
    WHERE workspace_id=ws AND coalesce(operating_name,legal_name)='Glebe Centre'
    LIMIT 1;
  IF org_id IS NOT NULL THEN
    SELECT id INTO contact_id FROM contacts
      WHERE workspace_id=ws AND first_name='Rod' AND last_name='Way'
      LIMIT 1;
    IF contact_id IS NULL THEN
      INSERT INTO contacts (
        workspace_id, first_name, last_name, job_title, email, phone,
        status, source_url, source_label, source_confidence, source_verified_at
      ) VALUES (
        ws, 'Rod', 'Way', 'Director of Environmental Services',
        'rway@glebecentre.ca', '613-238-2727',
        'active',
        'https://glebecentre.ca/wp-content/uploads/2024/07/Resident-Handbook-June-25-2024.pdf',
        'Glebe Centre Resident Handbook 2024/2025',
        'high', now()
      ) RETURNING id INTO contact_id;
    END IF;

    INSERT INTO organization_contacts (
      workspace_id, organization_id, contact_id, relationship_type, is_primary
    )
    SELECT ws, org_id, contact_id, 'environmental_services', true
    WHERE NOT EXISTS (
      SELECT 1 FROM organization_contacts
      WHERE workspace_id=ws AND organization_id=org_id AND contact_id=contact_id
    );

    SELECT property_id INTO prop_id FROM v_property_intelligence
      WHERE workspace_id=ws AND primary_customer_organization_id=org_id
      ORDER BY intelligence_score DESC NULLS LAST
      LIMIT 1;
    IF prop_id IS NOT NULL THEN
      INSERT INTO property_contacts (
        workspace_id, property_id, contact_id, relationship_type, is_primary, notes
      )
      SELECT ws, prop_id, contact_id, 'environmental_services', true,
        'Current 2024/2025 Glebe Centre handbook lists this contact as Director of Environmental Services for the campus.'
      WHERE NOT EXISTS (
        SELECT 1 FROM property_contacts
        WHERE workspace_id=ws AND property_id=prop_id AND contact_id=contact_id
      );
    END IF;

    UPDATE outreach_targets
      SET contact_id=coalesce(contact_id, contact_id),
          contact_name=coalesce(contact_name, 'Rod Way'),
          phone=coalesce(phone, '613-238-2727'),
          email=coalesce(email, 'rway@glebecentre.ca'),
          updated_at=now()
      WHERE workspace_id=ws AND organization_id=org_id AND contact_id IS NULL;
  END IF;

  -- Perley: existing verified Lorie Stuckless is explicitly tied to Support Services,
  -- whose published job scope covers Property Services, Physical Plant Operations,
  -- Security, contract/commercial services administration and grounds.
  SELECT id INTO org_id FROM organizations
    WHERE workspace_id=ws AND coalesce(operating_name,legal_name)='Perley Health'
    LIMIT 1;
  IF org_id IS NOT NULL THEN
    SELECT id INTO contact_id FROM contacts
      WHERE workspace_id=ws AND first_name='Lorie' AND last_name='Stuckless'
      LIMIT 1;
    SELECT property_id INTO prop_id FROM v_property_intelligence
      WHERE workspace_id=ws AND primary_customer_organization_id=org_id
      ORDER BY intelligence_score DESC NULLS LAST
      LIMIT 1;
    IF contact_id IS NOT NULL AND prop_id IS NOT NULL THEN
      INSERT INTO property_contacts (
        workspace_id, property_id, contact_id, relationship_type, is_primary, notes
      )
      SELECT ws, prop_id, contact_id, 'support_services_property_operations', true,
        'Published Perley Support Services scope covers Property Services, Physical Plant Operations, Security, contract/commercial services administration and grounds.'
      WHERE NOT EXISTS (
        SELECT 1 FROM property_contacts
        WHERE workspace_id=ws AND property_id=prop_id AND contact_id=contact_id
      );
    END IF;
  END IF;

  -- Ashbury: existing verified Maria El-Zeghayar explicitly owns Property Management
  -- within the Director of Operations and Risk portfolio.
  SELECT id INTO org_id FROM organizations
    WHERE workspace_id=ws AND coalesce(operating_name,legal_name)='Ashbury College'
    LIMIT 1;
  IF org_id IS NOT NULL THEN
    SELECT id INTO contact_id FROM contacts
      WHERE workspace_id=ws AND first_name='Maria' AND last_name='El-Zeghayar'
      LIMIT 1;
    SELECT property_id INTO prop_id FROM v_property_intelligence
      WHERE workspace_id=ws AND primary_customer_organization_id=org_id
      ORDER BY intelligence_score DESC NULLS LAST
      LIMIT 1;
    IF contact_id IS NOT NULL AND prop_id IS NOT NULL THEN
      INSERT INTO property_contacts (
        workspace_id, property_id, contact_id, relationship_type, is_primary, notes
      )
      SELECT ws, prop_id, contact_id, 'property_management_operations_risk', true,
        'Ashbury leadership source explicitly places Property Management within this role portfolio.'
      WHERE NOT EXISTS (
        SELECT 1 FROM property_contacts
        WHERE workspace_id=ws AND property_id=prop_id AND contact_id=contact_id
      );
    END IF;
  END IF;
END $$;

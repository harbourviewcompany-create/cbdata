-- Correct CHEO organization-name normalization and attach current facilities/capital contact.
-- Source: https://www.cheo.on.ca/en/about-us/senior-leadership.aspx
DO $$
DECLARE
  ws uuid := '431aa13d-3e7c-41e3-9686-e840b8ea5b7c';
  v_org_id uuid;
  v_contact_id uuid;
  v_prop_id uuid;
BEGIN
  SELECT id INTO v_org_id FROM organizations
  WHERE workspace_id=ws AND (legal_name='CHEO' OR operating_name='Children’s Hospital of Eastern Ontario')
  LIMIT 1;

  IF v_org_id IS NOT NULL THEN
    SELECT id INTO v_contact_id FROM contacts
    WHERE workspace_id=ws AND first_name='Nathalie' AND last_name='Fauvel'
    LIMIT 1;

    IF v_contact_id IS NULL THEN
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
      ) RETURNING id INTO v_contact_id;
    END IF;

    INSERT INTO organization_contacts (
      workspace_id, organization_id, contact_id, relationship_type, is_primary
    )
    SELECT ws, v_org_id, v_contact_id, 'facilities_capital_strategic_sourcing', true
    WHERE NOT EXISTS (
      SELECT 1 FROM organization_contacts oc
      WHERE oc.workspace_id=ws AND oc.organization_id=v_org_id AND oc.contact_id=v_contact_id
    );

    SELECT property_id INTO v_prop_id FROM v_property_intelligence
    WHERE workspace_id=ws AND primary_customer_organization_id=v_org_id
    ORDER BY intelligence_score DESC NULLS LAST
    LIMIT 1;

    IF v_prop_id IS NOT NULL THEN
      INSERT INTO property_contacts (
        workspace_id, property_id, contact_id, relationship_type, is_primary, notes
      )
      SELECT ws, v_prop_id, v_contact_id, 'facilities_capital_strategic_sourcing', true,
        'CHEO senior leadership source explicitly assigns Facilities, Strategic Sourcing and campus renewal to this role.'
      WHERE NOT EXISTS (
        SELECT 1 FROM property_contacts pc
        WHERE pc.workspace_id=ws AND pc.property_id=v_prop_id AND pc.contact_id=v_contact_id
      );
    END IF;

    UPDATE outreach_targets ot
    SET contact_id=v_contact_id,
        contact_name='Nathalie Fauvel',
        updated_at=now()
    WHERE ot.workspace_id=ws AND ot.organization_id=v_org_id AND ot.contact_id IS NULL;
  END IF;
END $$;

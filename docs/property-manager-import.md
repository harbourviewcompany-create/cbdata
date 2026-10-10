# Ottawa property-manager outreach — safe reconciliation

This is a **staging utility**, not a live Gmail/Supabase synchronization. It prepares the locally held Ottawa prospect, property, and Gmail-draft records for review before any workspace-scoped database import.

## Run locally

Export your private workbook to a local JSON file with this shape (never commit the file):

    {
      "companies": [{"id":"PC-001","company":"Example Management","email":"info@example.ca","phone":"","priority":"P2","source_url":"","verification":""}],
      "drafts": [{"company":"Example Management","email":"info@example.ca","subject":"Repairs","stage":"Drafted","gmail_draft_url":"https://mail.google.com/mail/u/0/#drafts/example"}],
      "properties": [{"property":"Example Building","manager":"Example Management","location":"Ottawa","source_url":""}]
    }

Then run:

    node scripts/property-manager-reconcile.mjs --input PRIVATE.json --output PRIVATE_OUT
    node --test tests/property-manager-reconcile.test.mjs

Outputs: accounts.csv, gmail_draft_ledger.csv, properties.csv, manual_review.csv, summary.json, and staging.json. Treat all outputs as private business data. Do not push them to the public repository.

## Guardrails

- Read-only against Gmail, Supabase and CBData: **no messages sent, no database changes**.
- Gmail **drafted does not mean contacted**; preserve prior sent-mail history independently.
- Every record begins with consent_status=unassessed and send_eligible=NO. A published email is not a blanket right to send marketing email.
- Similar company names are not auto-merged. Conflicting names, reused recipient addresses, and invalid draft URLs require review.
- Published properties are not treated as open jobs.
- On hold means no duplicate outreach until account ownership and previous contact history are reconciled.
- Before any real import, run a dry-run comparison scoped to the active workspace. Review account keys, contact provenance, vendor/anti-spam requirements, suppressions, reply history, and upsert conflicts.
- Do not store private contact lists or Gmail draft message links as repository fixtures.

## Live activation blocker (observed October 10, 2026)

Supabase reported that the existing CBData project was INACTIVE. Its restore call was rejected because the free-tier allowance already has two active projects (Harbourview Platform Recovery and Council). Neither was paused; no paid project was created. The live database remains unchanged. The importer should not be wired to an automatic job until the existing project is reactivated and migration/test parity is checked.

Once active, reconcile with the current CBData canonical \`organizations\`, \`contacts\`, \`outreach_targets\`, \`outreach_pursuits\`, \`outreach_drafts\` and opportunity pipeline. Review consent and suppression data before enabling sends; do not equate a Gmail draft with a CBData approved/sent draft.

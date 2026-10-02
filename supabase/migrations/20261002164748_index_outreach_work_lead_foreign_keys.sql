create index if not exists outreach_work_leads_matched_org_fk_idx
  on public.outreach_work_leads(matched_organization_id);
create index if not exists outreach_work_leads_target_fk_idx
  on public.outreach_work_leads(outreach_target_id);
create index if not exists outreach_work_leads_pursuit_fk_idx
  on public.outreach_work_leads(pursuit_id);

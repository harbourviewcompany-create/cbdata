begin;

do $$
declare
  v_view text;
  v_direct text;
  v_verified text;
begin
  if to_regclass('public.outreach_work_leads') is null then
    raise exception 'outreach_work_leads missing';
  end if;
  if to_regclass('public.v_outreach_work_lead_inbox') is null then
    raise exception 'work lead inbox view missing';
  end if;
  if to_regprocedure('public.prepare_direct_work_lead_draft(uuid)') is null then
    raise exception 'direct work lead draft helper missing';
  end if;
  if to_regprocedure('public.prepare_work_lead_draft(uuid,uuid)') is null then
    raise exception 'verified-contact work lead draft helper missing';
  end if;

  v_view:=pg_get_viewdef('public.v_outreach_execution_queue'::regclass,true);
  if position('signal_service_rollup' in v_view)=0
     or position('service_fit' in v_view)=0 then
    raise exception 'signal service fit is not carried into outreach execution queue';
  end if;

  if position('service_fit[1]' in pg_get_functiondef(
    'public.generate_outreach_draft(uuid,text,text)'::regprocedure
  ))=0 then
    raise exception 'draft generator does not use opportunity signal service fit';
  end if;

  v_direct:=pg_get_functiondef('public.prepare_direct_work_lead_draft(uuid)'::regprocedure);
  if position('signal_confidence' in v_direct)=0
     or position('contact_confidence' in v_direct)=0
     or position('manual_review_required' in v_direct)=0
     or position('auto_send' in v_direct)=0 then
    raise exception 'direct work lead drafts are missing canonical evidence/manual-review controls';
  end if;

  v_verified:=pg_get_functiondef('public.prepare_work_lead_draft(uuid,uuid)'::regprocedure);
  if position('source_confidence' in v_verified)=0
     or position('manual_review_required' in v_verified)=0
     or position('auto_send' in v_verified)=0 then
    raise exception 'verified-contact work lead drafts are missing evidence/manual-review controls';
  end if;

  if has_function_privilege(
    'authenticated','public.prepare_direct_work_lead_draft(uuid)','EXECUTE'
  ) then
    raise exception 'authenticated can execute service-only direct work lead draft helper';
  end if;
  if has_function_privilege(
    'authenticated','public.prepare_work_lead_draft(uuid,uuid)','EXECUTE'
  ) then
    raise exception 'authenticated can execute service-only verified work lead draft helper';
  end if;

  if not exists (
    select 1
    from pg_trigger
    where tgrelid='public.outreach_work_leads'::regclass
      and tgname='trg_sync_work_lead_organization_source'
      and not tgisinternal
  ) then
    raise exception 'work lead source-to-organization trigger missing';
  end if;

  if not exists (
    select 1 from cron.job
    where jobname='cbdata-outreach-work-scout' and active
  ) then
    raise exception 'work lead scout cron missing or inactive';
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='public'
      and tablename='outreach_work_leads'
      and policyname='outreach_work_leads_member_select'
  ) then
    raise exception 'work lead select RLS missing';
  end if;

  if exists (
    select 1
    from public.outreach_drafts
    where strategy in ('work_lead_direct','work_lead_trigger')
      and state in ('draft','approved')
      and (
        quality_passed is false
        or quality_score < 70
        or coalesce(evidence->>'auto_send','false')='true'
      )
  ) then
    raise exception 'active work lead draft failed quality/manual-send guard';
  end if;
end $$;

rollback;

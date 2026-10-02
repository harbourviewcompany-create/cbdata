begin;

do $$
declare
  v_direct text;
  v_verified text;
begin
  if to_regprocedure('public.prepare_direct_work_lead_draft(uuid)') is null then
    raise exception 'direct Work Lead draft helper missing';
  end if;
  if to_regprocedure('public.prepare_work_lead_draft(uuid,uuid)') is null then
    raise exception 'verified-contact Work Lead draft helper missing';
  end if;

  v_direct:=pg_get_functiondef('public.prepare_direct_work_lead_draft(uuid)'::regprocedure);
  v_verified:=pg_get_functiondef('public.prepare_work_lead_draft(uuid,uuid)'::regprocedure);

  if position('work_lead_conversion_v3' in v_direct)=0 then
    raise exception 'direct Work Lead copy version missing';
  end if;
  if position('signal_confidence' in v_direct)=0
     or position('contact_confidence' in v_direct)=0 then
    raise exception 'direct Work Lead canonical evidence missing';
  end if;
  if position('work_lead_conversion_v3' in v_verified)=0 then
    raise exception 'verified Work Lead copy version missing';
  end if;
  if position('signal_confidence' in v_verified)=0
     or position('contact_confidence' in v_verified)=0 then
    raise exception 'verified Work Lead canonical evidence missing';
  end if;

  if has_function_privilege(
    'authenticated','public.prepare_direct_work_lead_draft(uuid)','EXECUTE'
  ) then
    raise exception 'authenticated can execute direct Work Lead helper';
  end if;
  if has_function_privilege(
    'authenticated','public.prepare_work_lead_draft(uuid,uuid)','EXECUTE'
  ) then
    raise exception 'authenticated can execute verified Work Lead helper';
  end if;

  if exists (
    select 1
    from public.outreach_drafts
    where strategy in ('work_lead_direct','work_lead_trigger')
      and state in ('draft','approved')
      and (
        quality_passed is false
        or quality_score < 70
        or coalesce(quality_notes->>'auto_send','false')='true'
      )
  ) then
    raise exception 'active Work Lead draft failed quality/manual-review guard';
  end if;

  if exists (
    select 1
    from public.outreach_drafts
    where strategy='work_lead_direct'
      and state='draft'
      and coalesce(evidence->>'message_version','')='work_lead_conversion_v3'
      and (
        nullif(evidence->>'signal','') is null
        or coalesce(evidence->>'signal_confidence','')<>'high'
        or nullif(evidence->>'contact_source','') is null
      )
  ) then
    raise exception 'v3 direct draft evidence is incomplete';
  end if;
end $$;

rollback;

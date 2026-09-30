begin;

do $$
declare
  c record;
begin
  if to_regclass('public.outreach_pursuits') is null then
    raise exception 'outreach_pursuits missing';
  end if;
  if to_regclass('public.outreach_pursuit_contacts') is null then
    raise exception 'outreach_pursuit_contacts missing';
  end if;
  if to_regclass('public.outreach_suppressions') is null then
    raise exception 'outreach_suppressions missing';
  end if;

  if to_regclass('public.v_outreach_reply_inbox') is null then
    raise exception 'reply inbox view missing';
  end if;
  if to_regclass('public.v_outreach_pursuit_queue') is null then
    raise exception 'canonical pursuit queue missing';
  end if;
  if to_regclass('public.v_outreach_timeline') is null then
    raise exception 'outreach timeline missing';
  end if;
  if to_regclass('public.v_outreach_score_breakdown') is null then
    raise exception 'score breakdown missing';
  end if;
  if to_regclass('public.v_outreach_sequence_safety') is null then
    raise exception 'sequence safety view missing';
  end if;
  if to_regclass('public.v_outreach_conversion_analytics') is null then
    raise exception 'conversion analytics view missing';
  end if;

  if to_regprocedure('public.ingest_outreach_reply(uuid,text,text,text,text,text,text,date,text,jsonb)') is null then
    raise exception 'reply ingestion rpc missing';
  end if;
  if to_regprocedure('public.handle_outreach_reply(uuid,text,boolean)') is null then
    raise exception 'reply handling rpc missing';
  end if;
  if to_regprocedure('public.ensure_outreach_opportunity(uuid,uuid,numeric)') is null then
    raise exception 'outreach opportunity rpc missing';
  end if;
  if to_regprocedure('public.link_estimate_to_outreach_pursuit(uuid,uuid)') is null then
    raise exception 'estimate linkage rpc missing';
  end if;
  if to_regprocedure('public.run_safe_due_sequences(uuid,integer)') is null then
    raise exception 'safe sequence executor missing';
  end if;
  if to_regprocedure('public.queue_contact_research_task(uuid)') is null then
    raise exception 'contact research queue rpc missing';
  end if;
  if to_regprocedure('public.accept_contact_research_candidate(uuid)') is null then
    raise exception 'contact research accept rpc missing';
  end if;
  if to_regprocedure('public.get_outreach_pursuit_command_queue(integer)') is null then
    raise exception 'canonical command queue rpc missing';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='outreach_enrollments'
      and column_name='paused_reason'
  ) then
    raise exception 'sequence pause metadata missing';
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='outreach_drafts'
      and column_name='quality_score'
  ) then
    raise exception 'draft quality score missing';
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='outreach_replies'
      and column_name='needs_response'
  ) then
    raise exception 'reply inbox state missing';
  end if;

  select * into c from public.classify_outreach_reply_text('Could you send pricing and a quote for this property?');
  if c.classification <> 'request_quote' or c.confidence < 0.90 then
    raise exception 'quote reply classifier regression';
  end if;

  select * into c from public.classify_outreach_reply_text('Please remove me from your list and do not contact me again.');
  if c.classification <> 'unsubscribe' then
    raise exception 'unsubscribe classifier regression';
  end if;

  select * into c from public.classify_outreach_reply_text('Delivery Status Notification: mailbox unavailable 550');
  if c.classification <> 'bounce' then
    raise exception 'bounce classifier regression';
  end if;

  select * into c from public.classify_outreach_reply_text('I am not the right person. Please contact Sarah in facilities.');
  if c.classification not in ('wrong_person','referral') then
    raise exception 'routing classifier regression';
  end if;

  if not has_function_privilege('authenticated','public.ingest_outreach_reply(uuid,text,text,text,text,text,text,date,text,jsonb)','EXECUTE') then
    raise exception 'authenticated cannot ingest replies';
  end if;
  if not has_function_privilege('authenticated','public.run_safe_due_sequences(uuid,integer)','EXECUTE') then
    raise exception 'authenticated cannot run safe sequences';
  end if;
  if not has_function_privilege('authenticated','public.queue_contact_research_task(uuid)','EXECUTE') then
    raise exception 'authenticated cannot queue contact research';
  end if;
end $$;

rollback;

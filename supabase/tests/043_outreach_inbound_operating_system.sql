begin;

do $$
declare
  fn text;
  cls record;
begin
  if to_regclass('public.outreach_sync_state') is null then raise exception 'outreach sync state missing'; end if;
  if to_regclass('public.outreach_referral_candidates') is null then raise exception 'referral candidates missing'; end if;
  if to_regclass('public.v_outreach_needs_review') is null then raise exception 'needs-review view missing'; end if;
  if to_regclass('public.v_outreach_inbound_health') is null then raise exception 'inbound health view missing'; end if;
  if to_regclass('public.v_outreach_reply_command_center') is null then raise exception 'reply command center missing'; end if;

  if to_regprocedure('public.find_outreach_reply_targets_v2(uuid,text,text,text,text[],text)') is null then
    raise exception 'header-aware reply matcher missing';
  end if;
  if to_regprocedure('public.register_outreach_inbound_event_system(uuid,text,text,text,text,text,text,timestamptz,text,text[],text,boolean,jsonb)') is null then
    raise exception 'provider-neutral inbound registration RPC missing';
  end if;
  if to_regprocedure('public.record_outreach_inbound_failure_system(uuid,text)') is null then
    raise exception 'dead-letter failure recorder missing';
  end if;
  if to_regprocedure('public.promote_outreach_referral_candidate(uuid,text,text,text)') is null then
    raise exception 'referral promotion RPC missing';
  end if;

  if has_function_privilege('authenticated','public.register_outreach_inbound_event_system(uuid,text,text,text,text,text,text,timestamptz,text,text[],text,boolean,jsonb)','EXECUTE') then
    raise exception 'authenticated must not execute system inbound registration';
  end if;
  if not has_function_privilege('service_role','public.register_outreach_inbound_event_system(uuid,text,text,text,text,text,text,timestamptz,text,text[],text,boolean,jsonb)','EXECUTE') then
    raise exception 'service role cannot register provider inbound events';
  end if;

  select * into cls from public.classify_outreach_reply_text(
    'Please register on our subcontractor list to receive bid documents.'
  );
  if cls.classification<>'vendor_registration' or cls.confidence<0.90 then
    raise exception 'vendor registration intent is not classified correctly';
  end if;

  select pg_get_functiondef('public.find_outreach_reply_targets_v2(uuid,text,text,text,text[],text)'::regprocedure) into fn;
  if position('130' in fn)=0 or position('in_reply_to' in fn)=0 or position('references' in fn)=0 then
    raise exception 'message-header priority matching missing';
  end if;

  if not exists(
    select 1 from information_schema.columns
    where table_schema='public' and table_name='outreach_inbound_events' and column_name='is_test'
  ) then raise exception 'test-traffic isolation missing'; end if;
  if not exists(
    select 1 from information_schema.columns
    where table_schema='public' and table_name='outreach_inbound_events' and column_name='failure_count'
  ) then raise exception 'dead-letter retry state missing'; end if;
end $$;

rollback;

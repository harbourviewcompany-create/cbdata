begin;

do $$
declare
  fn text;
begin
  if to_regclass('public.outreach_inbound_events') is null then
    raise exception 'outreach_inbound_events missing';
  end if;
  if to_regprocedure('public.find_outreach_reply_targets(uuid,text,text)') is null then
    raise exception 'automatic reply target resolver missing';
  end if;
  if to_regprocedure('public.ingest_outreach_reply_system(uuid,uuid,text,text,text,text,text,text,text,timestamptz,jsonb)') is null then
    raise exception 'service reply ingestion rpc missing';
  end if;
  if to_regprocedure('public.resolve_outreach_inbound_event(uuid,uuid)') is null then
    raise exception 'operator inbound event resolver missing';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='outreach_replies' and column_name='sender_email'
  ) then raise exception 'reply sender email missing'; end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='outreach_replies' and column_name='subject'
  ) then raise exception 'reply subject missing'; end if;

  if has_function_privilege('authenticated',
    'public.ingest_outreach_reply_system(uuid,uuid,text,text,text,text,text,text,text,timestamptz,jsonb)',
    'EXECUTE'
  ) then raise exception 'authenticated must not execute service ingestion'; end if;

  if not has_function_privilege('service_role',
    'public.ingest_outreach_reply_system(uuid,uuid,text,text,text,text,text,text,text,timestamptz,jsonb)',
    'EXECUTE'
  ) then raise exception 'service role cannot ingest provider replies'; end if;

  if not has_function_privilege('authenticated',
    'public.resolve_outreach_inbound_event(uuid,uuid)',
    'EXECUTE'
  ) then raise exception 'sales users cannot resolve unmatched inbound events'; end if;

  select pg_get_functiondef(
    'public.ensure_outreach_opportunity(uuid,uuid,numeric)'::regprocedure
  ) into fn;
  if position('0.55' in fn)=0 or position('0.45' in fn)=0 or position('0.30' in fn)=0 then
    raise exception 'outreach opportunity probability still uses percent values instead of 0..1';
  end if;

  select pg_get_functiondef('public.sync_outreach_opportunity_from_estimate()'::regprocedure) into fn;
  if position('probability=1.0' in replace(fn,' ',''))=0 then
    raise exception 'accepted estimate must set probability to 1.0';
  end if;

  if not exists (
    select 1 from pg_trigger
    where tgname='trg_pause_outreach_pursuit_sequences_on_reply'
      and not tgisinternal
  ) then raise exception 'pursuit-wide reply pause trigger missing'; end if;
end $$;

rollback;

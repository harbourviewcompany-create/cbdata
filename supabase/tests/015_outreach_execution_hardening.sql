-- Outreach hardening regression checks.
do $$
declare
  v_def text;
  v_count int;
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema='public'
      and table_name='outreach_replies'
      and column_name='channel'
  ) then
    raise exception 'outreach_replies.channel missing';
  end if;

  if not exists (
    select 1
    from pg_trigger
    where tgrelid='public.outreach_drafts'::regclass
      and tgname='trg_outreach_draft_evidence_provenance'
      and not tgisinternal
  ) then
    raise exception 'outreach draft evidence provenance trigger missing';
  end if;

  select pg_get_functiondef('public.approve_outreach_draft(uuid)'::regprocedure)
    into v_def;
  if position('d.state <> ''draft''' in v_def)=0 then
    raise exception 'approve_outreach_draft does not enforce draft -> approved';
  end if;

  select pg_get_functiondef('public.mark_outreach_draft_sent(uuid,text,text,text)'::regprocedure)
    into v_def;
  if position('d.state <> ''approved''' in v_def)=0 then
    raise exception 'mark_outreach_draft_sent does not enforce approved -> sent';
  end if;

  select count(*) into v_count
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and p.proname='classify_outreach_reply'
    and pg_get_function_identity_arguments(p.oid) =
      'p_target_id uuid, p_classification text, p_summary text, p_channel text, p_renewal_date date, p_referred_contact text, p_provider text, p_provider_message_id text, p_provider_thread_id text';
  if v_count <> 1 then
    raise exception 'channel-aware classify_outreach_reply signature missing';
  end if;

  select pg_get_functiondef('public.normalize_outreach_draft_evidence()'::regprocedure)
    into v_def;
  if position('generated_from_verified_data' in v_def)=0
     or position('evidence_level' in v_def)=0 then
    raise exception 'evidence provenance normalization incomplete';
  end if;
end $$;

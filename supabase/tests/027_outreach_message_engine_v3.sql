begin;
do $$
begin
 if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='outreach_drafts' and column_name='strategy') then raise exception 'strategy missing'; end if;
 if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='outreach_drafts' and column_name='quality_passed') then raise exception 'quality gate missing'; end if;
 if to_regclass('public.v_outreach_message_learning') is null then raise exception 'learning view missing'; end if;
 if to_regprocedure('public.generate_outreach_draft(uuid,text,text)') is null then raise exception 'draft generator missing'; end if;
end $$;
rollback;
begin;
do $$ begin
 if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='v_outreach_command_queue' and column_name='command_mode') then raise exception 'command mode missing'; end if;
 if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='v_outreach_command_queue' and column_name='named_person') then raise exception 'named-person quality missing'; end if;
 if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='v_outreach_command_queue' and column_name='generic_inbox') then raise exception 'generic inbox quality missing'; end if;
end $$;
rollback;
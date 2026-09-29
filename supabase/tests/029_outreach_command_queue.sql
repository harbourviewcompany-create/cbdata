begin;
do $$ begin
 if to_regclass('public.v_outreach_command_queue') is null then raise exception 'command queue view missing'; end if;
 if to_regprocedure('public.get_daily_outreach_command_queue(integer)') is null then raise exception 'command queue rpc missing'; end if;
 if not has_function_privilege('authenticated','public.get_daily_outreach_command_queue(integer)','EXECUTE') then raise exception 'command queue rpc unavailable'; end if;
end $$;
rollback;
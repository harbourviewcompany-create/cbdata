begin;
do $$
begin
 if to_regclass('public.v_outreach_adaptive_next_touch') is null then raise exception 'adaptive next touch view missing'; end if;
 if to_regprocedure('public.generate_adaptive_followup(uuid,text)') is null then raise exception 'adaptive followup generator missing'; end if;
 if not has_function_privilege('authenticated','public.generate_adaptive_followup(uuid,text)','EXECUTE') then raise exception 'adaptive followup unavailable'; end if;
end $$;
rollback;
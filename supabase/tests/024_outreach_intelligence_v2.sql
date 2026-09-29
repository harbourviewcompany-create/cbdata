begin;
do $$
begin
 if to_regclass('public.v_outreach_buying_committee') is null then raise exception 'buying committee view missing'; end if;
 if to_regclass('public.v_outreach_contact_coverage') is null then raise exception 'contact coverage view missing'; end if;
 if to_regprocedure('public.select_outreach_contact(uuid)') is null then raise exception 'contact selector missing'; end if;
 if to_regprocedure('public.generate_outreach_draft(uuid,text,text)') is null then raise exception 'draft generator missing'; end if;
end $$;
rollback;
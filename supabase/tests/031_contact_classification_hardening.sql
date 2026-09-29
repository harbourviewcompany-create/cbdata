begin;
do $$ begin
 if public.is_named_outreach_person('Jami Omar administration') then raise exception 'administration route classified as person'; end if;
 if public.is_named_outreach_person('OCDSB Facilities Department') then raise exception 'department classified as person'; end if;
 if public.is_named_outreach_person('Extendicare facilities / procurement routing') then raise exception 'routing label classified as person'; end if;
 if not public.is_named_outreach_person('Michael Morin') then raise exception 'valid person rejected'; end if;
 if not public.is_named_outreach_person('Joanne H. Graham') then raise exception 'valid middle initial person rejected'; end if;
 if to_regprocedure('private.queue_route_contacts_for_research(uuid)') is null then raise exception 'research queue bridge missing'; end if;
end $$;
rollback;
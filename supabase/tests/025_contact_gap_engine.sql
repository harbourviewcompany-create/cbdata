begin;
do $$
begin
 if to_regclass('public.contact_enrichment_tasks') is null then raise exception 'contact enrichment tasks missing'; end if;
 if to_regclass('public.v_contact_enrichment_queue') is null then raise exception 'contact enrichment queue missing'; end if;
 if to_regprocedure('private.refresh_contact_enrichment_queue(uuid)') is null then raise exception 'contact enrichment refresh missing'; end if;
 if has_function_privilege('authenticated','private.refresh_contact_enrichment_queue(uuid)','EXECUTE') then raise exception 'internal enrichment refresh exposed'; end if;
end $$;
rollback;
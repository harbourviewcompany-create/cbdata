begin;

do $$
declare
  rid uuid;
  blocked boolean := false;
  bid_gaps integer;
begin
  select id into rid from public.supplier_registrations where source_key='canadabuys' limit 1;
  if rid is null then raise exception 'CanadaBuys registration row missing'; end if;

  if not exists (
    select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname='v_supplier_registration_readiness'
      and coalesce(c.reloptions,'{}'::text[]) @> array['security_invoker=true']
  ) then raise exception 'v_supplier_registration_readiness must use security_invoker'; end if;

  if (select count(*) from public.supplier_registration_steps where supplier_registration_id=rid) < 9 then
    raise exception 'CanadaBuys registration checklist incomplete';
  end if;

  select bid_gap_count into bid_gaps from public.v_supplier_registration_readiness where supplier_registration_id=rid;
  if coalesce(bid_gaps,0) < 1 then raise exception 'Expected unresolved CanadaBuys bid-readiness gaps'; end if;

  begin
    update public.supplier_registrations set status='active' where id=rid;
  exception when others then
    blocked := true;
  end;
  if not blocked then raise exception 'Incomplete CanadaBuys registration was incorrectly allowed active'; end if;

  if not exists (
    select 1 from public.supplier_registration_steps
    where supplier_registration_id=rid and step_key='account_access' and status='blocked'
  ) then raise exception 'Authentication blocker is not represented'; end if;

  raise notice 'Supplier registration operating system verification passed';
end $$;

rollback;

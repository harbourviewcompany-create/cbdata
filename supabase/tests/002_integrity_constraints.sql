-- Negative/positive constraint tests. Uses a transaction so no fixture data persists.
begin;
do $$
declare
  ws uuid := uuid_generate_v4();
  org uuid := uuid_generate_v4();
  prop uuid := uuid_generate_v4();
  con uuid := uuid_generate_v4();
begin
  insert into public.workspaces(id,name,slug) values(ws,'CBData Test Workspace','cbdata-test-'||replace(ws::text,'-',''));
  insert into public.organizations(id,workspace_id,legal_name,organization_type) values(org,ws,'Test Org','customer');
  insert into public.properties(id,workspace_id,name,address_line_1,city,property_type) values(prop,ws,'Test Property','1 Test Street','Ottawa','commercial');

  begin
    insert into public.contracts(id,workspace_id,contract_number,organization_id,property_id,name,start_date,end_date,contract_value)
    values(con,ws,'TEST-INVALID',org,prop,'Invalid',date '2026-10-01',date '2026-09-01',100);
    raise exception 'Expected contract date constraint did not fire';
  exception when check_violation then null; end;

  begin
    insert into public.work_orders(id,workspace_id,work_order_number,property_id,description,scheduled_start,scheduled_end)
    values(uuid_generate_v4(),ws,'TEST-INVALID-WO',prop,'Invalid',now(),now()-interval '1 hour');
    raise exception 'Expected work-order date constraint did not fire';
  exception when check_violation then null; end;

  raise notice 'CBData integrity constraint tests passed';
end $$;
rollback;

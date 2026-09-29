CREATE OR REPLACE FUNCTION private.select_material_price_plan(p_request_id uuid, p_plan_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_workspace_id uuid;
  v_delivery_mode text;
  v_plan public.material_price_plans%rowtype;
  v_latest_run uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select r.workspace_id,r.delivery_mode
  into v_workspace_id,v_delivery_mode
  from public.material_requests r
  where r.id=p_request_id
  for update;

  if v_workspace_id is null or not private.has_workspace_role(
    v_workspace_id,
    array['owner','administrator','operations_manager','sales_manager','sales_rep']::public.membership_role[]
  ) then
    raise exception 'Material request unavailable';
  end if;

  select pr.id into v_latest_run
  from public.material_price_runs pr
  where pr.workspace_id=v_workspace_id
    and pr.request_id=p_request_id
    and pr.status in ('completed','partial')
  order by pr.started_at desc
  limit 1;

  select p.* into v_plan
  from public.material_price_plans p
  where p.id=p_plan_id
    and p.workspace_id=v_workspace_id
    and p.request_id=p_request_id
    and p.run_id=v_latest_run;

  if not found then
    raise exception 'Plan must belong to the latest completed pricing run';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(v_plan.lines) line
    where coalesce((line->>'stale')::boolean,false)
  ) then
    raise exception 'Stale price evidence must be refreshed before approval';
  end if;

  if v_delivery_mode='delivery' and exists (
    select 1
    from jsonb_array_elements(v_plan.suppliers) supplier
    where coalesce((supplier->>'delivery_verified')::boolean,false)=false
  ) then
    raise exception 'Verify delivery fees before approving a delivery plan';
  end if;

  perform set_config('app.material_request_transition','approve',true);

  update public.material_price_plans
  set is_selected=(id=p_plan_id)
  where workspace_id=v_workspace_id
    and request_id=p_request_id
    and (is_selected or id=p_plan_id);

  update public.material_requests
  set status='approved',updated_at=now()
  where workspace_id=v_workspace_id and id=p_request_id;
end;
$function$;

revoke all on function private.select_material_price_plan(uuid,uuid) from public, anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.select_material_price_plan(uuid,uuid) to authenticated;

CREATE OR REPLACE FUNCTION public.select_material_price_plan(p_request_id uuid, p_plan_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO ''
AS $function$
BEGIN
  PERFORM private.select_material_price_plan(p_request_id,p_plan_id);
END;
$function$;

revoke all on function public.select_material_price_plan(uuid,uuid) from public, anon, authenticated;
grant execute on function public.select_material_price_plan(uuid,uuid) to authenticated;

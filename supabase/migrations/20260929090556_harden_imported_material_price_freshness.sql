create or replace function private.select_material_price_plan(p_request_id uuid, p_plan_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_workspace_id uuid;
  v_delivery_mode text;
  v_request_status text;
  v_plan public.material_price_plans%rowtype;
  v_latest_run uuid;
  v_today date := (now() at time zone 'America/Toronto')::date;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select r.workspace_id,r.delivery_mode,r.status
  into v_workspace_id,v_delivery_mode,v_request_status
  from public.material_requests r
  where r.id=p_request_id
  for update;

  if v_workspace_id is null or not private.has_workspace_role(
    v_workspace_id,
    array['owner','administrator','operations_manager','sales_manager','sales_rep']::public.membership_role[]
  ) then
    raise exception 'Material request unavailable';
  end if;

  if v_request_status not in ('priced','approved') then
    raise exception 'Reprice this material request before approving a plan';
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
    left join public.material_price_observations o
      on o.id=(line->>'observation_id')::uuid
    where o.id is null
       or o.workspace_id<>v_workspace_id
       or (
         o.source_type in ('live_page','import')
         and o.observed_at < now() - interval '7 days'
       )
       or (
         o.source_type='manual_quote'
         and (
           (o.valid_until is not null and o.valid_until < v_today)
           or (o.valid_until is null and o.observed_at < now() - interval '30 days')
         )
       )
  ) then
    raise exception 'Current price evidence is missing or expired; refresh pricing before approval';
  end if;

  if v_delivery_mode='delivery' and exists (
    select 1
    from jsonb_array_elements(v_plan.suppliers) supplier_json
    left join public.material_suppliers s
      on s.id=(supplier_json->>'id')::uuid
     and s.workspace_id=v_workspace_id
    left join public.material_request_supplier_terms t
      on t.workspace_id=v_workspace_id
     and t.request_id=p_request_id
     and t.supplier_id=s.id
    where s.id is null
       or not (
         (
           t.delivery_verified
           and t.delivery_fee is not null
           and (t.valid_until is null or t.valid_until >= v_today)
         )
         or s.default_delivery_fee is not null
       )
  ) then
    raise exception 'Current verified delivery terms are required before approving a delivery plan';
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

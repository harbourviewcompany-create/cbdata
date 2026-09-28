-- Create a draft and its lines in one transaction. Apply before shipping the UI.
create or replace function public.create_deck_estimate_draft(
  p_workspace_id uuid,
  p_organization_id uuid,
  p_property_id uuid,
  p_valid_until date,
  p_items jsonb
) returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_id uuid;
  v_item jsonb;
  v_description text;
  v_price numeric;
  v_material numeric;
  v_labor numeric;
  v_subtotal numeric := 0;
  v_direct numeric := 0;
  v_index integer := 0;
begin
  if auth.uid() is null or not exists (
    select 1 from public.workspace_memberships m
    where m.workspace_id = p_workspace_id and m.user_id = auth.uid()
      and m.status = 'active'
      and m.role in ('owner', 'administrator', 'sales_manager', 'sales_rep')
  ) then
    raise exception 'Not authorized to create an estimate';
  end if;

  if not exists (
    select 1 from public.organizations o
    where o.id = p_organization_id and o.workspace_id = p_workspace_id
  ) then
    raise exception 'Customer is not in this workspace';
  end if;
  if p_property_id is not null and not exists (
    select 1 from public.properties p
    where p.id = p_property_id and p.workspace_id = p_workspace_id
      and (p.primary_customer_organization_id is null
           or p.primary_customer_organization_id = p_organization_id)
  ) then
    raise exception 'Property does not belong to this customer';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array'
      or jsonb_array_length(p_items) < 1 or jsonb_array_length(p_items) > 20 then
    raise exception 'An estimate needs 1 to 20 line items';
  end if;

  insert into public.estimates (
    workspace_id, organization_id, property_id, estimate_number,
    status, valid_until, created_by
  ) values (
    p_workspace_id, p_organization_id, p_property_id,
    'DECK-' || to_char(now() at time zone 'America/Toronto', 'YYYYMMDD') || '-'
      || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10)),
    'draft', p_valid_until, auth.uid()
  ) returning id into v_id;

  for v_item in select value from jsonb_array_elements(p_items) loop
    v_description := btrim(v_item->>'description');
    if v_description is null or length(v_description) < 3 or length(v_description) > 1000 then
      raise exception 'Invalid line description';
    end if;
    if (v_item->>'price') !~ '^[0-9]{1,7}(\.[0-9]{1,2})?$'
       or (v_item->>'material_cost') !~ '^[0-9]{1,7}(\.[0-9]{1,2})?$'
       or (v_item->>'labor_cost') !~ '^[0-9]{1,7}(\.[0-9]{1,2})?$' then
      raise exception 'Invalid line amount';
    end if;
    v_price := (v_item->>'price')::numeric;
    v_material := (v_item->>'material_cost')::numeric;
    v_labor := (v_item->>'labor_cost')::numeric;
    v_subtotal := v_subtotal + v_price;
    v_direct := v_direct + v_material + v_labor;
    if v_material + v_labor > v_price then
      raise exception 'Direct costs cannot exceed the estimate price';
    end if;

    insert into public.estimate_items (
      workspace_id, estimate_id, description, quantity, unit, unit_price,
      line_total, estimated_material_cost, estimated_labor_cost, sort_order
    ) values (
      p_workspace_id, v_id, v_description, 1, 'lot', v_price,
      v_price, v_material, v_labor, v_index
    );
    v_index := v_index + 1;
  end loop;

  if v_subtotal <= 0 then raise exception 'Estimate total must be positive'; end if;
  update public.estimates set
    subtotal = v_subtotal,
    tax = round(v_subtotal * 0.13, 2),
    total = v_subtotal + round(v_subtotal * 0.13, 2),
    estimated_direct_cost = v_direct,
    estimated_gross_profit = v_subtotal - v_direct,
    estimated_margin = round((v_subtotal - v_direct) / v_subtotal * 100, 2)
  where id = v_id;
  return v_id;
end;
$$;

revoke all on function public.create_deck_estimate_draft(uuid, uuid, uuid, date, jsonb) from public, anon;
grant execute on function public.create_deck_estimate_draft(uuid, uuid, uuid, date, jsonb) to authenticated;

-- A measured site visit can revise the draft without leaving mismatched totals.
grant delete on public.estimate_items to authenticated;
create policy deck_estimate_draft_delete on public.estimate_items for delete to authenticated
using (
  exists (
    select 1 from public.estimates e
    join public.workspace_memberships m on m.workspace_id = e.workspace_id
    where e.id = estimate_items.estimate_id and e.workspace_id = estimate_items.workspace_id
      and e.status = 'draft' and m.user_id = (select auth.uid())
      and m.status = 'active'
      and m.role in ('owner', 'administrator', 'sales_manager', 'sales_rep')
  )
);

create or replace function public.update_deck_estimate_draft(
  p_estimate_id uuid,
  p_valid_until date,
  p_items jsonb
) returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_workspace_id uuid;
  v_item jsonb;
  v_description text;
  v_price numeric;
  v_material numeric;
  v_labor numeric;
  v_subtotal numeric := 0;
  v_direct numeric := 0;
  v_index integer := 0;
begin
  select e.workspace_id into v_workspace_id from public.estimates e
    where e.id = p_estimate_id and e.status = 'draft' for update;
  if v_workspace_id is null or auth.uid() is null or not exists (
    select 1 from public.workspace_memberships m
    where m.workspace_id = v_workspace_id and m.user_id = auth.uid()
      and m.status = 'active'
      and m.role in ('owner', 'administrator', 'sales_manager', 'sales_rep')
  ) then
    raise exception 'Draft estimate unavailable';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array'
      or jsonb_array_length(p_items) < 1 or jsonb_array_length(p_items) > 20 then
    raise exception 'An estimate needs 1 to 20 line items';
  end if;
  delete from public.estimate_items where estimate_id = p_estimate_id and workspace_id = v_workspace_id;
  for v_item in select value from jsonb_array_elements(p_items) loop
    v_description := btrim(v_item->>'description');
    if v_description is null or length(v_description) < 3 or length(v_description) > 1000 then
      raise exception 'Invalid line description';
    end if;
    if (v_item->>'price') !~ '^[0-9]{1,7}(\.[0-9]{1,2})?$'
       or (v_item->>'material_cost') !~ '^[0-9]{1,7}(\.[0-9]{1,2})?$'
       or (v_item->>'labor_cost') !~ '^[0-9]{1,7}(\.[0-9]{1,2})?$' then
      raise exception 'Invalid line amount';
    end if;
    v_price := (v_item->>'price')::numeric;
    v_material := (v_item->>'material_cost')::numeric;
    v_labor := (v_item->>'labor_cost')::numeric;
    if v_material + v_labor > v_price then
      raise exception 'Direct cost exceeds line price';
    end if;
    insert into public.estimate_items (
      workspace_id, estimate_id, description, quantity, unit, unit_price,
      line_total, estimated_material_cost, estimated_labor_cost, sort_order
    ) values (
      v_workspace_id, p_estimate_id, v_description, 1, 'lot', v_price,
      v_price, v_material, v_labor, v_index
    );
    v_subtotal := v_subtotal + v_price;
    v_direct := v_direct + v_material + v_labor;
    v_index := v_index + 1;
  end loop;
  if v_subtotal <= 0 then raise exception 'Estimate total must be positive'; end if;
  update public.estimates set
    valid_until = p_valid_until,
    subtotal = v_subtotal,
    tax = round(v_subtotal * 0.13, 2),
    total = v_subtotal + round(v_subtotal * 0.13, 2),
    estimated_direct_cost = v_direct,
    estimated_gross_profit = v_subtotal - v_direct,
    estimated_margin = round((v_subtotal - v_direct) / v_subtotal * 100, 2)
  where id = p_estimate_id;
end;
$$;

revoke all on function public.update_deck_estimate_draft(uuid, date, jsonb) from public, anon;
grant execute on function public.update_deck_estimate_draft(uuid, date, jsonb) to authenticated;

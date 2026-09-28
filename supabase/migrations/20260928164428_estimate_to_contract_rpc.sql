alter table public.contracts
  add column if not exists source_estimate_id uuid references public.estimates(id) on delete set null;

create unique index if not exists contracts_source_estimate_id_uidx
  on public.contracts(source_estimate_id);

create or replace function public.convert_estimate_to_contract(p_estimate_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  e public.estimates%rowtype;
  new_contract_id uuid;
  existing_contract_id uuid;
  item_count integer;
  missing_service_count integer;
begin
  select *
  into e
  from public.estimates
  where id = p_estimate_id;

  if not found then
    raise exception 'Estimate not found';
  end if;

  select id
  into existing_contract_id
  from public.contracts
  where source_estimate_id = e.id
  limit 1;

  if existing_contract_id is not null then
    return existing_contract_id;
  end if;

  if e.property_id is null then
    raise exception 'Estimate must have a property before conversion';
  end if;

  select count(*),
         count(*) filter (where service_definition_id is null)
  into item_count, missing_service_count
  from public.estimate_items
  where estimate_id = e.id;

  if item_count = 0 then
    raise exception 'Estimate must have at least one line item before conversion';
  end if;

  if missing_service_count > 0 then
    raise exception 'Every estimate line item must have a service definition before conversion';
  end if;

  insert into public.contracts (
    workspace_id,
    contract_number,
    organization_id,
    property_id,
    opportunity_id,
    name,
    status,
    start_date,
    contract_value,
    source_estimate_id
  )
  values (
    e.workspace_id,
    'CTR-' || e.estimate_number,
    e.organization_id,
    e.property_id,
    e.opportunity_id,
    'Contract ' || e.estimate_number,
    'draft',
    coalesce(e.estimated_start_date, current_date),
    e.total,
    e.id
  )
  returning id into new_contract_id;

  insert into public.contract_services (
    workspace_id,
    contract_id,
    service_definition_id,
    scope_description,
    pricing_model,
    contract_price,
    quantity,
    unit,
    start_date
  )
  select
    i.workspace_id,
    new_contract_id,
    i.service_definition_id,
    i.description,
    'fixed',
    i.line_total,
    i.quantity,
    i.unit,
    coalesce(e.estimated_start_date, current_date)
  from public.estimate_items i
  where i.estimate_id = e.id
  order by i.sort_order, i.created_at;

  return new_contract_id;
exception
  when unique_violation then
    select id
    into existing_contract_id
    from public.contracts
    where source_estimate_id = p_estimate_id
    limit 1;

    if existing_contract_id is not null then
      return existing_contract_id;
    end if;

    raise;
end;
$$;

revoke all on function public.convert_estimate_to_contract(uuid) from public;
grant execute on function public.convert_estimate_to_contract(uuid) to authenticated;
grant execute on function public.convert_estimate_to_contract(uuid) to service_role;

-- Deck estimate workflow v2.
-- Adds auditable site verification, atomic lifecycle transitions, contract conversion,
-- consistent estimate totals, and sales-scoped write access.

alter table public.estimates
  add column if not exists sent_at timestamptz,
  add column if not exists accepted_at timestamptz,
  add column if not exists rejected_at timestamptz,
  add column if not exists estimate_kind text not null default 'general',
  add column if not exists site_verified_at timestamptz,
  add column if not exists site_verified_by uuid,
  add column if not exists site_verification_notes text;

alter table public.estimates
  drop constraint if exists estimates_estimate_kind_check;
alter table public.estimates
  add constraint estimates_estimate_kind_check
  check (estimate_kind in ('general','deck'));

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.estimates'::regclass
      and conname='estimates_site_verified_by_fkey'
  ) then
    alter table public.estimates
      add constraint estimates_site_verified_by_fkey
      foreign key (site_verified_by) references auth.users(id) on delete set null;
  end if;
end $$;

alter table public.contracts
  add column if not exists source_estimate_id uuid;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.contracts'::regclass
      and conname='contracts_source_estimate_id_fkey'
  ) then
    alter table public.contracts
      add constraint contracts_source_estimate_id_fkey
      foreign key (source_estimate_id) references public.estimates(id) on delete set null;
  end if;
end $$;

create unique index if not exists contracts_source_estimate_uidx
  on public.contracts(source_estimate_id)
  where source_estimate_id is not null;
create index if not exists idx_estimates_site_verified_by
  on public.estimates(site_verified_by);

create or replace function private.recalculate_estimate_totals(p_estimate_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_subtotal numeric := 0;
  v_direct numeric := 0;
begin
  select
    coalesce(sum(i.line_total),0),
    coalesce(sum(
      i.estimated_material_cost
      + i.estimated_labor_cost
      + i.estimated_equipment_cost
      + i.estimated_subcontractor_cost
    ),0)
  into v_subtotal, v_direct
  from public.estimate_items i
  where i.estimate_id=p_estimate_id;

  update public.estimates
  set subtotal=v_subtotal,
      tax=round(v_subtotal * 0.13, 2),
      total=v_subtotal + round(v_subtotal * 0.13, 2),
      estimated_direct_cost=v_direct,
      estimated_gross_profit=v_subtotal-v_direct,
      estimated_margin=case when v_subtotal>0 then round((v_subtotal-v_direct)/v_subtotal*100,2) else 0 end,
      updated_at=now()
  where id=p_estimate_id;
end;
$$;

revoke all on function private.recalculate_estimate_totals(uuid) from public, anon, authenticated;

create or replace function private.sync_estimate_totals()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if tg_op='DELETE' then
    perform private.recalculate_estimate_totals(old.estimate_id);
    return old;
  end if;

  if tg_op='UPDATE' and old.estimate_id is distinct from new.estimate_id then
    perform private.recalculate_estimate_totals(old.estimate_id);
  end if;
  perform private.recalculate_estimate_totals(new.estimate_id);
  return new;
end;
$$;

revoke all on function private.sync_estimate_totals() from public, anon, authenticated;

drop trigger if exists sync_estimate_totals on public.estimate_items;
create trigger sync_estimate_totals
after insert or update or delete on public.estimate_items
for each row execute function private.sync_estimate_totals();

-- Estimate rows remain readable to workspace members, but writes are sales-scoped.
drop policy if exists workspace_member_select on public.estimates;
drop policy if exists workspace_member_insert on public.estimates;
drop policy if exists workspace_member_update on public.estimates;
drop policy if exists estimate_sales_insert on public.estimates;
drop policy if exists estimate_sales_update on public.estimates;

create policy workspace_member_select on public.estimates
for select to authenticated
using (private.is_workspace_member(workspace_id));

create policy estimate_sales_insert on public.estimates
for insert to authenticated
with check (
  private.has_workspace_role(
    workspace_id,
    array['owner','administrator','sales_manager','sales_rep']::public.membership_role[]
  )
);

create policy estimate_sales_update on public.estimates
for update to authenticated
using (
  private.has_workspace_role(
    workspace_id,
    array['owner','administrator','sales_manager','sales_rep']::public.membership_role[]
  )
)
with check (
  private.has_workspace_role(
    workspace_id,
    array['owner','administrator','sales_manager','sales_rep']::public.membership_role[]
  )
);

drop policy if exists workspace_member_select on public.estimate_items;
drop policy if exists workspace_member_insert on public.estimate_items;
drop policy if exists workspace_member_update on public.estimate_items;
drop policy if exists deck_estimate_draft_delete on public.estimate_items;
drop policy if exists estimate_item_sales_insert on public.estimate_items;
drop policy if exists estimate_item_sales_update on public.estimate_items;
drop policy if exists estimate_item_sales_delete on public.estimate_items;

create policy workspace_member_select on public.estimate_items
for select to authenticated
using (private.is_workspace_member(workspace_id));

create policy estimate_item_sales_insert on public.estimate_items
for insert to authenticated
with check (
  private.has_workspace_role(
    workspace_id,
    array['owner','administrator','sales_manager','sales_rep']::public.membership_role[]
  )
  and exists (
    select 1 from public.estimates e
    where e.id=estimate_id and e.workspace_id=workspace_id and e.status='draft'
  )
);

create policy estimate_item_sales_update on public.estimate_items
for update to authenticated
using (
  private.has_workspace_role(
    workspace_id,
    array['owner','administrator','sales_manager','sales_rep']::public.membership_role[]
  )
  and exists (
    select 1 from public.estimates e
    where e.id=estimate_id and e.workspace_id=workspace_id and e.status='draft'
  )
)
with check (
  private.has_workspace_role(
    workspace_id,
    array['owner','administrator','sales_manager','sales_rep']::public.membership_role[]
  )
  and exists (
    select 1 from public.estimates e
    where e.id=estimate_id and e.workspace_id=workspace_id and e.status='draft'
  )
);

create policy estimate_item_sales_delete on public.estimate_items
for delete to authenticated
using (
  private.has_workspace_role(
    workspace_id,
    array['owner','administrator','sales_manager','sales_rep']::public.membership_role[]
  )
  and exists (
    select 1 from public.estimates e
    where e.id=estimate_id and e.workspace_id=workspace_id and e.status='draft'
  )
);

revoke all on public.estimates from anon;
revoke delete, truncate, references, trigger on public.estimates from authenticated;
grant select, insert, update on public.estimates to authenticated;

revoke all on public.estimate_items from anon;
revoke truncate, references, trigger on public.estimate_items from authenticated;
grant select, insert, update, delete on public.estimate_items to authenticated;

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
  v_index integer := 0;
begin
  if auth.uid() is null or not private.has_workspace_role(
    p_workspace_id,
    array['owner','administrator','sales_manager','sales_rep']::public.membership_role[]
  ) then
    raise exception 'Not authorized to create an estimate';
  end if;

  if p_valid_until is null or p_valid_until < current_date then
    raise exception 'Quote expiry cannot be in the past';
  end if;

  if not exists (
    select 1 from public.organizations o
    where o.id=p_organization_id and o.workspace_id=p_workspace_id
  ) then
    raise exception 'Customer is not in this workspace';
  end if;

  if p_property_id is not null and not exists (
    select 1 from public.properties p
    where p.id=p_property_id and p.workspace_id=p_workspace_id
      and (p.primary_customer_organization_id is null
        or p.primary_customer_organization_id=p_organization_id)
  ) then
    raise exception 'Property does not belong to this customer';
  end if;

  if p_items is null or jsonb_typeof(p_items)<>'array'
    or jsonb_array_length(p_items)<1 or jsonb_array_length(p_items)>20 then
    raise exception 'An estimate needs 1 to 20 line items';
  end if;

  insert into public.estimates (
    workspace_id, organization_id, property_id, estimate_number,
    estimate_kind, status, valid_until, created_by
  ) values (
    p_workspace_id, p_organization_id, p_property_id,
    'DECK-' || to_char(now() at time zone 'America/Toronto','YYYYMMDD') || '-'
      || upper(substr(replace(extensions.uuid_generate_v4()::text,'-',''),1,10)),
    'deck','draft',p_valid_until,auth.uid()
  ) returning id into v_id;

  for v_item in select value from jsonb_array_elements(p_items) loop
    v_description := btrim(v_item->>'description');
    if v_description is null or length(v_description)<3 or length(v_description)>1000 then
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
    if v_material+v_labor>v_price then
      raise exception 'Direct costs cannot exceed the estimate price';
    end if;

    insert into public.estimate_items (
      workspace_id, estimate_id, description, quantity, unit, unit_price,
      line_total, estimated_material_cost, estimated_labor_cost, sort_order
    ) values (
      p_workspace_id,v_id,v_description,1,'lot',v_price,
      v_price,v_material,v_labor,v_index
    );
    v_index := v_index+1;
  end loop;

  if not exists (select 1 from public.estimate_items where estimate_id=v_id and line_total>0) then
    raise exception 'Estimate total must be positive';
  end if;

  return v_id;
end;
$$;

revoke all on function public.create_deck_estimate_draft(uuid,uuid,uuid,date,jsonb) from public, anon;
grant execute on function public.create_deck_estimate_draft(uuid,uuid,uuid,date,jsonb) to authenticated;

create or replace function public.update_deck_estimate_draft(
  p_estimate_id uuid,
  p_property_id uuid,
  p_valid_until date,
  p_items jsonb
) returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_workspace_id uuid;
  v_organization_id uuid;
  v_item jsonb;
  v_description text;
  v_price numeric;
  v_material numeric;
  v_labor numeric;
  v_index integer := 0;
begin
  select e.workspace_id, e.organization_id
  into v_workspace_id, v_organization_id
  from public.estimates e
  where e.id=p_estimate_id and e.status='draft' and e.estimate_kind='deck'
  for update;

  if v_workspace_id is null or auth.uid() is null or not private.has_workspace_role(
    v_workspace_id,
    array['owner','administrator','sales_manager','sales_rep']::public.membership_role[]
  ) then
    raise exception 'Draft deck estimate unavailable';
  end if;

  if p_property_id is not null and not exists (
    select 1 from public.properties p
    where p.id=p_property_id and p.workspace_id=v_workspace_id
      and (p.primary_customer_organization_id is null
        or p.primary_customer_organization_id=v_organization_id)
  ) then
    raise exception 'Property does not belong to this customer';
  end if;

  if p_valid_until is null or p_valid_until < current_date then
    raise exception 'Quote expiry cannot be in the past';
  end if;

  if p_items is null or jsonb_typeof(p_items)<>'array'
    or jsonb_array_length(p_items)<1 or jsonb_array_length(p_items)>20 then
    raise exception 'An estimate needs 1 to 20 line items';
  end if;

  delete from public.estimate_items
  where estimate_id=p_estimate_id and workspace_id=v_workspace_id;

  for v_item in select value from jsonb_array_elements(p_items) loop
    v_description := btrim(v_item->>'description');
    if v_description is null or length(v_description)<3 or length(v_description)>1000 then
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
    if v_material+v_labor>v_price then
      raise exception 'Direct cost exceeds line price';
    end if;

    insert into public.estimate_items (
      workspace_id, estimate_id, description, quantity, unit, unit_price,
      line_total, estimated_material_cost, estimated_labor_cost, sort_order
    ) values (
      v_workspace_id,p_estimate_id,v_description,1,'lot',v_price,
      v_price,v_material,v_labor,v_index
    );
    v_index := v_index+1;
  end loop;

  if not exists (
    select 1 from public.estimate_items
    where estimate_id=p_estimate_id and line_total>0
  ) then
    raise exception 'Estimate total must be positive';
  end if;

  update public.estimates
  set property_id=p_property_id,
      valid_until=p_valid_until,
      site_verified_at=null,
      site_verified_by=null,
      site_verification_notes=null,
      updated_at=now()
  where id=p_estimate_id;

end;
$$;

drop function if exists public.update_deck_estimate_draft(uuid,date,jsonb);
revoke all on function public.update_deck_estimate_draft(uuid,uuid,date,jsonb) from public, anon;
grant execute on function public.update_deck_estimate_draft(uuid,uuid,date,jsonb) to authenticated;

create or replace function public.advance_estimate(
  p_estimate_id uuid,
  p_action text,
  p_site_confirmed boolean default false,
  p_site_notes text default null
) returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_estimate public.estimates%rowtype;
begin
  select * into v_estimate
  from public.estimates
  where id=p_estimate_id
  for update;

  if not found or auth.uid() is null or not private.has_workspace_role(
    v_estimate.workspace_id,
    array['owner','administrator','sales_manager','sales_rep']::public.membership_role[]
  ) then
    raise exception 'Estimate unavailable';
  end if;

  if p_site_notes is not null and length(p_site_notes)>1000 then
    raise exception 'Site verification notes are too long';
  end if;

  if p_action='sent' then
    if v_estimate.status<>'draft' then raise exception 'Only a draft can be sent'; end if;
    if v_estimate.valid_until is null or v_estimate.valid_until<current_date then
      raise exception 'Revise the quote expiry before sending';
    end if;
    if not p_site_confirmed then raise exception 'Site verification is required'; end if;
    if v_estimate.subtotal<=0 then raise exception 'Estimate total must be positive'; end if;

    update public.estimates
    set status='sent',
        site_verified_at=now(),
        site_verified_by=auth.uid(),
        site_verification_notes=nullif(btrim(p_site_notes),''),
        sent_at=now(),
        updated_at=now()
    where id=p_estimate_id;

  elsif p_action='accepted' then
    if v_estimate.status<>'sent' then raise exception 'Only a sent estimate can be accepted'; end if;
    if v_estimate.site_verified_at is null then raise exception 'Site verification is missing'; end if;
    if v_estimate.valid_until is not null and v_estimate.valid_until<current_date then
      raise exception 'Expired estimates must be revised before acceptance';
    end if;

    update public.estimates
    set status='accepted', accepted_at=now(), updated_at=now()
    where id=p_estimate_id;

  elsif p_action='rejected' then
    if v_estimate.status<>'sent' then raise exception 'Only a sent estimate can be rejected'; end if;

    update public.estimates
    set status='rejected', rejected_at=now(), updated_at=now()
    where id=p_estimate_id;
  else
    raise exception 'Invalid estimate action';
  end if;
end;
$$;

revoke all on function public.advance_estimate(uuid,text,boolean,text) from public, anon;
grant execute on function public.advance_estimate(uuid,text,boolean,text) to authenticated;

create or replace function public.convert_estimate_to_contract(p_estimate_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_estimate public.estimates%rowtype;
  v_contract_id uuid;
begin
  select * into v_estimate
  from public.estimates
  where id=p_estimate_id
  for update;

  if not found or auth.uid() is null or not private.has_workspace_role(
    v_estimate.workspace_id,
    array['owner','administrator','sales_manager']::public.membership_role[]
  ) then
    raise exception 'Estimate unavailable';
  end if;

  if v_estimate.status<>'accepted' then
    raise exception 'Only accepted estimates can become contracts';
  end if;
  if v_estimate.property_id is null then
    raise exception 'Link a property before converting this estimate';
  end if;

  select id into v_contract_id
  from public.contracts
  where source_estimate_id=p_estimate_id
  limit 1;
  if v_contract_id is not null then
    return v_contract_id;
  end if;

  insert into public.contracts (
    workspace_id, contract_number, organization_id, property_id,
    opportunity_id, name, status, start_date, contract_value, source_estimate_id
  ) values (
    v_estimate.workspace_id,
    'CTR-' || to_char(now() at time zone 'America/Toronto','YYYYMMDD') || '-'
      || upper(substr(replace(extensions.uuid_generate_v4()::text,'-',''),1,10)),
    v_estimate.organization_id,
    v_estimate.property_id,
    v_estimate.opportunity_id,
    case when v_estimate.estimate_kind='deck'
      then 'Deck project — ' || v_estimate.estimate_number
      else 'Estimate conversion — ' || v_estimate.estimate_number
    end,
    'draft',
    coalesce(v_estimate.estimated_start_date,current_date),
    v_estimate.subtotal,
    p_estimate_id
  )
  returning id into v_contract_id;

  return v_contract_id;
end;
$$;

revoke all on function public.convert_estimate_to_contract(uuid) from public, anon;
grant execute on function public.convert_estimate_to_contract(uuid) to authenticated;

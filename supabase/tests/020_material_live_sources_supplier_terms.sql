begin;

do $$
declare
  w uuid;
  live_count int;
  view_cols int;
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='material_price_observations' and column_name='valid_until'
  ) then
    raise exception 'material price observation valid_until missing';
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid='public.material_price_observations'::regclass
      and conname='material_price_observations_valid_until_check'
      and pg_get_constraintdef(oid) ilike '%America/Toronto%'
  ) then
    raise exception 'material quote expiry constraint must use Ottawa local date';
  end if;

  if not exists (
    select 1 from information_schema.tables
    where table_schema='public' and table_name='material_request_supplier_terms'
  ) then
    raise exception 'material_request_supplier_terms missing';
  end if;

  if not exists (
    select 1 from pg_class c
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public'
      and c.relname='material_request_supplier_terms'
      and c.relrowsecurity
      and c.relforcerowsecurity
  ) then
    raise exception 'supplier terms RLS/FORCE RLS missing';
  end if;

  if (
    select count(*)
    from pg_policies
    where schemaname='public'
      and tablename='material_request_supplier_terms'
      and policyname in (
        'workspace_member_select',
        'workspace_material_operator_insert',
        'workspace_material_operator_update',
        'workspace_material_operator_delete'
      )
  ) <> 4 then
    raise exception 'supplier terms policies incomplete';
  end if;

  if has_table_privilege('anon','public.material_request_supplier_terms','SELECT')
     or has_table_privilege('anon','public.material_request_supplier_terms','INSERT')
     or has_table_privilege('anon','public.material_request_supplier_terms','UPDATE')
     or has_table_privilege('anon','public.material_request_supplier_terms','DELETE') then
    raise exception 'anon can access supplier terms';
  end if;

  if not exists (
    select 1 from pg_trigger
    where tgrelid='public.material_request_supplier_terms'::regclass
      and tgname='guard_material_request_supplier_terms'
      and not tgisinternal
  ) then
    raise exception 'supplier terms integrity trigger missing';
  end if;

  if not exists (
    select 1 from pg_trigger
    where tgrelid='public.material_request_supplier_terms'::regclass
      and tgname='invalidate_material_request_pricing'
      and not tgisinternal
  ) then
    raise exception 'supplier terms pricing invalidation trigger missing';
  end if;

  if not exists (
    select 1 from pg_trigger
    where tgrelid='public.material_requests'::regclass
      and tgname='a_invalidate_material_request_inputs'
      and not tgisinternal
  ) then
    raise exception 'material request input invalidation trigger missing';
  end if;

  if has_function_privilege('authenticated','private.invalidate_material_request_inputs()','EXECUTE')
     or has_function_privilege('anon','private.invalidate_material_request_inputs()','EXECUTE')
     or has_function_privilege('authenticated','private.guard_material_request_supplier_terms()','EXECUTE')
     or has_function_privilege('anon','private.guard_material_request_supplier_terms()','EXECUTE') then
    raise exception 'private material trigger helper is directly executable';
  end if;

  select count(*) into view_cols
  from information_schema.columns
  where table_schema='public'
    and table_name='v_material_request_summary'
    and column_name in (
      'selected_plan_id','selected_total','selected_material_subtotal','selected_delivery_total'
    );
  if view_cols <> 4 then
    raise exception 'selected material plan summary columns missing';
  end if;

  select id into w from public.workspaces where slug='cb-contracting' limit 1;
  if w is not null then
    select count(*) into live_count
    from public.material_supplier_products p
    join public.material_suppliers s on s.id=p.supplier_id
    where p.workspace_id=w
      and p.active
      and p.pricing_mode='live_page'
      and s.supplier_key in ('home-depot','rona');

    if live_count <> 30 then
      raise exception 'Expected 30 exact live retailer mappings, found %', live_count;
    end if;

    if exists (
      select 1
      from public.material_supplier_products p
      join public.material_suppliers s on s.id=p.supplier_id
      where p.workspace_id=w
        and p.active
        and p.pricing_mode='live_page'
        and s.supplier_key in ('home-depot','rona')
        and (
          p.supplier_sku is null
          or p.product_url is null
          or p.product_url ilike '%/categories/%'
          or p.product_url ilike '%pressure-treated-lumber%'
          or p.product_url ilike '%/search%'
        )
    ) then
      raise exception 'Live material source still uses a discovery URL or lacks SKU';
    end if;

    if (
      select count(*)
      from public.material_supplier_products p
      join public.material_suppliers s on s.id=p.supplier_id
      where p.workspace_id=w
        and p.pricing_mode='live_page'
        and s.supplier_key='home-depot'
        and p.bulk_min_qty is not null
        and p.bulk_discount_pct=10
    ) <> 15 then
      raise exception 'Home Depot bulk pricing metadata incomplete';
    end if;
  end if;

  raise notice 'Material live-source and supplier-terms verification passed';
end $$;

rollback;

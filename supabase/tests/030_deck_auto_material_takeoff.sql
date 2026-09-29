begin;

do $$
declare
  w uuid;
  estimate_id uuid;
  request_id uuid;
  run_id uuid;
  plan_id uuid;
  spec_id uuid;
  selected boolean;
  request_status text;
begin
  if not exists (
    select 1 from information_schema.tables
    where table_schema='public' and table_name='deck_estimate_specs'
  ) then
    raise exception 'deck_estimate_specs missing';
  end if;

  if not exists (
    select 1 from pg_class c
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public'
      and c.relname='deck_estimate_specs'
      and c.relrowsecurity
      and c.relforcerowsecurity
  ) then
    raise exception 'deck_estimate_specs must enforce RLS';
  end if;

  if (
    select count(*)
    from pg_policies
    where schemaname='public'
      and tablename='deck_estimate_specs'
      and policyname in (
        'workspace_member_select',
        'workspace_sales_insert',
        'workspace_sales_update',
        'workspace_sales_delete'
      )
  ) <> 4 then
    raise exception 'deck estimate spec policies incomplete';
  end if;

  if has_table_privilege('anon','public.deck_estimate_specs','SELECT')
     or has_table_privilege('anon','public.deck_estimate_specs','INSERT')
     or has_table_privilege('anon','public.deck_estimate_specs','UPDATE')
     or has_table_privilege('anon','public.deck_estimate_specs','DELETE') then
    raise exception 'anon can access deck estimate specs';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema='public'
      and table_name='material_request_items'
      and column_name='source_type'
  ) or not exists (
    select 1 from information_schema.columns
    where table_schema='public'
      and table_name='material_request_items'
      and column_name='source_key'
  ) then
    raise exception 'generated material item provenance columns missing';
  end if;

  if not exists (
    select 1 from pg_indexes
    where schemaname='public'
      and tablename='material_request_items'
      and indexname='uq_material_request_items_generated_key'
  ) then
    raise exception 'generated material item uniqueness guard missing';
  end if;

  if not exists (
    select 1
    from pg_trigger
    where tgrelid='public.deck_estimate_specs'::regclass
      and tgname='invalidate_material_pricing_from_deck_spec'
      and not tgisinternal
      and pg_get_triggerdef(oid) ilike '%AFTER INSERT OR UPDATE%'
  ) then
    raise exception 'Deck spec invalidation trigger must cover insert and update';
  end if;

  if not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='private'
      and p.proname='invalidate_material_request_pricing_from_spec'
      and pg_get_functiondef(p.oid) ilike '%set_config%'
      and pg_get_functiondef(p.oid) ilike '%app.material_request_transition%'
      and pg_get_functiondef(p.oid) ilike '%invalidate%'
  ) then
    raise exception 'Deck spec invalidation must authorize the draft transition';
  end if;

  if has_function_privilege('authenticated','private.guard_deck_estimate_spec()','EXECUTE')
     or has_function_privilege('anon','private.guard_deck_estimate_spec()','EXECUTE')
     or has_function_privilege('authenticated','private.invalidate_material_request_pricing_from_spec()','EXECUTE')
     or has_function_privilege('anon','private.invalidate_material_request_pricing_from_spec()','EXECUTE') then
    raise exception 'private deck spec trigger helper is directly executable';
  end if;

  select id into w from public.workspaces where slug='cb-contracting' limit 1;
  if w is null then
    raise notice 'CB Contracting workspace not present in clean replay; structural checks passed';
    return;
  end if;

  select id into estimate_id
  from public.estimates
  where workspace_id=w and estimate_kind='deck'
  limit 1;

  if estimate_id is null then
    raise notice 'No deck estimate fixture present; structural checks passed';
    return;
  end if;

  insert into public.deck_estimate_specs(
    workspace_id,estimate_id,width_ft,depth_ft,stair_width_ft,steps,footings,joist_spacing_in
  ) values(w,estimate_id,12,12,4,4,4,16)
  on conflict(workspace_id,estimate_id) do update set width_ft=excluded.width_ft
  returning id into spec_id;

  insert into public.material_requests(workspace_id,estimate_id,name,status,waste_pct,delivery_mode)
  values(w,estimate_id,'__deck_spec_invalidation_test__','draft',5,'pickup')
  returning id into request_id;

  insert into public.material_price_runs(workspace_id,request_id,status,finished_at)
  values(w,request_id,'completed',now())
  returning id into run_id;

  insert into public.material_price_plans(
    workspace_id,request_id,run_id,plan_type,material_subtotal,delivery_total,total,is_selected
  ) values(w,request_id,run_id,'split_cheapest',100,0,100,true)
  returning id into plan_id;

  perform set_config('app.material_request_transition','approve',true);
  update public.material_requests set status='approved' where id=request_id;

  update public.deck_estimate_specs
  set width_ft=13
  where id=spec_id;

  select status into request_status from public.material_requests where id=request_id;
  select is_selected into selected from public.material_price_plans where id=plan_id;

  if request_status <> 'draft' or selected then
    raise exception 'Deck spec update did not invalidate approved material plan';
  end if;

  raise notice 'Deck automatic takeoff verification passed';
end $$;

rollback;

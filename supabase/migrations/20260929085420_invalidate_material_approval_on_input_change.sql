create or replace function private.invalidate_material_request_inputs()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if old.waste_pct is distinct from new.waste_pct
     or old.delivery_mode is distinct from new.delivery_mode then
    perform set_config('app.material_request_transition','invalidate',true);

    update public.material_price_plans
    set is_selected=false
    where workspace_id=old.workspace_id
      and request_id=old.id
      and is_selected;

    new.status := 'draft';
    new.updated_at := now();
  end if;

  return new;
end;
$$;

revoke all on function private.invalidate_material_request_inputs() from public, anon, authenticated;

drop trigger if exists a_invalidate_material_request_inputs on public.material_requests;
create trigger a_invalidate_material_request_inputs
before update on public.material_requests
for each row execute function private.invalidate_material_request_inputs();

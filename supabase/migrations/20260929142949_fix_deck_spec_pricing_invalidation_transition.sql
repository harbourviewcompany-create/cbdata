create or replace function private.invalidate_material_request_pricing_from_spec()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  perform set_config('app.material_request_transition','invalidate',true);

  update public.material_price_plans p
  set is_selected=false
  from public.material_requests r
  where r.estimate_id=new.estimate_id
    and r.workspace_id=new.workspace_id
    and p.request_id=r.id
    and p.workspace_id=r.workspace_id
    and p.is_selected;

  update public.material_requests
  set status='draft',updated_at=now()
  where workspace_id=new.workspace_id
    and estimate_id=new.estimate_id
    and status in ('priced','approved');

  return new;
end;
$$;

revoke all on function private.invalidate_material_request_pricing_from_spec() from public,anon,authenticated;

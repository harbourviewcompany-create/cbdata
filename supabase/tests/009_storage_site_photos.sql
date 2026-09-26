begin;
do $$
begin
  if not exists (select 1 from storage.buckets where id = 'site-photos') then
    raise exception 'site-photos bucket missing';
  end if;
  if not exists (select 1 from storage.buckets where id = 'site-docs') then
    raise exception 'site-docs bucket missing';
  end if;
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'storage_workspace_id'
  ) then
    raise exception 'storage_workspace_id missing';
  end if;
  raise notice 'Storage verification passed';
end $$;
rollback;

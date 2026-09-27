-- Private buckets for field photos and job documents.
-- Object keys: {workspace_id}/{entity_type}/{entity_id}/{uuid}-{filename}

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  (
    'site-photos',
    'site-photos',
    false,
    10485760,
    array['image/jpeg','image/png','image/webp','image/heic','image/heif','image/jpg']
  ),
  (
    'site-docs',
    'site-docs',
    false,
    20971520,
    array['application/pdf','image/jpeg','image/png','image/webp']
  )
on conflict (id) do update
  set file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types,
      public = false;

create or replace function public.storage_workspace_id(object_name text)
returns uuid
language plpgsql
immutable
as $$
declare
  v_part text;
  v_id uuid;
begin
  v_part := split_part(coalesce(object_name, ''), '/', 1);
  begin
    v_id := v_part::uuid;
  exception when others then
    return null;
  end;
  return v_id;
end;
$$;

revoke all on function public.storage_workspace_id(text) from public;
grant execute on function public.storage_workspace_id(text) to authenticated;

drop policy if exists site_photos_select on storage.objects;
drop policy if exists site_photos_insert on storage.objects;
drop policy if exists site_photos_update on storage.objects;
drop policy if exists site_photos_delete on storage.objects;
drop policy if exists site_docs_select on storage.objects;
drop policy if exists site_docs_insert on storage.objects;
drop policy if exists site_docs_update on storage.objects;
drop policy if exists site_docs_delete on storage.objects;

create policy site_photos_select on storage.objects
for select to authenticated
using (
  bucket_id = 'site-photos'
  and public.storage_workspace_id(name) is not null
  and private.is_workspace_member(public.storage_workspace_id(name))
);

create policy site_photos_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'site-photos'
  and public.storage_workspace_id(name) is not null
  and private.is_workspace_member(public.storage_workspace_id(name))
);

create policy site_photos_update on storage.objects
for update to authenticated
using (
  bucket_id = 'site-photos'
  and private.is_workspace_member(public.storage_workspace_id(name))
)
with check (
  bucket_id = 'site-photos'
  and private.is_workspace_member(public.storage_workspace_id(name))
);

create policy site_photos_delete on storage.objects
for delete to authenticated
using (
  bucket_id = 'site-photos'
  and private.has_workspace_role(
    public.storage_workspace_id(name),
    array['owner','administrator','operations_manager']::public.membership_role[]
  )
);

create policy site_docs_select on storage.objects
for select to authenticated
using (
  bucket_id = 'site-docs'
  and public.storage_workspace_id(name) is not null
  and private.is_workspace_member(public.storage_workspace_id(name))
);

create policy site_docs_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'site-docs'
  and public.storage_workspace_id(name) is not null
  and private.is_workspace_member(public.storage_workspace_id(name))
);

create policy site_docs_update on storage.objects
for update to authenticated
using (
  bucket_id = 'site-docs'
  and private.is_workspace_member(public.storage_workspace_id(name))
)
with check (
  bucket_id = 'site-docs'
  and private.is_workspace_member(public.storage_workspace_id(name))
);

create policy site_docs_delete on storage.objects
for delete to authenticated
using (
  bucket_id = 'site-docs'
  and private.has_workspace_role(
    public.storage_workspace_id(name),
    array['owner','administrator','operations_manager']::public.membership_role[]
  )
);

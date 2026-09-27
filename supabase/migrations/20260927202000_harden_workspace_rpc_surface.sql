-- Harden exposed workspace helper functions.
-- RLS policies should call the private schema helpers directly; the public wrappers
-- are not part of the client API and must not be executable by signed-in users.
-- Also pin storage_workspace_id to a fixed search_path.

create or replace function public.storage_workspace_id(object_name text)
returns uuid
language plpgsql
immutable
set search_path = pg_catalog, public
as $function$
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
$function$;

drop policy if exists seq_steps_member_all on public.outreach_sequence_steps;
create policy seq_steps_member_all
on public.outreach_sequence_steps
for all to authenticated
using (private.is_workspace_member(workspace_id))
with check (private.is_workspace_member(workspace_id));

drop policy if exists seq_member_all on public.outreach_sequences;
create policy seq_member_all
on public.outreach_sequences
for all to authenticated
using (private.is_workspace_member(workspace_id))
with check (private.is_workspace_member(workspace_id));

revoke execute on function public.is_workspace_member(uuid) from public, authenticated, anon;
revoke execute on function public.has_workspace_role(uuid, public.membership_role[]) from public, authenticated, anon;
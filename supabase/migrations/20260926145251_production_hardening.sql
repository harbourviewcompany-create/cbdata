-- Production security and workflow hardening.
-- Captures the live hardening applied to the CBData Supabase project.

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create or replace function private.is_workspace_member(p_workspace_id uuid)
returns boolean language sql stable security definer set search_path=pg_catalog,public,auth
as $$ select exists(select 1 from public.workspace_memberships m where m.workspace_id=p_workspace_id and m.user_id=auth.uid() and m.status='active') $$;

create or replace function private.has_workspace_role(p_workspace_id uuid,p_roles public.membership_role[])
returns boolean language sql stable security definer set search_path=pg_catalog,public,auth
as $$ select exists(select 1 from public.workspace_memberships m where m.workspace_id=p_workspace_id and m.user_id=auth.uid() and m.status='active' and m.role=any(p_roles)) $$;

grant execute on function private.is_workspace_member(uuid) to authenticated;
grant execute on function private.has_workspace_role(uuid,public.membership_role[]) to authenticated;

do $$ declare r record; begin
 for r in select schemaname,tablename,policyname,cmd,qual,with_check from pg_policies where schemaname='public'
 loop
   if r.tablename in ('workspace_memberships','workspaces') then continue; end if;
   if r.cmd='SELECT' and r.qual in ('is_workspace_member(workspace_id)','is_workspace_member(id)') then execute format('alter policy %I on %I.%I using (private.is_workspace_member(%s))',r.policyname,r.schemaname,r.tablename,case when r.qual like '%(id)%' then 'id' else 'workspace_id' end);
   elsif r.cmd='INSERT' and r.with_check='is_workspace_member(workspace_id)' then execute format('alter policy %I on %I.%I with check (private.is_workspace_member(workspace_id))',r.policyname,r.schemaname,r.tablename);
   elsif r.cmd='UPDATE' and r.qual='is_workspace_member(workspace_id)' and r.with_check='is_workspace_member(workspace_id)' then execute format('alter policy %I on %I.%I using (private.is_workspace_member(workspace_id)) with check (private.is_workspace_member(workspace_id))',r.policyname,r.schemaname,r.tablename);
   end if;
 end loop;
end $$;

alter policy membership_select on public.workspace_memberships using (private.is_workspace_member(workspace_id));
alter policy membership_manage on public.workspace_memberships with check (private.has_workspace_role(workspace_id,ARRAY['owner'::membership_role,'administrator'::membership_role]));
alter policy membership_manage_delete on public.workspace_memberships using (private.has_workspace_role(workspace_id,ARRAY['owner'::membership_role,'administrator'::membership_role]));
alter policy membership_manage_update on public.workspace_memberships using (private.has_workspace_role(workspace_id,ARRAY['owner'::membership_role,'administrator'::membership_role])) with check (private.has_workspace_role(workspace_id,ARRAY['owner'::membership_role,'administrator'::membership_role]));
alter policy workspace_member_select on public.workspaces using (private.is_workspace_member(id));
alter policy workspace_member_update on public.workspaces using (private.has_workspace_role(id,ARRAY['owner'::membership_role,'administrator'::membership_role])) with check (private.has_workspace_role(id,ARRAY['owner'::membership_role,'administrator'::membership_role]));

drop function if exists public.is_workspace_member(uuid);
drop function if exists public.has_workspace_role(uuid,public.membership_role[]);

alter table public.work_order_assignments drop constraint if exists work_order_assignments_resource_type_check;
alter table public.work_order_assignments drop constraint if exists work_order_assignments_resource_type_check;
alter table public.work_order_assignments add constraint work_order_assignments_resource_type_check check (
 (assignment_type='crew' and crew_id is not null and employee_id is null and contractor_id is null and equipment_id is null)
 or (assignment_type='employee' and employee_id is not null and crew_id is null and contractor_id is null and equipment_id is null)
 or (assignment_type='contractor' and contractor_id is not null and crew_id is null and employee_id is null and equipment_id is null)
 or (assignment_type='equipment' and equipment_id is not null and crew_id is null and employee_id is null and contractor_id is null)
);

create or replace function private.validate_work_order_assignment()
returns trigger language plpgsql security definer set search_path=pg_catalog,public
as $$
declare resource_workspace uuid; resource_active boolean;
begin
 if new.assignment_type='crew' then select workspace_id,(status='active') into resource_workspace,resource_active from public.crews where id=new.crew_id;
 elsif new.assignment_type='employee' then select workspace_id,(employment_status='active') into resource_workspace,resource_active from public.employees where id=new.employee_id;
 elsif new.assignment_type='contractor' then select workspace_id,(status='active') into resource_workspace,resource_active from public.contractors where id=new.contractor_id;
 else select workspace_id,(status='available') into resource_workspace,resource_active from public.equipment where id=new.equipment_id;
 end if;
 if resource_workspace is null or resource_workspace <> new.workspace_id then raise exception 'Assignment resource does not belong to the work order workspace'; end if;
 if not coalesce(resource_active,false) then raise exception 'Assignment resource is not active or available'; end if;
 return new;
end $$;

drop trigger if exists validate_work_order_assignment on public.work_order_assignments;
create trigger validate_work_order_assignment before insert or update on public.work_order_assignments for each row execute function private.validate_work_order_assignment();

create index if not exists idx_work_order_assignments_active_work_order on public.work_order_assignments(work_order_id) where unassigned_at is null;
create index if not exists idx_issues_assigned_to_workspace on public.issues(workspace_id,assigned_to) where assigned_to is not null;

-- CBData command-center optimization and Action OS hardening.
-- Apply before deploying the dashboard that reads workspace_ops_snapshots/next_actions.

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create or replace function private.is_workspace_member(p_workspace_id uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, auth
as $$
  select exists (
    select 1 from public.workspace_memberships m
    where m.workspace_id = p_workspace_id
      and m.user_id = auth.uid()
      and m.status = 'active'
  )
$$;

grant execute on function private.is_workspace_member(uuid) to authenticated;

create or replace function private.has_workspace_role(p_workspace_id uuid, p_roles public.membership_role[])
returns boolean language sql stable security definer
set search_path = pg_catalog, public, auth
as $$
  select exists (
    select 1 from public.workspace_memberships m
    where m.workspace_id = p_workspace_id
      and m.user_id = auth.uid()
      and m.status = 'active'
      and m.role = any(p_roles)
  )
$$;

grant execute on function private.has_workspace_role(uuid, public.membership_role[]) to authenticated;

create or replace function public.is_workspace_member(p_workspace_id uuid)
returns boolean language sql stable security definer set search_path = pg_catalog, public, auth
as $$ select private.is_workspace_member(p_workspace_id) $$;

create or replace function public.has_workspace_role(p_workspace_id uuid, p_roles public.membership_role[])
returns boolean language sql stable security definer set search_path = pg_catalog, public, auth
as $$ select private.has_workspace_role(p_workspace_id, p_roles) $$;

grant execute on function public.is_workspace_member(uuid) to authenticated;
grant execute on function public.has_workspace_role(uuid, public.membership_role[]) to authenticated;

alter table public.user_profiles add column if not exists active_workspace_id uuid;
alter table public.user_profiles drop constraint if exists user_profiles_active_workspace_id_fkey;
alter table public.user_profiles add constraint user_profiles_active_workspace_id_fkey
  foreign key (active_workspace_id) references public.workspaces(id) on delete set null;

create unique index if not exists idx_memberships_active_user_workspace
  on public.workspace_memberships (workspace_id, user_id) where status = 'active';

alter table public.invoices add column if not exists work_order_id uuid;
alter table public.invoices drop constraint if exists invoices_work_order_id_fkey;
alter table public.invoices add constraint invoices_work_order_id_fkey
  foreign key (work_order_id) references public.work_orders(id) on delete set null;

create unique index if not exists idx_invoices_work_order_unique
  on public.invoices (work_order_id)
  where work_order_id is not null and status <> 'void';

create table if not exists public.workspace_ops_snapshots (
  workspace_id uuid primary key references public.workspaces(id) on delete cascade,
  property_count integer not null default 0,
  open_work_count integer not null default 0,
  open_issue_count integer not null default 0,
  renewal_count integer not null default 0,
  needs_dispatch_count integer not null default 0,
  open_task_count integer not null default 0,
  overdue_task_count integer not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.workspace_ops_snapshots enable row level security;
drop policy if exists workspace_ops_snapshots_select on public.workspace_ops_snapshots;
create policy workspace_ops_snapshots_select on public.workspace_ops_snapshots
  for select using (private.is_workspace_member(workspace_id));

create or replace function public.refresh_workspace_ops_snapshot(p_workspace_id uuid)
returns public.workspace_ops_snapshots
language plpgsql security definer set search_path = pg_catalog, public
as $$
declare v_row public.workspace_ops_snapshots%rowtype;
begin
  if p_workspace_id is null then raise exception 'workspace is required'; end if;

  insert into public.workspace_ops_snapshots (
    workspace_id, property_count, open_work_count, open_issue_count, renewal_count,
    needs_dispatch_count, open_task_count, overdue_task_count, updated_at
  )
  select
    p_workspace_id,
    (select count(*) from public.properties p where p.workspace_id=p_workspace_id and p.archived_at is null),
    (select count(*) from public.open_work_exceptions w where w.workspace_id=p_workspace_id),
    (select count(*) from public.open_issue_queue i where i.workspace_id=p_workspace_id),
    (select count(*) from public.contract_renewal_queue c where c.workspace_id=p_workspace_id and c.end_date <= current_date + 60),
    (select count(*) from public.work_orders w
      where w.workspace_id=p_workspace_id
        and w.status in ('draft','scheduled','assigned','en_route','in_progress','paused','needs_review')
        and not exists (
          select 1 from public.work_order_assignments a
          where a.work_order_id=w.id and a.status='assigned' and a.unassigned_at is null
        )),
    (select count(*) from public.tasks t where t.workspace_id=p_workspace_id and t.status in ('open','in_progress')),
    (select count(*) from public.tasks t where t.workspace_id=p_workspace_id and t.status in ('open','in_progress') and t.due_at < now()),
    now()
  on conflict (workspace_id) do update set
    property_count=excluded.property_count,
    open_work_count=excluded.open_work_count,
    open_issue_count=excluded.open_issue_count,
    renewal_count=excluded.renewal_count,
    needs_dispatch_count=excluded.needs_dispatch_count,
    open_task_count=excluded.open_task_count,
    overdue_task_count=excluded.overdue_task_count,
    updated_at=excluded.updated_at
  returning * into v_row;
  return v_row;
end;
$$;

revoke all on function public.refresh_workspace_ops_snapshot(uuid) from public;
grant execute on function public.refresh_workspace_ops_snapshot(uuid) to authenticated;

create or replace function private.touch_ops_snapshot()
returns trigger
language plpgsql security definer set search_path = pg_catalog, public
as $$
begin
  if tg_op='DELETE' then
    perform public.refresh_workspace_ops_snapshot(old.workspace_id);
    return old;
  elsif tg_op='UPDATE' then
    perform public.refresh_workspace_ops_snapshot(old.workspace_id);
    if new.workspace_id is distinct from old.workspace_id then
      perform public.refresh_workspace_ops_snapshot(new.workspace_id);
    end if;
    return new;
  else
    perform public.refresh_workspace_ops_snapshot(new.workspace_id);
    return new;
  end if;
end;
$$;

grant execute on function private.touch_ops_snapshot() to authenticated;

do $$
declare r record;
begin
  for r in select unnest(array['work_orders','issues','contracts','work_order_assignments','properties']) as table_name loop
    execute format('drop trigger if exists touch_ops_snapshot on public.%I',r.table_name);
    execute format('create trigger touch_ops_snapshot after insert or update or delete on public.%I for each row execute function private.touch_ops_snapshot()',r.table_name);
  end loop;
end $$;

drop function if exists public.next_actions(uuid, integer);
create or replace function public.next_actions(p_workspace_id uuid, p_limit integer default 25)
returns table (
  workspace_id uuid, action_type text, title text, detail text, entity_id uuid,
  due_at timestamptz, priority_score integer, href text
)
language plpgsql security invoker set search_path = public
as $$
declare v_limit integer := least(greatest(coalesce(p_limit,25),1),100);
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not private.is_workspace_member(p_workspace_id) then raise exception 'not a member of workspace'; end if;

  return query
  with arms as (
    select * from (
      select w.workspace_id,'work_order'::text,'Assign / dispatch'::text,
             coalesce(w.description,w.work_order_number),w.id,coalesce(w.scheduled_start,w.created_at),
             case w.priority when 'emergency' then 100 when 'urgent' then 90 when 'high' then 70 else 50 end,
             '/work-orders/'||w.id::text
      from public.work_orders w
      where w.workspace_id=p_workspace_id and w.status in ('draft','scheduled','assigned')
        and not exists (select 1 from public.work_order_assignments a
                        where a.work_order_id=w.id and a.status='assigned' and a.unassigned_at is null)
      order by case w.priority when 'emergency' then 100 when 'urgent' then 90 when 'high' then 70 else 50 end desc,
               coalesce(w.scheduled_start,w.created_at)
      limit v_limit
    ) q1
    union all
    select * from (
      select i.workspace_id,'issue'::text,'Resolve issue'::text,i.title,i.id,coalesce(i.due_at,i.reported_at),
             case i.severity when 'critical' then 95 when 'high' then 80 else 40 end,
             '/issues/'||i.id::text
      from public.issues i
      where i.workspace_id=p_workspace_id and i.status in ('open','in_progress','blocked')
        and i.severity in ('critical','high')
      order by case i.severity when 'critical' then 95 when 'high' then 80 else 40 end desc,
               coalesce(i.due_at,i.reported_at)
      limit v_limit
    ) q2
    union all
    select * from (
      select t.workspace_id,'outreach'::text,coalesce(t.next_action,'Follow up target')::text,
             coalesce(t.organization_name,t.contact_name,'Target')::text,t.id,
             coalesce(t.next_action_due_at,t.last_touch_at,t.created_at),coalesce(t.score,30)::integer,
             '/targets/'||t.id::text
      from public.outreach_targets t
      where t.workspace_id=p_workspace_id and t.status in ('queued','contacted','responded')
        and (t.next_action_due_at is null or t.next_action_due_at <= now()+interval '2 days'
             or t.last_touch_at is null or t.last_touch_at < now()-interval '14 days')
      order by coalesce(t.score,30) desc,coalesce(t.next_action_due_at,t.created_at)
      limit v_limit
    ) q3
    union all
    select * from (
      select c.workspace_id,'renewal'::text,'Renewal approaching'::text,c.name,c.id,c.end_date::timestamptz,75,
             '/contracts/'||c.id::text
      from public.contracts c
      where c.workspace_id=p_workspace_id and c.status in ('active','renewal_pending')
        and c.end_date is not null and c.end_date <= current_date+60
      order by c.end_date
      limit v_limit
    ) q4
    union all
    select * from (
      select t.workspace_id,'task'::text,t.title,coalesce(t.description,''),t.id,coalesce(t.due_at,t.created_at),
             case t.priority when 'emergency' then 100 when 'urgent' then 90 when 'high' then 70 else 45 end,
             case when t.outreach_target_id is not null then '/targets/'||t.outreach_target_id::text
                  when t.work_order_id is not null then '/work-orders/'||t.work_order_id::text
                  when t.issue_id is not null then '/issues/'||t.issue_id::text
                  else '/dashboard' end
      from public.tasks t
      where t.workspace_id=p_workspace_id and t.status in ('open','in_progress')
      order by case t.priority when 'emergency' then 100 when 'urgent' then 90 when 'high' then 70 else 45 end desc,
               coalesce(t.due_at,t.created_at)
      limit v_limit
    ) q5
  )
  select arms.column1,arms.column2,arms.column3,arms.column4,arms.column5,arms.column6,arms.column7,arms.column8
  from arms order by arms.column7 desc,arms.column6 nulls last limit v_limit;
end;
$$;

grant execute on function public.next_actions(uuid,integer) to authenticated;

drop policy if exists notifications_select_own on public.notifications;
create policy notifications_select_own on public.notifications for select using (
  user_id=auth.uid() and private.is_workspace_member(workspace_id)
);

drop policy if exists notifications_update_own on public.notifications;
create policy notifications_update_own on public.notifications for update using (
  user_id=auth.uid() and private.is_workspace_member(workspace_id)
) with check (
  user_id=auth.uid() and private.is_workspace_member(workspace_id)
);

drop policy if exists notifications_insert_member on public.notifications;
create policy notifications_insert_member on public.notifications for insert with check (
  private.is_workspace_member(workspace_id)
  and exists (
    select 1 from public.workspace_memberships m
    where m.workspace_id=notifications.workspace_id and m.user_id=notifications.user_id and m.status='active'
  )
);

create or replace function public.create_notification(
  p_workspace_id uuid,p_user_id uuid,p_title text,p_body text default null,
  p_entity_type text default null,p_entity_id uuid default null,p_action_href text default null
)
returns uuid language plpgsql security invoker set search_path=public
as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not private.is_workspace_member(p_workspace_id) then raise exception 'not a member of workspace'; end if;
  if not exists (select 1 from public.workspace_memberships m
                 where m.workspace_id=p_workspace_id and m.user_id=p_user_id and m.status='active') then
    raise exception 'target user is not an active member of workspace';
  end if;
  insert into public.notifications(workspace_id,user_id,channel,status,title,body,entity_type,entity_id,action_href)
  values(p_workspace_id,p_user_id,'in_app','pending',p_title,p_body,p_entity_type,p_entity_id,p_action_href)
  returning id into v_id;
  return v_id;
end;
$$;

grant execute on function public.create_notification(uuid,uuid,text,text,text,uuid,text) to authenticated;

create or replace function public.generate_work_orders_from_contract(p_contract_id uuid,p_days_ahead int default 14)
returns int language plpgsql security invoker set search_path=public
as $$
declare
  v_c public.contracts%rowtype; v_cs record; v_sched record; v_count int:=0;
  v_day date; v_start timestamptz; v_wo_num text; v_end date;
  v_days int:=least(greatest(coalesce(p_days_ahead,14),1),31);
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_c from public.contracts where id=p_contract_id;
  if not found then raise exception 'contract not found'; end if;
  if not private.is_workspace_member(v_c.workspace_id) then raise exception 'not a member of workspace'; end if;
  if v_c.status not in ('active','renewal_pending') then raise exception 'contract must be active or renewal_pending'; end if;
  v_end:=least(coalesce(v_c.end_date,current_date+v_days),current_date+v_days);
  for v_cs in select * from public.contract_services where contract_id=p_contract_id and active=true loop
    for v_sched in select * from public.service_schedules where contract_service_id=v_cs.id and active=true loop
      v_day:=current_date;
      while v_day<=v_end loop
        if v_sched.schedule_type='one_time'
           or (v_sched.day_of_week is not null and extract(dow from v_day)::int=v_sched.day_of_week)
           or (v_sched.day_of_month is not null and extract(day from v_day)::int=v_sched.day_of_month)
           or (v_sched.day_of_week is null and v_sched.day_of_month is null and v_sched.schedule_type='recurring') then
          v_start:=(v_day::text||' '||coalesce(v_sched.start_time::text,'09:00'))::timestamptz;
          if not exists (select 1 from public.work_orders w where w.workspace_id=v_c.workspace_id and w.property_id=v_c.property_id
                         and w.contract_id=v_c.id and w.contract_service_id=v_cs.id
                         and w.scheduled_start::date=v_day and w.status<>'cancelled') then
            v_wo_num:='WO-'||to_char(v_day,'YYYYMMDD')||'-'||substr(replace(gen_random_uuid()::text,'-',''),1,8);
            insert into public.work_orders(workspace_id,work_order_number,property_id,contract_id,contract_service_id,source_type,priority,status,scheduled_start,estimated_duration_minutes,description,site_instructions,created_by)
            values(v_c.workspace_id,upper(v_wo_num),v_c.property_id,v_c.id,v_cs.id,'contract_schedule','normal','scheduled',v_start,v_sched.duration_minutes,coalesce(v_cs.scope_description,v_c.name),v_sched.instructions,auth.uid());
            v_count:=v_count+1;
          end if;
        end if;
        v_day:=v_day+1;
      end loop;
    end loop;
  end loop;
  return v_count;
end;
$$;

grant execute on function public.generate_work_orders_from_contract(uuid,int) to authenticated;

drop function if exists public.complete_work_order_with_invoice(uuid);
drop function if exists public.complete_work_order_with_invoice(uuid,text);
create or replace function public.complete_work_order_with_invoice(p_work_order_id uuid,p_notes text default null)
returns uuid language plpgsql security invoker set search_path=public
as $$
declare
  v_w public.work_orders%rowtype; v_org uuid; v_inv uuid; v_amount numeric:=0; v_num text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_w from public.work_orders where id=p_work_order_id for update;
  if not found then raise exception 'work order not found'; end if;
  if not private.is_workspace_member(v_w.workspace_id) then raise exception 'not a member of workspace'; end if;
  if v_w.status='cancelled' then raise exception 'cannot complete cancelled work order'; end if;

  if not exists (select 1 from public.work_order_assignments a
                 where a.work_order_id=v_w.id and a.status='assigned' and a.unassigned_at is null) then
    raise exception 'work order must have an active assignment before completion';
  end if;

  select i.id into v_inv from public.invoices i
  where i.work_order_id=p_work_order_id and i.status<>'void'
  order by i.created_at desc limit 1;
  if v_inv is not null then return v_inv; end if;

  if v_w.status<>'completed' then
    if v_w.status<>'in_progress' then raise exception 'work order is not in progress'; end if;
    update public.work_visits
      set ended_at=coalesce(ended_at,now()),completion_status='completed',notes=coalesce(p_notes,notes)
      where work_order_id=p_work_order_id and ended_at is null;
    update public.work_orders
      set status='completed',completed_at=coalesce(completed_at,now()),updated_at=now()
      where id=p_work_order_id;
  end if;

  select coalesce(p.primary_customer_organization_id,c.organization_id) into v_org
  from public.properties p left join public.contracts c on c.id=v_w.contract_id
  where p.id=v_w.property_id;
  if v_org is null then raise exception 'work order has no bill-to organization'; end if;

  if v_w.contract_service_id is not null then
    select coalesce(cs.contract_price,0) into v_amount
    from public.contract_services cs where cs.id=v_w.contract_service_id;
  end if;

  v_num:='INV-'||to_char(now(),'YYYYMMDD')||'-'||substr(replace(gen_random_uuid()::text,'-',''),1,6);
  begin
    insert into public.invoices(workspace_id,invoice_number,organization_id,property_id,contract_id,work_order_id,status,invoice_date,due_date,subtotal,tax,total)
    values(v_w.workspace_id,upper(v_num),v_org,v_w.property_id,v_w.contract_id,v_w.id,'draft',current_date,current_date+30,coalesce(v_amount,0),0,coalesce(v_amount,0))
    returning id into v_inv;
  exception when unique_violation then
    select i.id into v_inv from public.invoices i
    where i.work_order_id=p_work_order_id and i.status<>'void'
    order by i.created_at desc limit 1;
    if v_inv is null then raise; end if;
  end;
  return v_inv;
end;
$$;

grant execute on function public.complete_work_order_with_invoice(uuid,text) to authenticated;

create index if not exists idx_work_orders_workspace_status_schedule
  on public.work_orders(workspace_id,status,scheduled_start);
create index if not exists idx_work_order_assignments_active_lookup
  on public.work_order_assignments(work_order_id,status) where unassigned_at is null;
create index if not exists idx_issues_workspace_severity_reported
  on public.issues(workspace_id,severity,reported_at);
create index if not exists idx_outreach_targets_workspace_due
  on public.outreach_targets(workspace_id,status,next_action_due_at);
create index if not exists idx_contracts_workspace_renewal
  on public.contracts(workspace_id,status,end_date);
create index if not exists idx_tasks_workspace_status_due
  on public.tasks(workspace_id,status,due_at);

do $$
declare r record;
begin
  for r in select id from public.workspaces loop
    perform public.refresh_workspace_ops_snapshot(r.id);
  end loop;
end $$;

-- Cover FKs introduced after the generic performance pass.
create index if not exists idx_outreach_lists_created_by
  on public.outreach_lists(created_by);
create index if not exists idx_outreach_touches_performed_by
  on public.outreach_touches(performed_by);
create index if not exists idx_outreach_sequences_workspace_id
  on public.outreach_sequences(workspace_id);
create index if not exists idx_outreach_sequence_steps_workspace_id
  on public.outreach_sequence_steps(workspace_id);
create index if not exists idx_outreach_enrollments_outreach_target_id
  on public.outreach_enrollments(outreach_target_id);
create index if not exists idx_user_profiles_active_workspace_id
  on public.user_profiles(active_workspace_id);
create index if not exists idx_invoices_work_order_id
  on public.invoices(work_order_id);

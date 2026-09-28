-- CBData Action OS: next-action engine, outreach sequences, notifications,
-- contract→WO generation, complete WO → draft invoice.
-- Additive; does not replace existing ops/BD tables.

-- ---------------------------------------------------------------------------
-- 1) Notifications
-- ---------------------------------------------------------------------------
create type public.notification_channel as enum ('in_app','email','sms');
create type public.notification_status as enum ('pending','sent','read','dismissed','failed');

create table public.notifications (
  id uuid primary key default uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete cascade,
  channel notification_channel not null default 'in_app',
  status notification_status not null default 'pending',
  title text not null,
  body text,
  entity_type text,
  entity_id uuid,
  action_href text,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  sent_at timestamptz
);

create index idx_notifications_user_status on public.notifications (user_id, status, created_at desc);
create index idx_notifications_workspace on public.notifications (workspace_id);

alter table public.notifications enable row level security;
alter table public.notifications force row level security;

create policy notifications_select_own on public.notifications
  for select using (user_id = auth.uid() and is_workspace_member(workspace_id));
create policy notifications_update_own on public.notifications
  for update using (user_id = auth.uid() and is_workspace_member(workspace_id))
  with check (user_id = auth.uid() and is_workspace_member(workspace_id));
create policy notifications_insert_member on public.notifications
  for insert with check (is_workspace_member(workspace_id));

-- ---------------------------------------------------------------------------
-- 2) Outreach sequences (executable marketing plans)
-- ---------------------------------------------------------------------------
create type public.sequence_step_channel as enum ('call','email','sms','task','wait');
create type public.enrollment_status as enum ('active','paused','completed','cancelled');

create table public.outreach_sequences (
  id uuid primary key default uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete restrict,
  name text not null,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.outreach_sequence_steps (
  id uuid primary key default uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete restrict,
  sequence_id uuid not null references public.outreach_sequences(id) on delete cascade,
  step_order int not null,
  channel sequence_step_channel not null,
  delay_days int not null default 0 check (delay_days >= 0),
  title text not null,
  body_template text,
  created_at timestamptz not null default now(),
  unique (sequence_id, step_order)
);

create table public.outreach_enrollments (
  id uuid primary key default uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete restrict,
  sequence_id uuid not null references public.outreach_sequences(id) on delete restrict,
  outreach_target_id uuid not null references public.outreach_targets(id) on delete cascade,
  status enrollment_status not null default 'active',
  current_step_order int not null default 1,
  next_run_at timestamptz not null default now(),
  enrolled_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (sequence_id, outreach_target_id)
);

create index idx_enrollments_next_run on public.outreach_enrollments (workspace_id, status, next_run_at)
  where status = 'active';

alter table public.outreach_sequences enable row level security;
alter table public.outreach_sequences force row level security;
alter table public.outreach_sequence_steps enable row level security;
alter table public.outreach_sequence_steps force row level security;
alter table public.outreach_enrollments enable row level security;
alter table public.outreach_enrollments force row level security;

create policy seq_member_all on public.outreach_sequences for all
  using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy seq_steps_member_all on public.outreach_sequence_steps for all
  using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));
create policy enroll_member_all on public.outreach_enrollments for all
  using (is_workspace_member(workspace_id)) with check (is_workspace_member(workspace_id));

create trigger touch_updated_at before update on public.outreach_sequences
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- 3) Helpers: notify
-- ---------------------------------------------------------------------------
create or replace function public.create_notification(
  p_workspace_id uuid,
  p_user_id uuid,
  p_title text,
  p_body text default null,
  p_entity_type text default null,
  p_entity_id uuid default null,
  p_action_href text default null
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if not public.is_workspace_member(p_workspace_id) then
    raise exception 'not a member of workspace';
  end if;

  insert into public.notifications (
    workspace_id, user_id, channel, status, title, body, entity_type, entity_id, action_href
  ) values (
    p_workspace_id, p_user_id, 'in_app', 'pending', p_title, p_body, p_entity_type, p_entity_id, p_action_href
  ) returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.create_notification(uuid, uuid, text, text, text, uuid, text) from public;
grant execute on function public.create_notification(uuid, uuid, text, text, text, uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 4) Enroll target in sequence + process due steps
-- ---------------------------------------------------------------------------
create or replace function public.enroll_outreach_target(
  p_target_id uuid,
  p_sequence_id uuid
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_target public.outreach_targets%rowtype;
  v_seq public.outreach_sequences%rowtype;
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select * into v_target from public.outreach_targets where id = p_target_id;
  if not found then raise exception 'target not found'; end if;
  if not public.is_workspace_member(v_target.workspace_id) then
    raise exception 'not a member of workspace';
  end if;

  select * into v_seq from public.outreach_sequences
  where id = p_sequence_id and workspace_id = v_target.workspace_id and is_active;
  if not found then raise exception 'sequence not found or inactive'; end if;

  insert into public.outreach_enrollments (
    workspace_id, sequence_id, outreach_target_id, status, current_step_order, next_run_at, enrolled_by
  ) values (
    v_target.workspace_id, p_sequence_id, p_target_id, 'active', 1, now(), auth.uid()
  )
  on conflict (sequence_id, outreach_target_id) do update
    set status = 'active',
        current_step_order = 1,
        next_run_at = now(),
        completed_at = null
  returning id into v_id;

  update public.outreach_targets
  set next_action = 'Sequence enrolled: ' || v_seq.name,
      next_action_due_at = now(),
      updated_at = now()
  where id = p_target_id;

  return v_id;
end;
$$;

create or replace function public.process_due_sequence_steps(p_workspace_id uuid, p_limit int default 50)
returns int
language plpgsql
security invoker
set search_path = public
as $$
declare
  r record;
  v_step public.outreach_sequence_steps%rowtype;
  v_next int;
  v_count int := 0;
  v_owner uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not public.is_workspace_member(p_workspace_id) then
    raise exception 'not a member of workspace';
  end if;

  for r in
    select e.*
    from public.outreach_enrollments e
    where e.workspace_id = p_workspace_id
      and e.status = 'active'
      and e.next_run_at <= now()
    order by e.next_run_at
    limit greatest(p_limit, 1)
    for update skip locked
  loop
    select * into v_step
    from public.outreach_sequence_steps s
    where s.sequence_id = r.sequence_id
      and s.step_order = r.current_step_order;

    if not found then
      update public.outreach_enrollments
      set status = 'completed', completed_at = now()
      where id = r.id;
      continue;
    end if;

    select owner_user_id into v_owner from public.outreach_targets where id = r.outreach_target_id;

    if v_step.channel in ('call','email','sms','task') then
      insert into public.tasks (
        workspace_id, title, description, task_type, status, priority,
        assigned_to, outreach_target_id, due_at, created_by
      ) values (
        p_workspace_id,
        v_step.title,
        v_step.body_template,
        'follow_up',
        'open',
        'normal',
        v_owner,
        r.outreach_target_id,
        now(),
        auth.uid()
      );

      update public.outreach_targets
      set next_action = v_step.title,
          next_action_due_at = now(),
          updated_at = now()
      where id = r.outreach_target_id;

      if v_owner is not null then
        perform public.create_notification(
          p_workspace_id, v_owner,
          'Outreach: ' || v_step.title,
          v_step.body_template,
          'outreach_targets', r.outreach_target_id,
          '/targets'
        );
      end if;
    end if;

    -- advance
    v_next := r.current_step_order + 1;
    if exists (
      select 1 from public.outreach_sequence_steps
      where sequence_id = r.sequence_id and step_order = v_next
    ) then
      update public.outreach_enrollments e
      set current_step_order = v_next,
          next_run_at = now() + make_interval(days => (
            select delay_days from public.outreach_sequence_steps
            where sequence_id = r.sequence_id and step_order = v_next
          ))
      where e.id = r.id;
    else
      update public.outreach_enrollments
      set status = 'completed', completed_at = now(), current_step_order = v_next
      where id = r.id;
    end if;

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

revoke all on function public.enroll_outreach_target(uuid, uuid) from public;
revoke all on function public.process_due_sequence_steps(uuid, int) from public;
grant execute on function public.enroll_outreach_target(uuid, uuid) to authenticated;
grant execute on function public.process_due_sequence_steps(uuid, int) to authenticated;

-- ---------------------------------------------------------------------------
-- 5) Contract → work orders (next 14 days window from schedules)
-- ---------------------------------------------------------------------------
create or replace function public.generate_work_orders_from_contract(
  p_contract_id uuid,
  p_days_ahead int default 14
)
returns int
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_c public.contracts%rowtype;
  v_cs record;
  v_sched record;
  v_count int := 0;
  v_day date;
  v_start timestamptz;
  v_wo_num text;
  v_end date;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select * into v_c from public.contracts where id = p_contract_id;
  if not found then raise exception 'contract not found'; end if;
  if not public.is_workspace_member(v_c.workspace_id) then
    raise exception 'not a member of workspace';
  end if;
  if v_c.status not in ('active', 'renewal_pending') then
    raise exception 'contract must be active or renewal_pending';
  end if;

  v_end := least(
    coalesce(v_c.end_date, current_date + p_days_ahead),
    current_date + greatest(p_days_ahead, 1)
  );

  for v_cs in
    select * from public.contract_services
    where contract_id = p_contract_id and active = true
  loop
    for v_sched in
      select * from public.service_schedules
      where contract_service_id = v_cs.id and active = true
    loop
      v_day := current_date;
      while v_day <= v_end loop
        if v_sched.schedule_type = 'one_time' or
           (v_sched.day_of_week is not null and extract(dow from v_day)::int = v_sched.day_of_week) or
           (v_sched.day_of_month is not null and extract(day from v_day)::int = v_sched.day_of_month) or
           (v_sched.day_of_week is null and v_sched.day_of_month is null and v_sched.schedule_type = 'recurring')
        then
          v_start := (v_day::text || ' ' || coalesce(v_sched.start_time::text, '09:00'))::timestamptz;

          -- skip if WO already exists same day/property/description marker
          if not exists (
            select 1 from public.work_orders w
            where w.workspace_id = v_c.workspace_id
              and w.property_id = v_c.property_id
              and w.contract_id = v_c.id
              and w.contract_service_id = v_cs.id
              and w.scheduled_start::date = v_day
              and w.status <> 'cancelled'
          ) then
            v_wo_num := 'WO-' || to_char(v_day, 'YYYYMMDD') || '-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);

            insert into public.work_orders (
              workspace_id, work_order_number, property_id, contract_id, contract_service_id,
              source_type, priority, status, scheduled_start,
              estimated_duration_minutes, description, site_instructions, created_by
            ) values (
              v_c.workspace_id,
              upper(v_wo_num),
              v_c.property_id,
              v_c.id,
              v_cs.id,
              'contract_schedule',
              'normal',
              'scheduled',
              v_start,
              v_sched.duration_minutes,
              coalesce(v_cs.scope_description, v_c.name),
              v_sched.instructions,
              auth.uid()
            );
            v_count := v_count + 1;
          end if;
        end if;
        v_day := v_day + 1;
      end loop;
    end loop;
  end loop;

  return v_count;
end;
$$;

revoke all on function public.generate_work_orders_from_contract(uuid, int) from public;
grant execute on function public.generate_work_orders_from_contract(uuid, int) to authenticated;

-- ---------------------------------------------------------------------------
-- 6) Complete work order → draft invoice
-- ---------------------------------------------------------------------------
create or replace function public.complete_work_order_with_invoice(p_work_order_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_w public.work_orders%rowtype;
  v_org uuid;
  v_inv uuid;
  v_num text;
  v_amount numeric := 0;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select * into v_w from public.work_orders where id = p_work_order_id for update;
  if not found then raise exception 'work order not found'; end if;
  if not public.is_workspace_member(v_w.workspace_id) then
    raise exception 'not a member of workspace';
  end if;
  if v_w.status in ('cancelled') then
    raise exception 'cannot complete cancelled work order';
  end if;

  update public.work_orders
  set status = 'completed', completed_at = coalesce(completed_at, now()), updated_at = now()
  where id = p_work_order_id;

  select coalesce(p.primary_customer_organization_id, c.organization_id)
  into v_org
  from public.properties p
  left join public.contracts c on c.id = v_w.contract_id
  where p.id = v_w.property_id;

  if v_org is null then
    return null; -- completed but no bill-to
  end if;

  if v_w.contract_service_id is not null then
    select coalesce(cs.contract_price, 0) into v_amount
    from public.contract_services cs where cs.id = v_w.contract_service_id;
  end if;

  v_num := 'INV-' || to_char(now(), 'YYYYMMDD') || '-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 6);

  insert into public.invoices (
    workspace_id, invoice_number, organization_id, property_id, contract_id,
    status, invoice_date, due_date, subtotal, tax, total
  ) values (
    v_w.workspace_id, upper(v_num), v_org, v_w.property_id, v_w.contract_id,
    'draft', current_date, current_date + 30, coalesce(v_amount, 0), 0, coalesce(v_amount, 0)
  )
  returning id into v_inv;

  return v_inv;
end;
$$;

revoke all on function public.complete_work_order_with_invoice(uuid) from public;
grant execute on function public.complete_work_order_with_invoice(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 7) Next-action engine (unified queue)
-- ---------------------------------------------------------------------------
create or replace view public.v_next_actions
with (security_invoker = true)
as
-- Unassigned work due today / overdue schedule
select
  w.workspace_id,
  'work_order'::text as action_type,
  'Assign / dispatch'::text as title,
  coalesce(w.description, w.work_order_number) as detail,
  w.id as entity_id,
  'work_orders'::text as entity_table,
  coalesce(w.scheduled_start, w.created_at) as due_at,
  case w.priority
    when 'emergency' then 100
    when 'urgent' then 90
    when 'high' then 70
    else 50
  end as priority_score,
  '/dispatch'::text as href
from public.work_orders w
where w.status in ('draft','scheduled','assigned')
  and not exists (
    select 1 from public.work_order_assignments a
    where a.work_order_id = w.id and a.status = 'assigned'
  )

union all

-- Critical / high open issues
select
  i.workspace_id,
  'issue',
  'Resolve issue',
  i.title,
  i.id,
  'issues',
  coalesce(i.due_at, i.reported_at),
  case i.severity when 'critical' then 95 when 'high' then 80 else 40 end,
  '/issues'
from public.issues i
where i.status in ('open','in_progress','blocked')
  and i.severity in ('critical','high')

union all

-- Stale or due outreach targets
select
  t.workspace_id,
  'outreach',
  coalesce(t.next_action, 'Follow up target'),
  coalesce(t.organization_name, t.contact_name, 'Target'),
  t.id,
  'outreach_targets',
  coalesce(t.next_action_due_at, t.last_touch_at, t.created_at),
  coalesce(t.score, 30)::int,
  '/targets'
from public.outreach_targets t
where t.status in ('queued','contacted','responded')
  and (
    t.next_action_due_at is null
    or t.next_action_due_at <= now() + interval '2 days'
    or t.last_touch_at is null
    or t.last_touch_at < now() - interval '14 days'
  )

union all

-- Contract renewals within 60 days
select
  c.workspace_id,
  'renewal',
  'Renewal approaching',
  c.name,
  c.id,
  'contracts',
  c.end_date::timestamptz,
  75,
  '/contracts'
from public.contracts c
where c.status in ('active','renewal_pending')
  and c.end_date is not null
  and c.end_date <= current_date + 60

union all

-- Open follow-up tasks
select
  tk.workspace_id,
  'task',
  tk.title,
  coalesce(tk.description, ''),
  tk.id,
  'tasks',
  coalesce(tk.due_at, tk.created_at),
  case tk.priority when 'emergency' then 100 when 'urgent' then 90 when 'high' then 70 else 45 end,
  case
    when tk.outreach_target_id is not null then '/targets'
    when tk.work_order_id is not null then '/work-orders'
    when tk.issue_id is not null then '/issues'
    else '/dashboard'
  end
from public.tasks tk
where tk.status in ('open','in_progress');

grant select on public.v_next_actions to authenticated;

-- ---------------------------------------------------------------------------
-- 8) Seed default PM sequence template function (per workspace, callable)
-- ---------------------------------------------------------------------------
create or replace function public.ensure_default_pm_sequence(p_workspace_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not public.is_workspace_member(p_workspace_id) then
    raise exception 'not a member of workspace';
  end if;

  select id into v_id from public.outreach_sequences
  where workspace_id = p_workspace_id and name = 'PM Intro – 3 touch'
  limit 1;

  if v_id is not null then return v_id; end if;

  insert into public.outreach_sequences (workspace_id, name, description)
  values (
    p_workspace_id,
    'PM Intro – 3 touch',
    'Call, email follow-up, then final check-in for property management accounts.'
  ) returning id into v_id;

  insert into public.outreach_sequence_steps (workspace_id, sequence_id, step_order, channel, delay_days, title, body_template)
  values
    (p_workspace_id, v_id, 1, 'call', 0, 'Intro call – confirm decision maker',
     'Call the PM. Confirm who handles trades, pain points (turnover, emergencies), and ask for a pilot building.'),
    (p_workspace_id, v_id, 2, 'email', 2, 'Send capability one-pager',
     'Email SLA sheet + insurance + 2 relevant job photos. Propose a 1-building pilot.'),
    (p_workspace_id, v_id, 3, 'task', 5, 'Final follow-up / book site walk',
     'If no reply, final call. Goal: schedule site walk or mark do-not-contact.');

  return v_id;
end;
$$;

revoke all on function public.ensure_default_pm_sequence(uuid) from public;
grant execute on function public.ensure_default_pm_sequence(uuid) to authenticated;

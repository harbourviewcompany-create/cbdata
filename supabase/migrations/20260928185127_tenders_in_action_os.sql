create or replace view public.v_next_actions
with (security_invoker = true)
as
select
  w.workspace_id,
  'work_order'::text as action_type,
  'Assign / dispatch'::text as title,
  coalesce(w.description, w.work_order_number) as detail,
  w.id as entity_id,
  'work_orders'::text as entity_table,
  coalesce(w.scheduled_start, w.created_at) as due_at,
  case w.priority when 'emergency' then 100 when 'urgent' then 90 when 'high' then 70 else 50 end as priority_score,
  '/dispatch'::text as href
from public.work_orders w
where w.status in ('draft','scheduled','assigned')
  and not exists (
    select 1 from public.work_order_assignments a
    where a.work_order_id=w.id and a.status='assigned'
  )

union all

select i.workspace_id,'issue','Resolve issue',i.title,i.id,'issues',
  coalesce(i.due_at,i.reported_at),
  case i.severity when 'critical' then 95 when 'high' then 80 else 40 end,
  '/issues'
from public.issues i
where i.status in ('open','in_progress','blocked')
  and i.severity in ('critical','high')

union all

select t.workspace_id,'outreach',coalesce(t.next_action,'Follow up target'),
  coalesce(t.organization_name,t.contact_name,'Target'),t.id,'outreach_targets',
  coalesce(t.next_action_due_at,t.last_touch_at,t.created_at),
  coalesce(t.score,30)::int,'/targets'
from public.outreach_targets t
where t.status in ('queued','contacted','responded')
  and (
    t.next_action_due_at is null
    or t.next_action_due_at <= now()+interval '2 days'
    or t.last_touch_at is null
    or t.last_touch_at < now()-interval '14 days'
  )

union all

select c.workspace_id,'renewal','Renewal approaching',c.name,c.id,'contracts',
  c.end_date::timestamptz,75,'/contracts'
from public.contracts c
where c.status in ('active','renewal_pending')
  and c.end_date is not null
  and c.end_date <= current_date+60

union all

select tk.workspace_id,'task',tk.title,coalesce(tk.description,''),tk.id,'tasks',
  coalesce(tk.due_at,tk.created_at),
  case tk.priority when 'emergency' then 100 when 'urgent' then 90 when 'high' then 70 else 45 end,
  case
    when tk.outreach_target_id is not null then '/targets'
    when tk.work_order_id is not null then '/work-orders'
    when tk.issue_id is not null then '/issues'
    else '/dashboard'
  end
from public.tasks tk
where tk.status in ('open','in_progress')

union all

select
  tr.workspace_id,
  'tender'::text,
  coalesce(tr.next_action,'Review tender')::text,
  tr.title,
  tr.id,
  'tender_records'::text,
  coalesce(tr.next_action_due_at, (tr.closing_date::timestamp + time '12:00') at time zone 'America/Toronto'),
  least(100,
    case
      when tr.closing_date <= current_date + 2 then 95
      when tr.closing_date <= current_date + 7 then 85
      when tr.closing_date <= current_date + 14 then 70
      else 50
    end
    + case when tr.action_state in ('pricing','review') then 5 else 0 end
  ),
  '/procurement/' || tr.id::text
from public.tender_records tr
where tr.action_state in ('new','qualifying','pursuing','pricing','review')
  and tr.closing_date is not null
  and tr.closing_date >= current_date
  and (
    tr.closing_date <= current_date + 14
    or tr.next_action_due_at is null
    or tr.next_action_due_at <= now() + interval '2 days'
  );

grant select on public.v_next_actions to authenticated;

create or replace function public.next_actions(p_workspace_id uuid, p_limit integer default 25)
returns table(
  workspace_id uuid,
  action_type text,
  title text,
  detail text,
  entity_id uuid,
  due_at timestamptz,
  priority_score integer,
  href text
)
language plpgsql
set search_path to 'public'
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit,25),1),100);
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not private.is_workspace_member(p_workspace_id) then raise exception 'not a member of workspace'; end if;

  return query
  with arms as (
    select * from (
      select w.workspace_id,'work_order'::text,'Assign / dispatch'::text,
        coalesce(w.description,w.work_order_number),w.id,
        coalesce(w.scheduled_start,w.created_at),
        case w.priority when 'emergency' then 100 when 'urgent' then 90 when 'high' then 70 else 50 end,
        '/work-orders/'||w.id::text
      from public.work_orders w
      where w.workspace_id=p_workspace_id
        and w.status in ('draft','scheduled','assigned')
        and not exists (
          select 1 from public.work_order_assignments a
          where a.work_order_id=w.id and a.status='assigned' and a.unassigned_at is null
        )
      order by 7 desc,6
      limit v_limit
    ) q1

    union all

    select * from (
      select i.workspace_id,'issue'::text,'Resolve issue'::text,i.title,i.id,
        coalesce(i.due_at,i.reported_at),
        case i.severity when 'critical' then 95 when 'high' then 80 else 40 end,
        '/issues/'||i.id::text
      from public.issues i
      where i.workspace_id=p_workspace_id
        and i.status in ('open','in_progress','blocked')
        and i.severity in ('critical','high')
      order by 7 desc,6
      limit v_limit
    ) q2

    union all

    select * from (
      select t.workspace_id,'outreach'::text,coalesce(t.next_action,'Follow up target')::text,
        coalesce(t.organization_name,t.contact_name,'Target')::text,t.id,
        coalesce(t.next_action_due_at,t.last_touch_at,t.created_at),
        coalesce(t.score,30)::integer,
        '/targets/'||t.id::text
      from public.outreach_targets t
      where t.workspace_id=p_workspace_id
        and t.status in ('queued','contacted','responded')
        and (
          t.next_action_due_at is null
          or t.next_action_due_at <= now()+interval '2 days'
          or t.last_touch_at is null
          or t.last_touch_at < now()-interval '14 days'
        )
      order by 7 desc,6
      limit v_limit
    ) q3

    union all

    select * from (
      select c.workspace_id,'renewal'::text,'Renewal approaching'::text,c.name,c.id,
        c.end_date::timestamptz,75,
        '/contracts/'||c.id::text
      from public.contracts c
      where c.workspace_id=p_workspace_id
        and c.status in ('active','renewal_pending')
        and c.end_date is not null
        and c.end_date <= current_date+60
      order by 6
      limit v_limit
    ) q4

    union all

    select * from (
      select t.workspace_id,'task'::text,t.title,coalesce(t.description,''),t.id,
        coalesce(t.due_at,t.created_at),
        case t.priority when 'emergency' then 100 when 'urgent' then 90 when 'high' then 70 else 45 end,
        case
          when t.outreach_target_id is not null then '/targets/'||t.outreach_target_id::text
          when t.work_order_id is not null then '/work-orders/'||t.work_order_id::text
          when t.issue_id is not null then '/issues/'||t.issue_id::text
          else '/dashboard'
        end
      from public.tasks t
      where t.workspace_id=p_workspace_id
        and t.status in ('open','in_progress')
      order by 7 desc,6
      limit v_limit
    ) q5

    union all

    select * from (
      select tr.workspace_id,'tender'::text,
        coalesce(tr.next_action,'Review tender')::text,
        tr.title,tr.id,
        coalesce(tr.next_action_due_at,(tr.closing_date::timestamp + time '12:00') at time zone 'America/Toronto'),
        least(100,
          case
            when tr.closing_date <= current_date+2 then 95
            when tr.closing_date <= current_date+7 then 85
            when tr.closing_date <= current_date+14 then 70
            else 50
          end
          + case when tr.action_state in ('pricing','review') then 5 else 0 end
        ),
        '/procurement/'||tr.id::text
      from public.tender_records tr
      where tr.workspace_id=p_workspace_id
        and tr.action_state in ('new','qualifying','pursuing','pricing','review')
        and tr.closing_date is not null
        and tr.closing_date >= current_date
        and (
          tr.closing_date <= current_date+14
          or tr.next_action_due_at is null
          or tr.next_action_due_at <= now()+interval '2 days'
        )
      order by 7 desc,6
      limit v_limit
    ) q6
  )
  select arms.column1,arms.column2,arms.column3,arms.column4,
         arms.column5,arms.column6,arms.column7,arms.column8
  from arms
  order by arms.column7 desc,arms.column6 nulls last
  limit v_limit;
end
$$;

revoke all on function public.next_actions(uuid,integer) from public;
grant execute on function public.next_actions(uuid,integer) to authenticated;
grant execute on function public.next_actions(uuid,integer) to service_role;

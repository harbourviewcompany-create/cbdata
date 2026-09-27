create or replace function public.refresh_workspace_ops_snapshot(p_workspace_id uuid)
returns public.workspace_ops_snapshots
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $function$
declare
  v_row public.workspace_ops_snapshots%rowtype;
begin
  if p_workspace_id is null then raise exception 'workspace is required'; end if;
  if not exists (select 1 from public.workspaces w where w.id=p_workspace_id) then
    raise exception 'workspace not found' using errcode='22023';
  end if;
  insert into public.workspace_ops_snapshots (
    workspace_id,property_count,open_work_count,open_issue_count,renewal_count,
    needs_dispatch_count,open_task_count,overdue_task_count,updated_at
  )
  select p_workspace_id,
    (select count(*) from public.properties p where p.workspace_id=p_workspace_id and p.archived_at is null),
    (select count(*) from public.open_work_exceptions w where w.workspace_id=p_workspace_id),
    (select count(*) from public.open_issue_queue i where i.workspace_id=p_workspace_id),
    (select count(*) from public.contract_renewal_queue c where c.workspace_id=p_workspace_id and c.end_date<=current_date+60),
    (select count(*) from public.work_orders w where w.workspace_id=p_workspace_id and w.status in ('draft','scheduled','assigned','en_route','in_progress','paused','needs_review') and not exists (select 1 from public.work_order_assignments a where a.work_order_id=w.id and a.status='assigned' and a.unassigned_at is null)),
    (select count(*) from public.tasks t where t.workspace_id=p_workspace_id and t.status in ('open','in_progress')),
    (select count(*) from public.tasks t where t.workspace_id=p_workspace_id and t.status in ('open','in_progress') and t.due_at<now()),
    now()
  on conflict(workspace_id) do update set
    property_count=excluded.property_count,open_work_count=excluded.open_work_count,
    open_issue_count=excluded.open_issue_count,renewal_count=excluded.renewal_count,
    needs_dispatch_count=excluded.needs_dispatch_count,open_task_count=excluded.open_task_count,
    overdue_task_count=excluded.overdue_task_count,updated_at=excluded.updated_at
  returning * into v_row;
  return v_row;
end
$function$;
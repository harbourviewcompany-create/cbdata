begin;

do $$
declare
  view_sql text;
  fn_sql text;
begin
  select pg_get_viewdef('public.v_next_actions'::regclass,true) into view_sql;
  if position('tender_records' in view_sql)=0 or position('/procurement/' in view_sql)=0 then
    raise exception 'v_next_actions does not surface tender actions';
  end if;

  select pg_get_functiondef(p.oid)
  into fn_sql
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and p.proname='next_actions'
    and pg_get_function_identity_arguments(p.oid)='p_workspace_id uuid, p_limit integer';

  if fn_sql is null or position('tender_records' in fn_sql)=0 or position('/procurement/' in fn_sql)=0 then
    raise exception 'next_actions does not surface tender actions';
  end if;

  if has_function_privilege('anon','public.next_actions(uuid,integer)','EXECUTE') then
    raise exception 'anon must not execute next_actions';
  end if;
end $$;

rollback;

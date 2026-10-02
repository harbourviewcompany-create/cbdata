begin;

do $$
declare
  fn text;
  idx_count integer;
begin
  select count(*) into idx_count
  from pg_indexes
  where schemaname='public'
    and tablename='contact_enrichment_tasks'
    and indexname='contact_enrichment_tasks_active_org_role_uidx'
    and indexdef like '%organization_id%'
    and indexdef like '%missing_role%';

  if idx_count<>1 then
    raise exception 'organization/role active-task dedupe index missing';
  end if;

  select pg_get_functiondef(
    'private.refresh_contact_enrichment_queue(uuid)'::regprocedure
  ) into fn;

  if position('DISTINCT ON' in upper(fn))=0 then
    raise exception 'research queue refresh must dedupe by organization and role';
  end if;

  if position('t.organization_id is not null' in lower(fn))=0 then
    raise exception 'research queue refresh must require a canonical organization';
  end if;
end $$;

rollback;

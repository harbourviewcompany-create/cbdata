begin;

do $$
declare
  v_unique boolean;
  v_partial boolean;
begin
  select i.indisunique, i.indpred is not null
    into v_unique, v_partial
  from pg_index i
  join pg_class c on c.oid=i.indexrelid
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public'
    and c.relname='outreach_inbound_events_provider_message_uidx';

  if not coalesce(v_unique,false) then
    raise exception 'inbound provider/message index must be unique';
  end if;

  if coalesce(v_partial,false) then
    raise exception 'inbound provider/message unique index must not be partial for PostgREST upsert';
  end if;
end $$;

rollback;

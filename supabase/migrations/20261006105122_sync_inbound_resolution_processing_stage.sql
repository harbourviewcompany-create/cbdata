create or replace function public.sync_outreach_inbound_processing_stage()
returns trigger
language plpgsql
set search_path=pg_catalog,public
as $$
begin
  if new.status='matched' and new.reply_id is not null then
    new.processing_stage:='actioned';
    new.finalized_at:=coalesce(new.finalized_at,now());
    new.last_error:=null;
  elsif new.status in ('unmatched','ambiguous') then
    new.processing_stage:='unresolved';
    new.finalized_at:=coalesce(new.finalized_at,now());
  elsif new.status='pending_content' then
    new.processing_stage:='pending_content';
  elsif new.status='error' then
    new.processing_stage:='error';
  elsif new.status='dead_letter' then
    new.processing_stage:='dead_letter';
    new.dead_letter_at:=coalesce(new.dead_letter_at,now());
  end if;
  return new;
end
$$;

drop trigger if exists trg_sync_outreach_inbound_processing_stage on public.outreach_inbound_events;
create trigger trg_sync_outreach_inbound_processing_stage
before insert or update of status,reply_id
on public.outreach_inbound_events
for each row execute function public.sync_outreach_inbound_processing_stage();

revoke all on function public.sync_outreach_inbound_processing_stage() from public,anon,authenticated;

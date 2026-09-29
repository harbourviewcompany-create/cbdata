-- Automatically route high-confidence procurement opportunities into Bid OS.
create or replace function private.route_procurement_pursuits(p_workspace uuid)
returns table(promoted integer, refreshed integer)
language plpgsql security invoker set search_path=''
as $$
declare o record; v_tender uuid; v_promoted integer:=0; v_refreshed integer:=0;
begin
 perform private.refresh_procurement_decision_fields(p_workspace);
 for o in
   select * from public.procurement_opportunities
   where workspace_id=p_workspace
     and bid_recommendation='pursue'
     and (closing_at is null or closing_at>=now()+interval '24 hours')
   order by bid_score desc, closing_at nulls last
 loop
   if o.promoted_tender_record_id is not null then
     update public.tender_records set
       fit_score=coalesce(o.bid_score,fit_score),
       fit_note='Automated Bid Score '||round(coalesce(o.bid_score,0))::text||'/100. Review mandatory requirements and scope.',
       next_action=case when action_state in ('new','qualifying') then 'Complete bid/no-bid qualification and mandatory requirement review' else next_action end,
       updated_at=now()
     where id=o.promoted_tender_record_id and workspace_id=p_workspace;
     v_refreshed:=v_refreshed+1;
     continue;
   end if;

   select id into v_tender from public.tender_records
   where workspace_id=p_workspace and source=o.source_key and external_id=o.external_id
   limit 1;

   if v_tender is null then
     insert into public.tender_records(
       workspace_id,source,external_id,title,buyer_name,category,region,published_date,closing_date,
       source_url,status,action_state,next_action,response_mode,fit_score,fit_note,matched_organization_id,
       raw_payload,last_verified_at,updated_at
     ) values (
       p_workspace,o.source_key,o.external_id,o.title,o.buyer_name,o.category,o.region,o.published_at::date,o.closing_at::date,
       o.source_url,'new','qualifying','Complete bid/no-bid qualification and mandatory requirement review','formal_tender',
       o.bid_score,'Auto-promoted from Procurement Inbox at Bid Score '||round(coalesce(o.bid_score,0))::text||'/100.',
       o.matched_organization_id,o.raw_payload,now(),now()
     ) returning id into v_tender;
   end if;

   update public.procurement_opportunities set promoted_tender_record_id=v_tender,classification_status='promoted',updated_at=now()
   where id=o.id;

   insert into public.tender_requirements(workspace_id,tender_record_id,requirement_type,title,description,mandatory,status)
   values(p_workspace,v_tender,'compliance','Review mandatory solicitation requirements','Capture mandatory clauses, forms, certifications, bonding, insurance, site visits and submission evidence.',true,'pending')
   on conflict(tender_record_id,title) do nothing;

   if o.closing_at is not null then
     insert into public.tender_deadlines(workspace_id,tender_record_id,deadline_type,title,due_at,mandatory,status)
     values(p_workspace,v_tender,'submission','Tender submission deadline',o.closing_at,true,'open')
     on conflict(tender_record_id,deadline_type,due_at) do nothing;
   end if;
   v_promoted:=v_promoted+1;
 end loop;
 return query select v_promoted,v_refreshed;
end $$;

revoke all on function private.route_procurement_pursuits(uuid) from public,anon,authenticated;
grant execute on function private.route_procurement_pursuits(uuid) to service_role;

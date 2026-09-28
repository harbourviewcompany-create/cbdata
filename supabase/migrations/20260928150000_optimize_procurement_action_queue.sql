-- Normalize the current CanadaBuys action queue around deadline urgency and evidence gaps.
-- Idempotent: only updates existing CanadaBuys records and preserves manual progress states.

update public.tender_records
set action_state=case
  when closing_date=current_date then 'urgent'
  when closing_date<=current_date+2 then 'urgent'
  when next_action is null then 'review'
  else action_state
end,
next_action=case
  when external_id='qc20167339' then 'Confirm closing time and complete immediate bid/eligibility review'
  when external_id='cb-660-38052142' then 'Review latest amendments and mandatory response requirements'
  when external_id='qc20170761' then 'Pull official SEAO package and verify route map, security and procurement contact'
  when external_id='cb-708-64614973' then 'Review mandatory site visits, security and Ottawa site scope'
  when next_action is null then 'Review solicitation package and assign bid decision'
  else next_action
end,
next_action_due_at=case
  when external_id='qc20167339' then now()
  when external_id='cb-660-38052142' then least(coalesce(next_action_due_at, now()+interval '1 day'), now()+interval '1 day')
  when external_id='qc20170761' then least(coalesce(next_action_due_at, now()+interval '3 days'), now()+interval '3 days')
  when external_id='cb-708-64614973' then least(coalesce(next_action_due_at, now()+interval '5 days'), now()+interval '5 days')
  else next_action_due_at
end,
updated_at=now()
where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'::uuid
  and source='CanadaBuys'
  and closing_date>=current_date;

-- A reported contact is useful intelligence, but it is not equivalent to a source-verified contact.
update public.tender_records tr
set next_action=case
  when tr.external_id='qc20167339' then 'Verify Eve-Marie Leduc as procurement contact; confirm closing time'
  when tr.external_id='qc20170761' then 'Find and verify Gatineau procurement authority; pull official SEAO package'
  else tr.next_action
end,
updated_at=now()
where tr.workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'::uuid
  and tr.source='CanadaBuys'
  and tr.external_id in ('qc20167339','qc20170761');
-- Preserve individual awarded contracts when a buyer has multiple scopes ending on the same date.

alter table public.procurement_contract_cycles
  add column if not exists contract_title text;

drop index if exists public.procurement_contract_cycles_natural_uidx;
create unique index procurement_contract_cycles_natural_uidx
  on public.procurement_contract_cycles(
    workspace_id,
    lower(buyer_name),
    lower(coalesce(contract_title,service_category)),
    coalesce(contract_end_date,'9999-12-31'::date),
    coalesce(source_tender_id,'00000000-0000-0000-0000-000000000000'::uuid)
  );

delete from public.procurement_future_opportunities
where signal_type='award_rebid'
  and contract_cycle_id in (
    select id from public.procurement_contract_cycles
    where notes like 'Award-derived contract cycle.%'
  );

delete from public.procurement_contract_cycles
where notes like 'Award-derived contract cycle.%';

create or replace function private.refresh_procurement_contract_cycles()
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_cycles integer := 0;
  v_future integer := 0;
begin
  insert into public.procurement_contract_cycles(
    workspace_id,organization_id,buyer_name,contract_title,service_category,incumbent_name,award_value,currency,
    contract_start_date,contract_end_date,expected_rebid_date,confidence,evidence_url,source,notes,
    status,last_verified_at
  )
  select
    a.workspace_id,
    b.organization_id,
    a.buyer_name,
    a.title,
    coalesce(
      nullif(array_to_string(array(select jsonb_array_elements_text(coalesce(a.raw_payload->'service_fit','[]'::jsonb))),', '),''),
      nullif(array_to_string(o.service_fit,', '),''),
      nullif(o.category,''),
      'procurement services'
    ),
    a.awarded_to,
    a.award_amount,
    coalesce(a.currency,'CAD'),
    a.contract_start_date,
    a.contract_end_date,
    coalesce(a.expected_rebid_date,case when a.contract_end_date is not null then a.contract_end_date-180 else null end),
    case when a.contract_end_date is not null then 'high' else 'medium' end,
    a.source_url,
    a.source_key,
    'Award-derived contract cycle. Expected rebid may be inferred from contract end date.',
    case
      when a.contract_end_date is null then 'unknown'
      when a.contract_end_date < current_date then 'expired'
      when coalesce(a.expected_rebid_date,a.contract_end_date-180) <= current_date + 180 then 'recompete_expected'
      else 'active'
    end,
    now()
  from public.procurement_awards a
  left join public.procurement_buyers b
    on b.workspace_id=a.workspace_id and (
      b.buyer_key=a.buyer_key or lower(b.display_name)=lower(a.buyer_name)
    )
  left join lateral (
    select po.service_fit,po.category
    from public.procurement_opportunities po
    where po.workspace_id=a.workspace_id
      and (po.buyer_key=a.buyer_key or lower(coalesce(po.buyer_name,''))=lower(a.buyer_name))
      and lower(po.title)=lower(a.title)
    order by po.last_seen_at desc
    limit 1
  ) o on true
  on conflict do nothing;
  get diagnostics v_cycles = row_count;

  insert into public.procurement_contract_cycles(
    workspace_id,organization_id,source_tender_id,buyer_name,contract_title,service_category,incumbent_name,
    award_value,currency,contract_start_date,contract_end_date,expected_rebid_date,confidence,
    evidence_url,source,notes,status,last_verified_at
  )
  select
    t.workspace_id,t.matched_organization_id,t.id,coalesce(t.buyer_name,'Unknown buyer'),t.title,
    coalesce(nullif(t.watch_query,''),nullif(t.category,''),'procurement services'),
    t.incumbent_name,t.previous_award_value,coalesce(t.currency,'CAD'),t.contract_start_date,
    t.contract_end_date,coalesce(t.expected_rebid_date,case when t.contract_end_date is not null then t.contract_end_date-180 else null end),
    case when t.contract_end_date is not null or t.expected_rebid_date is not null then 'high' else 'medium' end,
    t.source_url,t.source,'Tender-derived contract cycle.',
    case
      when t.contract_end_date is not null and t.contract_end_date < current_date then 'expired'
      when coalesce(t.expected_rebid_date,t.contract_end_date-180) <= current_date + 180 then 'recompete_expected'
      else 'active'
    end,
    coalesce(t.last_verified_at,now())
  from public.tender_records t
  where t.contract_end_date is not null
     or t.expected_rebid_date is not null
     or t.incumbent_name is not null
     or t.previous_award_value is not null
  on conflict do nothing;

  insert into public.procurement_future_opportunities(
    workspace_id,contract_cycle_id,organization_id,buyer_name,title,service_category,signal_type,
    expected_publish_start,expected_publish_end,fit_score,confidence,status,source_url,evidence,
    next_action,next_action_at
  )
  select
    c.workspace_id,c.id,c.organization_id,c.buyer_name,
    'Prepare for rebid — '||coalesce(c.contract_title,c.service_category),
    c.service_category,'award_rebid',
    coalesce(c.expected_rebid_date,c.contract_end_date-180)-60,
    coalesce(c.expected_rebid_date,c.contract_end_date-180)+60,
    least(100,greatest(0,coalesce(b.watch_priority,50)
      + case when c.incumbent_name is not null then 10 else 0 end
      + case when c.award_value is not null then 5 else 0 end
      + case when c.contract_end_date is not null then 10 else 0 end)),
    c.confidence,
    case when coalesce(c.expected_rebid_date,c.contract_end_date-180) <= current_date+120 then 'pre_position' else 'watch' end,
    c.evidence_url,
    jsonb_build_object(
      'contract_title',c.contract_title,'incumbent_name',c.incumbent_name,'award_value',c.award_value,
      'contract_end_date',c.contract_end_date,'expected_rebid_date',coalesce(c.expected_rebid_date,c.contract_end_date-180),
      'source',c.source,'forecast_method',case when c.expected_rebid_date is not null then 'explicit' else 'contract_end_minus_180_days' end
    ),
    'Identify facilities/procurement decision-maker, confirm incumbent and contract options, and establish vendor position before the rebid window.',
    (coalesce(c.expected_rebid_date,c.contract_end_date-180)-120)::timestamp at time zone 'America/Toronto'
  from public.procurement_contract_cycles c
  left join public.procurement_buyers b
    on b.workspace_id=c.workspace_id and (
      b.organization_id=c.organization_id or lower(b.display_name)=lower(c.buyer_name)
    )
  where coalesce(c.expected_rebid_date,c.contract_end_date-180) is not null
    and coalesce(c.expected_rebid_date,c.contract_end_date-180) >= current_date-90
  on conflict do nothing;
  get diagnostics v_future = row_count;

  update public.procurement_future_opportunities f
  set status=case
    when f.linked_tender_id is not null then 'published'
    when f.expected_publish_end is not null and f.expected_publish_end < current_date then 'closed'
    when f.expected_publish_start is not null and f.expected_publish_start <= current_date+120 then 'pre_position'
    else 'watch'
  end,updated_at=now()
  where f.signal_type='award_rebid';

  update public.procurement_buyers b
  set last_award_at=x.last_award_at,next_expected_procurement_at=x.next_expected_at,updated_at=now()
  from (
    select coalesce(a.buyer_key,p.buyer_key) buyer_key,
      max(a.award_date::timestamp at time zone 'America/Toronto') as last_award_at,
      min(coalesce(a.expected_rebid_date,a.contract_end_date-180)::timestamp at time zone 'America/Toronto')
        filter(where coalesce(a.expected_rebid_date,a.contract_end_date-180)>=current_date) as next_expected_at
    from public.procurement_awards a
    left join public.procurement_buyers p
      on p.workspace_id=a.workspace_id and lower(p.display_name)=lower(a.buyer_name)
    group by coalesce(a.buyer_key,p.buyer_key)
  ) x
  where x.buyer_key is not null and b.buyer_key=x.buyer_key;

  return jsonb_build_object('cycles_inserted',v_cycles,'future_opportunities_inserted',v_future);
end;
$$;

revoke all on function private.refresh_procurement_contract_cycles() from public,anon,authenticated;
grant execute on function private.refresh_procurement_contract_cycles() to service_role;

select private.refresh_procurement_contract_cycles();

drop view if exists public.v_procurement_rebid_queue;

create view public.v_procurement_rebid_queue
with (security_invoker = true)
as
select
  f.id,f.workspace_id,f.contract_cycle_id,f.organization_id,f.buyer_name,f.title,f.service_category,
  f.signal_type,f.expected_publish_start,f.expected_publish_end,f.fit_score,f.confidence,f.status,
  f.source_url,f.evidence,f.next_action,f.next_action_at,f.linked_tender_id,
  c.contract_title,c.incumbent_name,c.award_value,c.currency,c.contract_start_date,c.contract_end_date,
  c.expected_rebid_date,c.last_verified_at,b.buyer_key,b.coverage_status,b.watch_priority,b.primary_source_key,
  max(ot.score) as target_score,bool_or(ot.id is not null) as has_target,count(distinct oc.contact_id)::integer as known_contact_count
from public.procurement_future_opportunities f
left join public.procurement_contract_cycles c on c.id=f.contract_cycle_id
left join public.procurement_buyers b
  on b.workspace_id=f.workspace_id and (b.organization_id=f.organization_id or lower(b.display_name)=lower(f.buyer_name))
left join public.outreach_targets ot on ot.workspace_id=f.workspace_id and ot.organization_id=f.organization_id
left join public.organization_contacts oc on oc.workspace_id=f.workspace_id and oc.organization_id=f.organization_id
group by f.id,c.id,b.id;

grant select on public.v_procurement_rebid_queue to authenticated;

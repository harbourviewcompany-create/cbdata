-- Procurement pursuit readiness: turn forecast intelligence into executable BD work.

alter table public.procurement_future_opportunities
  add column if not exists target_id uuid references public.outreach_targets(id) on delete set null,
  add column if not exists owner_user_id uuid references auth.users(id) on delete set null,
  add column if not exists pursuit_priority text,
  add column if not exists contact_readiness_status text not null default 'unknown'
    check (contact_readiness_status in ('ready','gap','unknown')),
  add column if not exists vendor_readiness_status text not null default 'unknown'
    check (vendor_readiness_status in ('ready','gap','expired','unknown')),
  add column if not exists routed_at timestamptz;

create index if not exists procurement_future_target_idx
  on public.procurement_future_opportunities(target_id);
create index if not exists procurement_future_owner_idx
  on public.procurement_future_opportunities(owner_user_id);
create index if not exists procurement_future_readiness_idx
  on public.procurement_future_opportunities(workspace_id,status,contact_readiness_status,vendor_readiness_status,next_action_at);

create or replace function private.refresh_procurement_pursuits()
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  w record;
  b record;
  f record;
  v_list_id uuid;
  v_org_id uuid;
  v_target_id uuid;
  v_contact_id uuid;
  v_contact_count integer;
  v_registration_status text;
  v_target_count integer := 0;
  v_org_count integer := 0;
  v_routed_count integer := 0;
begin
  -- Close the buyer-to-organization gap without inventing contact details.
  for b in
    select *
    from public.procurement_buyers
    where organization_id is null
  loop
    select o.id into v_org_id
    from public.organizations o
    where o.workspace_id=b.workspace_id
      and (
        lower(o.legal_name)=lower(b.display_name)
        or lower(coalesce(o.operating_name,''))=lower(b.display_name)
      )
    order by o.created_at
    limit 1;

    if v_org_id is null then
      insert into public.organizations(
        workspace_id,legal_name,operating_name,organization_type,status,
        primary_region,source_notes
      ) values (
        b.workspace_id,b.display_name,b.display_name,'prospect','active',
        b.region,
        'Created by Regional Procurement Coverage Engine from procurement buyer registry. Contact and company details require evidence-based enrichment.'
      )
      returning id into v_org_id;
      v_org_count := v_org_count + 1;
    end if;

    update public.procurement_buyers
    set organization_id=v_org_id,updated_at=now()
    where id=b.id;
  end loop;

  for w in select id from public.workspaces
  loop
    select id into v_list_id
    from public.outreach_lists
    where workspace_id=w.id and name='Procurement Pre-Position'
    order by created_at
    limit 1;

    if v_list_id is null then
      insert into public.outreach_lists(workspace_id,name,criteria)
      values (
        w.id,
        'Procurement Pre-Position',
        '{"engine":"regional_procurement_coverage","purpose":"pre_tender_positioning"}'::jsonb
      )
      returning id into v_list_id;
    end if;

    for f in
      select
        fo.*,
        pb.organization_id as buyer_organization_id,
        pb.region as buyer_region,
        pb.primary_source_key,
        pb.registration_url,
        pb.watch_priority,
        pc.contract_title,
        pc.incumbent_name,
        pc.contract_end_date,
        pc.expected_rebid_date
      from public.procurement_future_opportunities fo
      left join public.procurement_buyers pb
        on pb.workspace_id=fo.workspace_id
       and (
         pb.organization_id=fo.organization_id
         or lower(pb.display_name)=lower(fo.buyer_name)
       )
      left join public.procurement_contract_cycles pc on pc.id=fo.contract_cycle_id
      where fo.workspace_id=w.id
        and fo.status in ('watch','research','pre_position')
        and coalesce(fo.expected_publish_end,current_date+365) >= current_date-30
        and coalesce(fo.expected_publish_start,current_date) <= current_date+365
    loop
      v_org_id := coalesce(f.organization_id,f.buyer_organization_id);
      if v_org_id is null then
        continue;
      end if;

      select count(*)
      into v_contact_count
      from public.organization_contacts oc
      where oc.workspace_id=f.workspace_id
        and oc.organization_id=v_org_id
        and oc.end_date is null;

      select oc.contact_id
      into v_contact_id
      from public.organization_contacts oc
      where oc.workspace_id=f.workspace_id
        and oc.organization_id=v_org_id
        and oc.end_date is null
      order by oc.is_primary desc nulls last, oc.start_date desc nulls last, oc.contact_id
      limit 1;

      select sr.status into v_registration_status
      from public.supplier_registrations sr
      where sr.workspace_id=f.workspace_id
        and sr.source_key=f.primary_source_key
      order by sr.updated_at desc
      limit 1;

      select ot.id into v_target_id
      from public.outreach_targets ot
      where ot.workspace_id=f.workspace_id
        and ot.organization_id=v_org_id
        and ot.outreach_list_id=v_list_id
      order by ot.created_at
      limit 1;

      if v_target_id is null then
        insert into public.outreach_targets(
          workspace_id,outreach_list_id,organization_id,organization_name,contact_id,
          status,region,score,score_reason,priority,next_action,next_action_due_at,notes
        ) values (
          f.workspace_id,v_list_id,v_org_id,f.buyer_name,v_contact_id,
          'queued',f.buyer_region,f.fit_score,
          'Procurement pre-position signal: '||coalesce(f.contract_title,f.title),
          case when f.fit_score>=90 then 'urgent'::outreach_priority else 'high'::outreach_priority end,
          case
            when coalesce(v_contact_count,0)=0 then 'Find procurement/facilities decision-maker before the expected rebid window'
            when v_registration_status is null then 'Verify supplier registration and procurement portal readiness'
            when v_registration_status not in ('active','complete','registered','ready') then 'Complete or renew supplier registration before pursuit'
            else 'Begin pre-position outreach using award/rebid intelligence'
          end,
          coalesce(f.next_action_at,now()+interval '7 days'),
          concat_ws(' ',
            'Auto-routed from procurement future opportunity.',
            'Expected publish window:',coalesce(f.expected_publish_start::text,'unknown'),'to',coalesce(f.expected_publish_end::text,'unknown')||'.',
            case when f.incumbent_name is not null then 'Incumbent: '||f.incumbent_name||'.' else 'Incumbent requires enrichment.' end
          )
        )
        returning id into v_target_id;
        v_target_count := v_target_count + 1;
      else
        update public.outreach_targets
        set
          contact_id=coalesce(contact_id,v_contact_id),
          score=greatest(coalesce(score,0),f.fit_score),
          priority=case when f.fit_score>=90 then 'urgent'::outreach_priority else priority end,
          next_action=case
            when coalesce(v_contact_count,0)=0 then 'Find procurement/facilities decision-maker before the expected rebid window'
            when v_registration_status is null then 'Verify supplier registration and procurement portal readiness'
            when v_registration_status not in ('active','complete','registered','ready') then 'Complete or renew supplier registration before pursuit'
            else 'Begin pre-position outreach using award/rebid intelligence'
          end,
          next_action_due_at=coalesce(f.next_action_at,next_action_due_at,now()+interval '7 days'),
          updated_at=now()
        where id=v_target_id;
      end if;

      update public.procurement_future_opportunities
      set
        organization_id=v_org_id,
        target_id=v_target_id,
        pursuit_priority=case
          when fit_score>=90 and status='pre_position' then 'critical'
          when fit_score>=80 then 'high'
          when fit_score>=60 then 'medium'
          else 'watch'
        end,
        contact_readiness_status=case when coalesce(v_contact_count,0)>0 then 'ready' else 'gap' end,
        vendor_readiness_status=case
          when v_registration_status is null then 'gap'
          when v_registration_status in ('active','complete','registered','ready') then 'ready'
          when v_registration_status in ('expired','lapsed') then 'expired'
          else 'gap'
        end,
        next_action=case
          when coalesce(v_contact_count,0)=0 then 'Find procurement/facilities decision-maker before the expected rebid window'
          when v_registration_status is null then 'Verify supplier registration and procurement portal readiness'
          when v_registration_status not in ('active','complete','registered','ready') then 'Complete or renew supplier registration before pursuit'
          else 'Begin pre-position outreach using award/rebid intelligence'
        end,
        routed_at=now(),
        updated_at=now()
      where id=f.id;
      v_routed_count := v_routed_count + 1;
    end loop;
  end loop;

  return jsonb_build_object(
    'organizations_created',v_org_count,
    'targets_created',v_target_count,
    'future_opportunities_routed',v_routed_count
  );
end;
$$;

revoke all on function private.refresh_procurement_pursuits() from public,anon,authenticated;
grant execute on function private.refresh_procurement_pursuits() to service_role;

drop view if exists public.v_procurement_pursuit_queue;
create view public.v_procurement_pursuit_queue
with (security_invoker = true)
as
select
  f.id,
  f.workspace_id,
  f.buyer_name,
  f.title,
  f.service_category,
  f.expected_publish_start,
  f.expected_publish_end,
  f.fit_score,
  f.confidence,
  f.status,
  f.pursuit_priority,
  f.contact_readiness_status,
  f.vendor_readiness_status,
  f.next_action,
  f.next_action_at,
  f.target_id,
  f.owner_user_id,
  f.routed_at,
  f.source_url,
  c.contract_title,
  c.incumbent_name,
  c.award_value,
  c.currency,
  c.contract_end_date,
  c.expected_rebid_date,
  b.buyer_key,
  b.primary_source_key,
  b.coverage_status,
  b.watch_priority,
  b.registration_url,
  coalesce(contact_stats.known_contact_count,0)::integer as known_contact_count,
  sr.status as supplier_registration_status,
  sr.expires_on as supplier_registration_expires_on
from public.procurement_future_opportunities f
left join public.procurement_contract_cycles c on c.id=f.contract_cycle_id
left join public.procurement_buyers b
  on b.workspace_id=f.workspace_id
 and (b.organization_id=f.organization_id or lower(b.display_name)=lower(f.buyer_name))
left join lateral (
  select count(*)::integer as known_contact_count
  from public.organization_contacts oc
  where oc.workspace_id=f.workspace_id
    and oc.organization_id=f.organization_id
    and oc.end_date is null
) contact_stats on true
left join lateral (
  select x.status,x.expires_on
  from public.supplier_registrations x
  where x.workspace_id=f.workspace_id and x.source_key=b.primary_source_key
  order by x.updated_at desc
  limit 1
) sr on true;

grant select on public.v_procurement_pursuit_queue to authenticated;

select private.refresh_procurement_pursuits();

do $$
begin
  if exists(select 1 from cron.job where jobname='cbdata-procurement-pursuit-refresh') then
    perform cron.unschedule('cbdata-procurement-pursuit-refresh');
  end if;
  perform cron.schedule(
    'cbdata-procurement-pursuit-refresh',
    '25 10 * * *',
    'select private.refresh_procurement_pursuits();'
  );
end $$;

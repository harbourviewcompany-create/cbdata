-- Outreach Intelligence v2: buying committee coverage and ranked contact selection.
create or replace view public.v_outreach_buying_committee
with (security_invoker=true) as
select
 t.workspace_id,t.id as outreach_target_id,t.organization_id,c.id as contact_id,
 nullif(trim(coalesce(c.first_name,'')||' '||coalesce(c.last_name,'')),'') as contact_name,
 c.job_title,c.email,coalesce(c.mobile,c.phone) as phone,c.linkedin_url,c.source_url,c.source_label,c.source_confidence,c.source_verified_at,
 case
   when lower(coalesce(c.job_title,'')) ~ '(owner|president|principal|chief|vice president|vp)' then 'decision_maker'
   when lower(coalesce(c.job_title,'')) ~ '(procurement|purchas|buyer|sourcing|contracts)' then 'procurement'
   when lower(coalesce(c.job_title,'')) ~ '(facilit|building|maintenance|operations|property)' then 'operations'
   else 'influencer'
 end as buying_role,
 least(100,
   case when lower(coalesce(c.job_title,'')) ~ '(owner|president|principal|chief|vice president|vp|director)' then 35
        when lower(coalesce(c.job_title,'')) ~ '(manager|procurement|purchas|facilit|operations|property|maintenance)' then 28 else 12 end
   + case when c.email is not null then 25 else 0 end
   + case when coalesce(c.mobile,c.phone) is not null then 18 else 0 end
   + case c.source_confidence when 'high' then 15 when 'medium' then 9 else 3 end
   + case when oc.is_primary then 7 else 0 end
 )::int as contact_score
from public.outreach_targets t
join public.organization_contacts oc on oc.workspace_id=t.workspace_id and oc.organization_id=t.organization_id and oc.end_date is null
join public.contacts c on c.id=oc.contact_id and c.workspace_id=t.workspace_id
where c.status::text not in ('inactive','do_not_contact');

grant select on public.v_outreach_buying_committee to authenticated;

create or replace view public.v_outreach_contact_coverage
with (security_invoker=true) as
select t.workspace_id,t.id as outreach_target_id,
 count(distinct bc.contact_id)::int as contact_count,
 count(distinct bc.contact_id) filter(where bc.email is not null)::int as email_contact_count,
 count(distinct bc.contact_id) filter(where bc.phone is not null)::int as phone_contact_count,
 bool_or(bc.buying_role='decision_maker') as has_decision_maker,
 bool_or(bc.buying_role='operations') as has_operations,
 bool_or(bc.buying_role='procurement') as has_procurement,
 max(bc.contact_score) as best_contact_score,
 least(100,
   least(60,count(distinct bc.contact_id)::int*15)
   + case when bool_or(bc.buying_role='decision_maker') then 15 else 0 end
   + case when bool_or(bc.buying_role='operations') then 15 else 0 end
   + case when bool_or(bc.buying_role='procurement') then 10 else 0 end
 )::int as contact_coverage_score
from public.outreach_targets t
left join public.v_outreach_buying_committee bc on bc.outreach_target_id=t.id
group by t.workspace_id,t.id;

grant select on public.v_outreach_contact_coverage to authenticated;

create or replace function public.select_outreach_contact(p_target_id uuid)
returns uuid language plpgsql security invoker set search_path=public
as $$
declare t public.outreach_targets%rowtype; v_contact uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 select * into t from public.outreach_targets where id=p_target_id;
 if not found or not private.is_workspace_member(t.workspace_id) then raise exception 'target unavailable'; end if;
 select contact_id into v_contact from public.v_outreach_buying_committee
 where outreach_target_id=p_target_id order by contact_score desc,case buying_role when 'decision_maker' then 1 when 'operations' then 2 when 'procurement' then 3 else 4 end limit 1;
 if v_contact is not null then
   update public.outreach_targets ot set contact_id=v_contact,updated_at=now()
   where ot.id=p_target_id and (ot.contact_id is null or exists(
     select 1 from public.v_outreach_buying_committee cur where cur.outreach_target_id=ot.id and cur.contact_id=ot.contact_id
     and cur.contact_score < (select max(x.contact_score) from public.v_outreach_buying_committee x where x.outreach_target_id=ot.id)
   ));
 end if;
 return v_contact;
end $$;

grant execute on function public.select_outreach_contact(uuid) to authenticated;

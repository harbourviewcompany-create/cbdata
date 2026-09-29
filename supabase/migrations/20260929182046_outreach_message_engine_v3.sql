-- Outreach Message Engine v3: role/evidence strategy, quality gate, learning metadata.
alter table public.outreach_drafts
 add column if not exists strategy text,
 add column if not exists quality_flags jsonb not null default '[]'::jsonb,
 add column if not exists quality_passed boolean not null default false;

create index if not exists outreach_drafts_strategy_idx on public.outreach_drafts(workspace_id,strategy,generated_at desc);

create or replace function public.generate_outreach_draft(p_target_id uuid,p_channel text default 'email',p_objective text default 'introduction')
returns uuid language plpgsql security invoker set search_path=public as $$
declare t public.outreach_targets%rowtype; c public.contacts%rowtype; v_first text; v_property uuid; v_property_name text; v_signal text; v_signal_conf text; v_service text; v_subject text; v_body text; v_id uuid; v_cta text; v_role text; v_strategy text; v_flags jsonb:='[]'::jsonb; v_contact_verified boolean:=false; v_evidence_strength text:='weak';
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 select * into t from public.outreach_targets where id=p_target_id;
 if not found or not private.is_workspace_member(t.workspace_id) then raise exception 'target unavailable'; end if;
 if p_channel not in ('email','linkedin','call','voicemail','sms') then raise exception 'unsupported channel'; end if;
 if p_objective not in ('referral','introduction','meeting','site_walk','vendor_registration','quote') then raise exception 'unsupported objective'; end if;
 perform public.select_outreach_contact(p_target_id);
 select * into t from public.outreach_targets where id=p_target_id;
 select * into c from public.contacts where id=t.contact_id;
 v_first:=coalesce(nullif(c.first_name,''),split_part(coalesce(t.contact_name,'there'),' ',1),'there');
 v_contact_verified:=c.source_url is not null and c.source_confidence::text='high';

 select bc.buying_role into v_role from public.v_outreach_buying_committee bc where bc.outreach_target_id=t.id and bc.contact_id=c.id limit 1;
 v_role:=coalesce(v_role,'influencer');

 select p.id,p.name,case when nullif(pi.snow_scope,'') is not null then 'snow and ice' when nullif(pi.grounds_scope,'') is not null then 'grounds maintenance' when nullif(pi.janitorial_scope,'') is not null then 'common-area cleaning' else null end
 into v_property,v_property_name,v_service from public.outreach_target_properties otp join public.properties p on p.id=otp.property_id
 left join public.property_intelligence pi on pi.workspace_id=t.workspace_id and pi.property_id=p.id
 where otp.outreach_target_id=t.id order by coalesce(pi.intelligence_score,0) desc limit 1;

 select s.title,s.source_confidence into v_signal,v_signal_conf from public.target_opportunity_signals s
 left join public.outreach_target_properties otp on otp.outreach_target_id=t.id where s.workspace_id=t.workspace_id and s.status='open'
 and (s.target_id=t.id or s.organization_id=t.organization_id or s.property_id=otp.property_id) and s.source_confidence in ('high','medium')
 order by case s.source_confidence when 'high' then 1 else 2 end,coalesce(s.deadline_at,'9999-12-31') limit 1;

 v_service:=coalesce(v_service,'property maintenance');
 v_evidence_strength:=case when v_contact_verified and v_signal_conf='high' then 'strong' when v_contact_verified or v_property is not null or v_signal is not null then 'moderate' else 'weak' end;
 v_strategy:=case
   when v_evidence_strength='weak' or not v_contact_verified then 'referral_first'
   when p_objective='vendor_registration' or v_role='procurement' then 'procurement_first'
   when v_signal is not null then 'trigger_first'
   when v_property is not null then 'property_first'
   else 'role_first' end;

 if v_strategy='referral_first' then p_objective:='referral'; end if;
 v_cta:=case
  when v_strategy='referral_first' then 'Are you the right person for this, or could you point me to whoever handles these contractor decisions?'
  when v_strategy='procurement_first' then 'What is the best way for us to get set up as an approved vendor for this work?'
  when p_objective='meeting' then 'Would a quick 10-minute call next week make sense?'
  when p_objective='site_walk' then 'Would you be open to a short site walkthrough so I can understand the scope before pricing anything?'
  when p_objective='quote' then 'If you have a site coming up for review, I can price that one first so you have a direct comparison.'
  else 'Is this something you handle, and is there an upcoming opportunity where it would make sense for us to talk?' end;

 v_subject:=case when p_channel='email' then case when v_property_name is not null and v_strategy='property_first' then v_service||' at '||v_property_name when v_strategy='procurement_first' then 'vendor setup — '||v_service else v_service||' — '||coalesce(t.organization_name,'property services') end end;
 v_body:=case p_channel
 when 'email' then 'Hi '||v_first||','||E'\n\n'||
   case
    when v_strategy='referral_first' then 'I’m Tyler with CB Contracting. We handle '||v_service||' work in the Ottawa area.'
    when v_strategy='procurement_first' then 'I’m Tyler with CB Contracting. I’m looking to get properly positioned for '||v_service||' opportunities with '||coalesce(t.organization_name,'your organization')||'.'
    when v_strategy='trigger_first' then 'I’m reaching out from CB Contracting because I noticed '||v_signal||'. We handle '||v_service||' work in the Ottawa area.'
    when v_strategy='property_first' then 'I’m reaching out from CB Contracting regarding '||v_property_name||'. We handle '||v_service||' work in the Ottawa area.'
    else 'I’m Tyler with CB Contracting. I came across your role with '||coalesce(t.organization_name,'the organization')||' while looking into '||v_service||' contractor coverage.' end||
   E'\n\n'||v_cta||E'\n\nTyler\nCB Contracting'
 when 'linkedin' then 'Hi '||v_first||' — Tyler with CB Contracting. We handle '||v_service||' in Ottawa. '||v_cta
 when 'sms' then 'Hi '||v_first||' — Tyler from CB Contracting. Reaching out about '||v_service||'. '||v_cta
 when 'call' then 'Hi '||v_first||', Tyler with CB Contracting. I’m calling about '||v_service||'. '||v_cta
 else 'Hi '||v_first||', Tyler with CB Contracting. I’m reaching out about '||v_service||'. '||v_cta end;

 if length(v_body)>1000 then v_flags:=v_flags||'"too_long"'::jsonb; end if;
 if v_body ilike '%snow and ice%grounds%' or v_body ilike '%grounds%cleaning%' then v_flags:=v_flags||'"service_dumping"'::jsonb; end if;
 if v_body ilike '%just following up%' then v_flags:=v_flags||'"generic_followup"'::jsonb; end if;
 if v_strategy<>'referral_first' and not v_contact_verified then v_flags:=v_flags||'"unverified_personalization"'::jsonb; end if;
 if v_strategy='trigger_first' and v_signal_conf is null then v_flags:=v_flags||'"unsupported_trigger"'::jsonb; end if;
 if jsonb_array_length(v_flags)>0 then raise exception 'draft quality gate failed: %',v_flags::text; end if;

 insert into public.outreach_drafts(workspace_id,outreach_target_id,contact_id,property_id,channel,objective,subject,body,evidence,strategy,quality_flags,quality_passed,created_by)
 values(t.workspace_id,t.id,c.id,v_property,p_channel,p_objective,v_subject,v_body,
 jsonb_build_object('property_id',v_property,'property_name',v_property_name,'signal',v_signal,'signal_confidence',v_signal_conf,'service_angle',v_service,'contact_source',c.source_url,'contact_confidence',c.source_confidence,'contact_role',v_role,'strategy',v_strategy,'evidence_strength',v_evidence_strength,'objective',p_objective,'generated_from_verified_data',v_contact_verified),
 v_strategy,v_flags,true,auth.uid()) returning id into v_id;
 update public.outreach_targets set next_action='Review evidence-backed outreach draft',next_action_due_at=now(),updated_at=now() where id=t.id;
 return v_id;
end $$;

create or replace view public.v_outreach_message_learning with(security_invoker=true) as
select d.workspace_id,d.id draft_id,d.outreach_target_id,d.channel,d.objective,d.strategy,d.quality_passed,d.sent_at,
 d.evidence->>'contact_role' contact_role,d.evidence->>'service_angle' service_angle,d.evidence->>'evidence_strength' evidence_strength,
 exists(select 1 from public.outreach_replies r where r.outreach_target_id=d.outreach_target_id and r.created_at>=coalesce(d.sent_at,d.created_at)) has_reply
from public.outreach_drafts d where d.state='sent';
grant select on public.v_outreach_message_learning to authenticated;

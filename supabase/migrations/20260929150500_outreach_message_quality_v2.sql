-- Upgrade outreach drafts to one evidence-backed service angle and objective-specific CTAs.
create or replace function public.generate_outreach_draft(p_target_id uuid,p_channel text default 'email',p_objective text default 'introduction')
returns uuid language plpgsql security invoker set search_path=public as $$
declare t public.outreach_targets%rowtype; c public.contacts%rowtype; v_first text; v_property uuid; v_property_name text; v_signal text; v_service text; v_subject text; v_body text; v_id uuid; v_cta text;
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

 select p.id,p.name,
   case
    when nullif(pi.snow_scope,'') is not null then 'snow and ice'
    when nullif(pi.grounds_scope,'') is not null then 'grounds maintenance'
    when nullif(pi.janitorial_scope,'') is not null then 'common-area cleaning'
    else null end
 into v_property,v_property_name,v_service
 from public.outreach_target_properties otp join public.properties p on p.id=otp.property_id
 left join public.property_intelligence pi on pi.workspace_id=t.workspace_id and pi.property_id=p.id
 where otp.outreach_target_id=t.id order by coalesce(pi.intelligence_score,0) desc limit 1;

 select s.title into v_signal from public.target_opportunity_signals s
 left join public.outreach_target_properties otp on otp.outreach_target_id=t.id
 where s.workspace_id=t.workspace_id and s.status='open'
 and (s.target_id=t.id or s.organization_id=t.organization_id or s.property_id=otp.property_id)
 and s.source_confidence in ('high','medium')
 order by case s.source_confidence when 'high' then 1 else 2 end,coalesce(s.deadline_at,'9999-12-31') limit 1;

 v_service:=coalesce(v_service,'property maintenance');
 v_cta:=case p_objective
  when 'referral' then 'Are you the right person for this, or could you point me to whoever handles these contractor decisions?'
  when 'meeting' then 'Would a quick 10-minute call next week make sense?'
  when 'site_walk' then 'Would you be open to a short site walkthrough so I can understand the scope before pricing anything?'
  when 'vendor_registration' then 'What is the best way for us to get set up as an approved vendor for this work?'
  when 'quote' then 'If you have a site coming up for review, I can price that one first so you have a direct comparison.'
  else 'Is this something you handle, and is there an upcoming opportunity where it would make sense for us to talk?' end;

 v_subject:=case when p_channel='email' then
   case when v_property_name is not null then v_service||' at '||v_property_name else v_service||' — '||coalesce(t.organization_name,'property services') end
 end;

 v_body:=case p_channel
 when 'email' then 'Hi '||v_first||','||E'\n\n'||
   case when v_property_name is not null then 'I’m reaching out from CB Contracting regarding '||v_property_name||'. '
        else 'I’m reaching out from CB Contracting regarding '||coalesce(t.organization_name,'your portfolio')||'. ' end||
   'We handle '||v_service||' work in the Ottawa area.'||
   case when v_signal is not null then E'\n\n'||'I noticed '||v_signal||', which is why I thought it was worth reaching out now.' else '' end||
   E'\n\n'||v_cta||E'\n\nTyler\nCB Contracting'
 when 'linkedin' then 'Hi '||v_first||' — Tyler with CB Contracting. We handle '||v_service||' in Ottawa. '||v_cta
 when 'sms' then 'Hi '||v_first||' — Tyler from CB Contracting. Reaching out about '||v_service||' for '||coalesce(v_property_name,t.organization_name,'your properties')||'. '||v_cta
 when 'call' then 'Hi '||v_first||', Tyler with CB Contracting. I’m calling about '||v_service||' for '||coalesce(v_property_name,t.organization_name,'your properties')||'. '||v_cta
 else 'Hi '||v_first||', Tyler with CB Contracting. I’m reaching out about '||v_service||' for '||coalesce(v_property_name,t.organization_name,'your properties')||'. '||v_cta end;

 if length(v_body)>1200 or v_body ilike '%snow and ice, grounds%' then raise exception 'draft quality gate failed'; end if;
 insert into public.outreach_drafts(workspace_id,outreach_target_id,contact_id,property_id,channel,objective,subject,body,evidence,created_by)
 values(t.workspace_id,t.id,c.id,v_property,p_channel,p_objective,v_subject,v_body,
 jsonb_build_object('property_id',v_property,'property_name',v_property_name,'signal',v_signal,'service_angle',v_service,'contact_source',c.source_url,'contact_confidence',c.source_confidence,'objective',p_objective,'generated_from_verified_data',true),auth.uid())
 returning id into v_id;
 update public.outreach_targets set next_action='Review personalized outreach draft',next_action_due_at=now(),updated_at=now() where id=t.id;
 return v_id;
end $$;

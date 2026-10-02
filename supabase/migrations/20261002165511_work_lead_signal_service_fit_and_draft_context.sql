-- Carry opportunity-signal service fit into the Outreach command queue and draft generator.
create or replace view public.v_outreach_execution_queue
with (security_invoker=true) as
 WITH property_rollup AS (
         SELECT otp.workspace_id,
            otp.outreach_target_id,
            count(DISTINCT otp.property_id)::integer AS property_count,
            count(DISTINCT
                CASE
                    WHEN pi.intelligence_score >= 80::numeric THEN otp.property_id
                    ELSE NULL::uuid
                END)::integer AS high_signal_property_count,
            bool_or(NULLIF(pi.snow_scope, ''::text) IS NOT NULL) AS has_snow,
            bool_or(NULLIF(pi.grounds_scope, ''::text) IS NOT NULL) AS has_grounds,
            bool_or(NULLIF(pi.janitorial_scope, ''::text) IS NOT NULL) AS has_janitorial,
            max(pi.intelligence_score) AS max_property_score,
            max(pi.verified_at) AS property_verified_at
           FROM outreach_target_properties otp
             LEFT JOIN property_intelligence pi ON pi.workspace_id = otp.workspace_id AND pi.property_id = otp.property_id
          GROUP BY otp.workspace_id, otp.outreach_target_id
        ), signal_rollup AS (
         SELECT t.id AS outreach_target_id,
            count(DISTINCT s.id) FILTER (WHERE s.status = 'open'::text)::integer AS open_signal_count,
            bool_or(s.status = 'open'::text AND s.source_confidence = 'high'::text) AS has_high_confidence_signal,
            min(s.deadline_at) FILTER (WHERE s.status = 'open'::text AND s.deadline_at IS NOT NULL) AS nearest_deadline,
            (array_agg(s.title ORDER BY (COALESCE(s.deadline_at, '9999-12-31 00:00:00+00'::timestamp with time zone)), s.created_at DESC) FILTER (WHERE s.status = 'open'::text))[1] AS top_signal
           FROM outreach_targets t
             LEFT JOIN outreach_target_properties otp ON otp.outreach_target_id = t.id
             LEFT JOIN target_opportunity_signals s ON s.workspace_id = t.workspace_id AND s.status = 'open'::text AND (s.target_id = t.id OR s.organization_id = t.organization_id OR s.property_id = otp.property_id)
          GROUP BY t.id
        ), signal_service_rollup AS (
         SELECT t.id AS outreach_target_id,
            COALESCE(array_agg(DISTINCT svc.service) FILTER (WHERE svc.service IS NOT NULL), '{}'::text[]) AS service_fit
           FROM outreach_targets t
             LEFT JOIN outreach_target_properties otp ON otp.outreach_target_id = t.id
             LEFT JOIN target_opportunity_signals s ON s.workspace_id = t.workspace_id AND s.status = 'open'::text AND (s.target_id = t.id OR s.organization_id = t.organization_id OR s.property_id = otp.property_id)
             LEFT JOIN LATERAL unnest(COALESCE(s.service_fit, '{}'::text[])) svc(service) ON true
          GROUP BY t.id
        ), latest_draft AS (
         SELECT DISTINCT ON (d.outreach_target_id) d.outreach_target_id,
            d.id,
            d.state,
            d.subject,
            d.body,
            d.channel,
            d.sent_at,
            d.created_at
           FROM outreach_drafts d
          ORDER BY d.outreach_target_id, d.created_at DESC
        )
 SELECT q.id,
    q.workspace_id,
    q.outreach_list_id,
    q.list_name,
    q.status,
    q.score,
    q.score_reason,
    q.priority,
    q.region,
    q.next_action,
    q.next_action_due_at,
    q.last_touch_at,
    q.owner_user_id,
    q.organization_id,
    q.organization_display_name,
    q.organization_type,
    q.doors_managed,
    q.buildings_managed,
    q.organization_website,
    q.organization_phone,
    q.organization_email,
    q.organization_address,
    q.contact_id,
    q.contact_display_name,
    q.contact_job_title,
    q.contact_phone,
    q.contact_email,
    q.converted_lead_id,
    q.notes,
    q.created_at,
    q.updated_at,
    q.linked_property_count,
    q.touch_count,
    COALESCE(pr.property_count, 0) AS property_count,
    COALESCE(pr.high_signal_property_count, 0) AS high_signal_property_count,
    COALESCE(sr.open_signal_count, 0) AS open_signal_count,
    sr.nearest_deadline,
    sr.top_signal,
        CASE
            WHEN q.contact_id IS NOT NULL AND q.contact_email IS NOT NULL AND c.source_confidence = 'high'::text THEN 100
            WHEN q.contact_id IS NOT NULL AND q.contact_email IS NOT NULL THEN 90
            WHEN q.contact_id IS NOT NULL AND q.contact_phone IS NOT NULL THEN 80
            WHEN q.contact_display_name IS NOT NULL AND (q.contact_email IS NOT NULL OR q.contact_phone IS NOT NULL) THEN 70
            WHEN q.contact_email IS NOT NULL OR q.contact_phone IS NOT NULL THEN 50
            ELSE 15
        END AS contact_confidence_score,
    LEAST(100, 20 +
        CASE
            WHEN q.contact_id IS NOT NULL THEN 15
            WHEN q.contact_display_name IS NOT NULL THEN 8
            ELSE 0
        END +
        CASE
            WHEN q.contact_email IS NOT NULL THEN 15
            WHEN q.contact_phone IS NOT NULL THEN 10
            ELSE 0
        END + LEAST(20, COALESCE(pr.high_signal_property_count, 0) * 5) + LEAST(15, COALESCE(sr.open_signal_count, 0) * 5) +
        CASE
            WHEN COALESCE(sr.has_high_confidence_signal, false) THEN 10
            ELSE 0
        END +
        CASE
            WHEN q.next_action IS NOT NULL AND length(TRIM(BOTH FROM q.next_action)) >= 12 THEN 5
            ELSE 0
        END) AS outreach_readiness_score,
        CASE
            WHEN q.contact_email IS NULL AND q.contact_phone IS NULL THEN 'research'::text
            WHEN q.contact_id IS NULL THEN 'verify_contact'::text
            WHEN ld.id IS NULL THEN 'generate_draft'::text
            WHEN ld.state = 'draft'::text THEN 'review_draft'::text
            WHEN ld.state = 'approved'::text THEN 'send'::text
            WHEN q.status = 'responded'::outreach_target_status THEN 'handle_reply'::text
            WHEN q.next_action_due_at IS NOT NULL AND q.next_action_due_at <= now() THEN 'follow_up'::text
            ELSE 'nurture'::text
        END AS recommended_action,
        CASE
            WHEN sr.top_signal IS NOT NULL THEN sr.top_signal
            WHEN COALESCE(pr.high_signal_property_count, 0) > 0 THEN (COALESCE(pr.high_signal_property_count, 0)::text || ' high-signal linked propert'::text) ||
            CASE
                WHEN pr.high_signal_property_count = 1 THEN 'y'::text
                ELSE 'ies'::text
            END
            WHEN q.score_reason IS NOT NULL THEN q.score_reason
            ELSE 'Target score and service fit'::text
        END AS why_now,
    ARRAY( SELECT DISTINCT service.service
           FROM unnest(array_cat(array_remove(ARRAY[
                CASE
                    WHEN COALESCE(pr.has_snow, false) THEN 'snow'::text
                    ELSE NULL::text
                END,
                CASE
                    WHEN COALESCE(pr.has_grounds, false) THEN 'grounds'::text
                    ELSE NULL::text
                END,
                CASE
                    WHEN COALESCE(pr.has_janitorial, false) THEN 'janitorial'::text
                    ELSE NULL::text
                END], NULL::text), COALESCE(ssr.service_fit, '{}'::text[]))) service(service)
          WHERE service.service IS NOT NULL
          ORDER BY service.service) AS service_fit,
    ld.id AS latest_draft_id,
    ld.state AS latest_draft_state,
    ld.subject AS latest_draft_subject,
    ld.body AS latest_draft_body,
    ld.channel AS latest_draft_channel,
    ld.sent_at AS latest_draft_sent_at
   FROM v_outreach_target_queue q
     LEFT JOIN contacts c ON c.id = q.contact_id
     LEFT JOIN property_rollup pr ON pr.outreach_target_id = q.id
     LEFT JOIN signal_rollup sr ON sr.outreach_target_id = q.id
     LEFT JOIN signal_service_rollup ssr ON ssr.outreach_target_id = q.id
     LEFT JOIN latest_draft ld ON ld.outreach_target_id = q.id;

grant select on public.v_outreach_execution_queue to authenticated;

CREATE OR REPLACE FUNCTION public.generate_outreach_draft(p_target_id uuid, p_channel text DEFAULT 'email'::text, p_objective text DEFAULT 'introduction'::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare t public.outreach_targets%rowtype; c public.contacts%rowtype; v_first text; v_property uuid; v_property_name text; v_signal text; v_signal_conf text; v_signal_service text; v_service text; v_subject text; v_body text; v_id uuid; v_cta text; v_role text; v_strategy text; v_flags jsonb:='[]'::jsonb; v_contact_verified boolean:=false; v_evidence_strength text:='weak';
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

 select s.title,s.source_confidence,s.service_fit[1] into v_signal,v_signal_conf,v_signal_service from public.target_opportunity_signals s
 left join public.outreach_target_properties otp on otp.outreach_target_id=t.id where s.workspace_id=t.workspace_id and s.status='open'
 and (s.target_id=t.id or s.organization_id=t.organization_id or s.property_id=otp.property_id) and s.source_confidence in ('high','medium')
 order by case s.source_confidence when 'high' then 1 else 2 end,coalesce(s.deadline_at,'9999-12-31') limit 1;

 v_service:=coalesce(v_service,v_signal_service,'property maintenance');
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
end $function$


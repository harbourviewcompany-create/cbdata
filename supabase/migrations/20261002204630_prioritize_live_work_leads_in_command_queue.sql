-- Prioritize active private Work Leads and deadline urgency in the canonical Outreach command queue.
create or replace view public.v_outreach_pursuit_queue
with (security_invoker=true) as
WITH primary_row AS (
         SELECT t.pursuit_id,
            e.id,
            e.workspace_id,
            e.outreach_list_id,
            e.list_name,
            e.status,
            e.score,
            e.score_reason,
            e.priority,
            e.region,
            e.next_action,
            e.next_action_due_at,
            e.last_touch_at,
            e.owner_user_id,
            e.organization_id,
            e.organization_display_name,
            e.organization_type,
            e.doors_managed,
            e.buildings_managed,
            e.organization_website,
            e.organization_phone,
            e.organization_email,
            e.organization_address,
            e.contact_id,
            e.contact_display_name,
            e.contact_job_title,
            e.contact_phone,
            e.contact_email,
            e.converted_lead_id,
            e.notes,
            e.created_at,
            e.updated_at,
            e.linked_property_count,
            e.touch_count,
            e.property_count,
            e.high_signal_property_count,
            e.open_signal_count,
            e.nearest_deadline,
            e.top_signal,
            e.contact_confidence_score,
            e.outreach_readiness_score,
            e.recommended_action,
            e.why_now,
            e.service_fit,
            e.latest_draft_id,
            e.latest_draft_state,
            e.latest_draft_subject,
            e.latest_draft_body,
            e.latest_draft_channel,
            e.latest_draft_sent_at,
            row_number() OVER (PARTITION BY t.pursuit_id ORDER BY (
                CASE
                    WHEN (EXISTS ( SELECT 1
                       FROM outreach_replies r
                      WHERE r.outreach_target_id = t.id AND r.needs_response AND r.handled_at IS NULL)) THEN 0
                    ELSE 1
                END), e.contact_confidence_score DESC, e.outreach_readiness_score DESC, (COALESCE(e.score, 0::numeric)) DESC, t.updated_at DESC) AS rn
           FROM v_outreach_execution_queue e
             JOIN outreach_targets t ON t.id = e.id
          WHERE t.pursuit_id IS NOT NULL
        ), reply_stats AS (
         SELECT outreach_replies.pursuit_id,
            count(*)::integer AS reply_count,
            count(*) FILTER (WHERE outreach_replies.needs_response AND outreach_replies.handled_at IS NULL)::integer AS needs_response_count,
            max(outreach_replies.received_at) AS latest_reply_at
           FROM outreach_replies
          WHERE outreach_replies.pursuit_id IS NOT NULL
          GROUP BY outreach_replies.pursuit_id
        ), work_lead_rollup AS (
         SELECT l.pursuit_id,
            count(*) FILTER (WHERE l.status = 'promoted'::text AND (l.deadline_at IS NULL OR l.deadline_at >= now()))::integer AS active_work_lead_count,
            max(l.conversion_score) FILTER (WHERE l.status = 'promoted'::text AND (l.deadline_at IS NULL OR l.deadline_at >= now())) AS best_work_lead_score,
            min(l.deadline_at) FILTER (WHERE l.status = 'promoted'::text AND l.deadline_at >= now()) AS nearest_work_lead_deadline
           FROM outreach_work_leads l
          WHERE l.pursuit_id IS NOT NULL
          GROUP BY l.pursuit_id
        ), latest_reply AS (
         SELECT DISTINCT ON (outreach_replies.pursuit_id) outreach_replies.pursuit_id,
            outreach_replies.id,
            outreach_replies.classification,
            outreach_replies.classification_confidence,
            outreach_replies.summary,
            outreach_replies.body,
            outreach_replies.received_at,
            outreach_replies.needs_response
           FROM outreach_replies
          WHERE outreach_replies.pursuit_id IS NOT NULL
          ORDER BY outreach_replies.pursuit_id, outreach_replies.received_at DESC
        )
 SELECT p.workspace_id,
    p.id AS pursuit_id,
    pr.id AS primary_target_id,
    p.display_name AS organization_display_name,
    p.organization_id,
    p.owner_user_id,
    p.next_action_owner_user_id,
    p.primary_property_id,
    p.opportunity_id,
    p.stage,
    p.status AS pursuit_status,
    COALESCE(p.next_action, pr.next_action) AS next_action,
    COALESCE(p.next_action_due_at, pr.next_action_due_at) AS next_action_due_at,
    p.estimated_value,
    p.last_activity_at,
    pr.contact_display_name,
    pr.contact_email,
    pr.contact_phone,
    pr.contact_job_title,
    pr.property_count,
    pr.high_signal_property_count,
    pr.open_signal_count,
    pr.why_now,
    pr.service_fit,
    pr.recommended_action AS target_recommended_action,
    pr.latest_draft_id,
    pr.latest_draft_state,
    pr.latest_draft_subject,
    pr.latest_draft_body,
    pr.latest_draft_channel,
    COALESCE(d.quality_score, 0) AS latest_draft_quality_score,
    COALESCE(d.quality_passed, false) AS latest_draft_quality_passed,
    d.quality_notes AS latest_draft_quality_notes,
    d.evidence AS latest_draft_evidence,
    d.strategy AS latest_draft_strategy,
    COALESCE(pc.contact_count, 0) AS contact_count,
    COALESCE(pc.contact_coverage_score, 0) AS contact_coverage_score,
    COALESCE(pc.has_decision_maker, false) AS has_decision_maker,
    COALESCE(pc.has_operations, false) AS has_operations,
    COALESCE(pc.has_procurement, false) AS has_procurement,
    COALESCE(pc.has_property_contact, false) AS has_property_contact,
    sb.fit_score,
    sb.timing_score,
    sb.evidence_score,
    sb.contact_score,
    sb.committee_score,
    sb.relationship_score,
    sb.total_score,
    sb.improvement_recommendations,
    COALESCE(rs.reply_count, 0) AS reply_count,
    COALESCE(rs.needs_response_count, 0) AS needs_response_count,
    rs.latest_reply_at,
    lr.id AS latest_reply_id,
    lr.classification AS latest_reply_classification,
    lr.classification_confidence AS latest_reply_confidence,
    lr.summary AS latest_reply_summary,
    lr.body AS latest_reply_body,
    lr.needs_response AS latest_reply_needs_response,
        CASE
            WHEN COALESCE(rs.needs_response_count, 0) > 0 THEN 'handle_reply'::text
            WHEN p.opportunity_id IS NOT NULL AND p.stage = 'estimating'::text THEN 'advance_estimate'::text
            ELSE pr.recommended_action
        END AS recommended_action,
    LEAST(100, COALESCE(sb.total_score, 0) +
        CASE
            WHEN COALESCE(rs.needs_response_count, 0) > 0 THEN 15
            ELSE 0
        END +
        CASE
            WHEN COALESCE(p.next_action_due_at, pr.next_action_due_at) <= now() THEN 5
            ELSE 0
        END +
        CASE
            WHEN COALESCE(wl.best_work_lead_score, 0::numeric) >= 90::numeric THEN 20
            WHEN COALESCE(wl.best_work_lead_score, 0::numeric) >= 80::numeric THEN 15
            WHEN COALESCE(wl.best_work_lead_score, 0::numeric) >= 70::numeric THEN 10
            ELSE 0
        END +
        CASE
            WHEN wl.nearest_work_lead_deadline IS NOT NULL AND wl.nearest_work_lead_deadline <= (now() + '7 days'::interval) THEN 10
            WHEN wl.nearest_work_lead_deadline IS NOT NULL AND wl.nearest_work_lead_deadline <= (now() + '21 days'::interval) THEN 5
            ELSE 0
        END +
        CASE
            WHEN COALESCE(wl.best_work_lead_score, 0::numeric) >= 80::numeric AND COALESCE(d.quality_passed, false) AND (d.state = ANY (ARRAY['draft'::text, 'approved'::text])) THEN 5
            ELSE 0
        END) AS command_score,
    COALESCE(wl.active_work_lead_count, 0) AS active_work_lead_count,
    wl.best_work_lead_score,
    wl.nearest_work_lead_deadline
   FROM outreach_pursuits p
     JOIN primary_row pr ON pr.pursuit_id = p.id AND pr.rn = 1
     LEFT JOIN outreach_drafts d ON d.id = pr.latest_draft_id
     LEFT JOIN v_outreach_pursuit_committee pc ON pc.pursuit_id = p.id
     LEFT JOIN v_outreach_score_breakdown sb ON sb.pursuit_id = p.id
     LEFT JOIN reply_stats rs ON rs.pursuit_id = p.id
     LEFT JOIN latest_reply lr ON lr.pursuit_id = p.id
     LEFT JOIN work_lead_rollup wl ON wl.pursuit_id = p.id
  WHERE p.status <> 'archived'::text;

grant select on public.v_outreach_pursuit_queue to authenticated;

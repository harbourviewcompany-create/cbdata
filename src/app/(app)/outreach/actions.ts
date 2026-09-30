"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireWorkspaceWithRole } from "@/lib/workspace";
import { ROLES } from "@/lib/authz";
import { customerNowAction, customerNowLane, rankCustomerNow } from "@/lib/customer-now";

type DbClient = Awaited<ReturnType<typeof createClient>>;

async function client() {
  const ctx = await requireWorkspaceWithRole(ROLES.sales);
  const s = await createClient();
  return { s, user: ctx.user, workspaceId: ctx.workspaceId };
}

async function assertTargetInWorkspace(s: DbClient, targetId: string, workspaceId: string) {
  const { data, error } = await (s as any)
    .from("outreach_targets")
    .select("id,pursuit_id")
    .eq("id", targetId)
    .eq("workspace_id", workspaceId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  if (!data) throw new Error("Target is not in the active workspace");
  return data as { id: string; pursuit_id: string | null };
}

async function assertPursuitInWorkspace(s: DbClient, pursuitId: string, workspaceId: string) {
  const { data, error } = await (s as any)
    .from("outreach_pursuits")
    .select("id,primary_target_id:primary_property_id,organization_id,opportunity_id")
    .eq("id", pursuitId)
    .eq("workspace_id", workspaceId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  if (!data) throw new Error("Pursuit is not in the active workspace");
  return data as {
    id: string;
    primary_target_id: string | null;
    organization_id: string | null;
    opportunity_id: string | null;
  };
}

async function assertDraftInWorkspace(s: DbClient, draftId: string, workspaceId: string) {
  const { data, error } = await (s as any)
    .from("outreach_drafts")
    .select("id,outreach_target_id")
    .eq("id", draftId)
    .eq("workspace_id", workspaceId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  if (!data) throw new Error("Draft is not in the active workspace");
  return data as { id: string; outreach_target_id: string };
}

async function assertReplyInWorkspace(s: DbClient, replyId: string, workspaceId: string) {
  const { data, error } = await (s as any)
    .from("outreach_replies")
    .select("id,outreach_target_id,pursuit_id")
    .eq("id", replyId)
    .eq("workspace_id", workspaceId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  if (!data) throw new Error("Reply is not in the active workspace");
  return data as { id: string; outreach_target_id: string; pursuit_id: string | null };
}

function refresh(targetId?: string) {
  revalidatePath("/outreach");
  revalidatePath("/targets");
  revalidatePath("/sales");
  revalidatePath("/estimates");
  revalidatePath("/dashboard");
  if (targetId) revalidatePath(`/targets/${targetId}`);
}

export async function generateDraft(formData: FormData) {
  const { s, workspaceId } = await client();
  const targetId = String(formData.get("target_id") ?? "");
  const channel = String(formData.get("channel") ?? "email");
  const objective = String(formData.get("objective") ?? "introduction");
  await assertTargetInWorkspace(s, targetId, workspaceId);

  const { error: contactError } = await s.rpc(
    "select_outreach_contact" as never,
    { p_target_id: targetId } as never,
  );
  if (contactError) throw new Error(contactError.message);

  const { error } = await s.rpc(
    "generate_outreach_draft" as never,
    { p_target_id: targetId, p_channel: channel, p_objective: objective } as never,
  );
  if (error) throw new Error(error.message);
  refresh(targetId);
}

export async function approveDraft(formData: FormData) {
  const { s, workspaceId } = await client();
  const draftId = String(formData.get("draft_id") ?? "");
  const targetId = String(formData.get("target_id") ?? "");
  const draft = await assertDraftInWorkspace(s, draftId, workspaceId);
  if (targetId && draft.outreach_target_id !== targetId) throw new Error("Draft does not belong to target");

  const { error } = await s.rpc("approve_outreach_draft" as never, { p_draft_id: draftId } as never);
  if (error) throw new Error(error.message);
  refresh(draft.outreach_target_id);
}

export async function markSent(formData: FormData) {
  const { s, workspaceId } = await client();
  const draftId = String(formData.get("draft_id") ?? "");
  const targetId = String(formData.get("target_id") ?? "");
  const draft = await assertDraftInWorkspace(s, draftId, workspaceId);
  if (targetId && draft.outreach_target_id !== targetId) throw new Error("Draft does not belong to target");

  const { error } = await s.rpc(
    "mark_outreach_draft_sent" as never,
    {
      p_draft_id: draftId,
      p_provider: String(formData.get("provider") ?? "") || null,
      p_provider_message_id: String(formData.get("provider_message_id") ?? "") || null,
      p_provider_thread_id: String(formData.get("provider_thread_id") ?? "") || null,
    } as never,
  );
  if (error) throw new Error(error.message);
  refresh(draft.outreach_target_id);
}

export async function classifyReply(formData: FormData) {
  const { s, workspaceId } = await client();
  const targetId = String(formData.get("target_id") ?? "");
  const replyBody = String(formData.get("reply_body") ?? formData.get("summary") ?? "").trim();
  const channel = String(formData.get("channel") ?? "email");
  const classificationOverride = String(formData.get("classification_override") ?? "").trim() || null;
  const renewal = String(formData.get("renewal_date") ?? "").trim() || null;
  const referredContact = String(formData.get("referred_contact") ?? "").trim() || null;
  await assertTargetInWorkspace(s, targetId, workspaceId);
  if (!replyBody) throw new Error("Paste or summarize the reply before classifying it");

  const { error } = await s.rpc(
    "ingest_outreach_reply" as never,
    {
      p_target_id: targetId,
      p_body: replyBody,
      p_channel: channel,
      p_provider: String(formData.get("provider") ?? "") || "manual",
      p_provider_message_id: String(formData.get("provider_message_id") ?? "") || null,
      p_provider_thread_id: String(formData.get("provider_thread_id") ?? "") || null,
      p_classification_override: classificationOverride,
      p_renewal_date: renewal,
      p_referred_contact: referredContact,
      p_raw_metadata: { source: "outreach_ui" },
    } as never,
  );
  if (error) throw new Error(error.message);
  refresh(targetId);
}

export async function handleReply(formData: FormData) {
  const { s, workspaceId } = await client();
  const replyId = String(formData.get("reply_id") ?? "");
  const reply = await assertReplyInWorkspace(s, replyId, workspaceId);
  const { error } = await s.rpc(
    "handle_outreach_reply" as never,
    {
      p_reply_id: replyId,
      p_resolution: String(formData.get("resolution") ?? "") || "handled",
      p_resume_sequence: formData.get("resume_sequence") === "true",
    } as never,
  );
  if (error) throw new Error(error.message);
  refresh(reply.outreach_target_id);
}

export async function createOpportunityFromPursuit(formData: FormData) {
  const { s, workspaceId } = await client();
  const pursuitId = String(formData.get("pursuit_id") ?? "");
  await assertPursuitInWorkspace(s, pursuitId, workspaceId);
  const replyId = String(formData.get("reply_id") ?? "").trim() || null;
  if (replyId) await assertReplyInWorkspace(s, replyId, workspaceId);
  const raw = String(formData.get("estimated_value") ?? "").trim();
  const estimatedValue = raw ? Number(raw) : 0;
  if (!Number.isFinite(estimatedValue) || estimatedValue < 0) throw new Error("Estimated value must be non-negative");

  const { error } = await s.rpc(
    "ensure_outreach_opportunity" as never,
    { p_pursuit_id: pursuitId, p_reply_id: replyId, p_estimated_value: estimatedValue } as never,
  );
  if (error) throw new Error(error.message);
  refresh();
}

export async function linkEstimateToPursuit(formData: FormData) {
  const { s, workspaceId } = await client();
  const pursuitId = String(formData.get("pursuit_id") ?? "");
  const estimateId = String(formData.get("estimate_id") ?? "");
  await assertPursuitInWorkspace(s, pursuitId, workspaceId);
  const { data: estimate, error: estimateError } = await (s as any)
    .from("estimates")
    .select("id")
    .eq("id", estimateId)
    .eq("workspace_id", workspaceId)
    .maybeSingle();
  if (estimateError) throw new Error(estimateError.message);
  if (!estimate) throw new Error("Estimate is not in the active workspace");

  const { error } = await s.rpc(
    "link_estimate_to_outreach_pursuit" as never,
    { p_pursuit_id: pursuitId, p_estimate_id: estimateId } as never,
  );
  if (error) throw new Error(error.message);
  refresh();
}

export async function queueContactResearch(formData: FormData) {
  const { s, workspaceId } = await client();
  const taskId = String(formData.get("task_id") ?? "");
  const { data: task, error: taskError } = await (s as any)
    .from("contact_enrichment_tasks")
    .select("id,outreach_target_id")
    .eq("id", taskId)
    .eq("workspace_id", workspaceId)
    .maybeSingle();
  if (taskError) throw new Error(taskError.message);
  if (!task) throw new Error("Research task is not in the active workspace");

  const { error } = await s.rpc("queue_contact_research_task" as never, { p_task_id: taskId } as never);
  if (error) throw new Error(error.message);
  refresh(task.outreach_target_id);
}

export async function acceptResearchCandidate(formData: FormData) {
  const { s, workspaceId } = await client();
  const taskId = String(formData.get("task_id") ?? "");
  const { data: task, error: taskError } = await (s as any)
    .from("contact_enrichment_tasks")
    .select("id,outreach_target_id")
    .eq("id", taskId)
    .eq("workspace_id", workspaceId)
    .maybeSingle();
  if (taskError) throw new Error(taskError.message);
  if (!task) throw new Error("Research task is not in the active workspace");

  const { error } = await s.rpc("accept_contact_research_candidate" as never, { p_task_id: taskId } as never);
  if (error) throw new Error(error.message);
  refresh(task.outreach_target_id);
}

export async function updatePursuitNextAction(formData: FormData) {
  const { s, user, workspaceId } = await client();
  const pursuitId = String(formData.get("pursuit_id") ?? "");
  const nextAction = String(formData.get("next_action") ?? "").trim();
  const dueAt = String(formData.get("next_action_due_at") ?? "").trim();
  if (!nextAction || nextAction.length > 240) throw new Error("Enter a concise next action");
  await assertPursuitInWorkspace(s, pursuitId, workspaceId);

  const patch: Record<string, unknown> = {
    next_action: nextAction,
    next_action_due_at: dueAt ? new Date(dueAt).toISOString() : null,
    updated_at: new Date().toISOString(),
  };
  if (formData.get("assign_to_me") === "true") patch.next_action_owner_user_id = user.id;

  const { error } = await (s as any)
    .from("outreach_pursuits")
    .update(patch)
    .eq("id", pursuitId)
    .eq("workspace_id", workspaceId);
  if (error) throw new Error(error.message);
  refresh();
}

export async function generateAdaptiveFollowup(formData: FormData) {
  const { s, workspaceId } = await client();
  const targetId = String(formData.get("target_id") ?? "");
  const channel = String(formData.get("channel") ?? "email");
  await assertTargetInWorkspace(s, targetId, workspaceId);
  const { error } = await s.rpc(
    "generate_adaptive_followup" as never,
    { p_target_id: targetId, p_channel: channel } as never,
  );
  if (error) throw new Error(error.message);
  refresh(targetId);
}

export async function enrollDefaultSequence(formData: FormData) {
  const { s, workspaceId } = await client();
  const targetId = String(formData.get("target_id") ?? "");
  const { data: target, error: targetError } = await (s as any)
    .from("outreach_targets")
    .select("workspace_id,status")
    .eq("id", targetId)
    .eq("workspace_id", workspaceId)
    .single();
  if (targetError || !target) throw new Error("Target not found in active workspace");
  if (!["queued", "contacted", "responded"].includes(target.status)) throw new Error("Target is closed");

  const { data: sequenceId, error: sequenceError } = await s.rpc(
    "ensure_cb_outreach_sequence" as never,
    { p_workspace_id: workspaceId } as never,
  );
  if (sequenceError || !sequenceId) throw new Error(sequenceError?.message ?? "Could not ensure sequence");

  const { error } = await s.rpc(
    "enroll_outreach_target" as never,
    { p_target_id: targetId, p_sequence_id: sequenceId } as never,
  );
  if (error) throw new Error(error.message);
  refresh(targetId);
}

export async function runDueSequences() {
  const { s, workspaceId } = await client();
  const { error } = await s.rpc(
    "run_safe_due_sequences" as never,
    { p_workspace_id: workspaceId, p_limit: 50 } as never,
  );
  if (error) throw new Error(error.message);
  refresh();
}


export async function activateCustomerNowSprint(formData: FormData) {
  const { s, user, workspaceId } = await client();
  const requested = Number(String(formData.get("limit") ?? "10"));
  const limit = Math.min(20, Math.max(1, Number.isFinite(requested) ? Math.trunc(requested) : 10));

  const { data, error } = await (s as any)
    .from("v_outreach_pursuit_queue")
    .select(
      "pursuit_id,primary_target_id,organization_display_name,stage,pursuit_status,next_action,why_now,contact_email,contact_phone,contact_coverage_score,high_signal_property_count,open_signal_count,service_fit,total_score,command_score,needs_response_count,latest_reply_classification,latest_draft_id,latest_draft_state,latest_draft_quality_passed,latest_draft_channel,opportunity_id",
    )
    .eq("workspace_id", workspaceId)
    .in("pursuit_status", ["active", "paused"])
    .limit(150);

  if (error) throw new Error(error.message);

  const candidates = rankCustomerNow((data ?? []) as any[]).slice(0, limit);
  if (!candidates.length) throw new Error("No active outreach pursuits are ready for a Customer Now sprint");

  const dueAt = new Date().toISOString();

  for (const candidate of candidates) {
    const lane = customerNowLane(candidate);
    let nextAction = customerNowAction(candidate);

    const needsFreshDraft =
      candidate.primary_target_id &&
      (
        (lane === "draft_now" && !["draft", "approved"].includes(candidate.latest_draft_state ?? "")) ||
        (
          lane === "call_now" &&
          !(candidate.latest_draft_state === "draft" && candidate.latest_draft_channel === "call")
        )
      );

    if (needsFreshDraft) {
      const channel = lane === "call_now" ? "call" : "email";
      const objective = lane === "call_now" ? "site_walk" : "quote";

      const { error: contactError } = await s.rpc(
        "select_outreach_contact" as never,
        { p_target_id: candidate.primary_target_id } as never,
      );

      if (!contactError) {
        const { error: draftError } = await s.rpc(
          "generate_outreach_draft" as never,
          {
            p_target_id: candidate.primary_target_id,
            p_channel: channel,
            p_objective: objective,
          } as never,
        );
        if (!draftError) {
          nextAction = lane === "call_now"
            ? "Use the prepared call opener now and ask for one current small job or a same-week site walk."
            : "Review the prepared one-site quote/site-walk email and send it today.";
        }
      }
    }

    if (lane === "research" && candidate.primary_target_id) {
      const { data: task } = await (s as any)
        .from("contact_enrichment_tasks")
        .select("id")
        .eq("workspace_id", workspaceId)
        .eq("outreach_target_id", candidate.primary_target_id)
        .in("status", ["queued", "not_found", "researching"])
        .order("research_priority_score", { ascending: false })
        .limit(1)
        .maybeSingle();

      if (task?.id) {
        await s.rpc("queue_contact_research_task" as never, { p_task_id: task.id } as never);
        nextAction = "Contact research queued. Promote the first verified operations/property/facilities contact and call them today.";
      }
    }

    const { error: updateError } = await (s as any)
      .from("outreach_pursuits")
      .update({
        next_action: "CUSTOMER NOW: " + nextAction,
        next_action_due_at: dueAt,
        next_action_owner_user_id: user.id,
        updated_at: dueAt,
      })
      .eq("id", candidate.pursuit_id)
      .eq("workspace_id", workspaceId);

    if (updateError) throw new Error(updateError.message);
  }

  refresh();
}

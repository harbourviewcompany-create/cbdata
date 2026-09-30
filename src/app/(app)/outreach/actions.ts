"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireWorkspace } from "@/lib/workspace";

type DbClient = Awaited<ReturnType<typeof createClient>>;

async function client() {
  const ctx = await requireWorkspace();
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

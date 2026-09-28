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
    .select("id")
    .eq("id", targetId)
    .eq("workspace_id", workspaceId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  if (!data) throw new Error("Target is not in the active workspace");
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

function refresh(targetId?: string) {
  revalidatePath("/outreach");
  revalidatePath("/targets");
  revalidatePath("/dashboard");
  if (targetId) revalidatePath(`/targets/${targetId}`);
}

export async function generateDraft(formData: FormData) {
  const { s, workspaceId } = await client();
  const targetId = String(formData.get("target_id") ?? "");
  const channel = String(formData.get("channel") ?? "email");
  const objective = String(formData.get("objective") ?? "introduction");
  await assertTargetInWorkspace(s, targetId, workspaceId);

  const { error } = await s.rpc("generate_outreach_draft" as never, {
    p_target_id: targetId,
    p_channel: channel,
    p_objective: objective,
  } as never);
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

  const { error } = await s.rpc("mark_outreach_draft_sent" as never, {
    p_draft_id: draftId,
    p_provider: String(formData.get("provider") ?? "") || null,
    p_provider_message_id: String(formData.get("provider_message_id") ?? "") || null,
    p_provider_thread_id: String(formData.get("provider_thread_id") ?? "") || null,
  } as never);
  if (error) throw new Error(error.message);
  refresh(draft.outreach_target_id);
}

export async function classifyReply(formData: FormData) {
  const { s, workspaceId } = await client();
  const targetId = String(formData.get("target_id") ?? "");
  const renewal = String(formData.get("renewal_date") ?? "") || null;
  const channel = String(formData.get("channel") ?? "email");
  await assertTargetInWorkspace(s, targetId, workspaceId);

  const { error } = await s.rpc("classify_outreach_reply" as never, {
    p_target_id: targetId,
    p_classification: String(formData.get("classification") ?? "other"),
    p_summary: String(formData.get("summary") ?? "") || null,
    p_channel: channel,
    p_renewal_date: renewal,
    p_referred_contact: String(formData.get("referred_contact") ?? "") || null,
    p_provider: null,
    p_provider_message_id: null,
    p_provider_thread_id: null,
  } as never);
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
  if (!["queued","contacted","responded"].includes(target.status)) throw new Error("Target is closed");

  const { data: sequenceId, error: sequenceError } = await s.rpc("ensure_cb_outreach_sequence" as never, {
    p_workspace_id: workspaceId,
  } as never);
  if (sequenceError || !sequenceId) throw new Error(sequenceError?.message ?? "Could not ensure sequence");

  const { error } = await s.rpc("enroll_outreach_target" as never, {
    p_target_id: targetId,
    p_sequence_id: sequenceId,
  } as never);
  if (error) throw new Error(error.message);
  refresh(targetId);
}

export async function runDueSequences() {
  const { s, workspaceId } = await client();
  const { error } = await s.rpc("process_due_sequence_steps" as never, {
    p_workspace_id: workspaceId,
    p_limit: 50,
  } as never);
  if (error) throw new Error(error.message);
  revalidatePath("/outreach");
  revalidatePath("/targets");
  revalidatePath("/dashboard");
}

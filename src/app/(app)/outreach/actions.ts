"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

async function client() {
  const s = await createClient();
  const { data: { user } } = await s.auth.getUser();
  if (!user) throw new Error("Unauthorized");
  return s;
}

function refresh(targetId?: string) {
  revalidatePath("/outreach");
  revalidatePath("/targets");
  revalidatePath("/dashboard");
  if (targetId) revalidatePath(`/targets/${targetId}`);
}

export async function generateDraft(formData: FormData) {
  const s = await client();
  const targetId = String(formData.get("target_id") ?? "");
  const channel = String(formData.get("channel") ?? "email");
  const objective = String(formData.get("objective") ?? "introduction");
  const { error } = await s.rpc("generate_outreach_draft" as never, {
    p_target_id: targetId,
    p_channel: channel,
    p_objective: objective,
  } as never);
  if (error) throw new Error(error.message);
  refresh(targetId);
}

export async function approveDraft(formData: FormData) {
  const s = await client();
  const draftId = String(formData.get("draft_id") ?? "");
  const targetId = String(formData.get("target_id") ?? "");
  const { error } = await s.rpc("approve_outreach_draft" as never, { p_draft_id: draftId } as never);
  if (error) throw new Error(error.message);
  refresh(targetId);
}

export async function markSent(formData: FormData) {
  const s = await client();
  const draftId = String(formData.get("draft_id") ?? "");
  const targetId = String(formData.get("target_id") ?? "");
  const { error } = await s.rpc("mark_outreach_draft_sent" as never, {
    p_draft_id: draftId,
    p_provider: String(formData.get("provider") ?? "") || null,
    p_provider_message_id: String(formData.get("provider_message_id") ?? "") || null,
    p_provider_thread_id: String(formData.get("provider_thread_id") ?? "") || null,
  } as never);
  if (error) throw new Error(error.message);
  refresh(targetId);
}

export async function classifyReply(formData: FormData) {
  const s = await client();
  const targetId = String(formData.get("target_id") ?? "");
  const renewal = String(formData.get("renewal_date") ?? "") || null;
  const { error } = await s.rpc("classify_outreach_reply" as never, {
    p_target_id: targetId,
    p_classification: String(formData.get("classification") ?? "other"),
    p_summary: String(formData.get("summary") ?? "") || null,
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
  const s = await client();
  const targetId = String(formData.get("target_id") ?? "");
  const { data: target, error: targetError } = await (s as any)
    .from("outreach_targets")
    .select("workspace_id,status")
    .eq("id", targetId)
    .single();
  if (targetError || !target) throw new Error("Target not found");
  if (!["queued","contacted","responded"].includes(target.status)) throw new Error("Target is closed");

  const { data: sequenceId, error: sequenceError } = await s.rpc("ensure_cb_outreach_sequence" as never, {
    p_workspace_id: target.workspace_id,
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
  const s = await client();
  const { data: { user } } = await s.auth.getUser();
  if (!user) throw new Error("Unauthorized");
  const { data: memberships } = await s
    .from("workspace_memberships")
    .select("workspace_id")
    .eq("user_id", user.id)
    .limit(1);
  const workspaceId = memberships?.[0]?.workspace_id;
  if (!workspaceId) throw new Error("No workspace");

  const { error } = await s.rpc("process_due_sequence_steps" as never, {
    p_workspace_id: workspaceId,
    p_limit: 50,
  } as never);
  if (error) throw new Error(error.message);
  revalidatePath("/outreach");
  revalidatePath("/targets");
  revalidatePath("/dashboard");
}

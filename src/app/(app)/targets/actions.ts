"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireTargetRole, requireWorkspaceRole, ROLES } from "@/lib/authz";
import { requireWorkspaceWithRole } from "@/lib/workspace";

type TouchChannel = "call" | "email" | "sms" | "door_knock" | "mail" | "other";
type TargetStatus =
  | "queued"
  | "contacted"
  | "responded"
  | "converted"
  | "rejected"
  | "do_not_contact";

async function salesClientForTarget(targetId: string) {
  const s = await createClient();
  await requireTargetRole(s, targetId, ROLES.sales);
  return s;
}

export async function logTouch(formData: FormData) {
  const targetId = String(formData.get("target_id") ?? "");
  const s = await salesClientForTarget(targetId);
  const channel = String(formData.get("channel") ?? "call") as TouchChannel;
  const outcome = String(formData.get("outcome") ?? "") || null;
  const notes = String(formData.get("notes") ?? "") || null;
  const newStatusRaw = String(formData.get("new_status") ?? "");
  const newStatus = (newStatusRaw || null) as TargetStatus | null;
  const nextAction = String(formData.get("next_action") ?? "") || null;
  const nextDue = String(formData.get("next_action_due_at") ?? "") || null;

  const { error } = await s.rpc("log_outreach_touch" as never, {
    p_target_id: targetId,
    p_channel: channel,
    p_outcome: outcome,
    p_notes: notes,
    p_new_status: newStatus,
    p_next_action: nextAction,
    p_next_action_due_at: nextDue ? new Date(nextDue).toISOString() : null,
  } as never);

  if (error) throw new Error(error.message);
  revalidatePath("/targets");
}

export async function updateTargetStatus(formData: FormData) {
  const targetId = String(formData.get("target_id") ?? "");
  const s = await salesClientForTarget(targetId);
  const status = String(formData.get("status") ?? "") as TargetStatus;
  const nextAction = String(formData.get("next_action") ?? "") || null;
  const nextDue = String(formData.get("next_action_due_at") ?? "") || null;

  const payload: Record<string, unknown> = {
    status,
    updated_at: new Date().toISOString(),
  };
  if (nextAction !== null) payload.next_action = nextAction;
  if (nextDue) payload.next_action_due_at = new Date(nextDue).toISOString();

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const { error } = await (s as any)
    .from("outreach_targets")
    .update(payload)
    .eq("id", targetId);

  if (error) throw new Error(error.message);
  revalidatePath("/targets");
}

export async function convertTarget(formData: FormData) {
  const targetId = String(formData.get("target_id") ?? "");
  const s = await salesClientForTarget(targetId);

  const { data, error } = await s.rpc("convert_outreach_target_to_lead" as never, {
    p_target_id: targetId,
  } as never);

  if (error) throw new Error(error.message);
  revalidatePath("/targets");
  revalidatePath("/sales");
  void data;
}

export async function refreshScores(formData: FormData) {
  const s = await createClient();
  const listId = String(formData.get("list_id") ?? "");
  if (!listId) throw new Error("list_id required");
  const { data: list, error: listError } = await s
    .from("outreach_lists")
    .select("workspace_id")
    .eq("id", listId)
    .maybeSingle();
  if (listError) throw new Error(listError.message);
  if (!list) throw new Error("List not found");
  await requireWorkspaceRole(s, list.workspace_id, ROLES.sales);

  const { error } = await s.rpc("refresh_outreach_target_scores_for_list" as never, {
    p_list_id: listId,
  } as never);

  if (error) throw new Error(error.message);
  revalidatePath("/targets");
}

export async function ensurePmSequence() {
  const { workspaceId } = await requireWorkspaceWithRole(ROLES.sales);
  const s = await createClient();
  const { data, error } = await s.rpc("ensure_default_pm_sequence" as never, {
    p_workspace_id: workspaceId,
  } as never);
  if (error) throw new Error(error.message);
  revalidatePath("/targets");
  void data;
}

export async function enrollTarget(formData: FormData) {
  const targetId = String(formData.get("target_id") ?? "");
  const s = await salesClientForTarget(targetId);
  const sequenceId = String(formData.get("sequence_id") ?? "");
  const { data: target, error: targetError } = await s
    .from("outreach_targets")
    .select("status")
    .eq("id", targetId)
    .single();
  if (targetError || !target) throw new Error("Target not found");
  if (!["queued", "contacted", "responded"].includes(target.status)) {
    throw new Error("Cannot enroll a closed target");
  }
  const { error } = await s.rpc("enroll_outreach_target" as never, {
    p_target_id: targetId,
    p_sequence_id: sequenceId,
  } as never);
  if (error) throw new Error(error.message);
  revalidatePath("/targets");
}

export async function processSequences() {
  const { workspaceId } = await requireWorkspaceWithRole(ROLES.sales);
  const s = await createClient();
  const { data, error } = await s.rpc("process_due_sequence_steps" as never, {
    p_workspace_id: workspaceId,
    p_limit: 50,
  } as never);
  if (error) throw new Error(error.message);
  revalidatePath("/targets");
  revalidatePath("/dashboard");
  void data;
}

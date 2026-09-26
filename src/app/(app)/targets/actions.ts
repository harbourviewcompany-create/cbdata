"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

type TouchChannel = "call" | "email" | "sms" | "door_knock" | "mail" | "other";
type TargetStatus =
  | "queued"
  | "contacted"
  | "responded"
  | "converted"
  | "rejected"
  | "do_not_contact";

async function requireUser() {
  const s = await createClient();
  const {
    data: { user },
  } = await s.auth.getUser();
  if (!user) throw new Error("Unauthorized");
  return { s, user };
}

export async function logTouch(formData: FormData) {
  const { s } = await requireUser();
  const targetId = String(formData.get("target_id") ?? "");
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
  const { s } = await requireUser();
  const targetId = String(formData.get("target_id") ?? "");
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
  const { s } = await requireUser();
  const targetId = String(formData.get("target_id") ?? "");

  const { data, error } = await s.rpc("convert_outreach_target_to_lead" as never, {
    p_target_id: targetId,
  } as never);

  if (error) throw new Error(error.message);
  revalidatePath("/targets");
  revalidatePath("/sales");
  return data as string;
}

export async function refreshScores(formData: FormData) {
  const { s } = await requireUser();
  const listId = String(formData.get("list_id") ?? "");
  if (!listId) throw new Error("list_id required");

  const { error } = await s.rpc("refresh_outreach_target_scores_for_list" as never, {
    p_list_id: listId,
  } as never);

  if (error) throw new Error(error.message);
  revalidatePath("/targets");
}

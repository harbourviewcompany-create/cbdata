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

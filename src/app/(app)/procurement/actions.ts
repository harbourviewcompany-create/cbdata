"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireWorkspace } from "@/lib/workspace";

const STAGES: Record<string, string> = {
  new: "Review solicitation and mandatory requirements",
  qualifying: "Complete bid/no-bid qualification",
  pursuing: "Confirm site visit, questions, takeoff and compliance package",
  pricing: "Complete takeoff and final pricing",
  review: "Complete owner review and submission QA",
  submitted: "Confirm receipt and monitor award",
  won: "Create contract handoff and mobilization plan",
  lost: "Capture debrief, incumbent and next rebid date",
  no_bid: "Record no-bid reason and future trigger",
};

export async function updateTenderStage(formData: FormData) {
  const ctx = await requireWorkspace();
  const s = await createClient();
  const tenderId = String(formData.get("tender_id") || "");
  const stage = String(formData.get("stage") || "");
  if (!tenderId || !STAGES[stage]) throw new Error("Invalid tender stage");

  const { error } = await (s as any)
    .from("tender_records")
    .update({ action_state: stage, next_action: STAGES[stage] })
    .eq("workspace_id", ctx.workspaceId)
    .eq("id", tenderId);

  if (error) throw error;
  revalidatePath("/procurement");
  revalidatePath("/dashboard");
}

export async function runCanadaBuysScout() {
  const ctx = await requireWorkspace();
  const s = await createClient();

  const { data: sessionData } = await s.auth.getSession();
  const accessToken = sessionData.session?.access_token;
  if (!accessToken) throw new Error("No active session");

  const base = process.env.NEXT_PUBLIC_SUPABASE_URL;
  if (!base) throw new Error("Supabase URL is not configured");

  const response = await fetch(base + "/functions/v1/canadabuys-scout", {
    method: "POST",
    headers: { Authorization: "Bearer " + accessToken, "Content-Type": "application/json" },
    body: JSON.stringify({ workspace_id: ctx.workspaceId }),
    cache: "no-store",
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(payload.error || "CanadaBuys scout failed");

  revalidatePath("/procurement");
  revalidatePath("/targets");
  revalidatePath("/dashboard");
}

"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
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

  const { data: current, error: currentError } = await (s as any)
    .from("tender_records").select("action_state").eq("workspace_id", ctx.workspaceId).eq("id", tenderId).single();
  if (currentError) throw currentError;

  const { data: userData } = await s.auth.getUser();
  const { error } = await (s as any)
    .from("tender_records")
    .update({ action_state: stage, next_action: STAGES[stage] })
    .eq("workspace_id", ctx.workspaceId)
    .eq("id", tenderId);
  if (error) throw error;

  await (s as any).from("tender_stage_history").insert({
    workspace_id: ctx.workspaceId,
    tender_record_id: tenderId,
    from_stage: current?.action_state ?? null,
    to_stage: stage,
    changed_by: userData.user?.id ?? null,
  });

  revalidatePath("/procurement");
  revalidatePath(`/procurement/${tenderId}`);
  revalidatePath("/dashboard");
}

export async function updateTenderRequirement(formData: FormData) {
  const ctx = await requireWorkspace();
  const s = await createClient();
  const id = String(formData.get("requirement_id") || "");
  const tenderId = String(formData.get("tender_id") || "");
  const status = String(formData.get("status") || "");
  if (!id || !tenderId || !["pending","in_progress","complete","blocked","not_applicable"].includes(status)) throw new Error("Invalid requirement update");
  const { error } = await (s as any).from("tender_requirements").update({ status, updated_at: new Date().toISOString() }).eq("workspace_id",ctx.workspaceId).eq("id",id).eq("tender_record_id",tenderId);
  if (error) throw error;
  revalidatePath(`/procurement/${tenderId}`);
  revalidatePath("/procurement");
}

export async function updateTenderDeadline(formData: FormData) {
  const ctx = await requireWorkspace();
  const s = await createClient();
  const id = String(formData.get("deadline_id") || "");
  const tenderId = String(formData.get("tender_id") || "");
  const status = String(formData.get("status") || "");
  if (!id || !tenderId || !["open","complete","missed","not_applicable"].includes(status)) throw new Error("Invalid deadline update");
  const { error } = await (s as any).from("tender_deadlines").update({ status, updated_at: new Date().toISOString() }).eq("workspace_id",ctx.workspaceId).eq("id",id).eq("tender_record_id",tenderId);
  if (error) throw error;
  revalidatePath(`/procurement/${tenderId}`);
}

export async function createEstimateFromTender(formData: FormData) {
  const ctx = await requireWorkspace();
  const s = await createClient();
  const tenderId = String(formData.get("tender_id") || "");
  if (!tenderId) throw new Error("Tender is required");

  const { data: tender, error } = await (s as any).from("tender_records")
    .select("id,title,external_id,matched_organization_id,lead_id,estimated_value,closing_date,estimate_id,opportunity_id")
    .eq("workspace_id",ctx.workspaceId).eq("id",tenderId).single();
  if (error) throw error;
  if (tender.estimate_id) redirect(`/estimates/${tender.estimate_id}`);
  if (!tender.matched_organization_id) throw new Error("Match this tender to a buyer organization before creating an estimate");

  const { data: prop } = await (s as any).from("tender_properties").select("property_id").eq("workspace_id",ctx.workspaceId).eq("tender_record_id",tenderId).limit(1).maybeSingle();
  const { data: userData } = await s.auth.getUser();

  let opportunityId = tender.opportunity_id as string | null;
  if (!opportunityId) {
    const { data: opp, error: oppError } = await (s as any).from("opportunities").insert({
      workspace_id: ctx.workspaceId,
      organization_id: tender.matched_organization_id,
      property_id: prop?.property_id ?? null,
      name: tender.title,
      stage: "estimating",
      status: "open",
      owner_user_id: userData.user?.id ?? null,
      estimated_value: tender.estimated_value ?? 0,
      estimated_close_date: tender.closing_date ?? null,
      lead_id: tender.lead_id ?? null,
      notes: `Created from tender ${tender.external_id}`,
    }).select("id").single();
    if (oppError) throw oppError;
    opportunityId = opp.id;
  }

  const estimateNumber = `TND-${String(tender.external_id).replace(/[^A-Za-z0-9]/g,"").slice(-12)}-${Date.now().toString().slice(-6)}`;
  const { data: estimate, error: estimateError } = await (s as any).from("estimates").insert({
    workspace_id: ctx.workspaceId,
    estimate_number: estimateNumber,
    opportunity_id: opportunityId,
    organization_id: tender.matched_organization_id,
    property_id: prop?.property_id ?? null,
    created_by: userData.user?.id ?? null,
  }).select("id").single();
  if (estimateError) throw estimateError;

  const { error: linkError } = await (s as any).from("tender_records").update({
    opportunity_id: opportunityId,
    estimate_id: estimate.id,
    action_state: "pricing",
    next_action: "Complete takeoff and final pricing",
  }).eq("workspace_id",ctx.workspaceId).eq("id",tenderId);
  if (linkError) throw linkError;

  revalidatePath("/procurement");
  revalidatePath(`/procurement/${tenderId}`);
  redirect(`/estimates/${estimate.id}`);
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

  await (s as any).from("tender_sources").update({
    last_run_at: new Date().toISOString(),
    last_success_at: new Date().toISOString(),
    last_error: null,
  }).eq("workspace_id",ctx.workspaceId).eq("source_key","canadabuys");

  revalidatePath("/procurement");
  revalidatePath("/targets");
  revalidatePath("/dashboard");
}

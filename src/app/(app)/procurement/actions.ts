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
    .from("tender_records").select("action_state,estimate_id,no_bid_reason").eq("workspace_id", ctx.workspaceId).eq("id", tenderId).single();
  if (currentError) throw currentError;

  if (stage === "submitted") {
    const { data: blockers, error: blockersError } = await (s as any)
      .from("tender_requirements")
      .select("id")
      .eq("workspace_id", ctx.workspaceId)
      .eq("tender_record_id", tenderId)
      .eq("mandatory", true)
      .not("status", "in", '("complete","not_applicable")');
    if (blockersError) throw blockersError;
    if ((blockers ?? []).length) throw new Error("Submission blocked: complete every mandatory tender requirement first");
    if (!current?.estimate_id) throw new Error("Submission blocked: link and complete an estimate before submitting");
  }

  if (stage === "no_bid" && !current?.no_bid_reason) {
    throw new Error("Record a no-bid reason before moving this tender to No Bid");
  }

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


export async function addTenderRequirement(formData: FormData) {
  const ctx = await requireWorkspace();
  const s = await createClient();
  const tenderId = String(formData.get("tender_id") || "");
  const title = String(formData.get("title") || "").trim();
  const type = String(formData.get("requirement_type") || "other");
  if (!tenderId || !title) throw new Error("Tender and requirement title are required");
  const { error } = await (s as any).from("tender_requirements").insert({
    workspace_id: ctx.workspaceId,
    tender_record_id: tenderId,
    requirement_type: type,
    title,
    mandatory: formData.get("mandatory") === "on",
    status: "pending",
  });
  if (error) throw error;
  revalidatePath(`/procurement/${tenderId}`);
}

export async function addTenderDeadline(formData: FormData) {
  const ctx = await requireWorkspace();
  const s = await createClient();
  const tenderId = String(formData.get("tender_id") || "");
  const title = String(formData.get("title") || "").trim();
  const dueAt = String(formData.get("due_at") || "");
  const type = String(formData.get("deadline_type") || "other");
  if (!tenderId || !title || !dueAt) throw new Error("Tender, deadline title and due date are required");
  const { error } = await (s as any).from("tender_deadlines").insert({
    workspace_id: ctx.workspaceId,
    tender_record_id: tenderId,
    deadline_type: type,
    title,
    due_at: new Date(dueAt).toISOString(),
    mandatory: formData.get("mandatory") === "on",
    status: "open",
  });
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


export async function saveTenderScorecard(formData: FormData) {
  const ctx = await requireWorkspace();
  const s = await createClient();
  const tenderId = String(formData.get("tender_id") || "");
  if (!tenderId) throw new Error("Tender is required");

  const fields: Record<string, number> = {
    capability: 20,
    geography: 10,
    contract_size: 15,
    experience: 15,
    equipment: 10,
    labor_capacity: 10,
    compliance: 10,
    competitive_position: 5,
    margin_potential: 5,
  };

  const breakdown: Record<string, number> = {};
  let score = 0;
  for (const [key, max] of Object.entries(fields)) {
    const raw = Number(formData.get(key) || 0);
    const value = Math.max(0, Math.min(max, Number.isFinite(raw) ? raw : 0));
    breakdown[key] = value;
    score += value;
  }

  const fitNote = String(formData.get("fit_note") || "").trim() || null;
  const { error } = await (s as any).from("tender_records").update({
    fit_score: score,
    fit_breakdown: breakdown,
    fit_note: fitNote,
  }).eq("workspace_id", ctx.workspaceId).eq("id", tenderId);
  if (error) throw error;

  revalidatePath("/procurement");
  revalidatePath(`/procurement/${tenderId}`);
}

export async function saveNoBidReason(formData: FormData) {
  const ctx = await requireWorkspace();
  const s = await createClient();
  const tenderId = String(formData.get("tender_id") || "");
  const reason = String(formData.get("no_bid_reason") || "").trim();
  if (!tenderId || !reason) throw new Error("A no-bid reason is required");
  const { data: userData } = await s.auth.getUser();
  const { error } = await (s as any).from("tender_records").update({
    no_bid_reason: reason,
    bid_decision_at: new Date().toISOString(),
    bid_decision_by: userData.user?.id ?? null,
  }).eq("workspace_id",ctx.workspaceId).eq("id",tenderId);
  if (error) throw error;
  revalidatePath(`/procurement/${tenderId}`);
  revalidatePath("/procurement");
}

export async function confirmTenderSubmission(formData: FormData) {
  const ctx = await requireWorkspace();
  const s = await createClient();
  const tenderId = String(formData.get("tender_id") || "");
  const reference = String(formData.get("submission_reference") || "").trim();
  const receiptUrl = String(formData.get("submission_receipt_url") || "").trim();
  const method = String(formData.get("submission_method") || "").trim();
  if (!tenderId || !reference) throw new Error("Submission reference/receipt number is required");

  const { data: blockers, error: blockersError } = await (s as any)
    .from("tender_requirements").select("id")
    .eq("workspace_id",ctx.workspaceId).eq("tender_record_id",tenderId)
    .eq("mandatory",true).not("status","in",'("complete","not_applicable")');
  if (blockersError) throw blockersError;
  if ((blockers ?? []).length) throw new Error("Submission cannot be confirmed while mandatory requirements are incomplete");

  const { data: tender, error: tenderError } = await (s as any)
    .from("tender_records").select("estimate_id,action_state")
    .eq("workspace_id",ctx.workspaceId).eq("id",tenderId).single();
  if (tenderError) throw tenderError;
  if (!tender.estimate_id) throw new Error("Submission cannot be confirmed without a linked estimate");

  const { error } = await (s as any).from("tender_records").update({
    submission_reference: reference,
    submission_receipt_url: receiptUrl || null,
    submission_method: method || null,
    submission_confirmed_at: new Date().toISOString(),
    action_state: "submitted",
    next_action: "Confirm receipt and monitor award",
  }).eq("workspace_id",ctx.workspaceId).eq("id",tenderId);
  if (error) throw error;

  revalidatePath("/procurement");
  revalidatePath(`/procurement/${tenderId}`);
}

export async function markAddendaChecked(formData: FormData) {
  const ctx = await requireWorkspace();
  const s = await createClient();
  const tenderId = String(formData.get("tender_id") || "");
  const count = Math.max(0, Number(formData.get("addenda_count") || 0));
  if (!tenderId) throw new Error("Tender is required");
  const { error } = await (s as any).from("tender_records").update({
    addenda_count: Number.isFinite(count) ? count : 0,
    last_addenda_checked_at: new Date().toISOString(),
  }).eq("workspace_id",ctx.workspaceId).eq("id",tenderId);
  if (error) throw error;
  revalidatePath(`/procurement/${tenderId}`);
}

export async function updateSupplierRegistration(formData: FormData) {
  const ctx = await requireWorkspace();
  const s = await createClient();
  const id = String(formData.get("registration_id") || "");
  const status = String(formData.get("status") || "");
  const allowed = ["unknown","not_required","required","in_progress","active","expired","blocked"];
  if (!id || !allowed.includes(status)) throw new Error("Invalid supplier registration status");
  const { error } = await (s as any).from("supplier_registrations").update({
    status,
    account_reference: String(formData.get("account_reference") || "").trim() || null,
    evidence_url: String(formData.get("evidence_url") || "").trim() || null,
    notes: String(formData.get("notes") || "").trim() || null,
    updated_at: new Date().toISOString(),
  }).eq("workspace_id",ctx.workspaceId).eq("id",id);
  if (error) throw error;
  revalidatePath("/procurement");
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


export async function runRegionalTenderScout() {
  const ctx = await requireWorkspace();
  const s = await createClient();

  const { data: sessionData } = await s.auth.getSession();
  const accessToken = sessionData.session?.access_token;
  if (!accessToken) throw new Error("No active session");

  const base = process.env.NEXT_PUBLIC_SUPABASE_URL;
  if (!base) throw new Error("Supabase URL is not configured");

  const calls = [
    fetch(base + "/functions/v1/canadabuys-scout", {
      method: "POST",
      headers: { Authorization: "Bearer " + accessToken, "Content-Type": "application/json" },
      body: JSON.stringify({ workspace_id: ctx.workspaceId }),
      cache: "no-store",
    }),
    fetch(base + "/functions/v1/regional-tender-scout", {
      method: "POST",
      headers: { Authorization: "Bearer " + accessToken, "Content-Type": "application/json" },
      body: JSON.stringify({ workspace_id: ctx.workspaceId }),
      cache: "no-store",
    }),
  ];

  const responses = await Promise.allSettled(calls);
  const failures: string[] = [];
  for (const result of responses) {
    if (result.status === "rejected") {
      failures.push(result.reason instanceof Error ? result.reason.message : "Scout request failed");
      continue;
    }
    if (!result.value.ok) {
      const payload = await result.value.json().catch(() => ({}));
      failures.push(payload.error || ("Scout failed with " + result.value.status));
    }
  }

  revalidatePath("/procurement");
  revalidatePath("/targets");
  revalidatePath("/dashboard");

  if (failures.length === responses.length) throw new Error(failures.join("; "));
}


export async function runProcurementCoverageEngine() {
  const ctx = await requireWorkspace();
  const s = await createClient();

  const { data: sessionData } = await s.auth.getSession();
  const accessToken = sessionData.session?.access_token;
  if (!accessToken) throw new Error("No active session");

  const base = process.env.NEXT_PUBLIC_SUPABASE_URL;
  if (!base) throw new Error("Supabase URL is not configured");

  const response = await fetch(base + "/functions/v1/procurement-coverage-engine", {
    method: "POST",
    headers: { Authorization: "Bearer " + accessToken, "Content-Type": "application/json" },
    body: JSON.stringify({ workspace_id: ctx.workspaceId }),
    cache: "no-store",
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(payload.error || "Procurement coverage engine failed");

  revalidatePath("/procurement");
  revalidatePath("/procurement/coverage");
  revalidatePath("/targets");
  revalidatePath("/dashboard");
}

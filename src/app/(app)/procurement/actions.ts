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
    const { data: readiness, error: readinessError } = await (s as any)
      .from("v_tender_bid_readiness")
      .select("*")
      .eq("workspace_id",ctx.workspaceId)
      .eq("tender_record_id",tenderId)
      .maybeSingle();
    if (readinessError) throw readinessError;
    if (!readiness?.ready_to_submit) {
      const reasons = [
        readiness?.mandatory_requirement_gaps ? `${readiness.mandatory_requirement_gaps} mandatory requirement gap(s)` : null,
        readiness?.evidence_gaps ? `${readiness.evidence_gaps} evidence gap(s)` : null,
        readiness?.unacknowledged_amendments ? `${readiness.unacknowledged_amendments} unacknowledged amendment(s)` : null,
        readiness?.blocking_clarifications ? `${readiness.blocking_clarifications} blocking clarification(s)` : null,
        readiness?.high_open_risks ? `${readiness.high_open_risks} high open risk(s)` : null,
        !readiness?.estimate_linked ? "estimate not linked" : null,
        !readiness?.commercial_model_approved ? "commercial model not approved" : null,
        !readiness?.compliance_approved ? "compliance approval missing" : null,
        !readiness?.commercial_approved ? "commercial approval missing" : null,
        !readiness?.final_approved ? "final approval missing" : null,
      ].filter(Boolean);
      throw new Error("Submission blocked: " + reasons.join("; "));
    }
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
  const evidenceUrl = String(formData.get("evidence_url") || "").trim();
  const { error } = await (s as any).from("tender_requirements").update({
    status,
    evidence_url: evidenceUrl || null,
    updated_at: new Date().toISOString(),
  }).eq("workspace_id",ctx.workspaceId).eq("id",id).eq("tender_record_id",tenderId);
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
    evidence_required: formData.get("evidence_required") === "on",
    source_reference: String(formData.get("source_reference") || "").trim() || null,
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

  const { data: readiness, error: readinessError } = await (s as any)
    .from("v_tender_bid_readiness").select("*")
    .eq("workspace_id",ctx.workspaceId).eq("tender_record_id",tenderId).maybeSingle();
  if (readinessError) throw readinessError;
  if (!readiness?.ready_to_submit) throw new Error("Submission cannot be confirmed until the Bid OS readiness gate is clear");

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
  const now = new Date().toISOString();
  const { error } = await (s as any).from("tender_records").update({
    addenda_count: Number.isFinite(count) ? count : 0,
    last_addenda_checked_at: now,
  }).eq("workspace_id",ctx.workspaceId).eq("id",tenderId);
  if (error) throw error;
  const { data: userData } = await s.auth.getUser();
  const { error: amendmentError } = await (s as any).from("tender_amendments").update({
    acknowledged_at: now,
    acknowledged_by: userData.user?.id ?? null,
  }).eq("workspace_id",ctx.workspaceId).eq("tender_record_id",tenderId).is("acknowledged_at",null);
  if (amendmentError) throw amendmentError;
  revalidatePath(`/procurement/${tenderId}`);
  revalidatePath("/procurement");
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


function numberField(formData: FormData, key: string, fallback = 0) {
  const value = Number(formData.get(key) ?? fallback);
  return Number.isFinite(value) ? value : fallback;
}

export async function acknowledgeTenderAmendment(formData: FormData) {
  const ctx = await requireWorkspace();
  const s = await createClient();
  const tenderId = String(formData.get("tender_id") || "");
  const amendmentId = String(formData.get("amendment_id") || "");
  if (!tenderId || !amendmentId) throw new Error("Tender and amendment are required");
  const { data: userData } = await s.auth.getUser();
  const { error } = await (s as any).from("tender_amendments").update({
    acknowledged_at: new Date().toISOString(),
    acknowledged_by: userData.user?.id ?? null,
  }).eq("workspace_id",ctx.workspaceId).eq("tender_record_id",tenderId).eq("id",amendmentId);
  if (error) throw error;
  revalidatePath(`/procurement/${tenderId}`);
  revalidatePath("/procurement");
}

export async function addTenderClarification(formData: FormData) {
  const ctx = await requireWorkspace();
  const s = await createClient();
  const tenderId = String(formData.get("tender_id") || "");
  const question = String(formData.get("question") || "").trim();
  if (!tenderId || !question) throw new Error("Tender and question are required");
  const { data: userData } = await s.auth.getUser();
  const dueAt = String(formData.get("due_at") || "");
  const { error } = await (s as any).from("tender_clarifications").insert({
    workspace_id: ctx.workspaceId,
    tender_record_id: tenderId,
    question,
    blocking: formData.get("blocking") === "on",
    due_at: dueAt ? new Date(dueAt).toISOString() : null,
    owner_user_id: userData.user?.id ?? null,
  });
  if (error) throw error;
  revalidatePath(`/procurement/${tenderId}`);
}

export async function updateTenderClarification(formData: FormData) {
  const ctx = await requireWorkspace();
  const s = await createClient();
  const tenderId = String(formData.get("tender_id") || "");
  const id = String(formData.get("clarification_id") || "");
  const status = String(formData.get("status") || "");
  if (!tenderId || !id || !["draft","sent","answered","closed"].includes(status)) throw new Error("Invalid clarification update");
  const responseText = String(formData.get("response_text") || "").trim();
  const now = new Date().toISOString();
  const { error } = await (s as any).from("tender_clarifications").update({
    status,
    response_text: responseText || null,
    sent_at: status === "sent" ? now : undefined,
    answered_at: status === "answered" ? now : undefined,
    updated_at: now,
  }).eq("workspace_id",ctx.workspaceId).eq("tender_record_id",tenderId).eq("id",id);
  if (error) throw error;
  revalidatePath(`/procurement/${tenderId}`);
}

export async function addTenderSupplierQuote(formData: FormData) {
  const ctx = await requireWorkspace();
  const s = await createClient();
  const tenderId = String(formData.get("tender_id") || "");
  const supplierName = String(formData.get("supplier_name") || "").trim();
  if (!tenderId || !supplierName) throw new Error("Tender and supplier are required");
  const validUntil = String(formData.get("valid_until") || "");
  const { error } = await (s as any).from("tender_supplier_quotes").insert({
    workspace_id: ctx.workspaceId,
    tender_record_id: tenderId,
    supplier_name: supplierName,
    supplier_contact_name: String(formData.get("supplier_contact_name") || "").trim() || null,
    supplier_email: String(formData.get("supplier_email") || "").trim() || null,
    status: String(formData.get("status") || "received"),
    product_cost: numberField(formData,"product_cost"),
    freight_cost: numberField(formData,"freight_cost"),
    deposits_cost: numberField(formData,"deposits_cost"),
    handling_cost: numberField(formData,"handling_cost"),
    financing_cost: numberField(formData,"financing_cost"),
    contingency_cost: numberField(formData,"contingency_cost"),
    delivery_verified: formData.get("delivery_verified") === "on",
    valid_until: validUntil || null,
    quote_reference: String(formData.get("quote_reference") || "").trim() || null,
    evidence_url: String(formData.get("evidence_url") || "").trim() || null,
    notes: String(formData.get("notes") || "").trim() || null,
    received_at: new Date().toISOString(),
  });
  if (error) throw error;
  revalidatePath(`/procurement/${tenderId}`);
}

export async function updateTenderSupplierQuote(formData: FormData) {
  const ctx = await requireWorkspace();
  const s = await createClient();
  const tenderId = String(formData.get("tender_id") || "");
  const id = String(formData.get("quote_id") || "");
  const status = String(formData.get("status") || "");
  if (!tenderId || !id || !["invited","sent","received","shortlisted","accepted","rejected"].includes(status)) throw new Error("Invalid quote update");
  const { error } = await (s as any).from("tender_supplier_quotes").update({
    status,
    delivery_verified: formData.get("delivery_verified") === "on",
    updated_at: new Date().toISOString(),
  }).eq("workspace_id",ctx.workspaceId).eq("tender_record_id",tenderId).eq("id",id);
  if (error) throw error;
  revalidatePath(`/procurement/${tenderId}`);
}

export async function saveTenderCostModel(formData: FormData) {
  const ctx = await requireWorkspace();
  const s = await createClient();
  const tenderId = String(formData.get("tender_id") || "");
  const scenarioName = String(formData.get("scenario_name") || "Base").trim() || "Base";
  if (!tenderId) throw new Error("Tender is required");
  const costExpected = Math.max(0,numberField(formData,"cost_expected"));
  const minimumMargin = Math.max(0,Math.min(0.95,numberField(formData,"minimum_margin",10)/100));
  const targetMargin = Math.max(minimumMargin,Math.min(0.95,numberField(formData,"target_margin",20)/100));
  const priceFloor = costExpected / Math.max(0.05,1-minimumMargin);
  const targetPrice = costExpected / Math.max(0.05,1-targetMargin);
  const approve = formData.get("approve") === "on";
  const { data: userData } = await s.auth.getUser();
  const payload = {
    workspace_id: ctx.workspaceId,
    tender_record_id: tenderId,
    scenario_name: scenarioName,
    status: approve ? "approved" : "draft",
    volume_low: numberField(formData,"volume_low") || null,
    volume_expected: numberField(formData,"volume_expected") || null,
    volume_high: numberField(formData,"volume_high") || null,
    cost_low: numberField(formData,"cost_low") || null,
    cost_expected: costExpected,
    cost_high: numberField(formData,"cost_high") || null,
    minimum_margin: minimumMargin,
    target_margin: targetMargin,
    price_floor: priceFloor,
    target_price: targetPrice,
    max_competitive_price: numberField(formData,"max_competitive_price") || null,
    working_capital_required: numberField(formData,"working_capital_required") || null,
    payment_lag_days: numberField(formData,"payment_lag_days") || null,
    assumptions: String(formData.get("assumptions") || "").trim() || null,
    approved_at: approve ? new Date().toISOString() : null,
    approved_by: approve ? userData.user?.id ?? null : null,
    updated_at: new Date().toISOString(),
  };
  const { error } = await (s as any).from("tender_cost_models").upsert(payload,{onConflict:"tender_record_id,scenario_name"});
  if (error) throw error;
  revalidatePath(`/procurement/${tenderId}`);
}

export async function addTenderRisk(formData: FormData) {
  const ctx = await requireWorkspace();
  const s = await createClient();
  const tenderId = String(formData.get("tender_id") || "");
  const title = String(formData.get("title") || "").trim();
  if (!tenderId || !title) throw new Error("Tender and risk title are required");
  const { error } = await (s as any).from("tender_risks").insert({
    workspace_id: ctx.workspaceId,
    tender_record_id: tenderId,
    title,
    category: String(formData.get("category") || "commercial"),
    probability: Math.max(1,Math.min(5,numberField(formData,"probability",3))),
    impact: Math.max(1,Math.min(5,numberField(formData,"impact",3))),
    mitigation: String(formData.get("mitigation") || "").trim() || null,
  });
  if (error) throw error;
  revalidatePath(`/procurement/${tenderId}`);
}

export async function updateTenderRisk(formData: FormData) {
  const ctx = await requireWorkspace();
  const s = await createClient();
  const tenderId = String(formData.get("tender_id") || "");
  const id = String(formData.get("risk_id") || "");
  const status = String(formData.get("status") || "");
  if (!tenderId || !id || !["open","mitigated","accepted","closed"].includes(status)) throw new Error("Invalid risk update");
  const { error } = await (s as any).from("tender_risks").update({status,updated_at:new Date().toISOString()})
    .eq("workspace_id",ctx.workspaceId).eq("tender_record_id",tenderId).eq("id",id);
  if (error) throw error;
  revalidatePath(`/procurement/${tenderId}`);
}

export async function approveTenderGate(formData: FormData) {
  const ctx = await requireWorkspace();
  const s = await createClient();
  const tenderId = String(formData.get("tender_id") || "");
  const approvalType = String(formData.get("approval_type") || "");
  if (!tenderId || !["compliance","commercial","final"].includes(approvalType)) throw new Error("Invalid approval type");
  const { data: userData } = await s.auth.getUser();
  const { error } = await (s as any).from("tender_approvals").upsert({
    workspace_id: ctx.workspaceId,
    tender_record_id: tenderId,
    approval_type: approvalType,
    status: "approved",
    note: String(formData.get("note") || "").trim() || null,
    approved_by: userData.user?.id ?? null,
    approved_at: new Date().toISOString(),
  },{onConflict:"tender_record_id,approval_type"});
  if (error) throw error;
  revalidatePath(`/procurement/${tenderId}`);
}

export async function addSupplierVaultDocument(formData: FormData) {
  const ctx = await requireWorkspace();
  const s = await createClient();
  const tenderId = String(formData.get("tender_id") || "");
  const title = String(formData.get("title") || "").trim();
  const documentType = String(formData.get("document_type") || "other").trim();
  if (!title) throw new Error("Document title is required");
  const expiresOn = String(formData.get("expires_on") || "");
  const { data: userData } = await s.auth.getUser();
  const { error } = await (s as any).from("supplier_document_vault").upsert({
    workspace_id: ctx.workspaceId,
    document_type: documentType,
    title,
    status: String(formData.get("status") || "active"),
    issuer: String(formData.get("issuer") || "").trim() || null,
    reference_number: String(formData.get("reference_number") || "").trim() || null,
    expires_on: expiresOn || null,
    evidence_url: String(formData.get("evidence_url") || "").trim() || null,
    notes: String(formData.get("notes") || "").trim() || null,
    owner_user_id: userData.user?.id ?? null,
    last_verified_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  },{onConflict:"workspace_id,document_type,title"});
  if (error) throw error;
  if (tenderId) revalidatePath(`/procurement/${tenderId}`);
  revalidatePath("/procurement");
}

export async function addTenderCallup(formData: FormData) {
  const ctx = await requireWorkspace();
  const s = await createClient();
  const tenderId = String(formData.get("tender_id") || "");
  const callupNumber = String(formData.get("callup_number") || "").trim();
  if (!tenderId || !callupNumber) throw new Error("Tender and call-up number are required");
  const dueAt = String(formData.get("due_at") || "");
  const { error } = await (s as any).from("tender_callups").insert({
    workspace_id: ctx.workspaceId,
    tender_record_id: tenderId,
    callup_number: callupNumber,
    issued_at: new Date().toISOString(),
    due_at: dueAt ? new Date(dueAt).toISOString() : null,
    revenue: Math.max(0,numberField(formData,"revenue")),
    direct_cost: Math.max(0,numberField(formData,"direct_cost")),
    notes: String(formData.get("notes") || "").trim() || null,
  });
  if (error) throw error;
  revalidatePath(`/procurement/${tenderId}`);
}

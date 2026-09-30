"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { requireWorkspaceWithRole } from "@/lib/workspace";
import { ROLES } from "@/lib/authz";

export async function addManualTender(formData: FormData) {
  const ctx = await requireWorkspaceWithRole(ROLES.procurement);
  const s = await createClient();
  const externalId = String(formData.get("external_id") || "").trim();
  const title = String(formData.get("title") || "").trim();
  const source = String(formData.get("source") || "Manual").trim() || "Manual";
  if (!externalId || !title) throw new Error("Tender ID and title are required");

  const closingDate = String(formData.get("closing_date") || "");
  const payload = {
    workspace_id: ctx.workspaceId,
    source,
    external_id: externalId,
    title,
    buyer_name: String(formData.get("buyer_name") || "").trim() || null,
    category: String(formData.get("category") || "").trim() || null,
    region: String(formData.get("region") || "").trim() || null,
    closing_date: closingDate || null,
    source_url: String(formData.get("source_url") || "").trim() || null,
    response_mode: String(formData.get("response_mode") || "formal_rfp"),
    status: "new",
    action_state: "new",
    next_action: "Review solicitation and mandatory requirements",
    last_verified_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  };

  const { data: existing, error: lookupError } = await (s as any).from("tender_records")
    .select("id").eq("workspace_id",ctx.workspaceId).eq("source",source).eq("external_id",externalId).maybeSingle();
  if (lookupError) throw lookupError;

  let tenderId = existing?.id as string | undefined;
  if (tenderId) {
    const { error } = await (s as any).from("tender_records").update(payload)
      .eq("workspace_id",ctx.workspaceId).eq("id",tenderId);
    if (error) throw error;
  } else {
    const { data: created, error } = await (s as any).from("tender_records").insert(payload).select("id").single();
    if (error) throw error;
    tenderId = created.id;
  }

  await (s as any).from("tender_requirements").upsert({
    workspace_id: ctx.workspaceId,
    tender_record_id: tenderId,
    requirement_type: "compliance",
    title: "Review mandatory solicitation requirements",
    description: "Capture every mandatory clause, required form, certification and supporting evidence before submission.",
    mandatory: true,
    status: "pending",
  },{onConflict:"tender_record_id,title"});

  if (closingDate) {
    await (s as any).from("tender_deadlines").upsert({
      workspace_id: ctx.workspaceId,
      tender_record_id: tenderId,
      deadline_type: "submission",
      title: "Tender submission deadline",
      due_at: new Date(closingDate+"T23:59:00").toISOString(),
      mandatory: true,
      status: "open",
    },{onConflict:"tender_record_id,deadline_type,due_at"});
  }

  revalidatePath("/procurement");
  redirect(`/procurement/${tenderId}`);
}

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
  const ctx = await requireWorkspaceWithRole(ROLES.procurement);
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
  const ctx = await requireWorkspaceWithRole(ROLES.procurement);
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
  const ctx = await requireWorkspaceWithRole(ROLES.procurement);
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
  const ctx = await requireWorkspaceWithRole(ROLES.procurement);
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
  const ctx = await requireWorkspaceWithRole(ROLES.procurement);
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
  const ctx = await requireWorkspaceWithRole(ROLES.procurement);
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
  const ctx = await requireWorkspaceWithRole(ROLES.procurement);
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
  const ctx = await requireWorkspaceWithRole(ROLES.procurement);
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
  const ctx = await requireWorkspaceWithRole(ROLES.procurementLead);
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

  await (s as any).from("tender_bid_packs").update({
    status: "submitted",
    submitted_at: new Date().toISOString(),
  }).eq("workspace_id",ctx.workspaceId).eq("tender_record_id",tenderId).eq("status","ready");

  revalidatePath("/procurement");
  revalidatePath(`/procurement/${tenderId}`);
}

export async function markAddendaChecked(formData: FormData) {
  const ctx = await requireWorkspaceWithRole(ROLES.procurement);
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
  const ctx = await requireWorkspaceWithRole(ROLES.procurement);
  const s = await createClient();
  const id = String(formData.get("registration_id") || "");
  const status = String(formData.get("status") || "");
  const allowed = ["unknown","not_required","required","in_progress","active","expired","blocked"];
  if (!id || !allowed.includes(status)) throw new Error("Invalid supplier registration status");
  const accountReference = String(formData.get("account_reference") || "").trim();
  const evidenceUrl = String(formData.get("evidence_url") || "").trim();
  const notes = String(formData.get("notes") || "").trim();
  if (notes && /(?:password|secret|cra\s*(?:business|bn)|business\s*number|bank\s*account|account\s*number|transit\s*number|institution\s*number|routing\s*number)/i.test(notes)) {
    throw new Error("Do not store passwords, CRA business numbers, banking identifiers, or other secrets in CBData.");
  }
  const { error } = await (s as any).from("supplier_registrations").update({
    status,
    account_reference: accountReference || null,
    evidence_url: evidenceUrl || null,
    notes: notes || null,
    updated_at: new Date().toISOString(),
  }).eq("workspace_id",ctx.workspaceId).eq("id",id);
  if (error) throw error;
  revalidatePath("/procurement");
  revalidatePath("/procurement/registration");
}

export async function updateSupplierRegistrationStep(formData: FormData) {
  const ctx = await requireWorkspaceWithRole(ROLES.procurement);
  const s = await createClient();
  const id = String(formData.get("step_id") || "");
  const status = String(formData.get("status") || "");
  const allowed = ["pending","in_progress","complete","blocked","not_applicable"];
  if (!id || !allowed.includes(status)) throw new Error("Invalid registration step");

  const { data: step, error: stepError } = await (s as any)
    .from("supplier_registration_steps")
    .select("id,supplier_registration_id,sensitive,evidence_required")
    .eq("workspace_id",ctx.workspaceId).eq("id",id).single();
  if (stepError) throw stepError;

  const evidenceUrl = String(formData.get("evidence_url") || "").trim();
  const notes = String(formData.get("notes") || "").trim();
  if (step.sensitive && notes && /(?:business\s*number|account\s*number|transit|institution\s*number|password|secret|routing\s*number)/i.test(notes)) {
    throw new Error("Do not store passwords, CRA business numbers, banking identifiers, or other secrets in CBData. Record completion/evidence only.");
  }
  if (status === "complete" && step.evidence_required && !evidenceUrl) {
    throw new Error("Evidence is required before this registration step can be completed");
  }

  const { data: userData } = await s.auth.getUser();
  const { error } = await (s as any).from("supplier_registration_steps").update({
    status,
    evidence_url: evidenceUrl || null,
    notes: notes || null,
    completed_at: status === "complete" ? new Date().toISOString() : null,
    completed_by: status === "complete" ? userData.user?.id ?? null : null,
    updated_at: new Date().toISOString(),
  }).eq("workspace_id",ctx.workspaceId).eq("id",id);
  if (error) throw error;

  const { data: readiness } = await (s as any).from("v_supplier_registration_readiness")
    .select("bid_ready,award_ready,bid_gap_count,award_gap_count")
    .eq("workspace_id",ctx.workspaceId)
    .eq("supplier_registration_id",step.supplier_registration_id)
    .maybeSingle();

  const nextStatus = readiness?.bid_ready ? "active" : status === "blocked" ? "blocked" : "in_progress";
  const { error: registrationError } = await (s as any).from("supplier_registrations").update({
    status: nextStatus,
    updated_at: new Date().toISOString(),
  }).eq("workspace_id",ctx.workspaceId).eq("id",step.supplier_registration_id);
  if (registrationError && readiness?.bid_ready) throw registrationError;

  revalidatePath("/procurement");
  revalidatePath("/procurement/registration");
  revalidatePath("/procurement/coverage");
}

export async function runCanadaBuysScout() {
  const ctx = await requireWorkspaceWithRole(ROLES.procurementLead);
  const s = await createClient();

  const { data: sessionData } = await s.auth.getSession();
  const accessToken = sessionData.session?.access_token;
  if (!accessToken) throw new Error("No active session");

  const base = process.env.NEXT_PUBLIC_SUPABASE_URL;
  if (!base) throw new Error("Supabase URL is not configured");

  const [noticeResponse, awardResponse] = await Promise.all([
    fetch(base + "/functions/v1/canadabuys-scout", {
      method: "POST",
      headers: { Authorization: "Bearer " + accessToken, "Content-Type": "application/json" },
      body: JSON.stringify({ workspace_id: ctx.workspaceId }),
      cache: "no-store",
    }),
    fetch(base + "/functions/v1/canadabuys-award-scout", {
      method: "POST",
      headers: { Authorization: "Bearer " + accessToken, "Content-Type": "application/json" },
      body: JSON.stringify({ workspace_id: ctx.workspaceId }),
      cache: "no-store",
    }),
  ]);

  const noticePayload = await noticeResponse.json().catch(() => ({}));
  const awardPayload = await awardResponse.json().catch(() => ({}));
  if (!noticeResponse.ok) throw new Error(noticePayload.error || "CanadaBuys notice scout failed");
  if (!awardResponse.ok) throw new Error(awardPayload.error || "CanadaBuys award scout failed");

  await (s as any).from("tender_sources").update({
    last_run_at: new Date().toISOString(),
    last_success_at: new Date().toISOString(),
    last_error: null,
  }).eq("workspace_id",ctx.workspaceId).eq("source_key","canadabuys");

  const coverage = await fetch(base + "/functions/v1/procurement-coverage-engine", {
    method: "POST",
    headers: { Authorization: "Bearer " + accessToken, "Content-Type": "application/json" },
    body: JSON.stringify({ workspace_id: ctx.workspaceId, skip_scouts: true }),
    cache: "no-store",
  });
  if (!coverage.ok) {
    const coveragePayload = await coverage.json().catch(() => ({}));
    throw new Error(coveragePayload.error || "CanadaBuys scan succeeded but coverage routing failed");
  }

  const intelligence = await fetch(base + "/functions/v1/tender-intelligence-engine", {
    method: "POST",
    headers: { Authorization: "Bearer " + accessToken, "Content-Type": "application/json" },
    body: JSON.stringify({ workspace_id: ctx.workspaceId }),
    cache: "no-store",
  });
  if (!intelligence.ok) {
    const intelligencePayload = await intelligence.json().catch(() => ({}));
    throw new Error(intelligencePayload.error || "CanadaBuys routing succeeded but pursuit intelligence failed");
  }

  revalidatePath("/procurement");
  revalidatePath("/procurement/coverage");
  revalidatePath("/targets");
  revalidatePath("/dashboard");
}


export async function runRegionalTenderScout() {
  const ctx = await requireWorkspaceWithRole(ROLES.procurementLead);
  const s = await createClient();

  const { data: sessionData } = await s.auth.getSession();
  const accessToken = sessionData.session?.access_token;
  if (!accessToken) throw new Error("No active session");
  const base = process.env.NEXT_PUBLIC_SUPABASE_URL;
  if (!base) throw new Error("Supabase URL is not configured");

  const coverage = await fetch(base + "/functions/v1/procurement-coverage-engine", {
    method: "POST",
    headers: { Authorization: "Bearer " + accessToken, "Content-Type": "application/json" },
    body: JSON.stringify({ workspace_id: ctx.workspaceId }),
    cache: "no-store",
  });
  const coveragePayload = await coverage.json().catch(() => ({}));
  if (!coverage.ok) throw new Error(coveragePayload.error || "Regional procurement scan failed");

  const intelligence = await fetch(base + "/functions/v1/tender-intelligence-engine", {
    method: "POST",
    headers: { Authorization: "Bearer " + accessToken, "Content-Type": "application/json" },
    body: JSON.stringify({ workspace_id: ctx.workspaceId }),
    cache: "no-store",
  });
  const intelligencePayload = await intelligence.json().catch(() => ({}));
  if (!intelligence.ok) throw new Error(intelligencePayload.error || "Discovery succeeded but pursuit intelligence failed");

  revalidatePath("/procurement");
  revalidatePath("/procurement/coverage");
  revalidatePath("/targets");
  revalidatePath("/dashboard");
}


export async function runProcurementCoverageEngine() {
  const ctx = await requireWorkspaceWithRole(ROLES.procurementLead);
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

  const intelligence = await fetch(base + "/functions/v1/tender-intelligence-engine", {
    method: "POST",
    headers: { Authorization: "Bearer " + accessToken, "Content-Type": "application/json" },
    body: JSON.stringify({ workspace_id: ctx.workspaceId }),
    cache: "no-store",
  });
  const intelligencePayload = await intelligence.json().catch(() => ({}));
  if (!intelligence.ok) throw new Error(intelligencePayload.error || "Coverage refresh succeeded but pursuit intelligence failed");

  revalidatePath("/procurement");
  revalidatePath("/procurement/coverage");
  revalidatePath("/targets");
  revalidatePath("/dashboard");
}


export async function runTenderIntelligence(formData?: FormData) {
  const ctx = await requireWorkspaceWithRole(ROLES.procurementLead);
  const s = await createClient();

  const { data: sessionData } = await s.auth.getSession();
  const accessToken = sessionData.session?.access_token;
  if (!accessToken) throw new Error("No active session");
  const base = process.env.NEXT_PUBLIC_SUPABASE_URL;
  if (!base) throw new Error("Supabase URL is not configured");

  const tenderId = formData ? String(formData.get("tender_id") || "") : "";
  const response = await fetch(base + "/functions/v1/tender-intelligence-engine", {
    method: "POST",
    headers: { Authorization: "Bearer " + accessToken, "Content-Type": "application/json" },
    body: JSON.stringify({ workspace_id: ctx.workspaceId, tender_id: tenderId || undefined }),
    cache: "no-store",
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(payload.error || "Tender intelligence refresh failed");

  revalidatePath("/procurement");
  revalidatePath("/procurement/coverage");
  if (tenderId) revalidatePath(`/procurement/${tenderId}`);
  revalidatePath("/dashboard");
}

export async function runTenderDocumentIntelligence(formData: FormData) {
  const ctx = await requireWorkspaceWithRole(ROLES.procurementLead);
  const s = await createClient();
  const tenderId = String(formData.get("tender_id") || "");
  if (!tenderId) throw new Error("Tender is required");

  const { data: sessionData } = await s.auth.getSession();
  const accessToken = sessionData.session?.access_token;
  if (!accessToken) throw new Error("No active session");
  const base = process.env.NEXT_PUBLIC_SUPABASE_URL;
  if (!base) throw new Error("Supabase URL is not configured");

  const response = await fetch(base + "/functions/v1/tender-document-intelligence", {
    method: "POST",
    headers: { Authorization: "Bearer " + accessToken, "Content-Type": "application/json" },
    body: JSON.stringify({ workspace_id: ctx.workspaceId, tender_id: tenderId }),
    cache: "no-store",
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(payload.error || "Tender document intelligence failed");

  revalidatePath(`/procurement/${tenderId}`);
  revalidatePath("/procurement");
}

export async function saveTenderContractCycle(formData: FormData) {
  const ctx = await requireWorkspaceWithRole(ROLES.procurement);
  const s = await createClient();
  const tenderId = String(formData.get("tender_id") || "");
  if (!tenderId) throw new Error("Tender is required");

  const amountRaw = String(formData.get("previous_award_value") || "").trim();
  const amount = amountRaw ? Number(amountRaw) : null;
  if (amountRaw && !Number.isFinite(amount)) throw new Error("Previous award value must be numeric");

  const { error } = await (s as any).from("tender_records").update({
    incumbent_name: String(formData.get("incumbent_name") || "").trim() || null,
    previous_award_value: amount,
    contract_start_date: String(formData.get("contract_start_date") || "") || null,
    contract_end_date: String(formData.get("contract_end_date") || "") || null,
    expected_rebid_date: String(formData.get("expected_rebid_date") || "") || null,
    updated_at: new Date().toISOString(),
  }).eq("workspace_id",ctx.workspaceId).eq("id",tenderId);
  if (error) throw error;

  const fd = new FormData();
  fd.set("tender_id",tenderId);
  await runTenderIntelligence(fd);
}

export async function updateSubtradeStatus(formData: FormData) {
  const ctx = await requireWorkspaceWithRole(ROLES.procurement);
  const s = await createClient();
  const id = String(formData.get("subtrade_id") || "");
  const tenderId = String(formData.get("tender_id") || "");
  const status = String(formData.get("status") || "");
  const allowed = ["identified","researching_primes","outreach","pricing","submitted","won","lost","not_pursuing"];
  if (!id || !tenderId || !allowed.includes(status)) throw new Error("Invalid subtrade status");

  const { error } = await (s as any).from("tender_subtrade_opportunities").update({
    pursuit_status:status,updated_at:new Date().toISOString(),
  }).eq("workspace_id",ctx.workspaceId).eq("id",id).eq("tender_record_id",tenderId);
  if (error) throw error;
  revalidatePath(`/procurement/${tenderId}`);
  revalidatePath("/procurement");
}

export async function updateFutureOpportunityStatus(formData: FormData) {
  const ctx = await requireWorkspaceWithRole(ROLES.procurement);
  const s = await createClient();
  const id = String(formData.get("future_id") || "");
  const status = String(formData.get("status") || "");
  const allowed = ["watch","research","pre_position","published","converted","closed"];
  if (!id || !allowed.includes(status)) throw new Error("Invalid future opportunity status");

  const { error } = await (s as any).from("procurement_future_opportunities").update({
    status,updated_at:new Date().toISOString(),
  }).eq("workspace_id",ctx.workspaceId).eq("id",id);
  if (error) throw error;
  revalidatePath("/procurement");
}

function numberField(formData: FormData, key: string, fallback = 0) {
  const value = Number(formData.get(key) ?? fallback);
  return Number.isFinite(value) ? value : fallback;
}

export async function acknowledgeTenderAmendment(formData: FormData) {
  const ctx = await requireWorkspaceWithRole(ROLES.procurement);
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
  const ctx = await requireWorkspaceWithRole(ROLES.procurement);
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
  const ctx = await requireWorkspaceWithRole(ROLES.procurement);
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
  const ctx = await requireWorkspaceWithRole(ROLES.procurement);
  const s = await createClient();
  const tenderId = String(formData.get("tender_id") || "");
  const supplierName = String(formData.get("supplier_name") || "").trim();
  if (!tenderId || !supplierName) throw new Error("Tender and supplier are required");
  const validUntil = String(formData.get("valid_until") || "");
  const status = String(formData.get("status") || "received");
  if (!["invited","sent","received","shortlisted","accepted","rejected"].includes(status)) throw new Error("Invalid supplier quote status");
  const { error } = await (s as any).from("tender_supplier_quotes").insert({
    workspace_id: ctx.workspaceId,
    tender_record_id: tenderId,
    supplier_name: supplierName,
    supplier_contact_name: String(formData.get("supplier_contact_name") || "").trim() || null,
    supplier_email: String(formData.get("supplier_email") || "").trim() || null,
    status,
    product_cost: numberField(formData,"product_cost"),
    freight_cost: numberField(formData,"freight_cost"),
    deposits_cost: numberField(formData,"deposits_cost"),
    handling_cost: numberField(formData,"handling_cost"),
    financing_cost: numberField(formData,"financing_cost"),
    contingency_cost: numberField(formData,"contingency_cost"),
    service_region: String(formData.get("service_region") || "").trim() || null,
    distance_km: numberField(formData,"distance_km") || null,
    capacity_score: numberField(formData,"capacity_score") || null,
    reliability_score: numberField(formData,"reliability_score") || null,
    emergency_score: numberField(formData,"emergency_score") || null,
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
  const ctx = await requireWorkspaceWithRole(ROLES.procurement);
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
  const ctx = await requireWorkspaceWithRole(ROLES.procurement);
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
  const ctx = await requireWorkspaceWithRole(ROLES.procurement);
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
  const ctx = await requireWorkspaceWithRole(ROLES.procurement);
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
  const ctx = await requireWorkspaceWithRole(ROLES.procurementLead);
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
  const ctx = await requireWorkspaceWithRole(ROLES.procurement);
  const s = await createClient();
  const tenderId = String(formData.get("tender_id") || "");
  const title = String(formData.get("title") || "").trim();
  const documentType = String(formData.get("document_type") || "other").trim();
  if (!title) throw new Error("Document title is required");
  const expiresOn = String(formData.get("expires_on") || "");
  const status = String(formData.get("status") || "active");
  if (!["active","expiring","expired","draft"].includes(status)) throw new Error("Invalid vault document status");
  const { data: userData } = await s.auth.getUser();
  const { error } = await (s as any).from("supplier_document_vault").upsert({
    workspace_id: ctx.workspaceId,
    document_type: documentType,
    title,
    status,
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
  const ctx = await requireWorkspaceWithRole(ROLES.procurement);
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


export async function saveTenderPortalSnapshot(formData: FormData) {
  const ctx = await requireWorkspaceWithRole(ROLES.procurement);
  const s = await createClient();
  const tenderId = String(formData.get("tender_id") || "");
  const portalName = String(formData.get("portal_name") || "").trim();
  if (!tenderId || !portalName) throw new Error("Tender and portal name are required");
  const captureMethod = String(formData.get("capture_method") || "authenticated_manual");
  if (!["authenticated_manual","authenticated_automation","public","import"].includes(captureMethod)) throw new Error("Invalid portal capture method");
  const rawText = String(formData.get("raw_payload") || "").trim();
  let rawPayload: Record<string, unknown> = {};
  if (rawText) {
    try { rawPayload = JSON.parse(rawText); }
    catch { rawPayload = { captured_text: rawText }; }
  }
  const sourceUrl = String(formData.get("source_url") || "").trim() || null;
  const deadline = String(formData.get("response_deadline_at") || "");
  const fingerprintSource = JSON.stringify(rawPayload) + "|" + String(sourceUrl || "") + "|" + String(deadline || "");
  let hash = 0;
  for (let i=0;i<fingerprintSource.length;i++) hash=((hash<<5)-hash+fingerprintSource.charCodeAt(i))|0;
  const contentHash = "cb-"+Math.abs(hash).toString(16);
  const { data: userData } = await s.auth.getUser();
  const { error } = await (s as any).from("tender_portal_snapshots").upsert({
    workspace_id: ctx.workspaceId,
    tender_record_id: tenderId,
    portal_name: portalName,
    capture_method: captureMethod,
    response_status: String(formData.get("response_status") || "").trim() || null,
    response_deadline_at: deadline ? new Date(deadline).toISOString() : null,
    source_url: sourceUrl,
    content_hash: contentHash,
    raw_payload: rawPayload,
    notes: String(formData.get("notes") || "").trim() || null,
    captured_by: userData.user?.id ?? null,
    captured_at: new Date().toISOString(),
  },{onConflict:"tender_record_id,portal_name,content_hash"});
  if (error) throw error;
  revalidatePath(`/procurement/${tenderId}`);
}

export async function addTenderLineItem(formData: FormData) {
  const ctx = await requireWorkspaceWithRole(ROLES.procurement);
  const s = await createClient();
  const tenderId = String(formData.get("tender_id") || "");
  const itemNumber = String(formData.get("item_number") || "").trim();
  const description = String(formData.get("description") || "").trim();
  if (!tenderId || !itemNumber || !description) throw new Error("Tender, item number and description are required");
  const status = String(formData.get("status") || "pending");
  if (!["pending","priced","complete","not_applicable"].includes(status)) throw new Error("Invalid line-item status");
  const { error } = await (s as any).from("tender_line_items").upsert({
    workspace_id: ctx.workspaceId,
    tender_record_id: tenderId,
    item_number: itemNumber,
    description,
    specification: String(formData.get("specification") || "").trim() || null,
    quantity: numberField(formData,"quantity") || null,
    unit: String(formData.get("unit") || "").trim() || null,
    mandatory: formData.get("mandatory") === "on",
    source_reference: String(formData.get("source_reference") || "").trim() || null,
    response_value: String(formData.get("response_value") || "").trim() || null,
    unit_price: numberField(formData,"unit_price") || null,
    status,
    updated_at: new Date().toISOString(),
  },{onConflict:"tender_record_id,item_number"});
  if (error) throw error;
  revalidatePath(`/procurement/${tenderId}`);
}

export async function updateTenderLineItem(formData: FormData) {
  const ctx = await requireWorkspaceWithRole(ROLES.procurement);
  const s = await createClient();
  const tenderId = String(formData.get("tender_id") || "");
  const id = String(formData.get("line_item_id") || "");
  const status = String(formData.get("status") || "");
  if (!tenderId || !id || !["pending","priced","complete","not_applicable"].includes(status)) throw new Error("Invalid line-item update");
  const { error } = await (s as any).from("tender_line_items").update({
    response_value: String(formData.get("response_value") || "").trim() || null,
    unit_price: numberField(formData,"unit_price") || null,
    status,
    updated_at: new Date().toISOString(),
  }).eq("workspace_id",ctx.workspaceId).eq("tender_record_id",tenderId).eq("id",id);
  if (error) throw error;
  revalidatePath(`/procurement/${tenderId}`);
}

export async function saveTenderPriceYear(formData: FormData) {
  const ctx = await requireWorkspaceWithRole(ROLES.procurement);
  const s = await createClient();
  const tenderId = String(formData.get("tender_id") || "");
  const costModelId = String(formData.get("cost_model_id") || "");
  const yearNumber = Math.max(1,Math.min(10,Math.trunc(numberField(formData,"year_number",1))));
  if (!tenderId || !costModelId) throw new Error("Tender and cost model are required");
  const { error } = await (s as any).from("tender_price_years").upsert({
    workspace_id: ctx.workspaceId,
    tender_record_id: tenderId,
    cost_model_id: costModelId,
    year_number: yearNumber,
    projected_cost: Math.max(0,numberField(formData,"projected_cost")),
    escalation_rate: numberField(formData,"escalation_rate")/100,
    bid_price: Math.max(0,numberField(formData,"bid_price")),
    notes: String(formData.get("notes") || "").trim() || null,
    updated_at: new Date().toISOString(),
  },{onConflict:"cost_model_id,year_number"});
  if (error) throw error;
  revalidatePath(`/procurement/${tenderId}`);
}

export async function saveTenderDebrief(formData: FormData) {
  const ctx = await requireWorkspaceWithRole(ROLES.procurement);
  const s = await createClient();
  const tenderId = String(formData.get("tender_id") || "");
  if (!tenderId) throw new Error("Tender is required");
  const { data: userData } = await s.auth.getUser();
  const nextRebid = String(formData.get("next_rebid_date") || "");
  const winningValue = numberField(formData,"winning_value");
  const payload = {
    workspace_id: ctx.workspaceId,
    tender_record_id: tenderId,
    requested_at: formData.get("requested") === "on" ? new Date().toISOString() : null,
    received_at: formData.get("received") === "on" ? new Date().toISOString() : null,
    winning_supplier: String(formData.get("winning_supplier") || "").trim() || null,
    winning_value: winningValue || null,
    result_summary: String(formData.get("result_summary") || "").trim() || null,
    strengths: String(formData.get("strengths") || "").trim() || null,
    gaps: String(formData.get("gaps") || "").trim() || null,
    lessons_learned: String(formData.get("lessons_learned") || "").trim() || null,
    next_rebid_date: nextRebid || null,
    source_url: String(formData.get("source_url") || "").trim() || null,
    created_by: userData.user?.id ?? null,
    updated_at: new Date().toISOString(),
  };
  const { error } = await (s as any).from("tender_debriefs").upsert(payload,{onConflict:"tender_record_id"});
  if (error) throw error;

  const winner = String(formData.get("winning_supplier") || "").trim() || null;
  const outcome = String(formData.get("outcome") || "");
  const tenderPatch: Record<string,unknown> = {
    award_supplier_name: winner,
    award_value: winningValue || null,
    expected_rebid_date: nextRebid || null,
    debrief_requested_at: payload.requested_at,
    debrief_notes: payload.lessons_learned,
  };
  if (outcome === "won" || outcome === "lost") {
    tenderPatch.action_state = outcome;
    tenderPatch.status = outcome;
    tenderPatch.next_action = outcome === "won" ? "Create contract handoff and mobilization plan" : "Capture debrief, incumbent and next rebid date";
  }
  const { error: tenderError } = await (s as any).from("tender_records").update(tenderPatch)
    .eq("workspace_id",ctx.workspaceId).eq("id",tenderId);
  if (tenderError) throw tenderError;
  revalidatePath(`/procurement/${tenderId}`);
  revalidatePath("/procurement");
}


export async function generateTenderBidPack(formData: FormData) {
  const ctx = await requireWorkspaceWithRole(ROLES.procurement);
  const s = await createClient();
  const tenderId = String(formData.get("tender_id") || "");
  if (!tenderId) throw new Error("Tender is required");

  const [
    { data: tender, error: tenderError },
    { data: requirements },
    { data: amendments },
    { data: clarifications },
    { data: quotes },
    { data: costModels },
    { data: priceYears },
    { data: lineItems },
    { data: risks },
    { data: approvals },
    { data: vaultDocs },
  ] = await Promise.all([
    (s as any).from("tender_records").select("*").eq("workspace_id",ctx.workspaceId).eq("id",tenderId).single(),
    (s as any).from("tender_requirements").select("*").eq("workspace_id",ctx.workspaceId).eq("tender_record_id",tenderId).order("mandatory",{ascending:false}),
    (s as any).from("tender_amendments").select("*").eq("workspace_id",ctx.workspaceId).eq("tender_record_id",tenderId).order("amendment_number"),
    (s as any).from("tender_clarifications").select("*").eq("workspace_id",ctx.workspaceId).eq("tender_record_id",tenderId),
    (s as any).from("tender_supplier_quotes").select("*").eq("workspace_id",ctx.workspaceId).eq("tender_record_id",tenderId),
    (s as any).from("tender_cost_models").select("*").eq("workspace_id",ctx.workspaceId).eq("tender_record_id",tenderId),
    (s as any).from("tender_price_years").select("*").eq("workspace_id",ctx.workspaceId).eq("tender_record_id",tenderId).order("year_number"),
    (s as any).from("tender_line_items").select("*").eq("workspace_id",ctx.workspaceId).eq("tender_record_id",tenderId).order("item_number"),
    (s as any).from("tender_risks").select("*").eq("workspace_id",ctx.workspaceId).eq("tender_record_id",tenderId),
    (s as any).from("tender_approvals").select("*").eq("workspace_id",ctx.workspaceId).eq("tender_record_id",tenderId),
    (s as any).from("supplier_document_vault").select("*").eq("workspace_id",ctx.workspaceId).eq("status","active"),
  ]);
  if (tenderError) throw tenderError;

  const mandatoryGaps=(requirements??[]).filter((r:any)=>r.mandatory && !["complete","not_applicable"].includes(r.status));
  const evidenceGaps=(requirements??[]).filter((r:any)=>r.mandatory && r.evidence_required && r.status==="complete" && !r.evidence_url);
  const amendmentGaps=(amendments??[]).filter((a:any)=>a.amendment_number>0 && !a.acknowledged_at);
  const clarificationGaps=(clarifications??[]).filter((q:any)=>q.blocking && !["answered","closed"].includes(q.status));
  const lineItemGaps=(lineItems??[]).filter((li:any)=>li.mandatory && !["complete","not_applicable"].includes(li.status));
  const highRisks=(risks??[]).filter((r:any)=>r.status==="open" && Number(r.probability)*Number(r.impact)>=15);
  const commercial=(costModels??[]).find((m:any)=>m.status==="approved");
  if (mandatoryGaps.length || evidenceGaps.length || amendmentGaps.length || clarificationGaps.length || lineItemGaps.length || highRisks.length || !commercial || !tender.estimate_id) {
    throw new Error("Bid pack cannot be generated until compliance, amendments, questions, line items, high risks, estimate and commercial model are clear");
  }

  const { data: latest } = await (s as any).from("tender_bid_packs")
    .select("version").eq("workspace_id",ctx.workspaceId).eq("tender_record_id",tenderId)
    .order("version",{ascending:false}).limit(1).maybeSingle();
  const version=Number(latest?.version||0)+1;
  const acceptedQuote=(quotes??[]).find((q:any)=>q.status==="accepted") ?? null;
  const manifest={
    tender:{
      id:tender.id,external_id:tender.external_id,title:tender.title,buyer_name:tender.buyer_name,
      closing_date:tender.closing_date,source:tender.source,source_url:tender.source_url,
    },
    generated_at:new Date().toISOString(),
    requirements:(requirements??[]).map((r:any)=>({title:r.title,status:r.status,mandatory:r.mandatory,evidence_url:r.evidence_url,source_reference:r.source_reference})),
    amendments:(amendments??[]).map((a:any)=>({number:a.amendment_number,title:a.title,acknowledged_at:a.acknowledged_at,changed_fields:a.changed_fields})),
    clarifications:(clarifications??[]).map((q:any)=>({question:q.question,status:q.status,response_text:q.response_text})),
    supplier_quote:acceptedQuote,
    commercial_model:commercial,
    price_years:priceYears??[],
    line_items:lineItems??[],
    risks:risks??[],
    approvals:approvals??[],
    reusable_documents:(vaultDocs??[]).map((d:any)=>({document_type:d.document_type,title:d.title,evidence_url:d.evidence_url,expires_on:d.expires_on})),
  };
  const { data: userData } = await s.auth.getUser();
  await (s as any).from("tender_bid_packs").update({status:"obsolete"})
    .eq("workspace_id",ctx.workspaceId).eq("tender_record_id",tenderId).in("status",["draft","ready"]);
  const { error } = await (s as any).from("tender_bid_packs").insert({
    workspace_id:ctx.workspaceId,
    tender_record_id:tenderId,
    version,
    status:"ready",
    manifest,
    generated_by:userData.user?.id ?? null,
    approved_at:new Date().toISOString(),
  });
  if (error) throw error;
  revalidatePath(`/procurement/${tenderId}`);
  revalidatePath("/procurement");
}

export async function updateTenderCallup(formData: FormData) {
  const ctx = await requireWorkspaceWithRole(ROLES.procurement);
  const s = await createClient();
  const tenderId = String(formData.get("tender_id") || "");
  const id = String(formData.get("callup_id") || "");
  const status = String(formData.get("status") || "");
  if (!tenderId || !id || !["issued","accepted","in_fulfillment","delivered","invoiced","paid","cancelled"].includes(status)) throw new Error("Invalid call-up update");
  const now=new Date().toISOString();
  const { error } = await (s as any).from("tender_callups").update({
    status,
    revenue: Math.max(0,numberField(formData,"revenue")),
    direct_cost: Math.max(0,numberField(formData,"direct_cost")),
    invoice_number: String(formData.get("invoice_number") || "").trim() || null,
    delivered_at: status==="delivered" ? now : undefined,
    invoice_sent_at: status==="invoiced" ? now : undefined,
    paid_at: status==="paid" ? now : undefined,
    updated_at: now,
  }).eq("workspace_id",ctx.workspaceId).eq("tender_record_id",tenderId).eq("id",id);
  if (error) throw error;
  revalidatePath(`/procurement/${tenderId}`);
}

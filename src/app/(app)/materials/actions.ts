"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { requireWorkspace } from "@/lib/workspace";
import { requireWorkspaceRole } from "@/lib/authz";
import { buildDeckTakeoff, parseLegacyDeckSpec } from "../estimates/deck-takeoff";

const MATERIAL_ROLES = ["owner", "administrator", "operations_manager", "sales_manager", "sales_rep"] as const;

function textValue(f: FormData, key: string) {
  return String(f.get(key) ?? "").trim();
}

function numberValue(f: FormData, key: string, fallback = 0) {
  const n = Number(f.get(key));
  return Number.isFinite(n) ? n : fallback;
}

function todayInOttawa() {
  return new Intl.DateTimeFormat("sv-SE", { timeZone: "America/Toronto" }).format(new Date());
}

function optionalDate(f: FormData, key: string) {
  const value = textValue(f, key);
  if (!value) return null;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value) || value < todayInOttawa()) {
    throw new Error("Quote expiry must be today or later");
  }
  return value;
}

function optionalUrl(f: FormData, key: string) {
  const value = textValue(f, key);
  if (!value) return null;
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    throw new Error("Evidence URL is invalid");
  }
  if (!["https:", "http:"].includes(url.protocol)) throw new Error("Evidence URL must use HTTP or HTTPS");
  return url.toString();
}

async function context() {
  const ctx = await requireWorkspace();
  const s = await createClient();
  await requireWorkspaceRole(s, ctx.workspaceId, MATERIAL_ROLES);
  return { ctx, s };
}

async function invokePriceScout(
  s: Awaited<ReturnType<typeof createClient>>,
  workspaceId: string,
  requestId: string,
  refresh: boolean,
) {
  const { data: sessionData } = await s.auth.getSession();
  const accessToken = sessionData.session?.access_token;
  if (!accessToken) throw new Error("No active session");

  const base = process.env.NEXT_PUBLIC_SUPABASE_URL;
  if (!base) throw new Error("Supabase URL is not configured");

  const response = await fetch(base + "/functions/v1/material-price-intelligence", {
    method: "POST",
    headers: {
      Authorization: "Bearer " + accessToken,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      workspace_id: workspaceId,
      request_id: requestId,
      refresh,
    }),
    cache: "no-store",
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(payload.error || "Material price scan failed");
  return payload;
}

async function recalculateIfReady(
  s: Awaited<ReturnType<typeof createClient>>,
  workspaceId: string,
  requestId: string,
  refresh: boolean,
) {
  const { count, error } = await (s as any)
    .from("material_request_items")
    .select("id", { count: "exact", head: true })
    .eq("workspace_id", workspaceId)
    .eq("request_id", requestId);
  if (error) throw new Error(error.message);
  if ((count ?? 0) > 0) {
    return invokePriceScout(s, workspaceId, requestId, refresh);
  }
  return null;
}

export async function generateDeckMaterialTakeoff(f: FormData) {
  const { ctx, s } = await context();
  const estimateId = textValue(f, "estimate_id");
  if (!estimateId) throw new Error("Estimate is required");

  const [{ data: estimate }, { data: firstItems }, { data: existingSpec }, { data: userData }] = await Promise.all([
    (s as any)
      .from("estimates")
      .select("id,estimate_number,estimate_kind,property_id,status")
      .eq("workspace_id", ctx.workspaceId)
      .eq("id", estimateId)
      .maybeSingle(),
    (s as any)
      .from("estimate_items")
      .select("description")
      .eq("workspace_id", ctx.workspaceId)
      .eq("estimate_id", estimateId)
      .order("sort_order")
      .limit(1),
    (s as any)
      .from("deck_estimate_specs")
      .select("*")
      .eq("workspace_id", ctx.workspaceId)
      .eq("estimate_id", estimateId)
      .maybeSingle(),
    s.auth.getUser(),
  ]);

  if (!estimate || estimate.estimate_kind !== "deck") throw new Error("Deck estimate not found");

  let spec = existingSpec as any;
  if (!spec) {
    const legacy = parseLegacyDeckSpec(firstItems?.[0]?.description ?? "");
    if (!legacy) throw new Error("This legacy deck estimate has no recoverable dimensions. Revise the estimate and save its structured scope first.");

    const { data: inserted, error: specError } = await (s as any)
      .from("deck_estimate_specs")
      .insert({
        workspace_id: ctx.workspaceId,
        estimate_id: estimateId,
        ...legacy,
        created_by: userData.user?.id ?? null,
      })
      .select("*")
      .single();
    if (specError || !inserted) throw new Error(specError?.message || "Could not persist recovered deck specification");
    spec = inserted;
  }

  const takeoff = buildDeckTakeoff(spec);
  const canonicalKeys = [...new Set(takeoff.map((line) => line.canonicalKey))];

  const { data: catalog, error: catalogError } = await (s as any)
    .from("material_catalog_items")
    .select("id,canonical_key,description")
    .eq("workspace_id", ctx.workspaceId)
    .eq("active", true)
    .in("canonical_key", canonicalKeys);
  if (catalogError) throw new Error(catalogError.message);

  const catalogByKey = new Map((catalog ?? []).map((row: any) => [row.canonical_key, row]));
  const missing = canonicalKeys.filter((key) => !catalogByKey.has(key));
  if (missing.length) throw new Error(`Material catalog is missing: ${missing.join(", ")}`);

  const { data: existingRequests, error: requestLookupError } = await (s as any)
    .from("material_requests")
    .select("id,status")
    .eq("workspace_id", ctx.workspaceId)
    .eq("estimate_id", estimateId)
    .neq("status", "archived")
    .order("created_at", { ascending: false })
    .limit(1);
  if (requestLookupError) throw new Error(requestLookupError.message);

  let requestId = existingRequests?.[0]?.id as string | undefined;
  if (!requestId) {
    const { data: created, error: createError } = await (s as any)
      .from("material_requests")
      .insert({
        workspace_id: ctx.workspaceId,
        estimate_id: estimateId,
        property_id: estimate.property_id ?? null,
        name: `${estimate.estimate_number} automatic deck takeoff`,
        region: "Ottawa, ON",
        status: "draft",
        waste_pct: 5,
        delivery_mode: "pickup",
        notes: "Core lumber generated from the structured deck estimate. Verify structural design, hardware, concrete, stairs and guards before purchasing.",
        created_by: userData.user?.id ?? null,
      })
      .select("id")
      .single();
    if (createError || !created) throw new Error(createError?.message || "Could not create material request");
    requestId = created.id;
  }

  const { error: deleteError } = await (s as any)
    .from("material_request_items")
    .delete()
    .eq("workspace_id", ctx.workspaceId)
    .eq("request_id", requestId)
    .eq("source_type", "deck_takeoff");
  if (deleteError) throw new Error(deleteError.message);

  const generatedRows = takeoff.map((line, index) => ({
    workspace_id: ctx.workspaceId,
    request_id: requestId,
    material_item_id: catalogByKey.get(line.canonicalKey).id,
    quantity: line.quantity,
    notes: line.note,
    sort_order: index,
    source_type: "deck_takeoff",
    source_key: line.sourceKey,
  }));

  const { error: insertError } = await (s as any)
    .from("material_request_items")
    .insert(generatedRows);
  if (insertError) throw new Error(insertError.message);

  await (s as any)
    .from("material_requests")
    .update({
      property_id: estimate.property_id ?? null,
      status: "draft",
      updated_at: new Date().toISOString(),
    })
    .eq("workspace_id", ctx.workspaceId)
    .eq("id", requestId);

  await invokePriceScout(s, ctx.workspaceId, requestId, true);

  revalidatePath("/materials");
  revalidatePath(`/materials/${requestId}`);
  revalidatePath(`/estimates/${estimateId}`);
  redirect(`/materials/${requestId}`);
}

export async function createMaterialRequest(f: FormData) {
  const { ctx, s } = await context();
  const name = textValue(f, "name");
  if (!name) throw new Error("Request name is required");

  const estimateId = textValue(f, "estimate_id") || null;
  if (estimateId) {
    const { data: estimate } = await (s as any)
      .from("estimates")
      .select("id")
      .eq("workspace_id", ctx.workspaceId)
      .eq("id", estimateId)
      .maybeSingle();
    if (!estimate) throw new Error("Estimate not found in this workspace");
  }

  const { data: userData } = await s.auth.getUser();
  const { data: row, error } = await (s as any)
    .from("material_requests")
    .insert({
      workspace_id: ctx.workspaceId,
      estimate_id: estimateId,
      name,
      region: textValue(f, "region") || "Ottawa, ON",
      waste_pct: Math.min(50, Math.max(0, numberValue(f, "waste_pct", 5))),
      delivery_mode: textValue(f, "delivery_mode") === "delivery" ? "delivery" : "pickup",
      notes: textValue(f, "notes") || null,
      created_by: userData.user?.id ?? null,
    })
    .select("id")
    .single();
  if (error || !row) throw new Error(error?.message || "Could not create material request");
  redirect(`/materials/${row.id}`);
}

export async function addMaterialRequestItem(f: FormData) {
  const { ctx, s } = await context();
  const requestId = textValue(f, "request_id");
  const materialItemId = textValue(f, "material_item_id");
  const quantity = numberValue(f, "quantity");
  if (!requestId || !materialItemId || quantity <= 0) throw new Error("Material and quantity are required");

  const [{ data: request }, { data: catalog }] = await Promise.all([
    (s as any).from("material_requests").select("id").eq("workspace_id", ctx.workspaceId).eq("id", requestId).maybeSingle(),
    (s as any).from("material_catalog_items").select("id").eq("workspace_id", ctx.workspaceId).eq("id", materialItemId).eq("active", true).maybeSingle(),
  ]);
  if (!request || !catalog) throw new Error("Material request or catalog item not found");

  const { data: current } = await (s as any)
    .from("material_request_items")
    .select("sort_order")
    .eq("workspace_id", ctx.workspaceId)
    .eq("request_id", requestId)
    .order("sort_order", { ascending: false })
    .limit(1);

  const { error } = await (s as any).from("material_request_items").insert({
    workspace_id: ctx.workspaceId,
    request_id: requestId,
    material_item_id: materialItemId,
    quantity,
    notes: textValue(f, "notes") || null,
    sort_order: Number(current?.[0]?.sort_order ?? -1) + 1,
  });
  if (error) throw new Error(error.message);

  revalidatePath(`/materials/${requestId}`);
  revalidatePath("/materials");
}

export async function removeMaterialRequestItem(f: FormData) {
  const { ctx, s } = await context();
  const requestId = textValue(f, "request_id");
  const itemId = textValue(f, "request_item_id");
  if (!requestId || !itemId) throw new Error("Request item is required");

  const { error } = await (s as any)
    .from("material_request_items")
    .delete()
    .eq("workspace_id", ctx.workspaceId)
    .eq("request_id", requestId)
    .eq("id", itemId);
  if (error) throw new Error(error.message);

  revalidatePath(`/materials/${requestId}`);
  revalidatePath("/materials");
}

export async function runMaterialPriceScan(f: FormData) {
  const { ctx, s } = await context();
  const requestId = textValue(f, "request_id");
  if (!requestId) throw new Error("Request is required");

  const { data: request } = await (s as any)
    .from("material_requests")
    .select("id")
    .eq("workspace_id", ctx.workspaceId)
    .eq("id", requestId)
    .maybeSingle();
  if (!request) throw new Error("Material request not found");

  await invokePriceScout(s, ctx.workspaceId, requestId, true);
  revalidatePath(`/materials/${requestId}`);
  revalidatePath("/materials");
}

export async function recordManualMaterialQuote(f: FormData) {
  const { ctx, s } = await context();
  const requestId = textValue(f, "request_id");
  const requestItemId = textValue(f, "request_item_id");
  const supplierId = textValue(f, "supplier_id");
  const priceEach = numberValue(f, "price_each");
  if (!requestId || !requestItemId || !supplierId || priceEach <= 0) {
    throw new Error("Request item, supplier, and price are required");
  }

  const [{ data: requestItem }, { data: supplier }] = await Promise.all([
    (s as any)
      .from("material_request_items")
      .select("id,material_item_id")
      .eq("workspace_id", ctx.workspaceId)
      .eq("request_id", requestId)
      .eq("id", requestItemId)
      .maybeSingle(),
    (s as any)
      .from("material_suppliers")
      .select("id")
      .eq("workspace_id", ctx.workspaceId)
      .eq("id", supplierId)
      .eq("active", true)
      .maybeSingle(),
  ]);
  if (!requestItem || !supplier) throw new Error("Material or supplier not found");

  const { data: userData } = await s.auth.getUser();
  const { error } = await (s as any).from("material_price_observations").insert({
    workspace_id: ctx.workspaceId,
    material_item_id: requestItem.material_item_id,
    supplier_id: supplierId,
    price_each: priceEach,
    currency: "CAD",
    stock_status: textValue(f, "stock_status") || "quoted",
    store_label: textValue(f, "store_label") || "Ottawa contractor desk",
    evidence_url: optionalUrl(f, "evidence_url"),
    valid_until: optionalDate(f, "valid_until"),
    source_type: "manual_quote",
    confidence: textValue(f, "evidence_url") ? "high" : "medium",
    raw_excerpt: textValue(f, "quote_note") || null,
    observed_at: new Date().toISOString(),
    created_by: userData.user?.id ?? null,
  });
  if (error) throw new Error(error.message);

  await invokePriceScout(s, ctx.workspaceId, requestId, false);
  revalidatePath(`/materials/${requestId}`);
  revalidatePath("/materials");
}

export async function saveMaterialSupplierTerms(f: FormData) {
  const { ctx, s } = await context();
  const requestId = textValue(f, "request_id");
  const supplierId = textValue(f, "supplier_id");
  if (!requestId || !supplierId) throw new Error("Request and supplier are required");

  const [{ data: request }, { data: supplier }] = await Promise.all([
    (s as any)
      .from("material_requests")
      .select("id")
      .eq("workspace_id", ctx.workspaceId)
      .eq("id", requestId)
      .maybeSingle(),
    (s as any)
      .from("material_suppliers")
      .select("id")
      .eq("workspace_id", ctx.workspaceId)
      .eq("id", supplierId)
      .eq("active", true)
      .maybeSingle(),
  ]);
  if (!request || !supplier) throw new Error("Material request or supplier not found");

  const rawFee = textValue(f, "delivery_fee");
  const deliveryFee = rawFee ? Number(rawFee) : null;
  if (deliveryFee != null && (!Number.isFinite(deliveryFee) || deliveryFee < 0 || deliveryFee > 100000)) {
    throw new Error("Delivery fee is invalid");
  }
  const deliveryVerified = f.get("delivery_verified") === "on";
  if (deliveryVerified && deliveryFee == null) throw new Error("Enter a delivery fee before marking delivery verified");

  const { data: userData } = await s.auth.getUser();
  const { error } = await (s as any)
    .from("material_request_supplier_terms")
    .upsert(
      {
        workspace_id: ctx.workspaceId,
        request_id: requestId,
        supplier_id: supplierId,
        delivery_fee: deliveryFee,
        delivery_verified: deliveryVerified,
        quote_reference: textValue(f, "quote_reference") || null,
        valid_until: optionalDate(f, "valid_until"),
        evidence_url: optionalUrl(f, "evidence_url"),
        notes: textValue(f, "notes") || null,
        updated_by: userData.user?.id ?? null,
      },
      { onConflict: "workspace_id,request_id,supplier_id" },
    );
  if (error) throw new Error(error.message);

  await recalculateIfReady(s, ctx.workspaceId, requestId, false);
  revalidatePath(`/materials/${requestId}`);
  revalidatePath("/materials");
  revalidatePath("/estimates");
}

export async function updateMaterialRequestSettings(f: FormData) {
  const { ctx, s } = await context();
  const requestId = textValue(f, "request_id");
  if (!requestId) throw new Error("Request is required");

  const waste = numberValue(f, "waste_pct", 5);
  if (waste < 0 || waste > 50) throw new Error("Waste must be between 0% and 50%");
  const deliveryMode = textValue(f, "delivery_mode") === "delivery" ? "delivery" : "pickup";

  const { data: request } = await (s as any)
    .from("material_requests")
    .select("id,status")
    .eq("workspace_id", ctx.workspaceId)
    .eq("id", requestId)
    .maybeSingle();
  if (!request) throw new Error("Material request not found");
  const { error } = await (s as any)
    .from("material_requests")
    .update({
      waste_pct: waste,
      delivery_mode: deliveryMode,
      notes: textValue(f, "notes") || null,
      updated_at: new Date().toISOString(),
    })
    .eq("workspace_id", ctx.workspaceId)
    .eq("id", requestId);
  if (error) throw new Error(error.message);

  await recalculateIfReady(s, ctx.workspaceId, requestId, false);
  revalidatePath(`/materials/${requestId}`);
  revalidatePath("/materials");
  revalidatePath("/estimates");
}

export async function selectMaterialPricePlan(f: FormData) {
  const { ctx, s } = await context();
  const requestId = textValue(f, "request_id");
  const planId = textValue(f, "plan_id");
  if (!requestId || !planId) throw new Error("Plan is required");

  const { data: request } = await (s as any)
    .from("material_requests")
    .select("id")
    .eq("workspace_id", ctx.workspaceId)
    .eq("id", requestId)
    .maybeSingle();
  if (!request) throw new Error("Material request not found");

  const { error } = await (s as any).rpc("select_material_price_plan", {
    p_request_id: requestId,
    p_plan_id: planId,
  });
  if (error) throw new Error(error.message);

  revalidatePath(`/materials/${requestId}`);
  revalidatePath("/materials");
  revalidatePath("/estimates");
}

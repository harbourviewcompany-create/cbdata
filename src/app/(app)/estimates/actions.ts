"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { requireWorkspaceRole, ROLES } from "@/lib/authz";
import { getWorkspaceContext } from "@/lib/workspace";
import { DECK_LINES, GUARD_LINE } from "./deck-pricing";

function text(f: FormData, key: string) {
  return String(f.get(key) ?? "").trim();
}

function todayInOttawa() {
  return new Intl.DateTimeFormat("sv-SE", { timeZone: "America/Toronto" }).format(new Date());
}

function amount(f: FormData, key: string) {
  const raw = text(f, key);
  if (!/^\d{1,7}(\.\d{1,2})?$/.test(raw)) throw new Error(`Invalid amount: ${key}`);
  return Number(raw);
}

function validateExpiry(value: string) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value) || value < todayInOttawa()) {
    throw new Error("Choose a current or future quote expiry date");
  }
}

function dimension(f: FormData, key: string, min: number, max: number) {
  const n = Number(text(f, key));
  if (!Number.isFinite(n) || n < min || n > max) throw new Error(`Invalid ${key}`);
  return n;
}

async function validateProperty(
  s: Awaited<ReturnType<typeof createClient>>,
  workspaceId: string,
  organizationId: string,
  propertyId: string,
) {
  if (!propertyId) return;
  const { data: property, error } = await s
    .from("properties")
    .select("id,primary_customer_organization_id")
    .eq("id", propertyId)
    .eq("workspace_id", workspaceId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  if (!property || (property.primary_customer_organization_id && property.primary_customer_organization_id !== organizationId)) {
    throw new Error("Property does not belong to this customer");
  }
}

export async function createDeckEstimate(f: FormData) {
  const ctx = await getWorkspaceContext();
  if (!ctx) throw new Error("Workspace required");
  const s = await createClient();
  await requireWorkspaceRole(s, ctx.workspaceId, ROLES.sales);

  const organizationId = text(f, "organization_id");
  const propertyId = text(f, "property_id");
  const { data: customer, error: customerError } = await s
    .from("organizations")
    .select("id")
    .eq("id", organizationId)
    .eq("workspace_id", ctx.workspaceId)
    .maybeSingle();
  if (customerError) throw new Error(customerError.message);
  if (!customer) throw new Error("Select a customer in your workspace");
  await validateProperty(s, ctx.workspaceId, organizationId, propertyId);

  const validUntil = text(f, "valid_until");
  validateExpiry(validUntil);

  const width = dimension(f, "width_ft", 4, 40);
  const depth = dimension(f, "depth_ft", 4, 40);
  const stairWidth = dimension(f, "stair_width_ft", 2, 12);
  const steps = dimension(f, "steps", 1, 20);
  const footings = dimension(f, "footings", 1, 20);
  if (!Number.isInteger(steps) || !Number.isInteger(footings)) {
    throw new Error("Steps and footings must be whole numbers");
  }
  const height = text(f, "height_in") ? dimension(f, "height_in", 0, 120) : null;
  const site = text(f, "site_reference");
  const landing = text(f, "landing");
  const notes = text(f, "site_notes");
  if (!site || site.length > 180 || landing.length > 80 || notes.length > 600) {
    throw new Error("Invalid site details");
  }

  const includeGuards = f.get("include_guards") === "on";
  const scope = `${site}; ${width} × ${depth} ft (${width * depth} sq ft); landing: ${landing || "none specified"}; stairs ${stairWidth} ft wide, ${steps} estimated steps; ${footings} assumed footings; deck height: ${height === null ? "not measured" : `${height} in`}.`;
  const definitions = [...DECK_LINES, ...(includeGuards ? [GUARD_LINE] : [])];
  const items = definitions.map((line, i) => {
    const price = amount(f, `${line.key}_price`);
    const material_cost = amount(f, `${line.key}_material`);
    const labor_cost = amount(f, `${line.key}_labor`);
    if (material_cost + labor_cost > price) throw new Error(`${line.label}: direct cost exceeds price`);
    return {
      description: i === 0 ? `${line.label} — ${scope}${notes ? ` Site notes: ${notes}.` : ""}` : line.label,
      price,
      material_cost,
      labor_cost,
    };
  });
  if (items.reduce((sum, item) => sum + item.price, 0) <= 0) {
    throw new Error("Estimate total must be positive");
  }

  const { data: id, error } = await s.rpc("create_deck_estimate_draft" as never, {
    p_workspace_id: ctx.workspaceId,
    p_organization_id: organizationId,
    p_property_id: propertyId || null,
    p_valid_until: validUntil,
    p_items: items,
  } as never);
  if (error) throw new Error(error.message);
  if (!id || typeof id !== "string") throw new Error("Estimate could not be created");

  revalidatePath("/estimates");
  redirect(`/estimates/${id}`);
}

export async function createEstimateCustomer(f: FormData) {
  const ctx = await getWorkspaceContext();
  if (!ctx) throw new Error("Workspace required");
  const name = text(f, "customer_name");
  if (name.length < 2 || name.length > 180) throw new Error("Enter a customer name");

  const s = await createClient();
  await requireWorkspaceRole(s, ctx.workspaceId, ROLES.sales);
  const { error } = await s.from("organizations").insert({
    workspace_id: ctx.workspaceId,
    legal_name: name,
    organization_type: "customer",
  });
  if (error) throw new Error(error.message);

  revalidatePath("/estimates/new");
  redirect("/estimates/new");
}

export async function advanceEstimate(f: FormData) {
  const id = text(f, "id");
  const action = text(f, "action");
  if (!["sent", "accepted", "rejected"].includes(action)) throw new Error("Invalid status action");

  const ctx = await getWorkspaceContext();
  if (!ctx) throw new Error("Workspace required");
  const s = await createClient();
  await requireWorkspaceRole(s, ctx.workspaceId, ROLES.sales);

  const { data: estimate, error: estimateError } = await s
    .from("estimates")
    .select("id")
    .eq("id", id)
    .eq("workspace_id", ctx.workspaceId)
    .maybeSingle();
  if (estimateError) throw new Error(estimateError.message);
  if (!estimate) throw new Error("Estimate not found");

  const { error } = await s.rpc("advance_estimate" as never, {
    p_estimate_id: id,
    p_action: action,
    p_site_confirmed: f.get("site_confirmed") === "on",
    p_site_notes: text(f, "site_verification_notes") || null,
  } as never);
  if (error) throw new Error(error.message);

  revalidatePath("/estimates");
  revalidatePath(`/estimates/${id}`);
  revalidatePath(`/estimates/${id}/quote`);
}

export async function updateDeckEstimate(f: FormData) {
  const id = text(f, "id");
  const ctx = await getWorkspaceContext();
  if (!ctx) throw new Error("Workspace required");
  const s = await createClient();
  await requireWorkspaceRole(s, ctx.workspaceId, ROLES.sales);

  const { data: estimate, error: estimateError } = await s
    .from("estimates")
    .select("id,status,estimate_number,organization_id")
    .eq("id", id)
    .eq("workspace_id", ctx.workspaceId)
    .maybeSingle();
  if (estimateError) throw new Error(estimateError.message);
  if (!estimate || estimate.status !== "draft" || !estimate.estimate_number.startsWith("DECK-")) {
    throw new Error("Only draft deck estimates can be revised");
  }

  const propertyId = text(f, "property_id");
  await validateProperty(s, ctx.workspaceId, estimate.organization_id, propertyId);

  const validUntil = text(f, "valid_until");
  validateExpiry(validUntil);
  const count = Number(text(f, "count"));
  if (!Number.isInteger(count) || count < 1 || count > 20) throw new Error("Invalid line count");

  const items = Array.from({ length: count }, (_, i) => {
    const description = text(f, `item_${i}_description`);
    const price = amount(f, `item_${i}_price`);
    const material_cost = amount(f, `item_${i}_material`);
    const labor_cost = amount(f, `item_${i}_labor`);
    if (description.length < 3 || description.length > 1000 || material_cost + labor_cost > price) {
      throw new Error(`Invalid item ${i + 1}`);
    }
    return { description, price, material_cost, labor_cost };
  });

  if (f.get("add_guards") === "on") {
    if (items.some((item) => item.description.startsWith(GUARD_LINE.label))) {
      throw new Error("Guards are already included");
    }
    const price = amount(f, "guards_price");
    const material_cost = amount(f, "guards_material");
    const labor_cost = amount(f, "guards_labor");
    if (material_cost + labor_cost > price) throw new Error("Guard costs exceed price");
    items.push({ description: GUARD_LINE.label, price, material_cost, labor_cost });
  }

  const { error } = await s.rpc("update_deck_estimate_draft" as never, {
    p_estimate_id: id,
    p_property_id: propertyId || null,
    p_valid_until: validUntil,
    p_items: items,
  } as never);
  if (error) throw new Error(error.message);

  revalidatePath("/estimates");
  revalidatePath(`/estimates/${id}`);
  redirect(`/estimates/${id}`);
}

export async function convertEstimate(f: FormData) {
  const ctx = await getWorkspaceContext();
  if (!ctx) throw new Error("Workspace required");
  const s = await createClient();
  await requireWorkspaceRole(s, ctx.workspaceId, ["owner", "administrator", "sales_manager"]);

  const id = text(f, "id");
  const { data: estimate, error: estimateError } = await s
    .from("estimates")
    .select("id,status,property_id")
    .eq("id", id)
    .eq("workspace_id", ctx.workspaceId)
    .maybeSingle();
  if (estimateError) throw new Error(estimateError.message);
  if (!estimate) throw new Error("Estimate not found");
  if (estimate.status !== "accepted") throw new Error("Only accepted estimates can become contracts");
  if (!estimate.property_id) throw new Error("Link a property before converting this estimate");

  const { data: contractId, error } = await s.rpc("convert_estimate_to_contract" as never, {
    p_estimate_id: id,
  } as never);
  if (error) throw new Error(error.message);
  if (!contractId || typeof contractId !== "string") throw new Error("Contract could not be created");

  revalidatePath("/estimates");
  revalidatePath("/contracts");
  revalidatePath("/sales");
  redirect(`/contracts/${contractId}`);
}

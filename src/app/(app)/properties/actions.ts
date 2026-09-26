"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getWorkspaceContext } from "@/lib/workspace";

export async function createProperty(formData: FormData) {
  const ctx = await getWorkspaceContext();
  if (!ctx) throw new Error("No workspace access");

  const s = await createClient();
  const name = String(formData.get("name") ?? "").trim();
  const address_line_1 = String(formData.get("address_line_1") ?? "").trim();
  const address_line_2 = String(formData.get("address_line_2") ?? "").trim() || null;
  const city = String(formData.get("city") ?? "").trim();
  const province = String(formData.get("province") ?? "").trim() || null;
  const postal_code = String(formData.get("postal_code") ?? "").trim() || null;
  const country = String(formData.get("country") ?? "Canada").trim() || "Canada";
  const property_type = String(formData.get("property_type") ?? "residential").trim();
  const status = String(formData.get("status") ?? "prospect").trim();
  const site_notes = String(formData.get("site_notes") ?? "").trim() || null;
  const access_notes = String(formData.get("access_notes") ?? "").trim() || null;
  const customer_name = String(formData.get("customer_name") ?? "").trim();
  const manager_name = String(formData.get("manager_name") ?? "").trim();

  if (!name || !address_line_1 || !city) {
    throw new Error("Name, street address, and city are required");
  }

  let primary_customer_organization_id: string | null = null;
  let management_organization_id: string | null = null;

  if (customer_name) {
    const { data: org, error } = await s
      .from("organizations")
      .insert({
        workspace_id: ctx.workspaceId,
        legal_name: customer_name,
        operating_name: customer_name,
        organization_type: "customer",
        status: "active",
      } as never)
      .select("id")
      .single();
    if (error) throw new Error(error.message);
    primary_customer_organization_id = org?.id ?? null;
  }

  if (manager_name) {
    const { data: org, error } = await s
      .from("organizations")
      .insert({
        workspace_id: ctx.workspaceId,
        legal_name: manager_name,
        operating_name: manager_name,
        organization_type: "property_manager",
        status: "active",
      } as never)
      .select("id")
      .single();
    if (error) throw new Error(error.message);
    management_organization_id = org?.id ?? null;
  }

  const { data: prop, error } = await s
    .from("properties")
    .insert({
      workspace_id: ctx.workspaceId,
      name,
      address_line_1,
      address_line_2,
      city,
      province,
      postal_code,
      country,
      property_type,
      status: status as never,
      site_notes,
      access_notes,
      primary_customer_organization_id,
      management_organization_id,
    } as never)
    .select("id")
    .single();

  if (error) throw new Error(error.message);

  revalidatePath("/properties");
  revalidatePath("/dashboard");
  if (prop?.id) redirect(`/properties/${prop.id}`);
  redirect("/properties");
}

export async function updateProperty(formData: FormData) {
  const ctx = await getWorkspaceContext();
  if (!ctx) throw new Error("No workspace access");

  const s = await createClient();
  const { requireWorkspaceRole, ROLES } = await import("@/lib/authz");
  await requireWorkspaceRole(s, ctx.workspaceId, ROLES.operations);

  const id = String(formData.get("id") ?? "").trim();
  const name = String(formData.get("name") ?? "").trim();
  const address_line_1 = String(formData.get("address_line_1") ?? "").trim();
  const city = String(formData.get("city") ?? "").trim();
  const property_type = String(formData.get("property_type") ?? "").trim();
  if (!id || !name || !address_line_1 || !city || !property_type) {
    throw new Error("Name, address, city and property type are required");
  }

  const { error } = await s
    .from("properties")
    .update({
      name,
      address_line_1,
      address_line_2: String(formData.get("address_line_2") ?? "").trim() || null,
      city,
      province: String(formData.get("province") ?? "").trim() || null,
      postal_code: String(formData.get("postal_code") ?? "").trim() || null,
      property_type,
      access_notes: String(formData.get("access_notes") ?? "").trim() || null,
      site_notes: String(formData.get("site_notes") ?? "").trim() || null,
    } as never)
    .eq("id", id)
    .eq("workspace_id", ctx.workspaceId);

  if (error) throw new Error(error.message);
  revalidatePath("/properties");
  revalidatePath(`/properties/${id}`);
  revalidatePath("/dashboard");
}

"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireWorkspaceRole, ROLES } from "@/lib/authz";

const v = (f: FormData, k: string) => String(f.get(k) ?? "").trim();

function splitName(full: string) {
  const parts = full.split(/\s+/).filter(Boolean);
  if (parts.length === 0) return { first_name: "Unknown", last_name: "Contact" };
  if (parts.length === 1) return { first_name: parts[0], last_name: "\u2014" };
  return { first_name: parts[0], last_name: parts.slice(1).join(" ") };
}

async function loadTarget(s: Awaited<ReturnType<typeof createClient>>, id: string) {
  const { data, error } = await s
    .from("outreach_targets")
    .select("id,workspace_id,organization_id,contact_id,organization_name,contact_name,phone,email")
    .eq("id", id)
    .single();
  if (error || !data) throw new Error("Target not found");
  return data;
}

export async function saveTargetAccount(f: FormData) {
  const s = await createClient();
  const id = v(f, "target_id");
  const t = await loadTarget(s, id);
  await requireWorkspaceRole(s, t.workspace_id, ROLES.sales);

  const company = v(f, "company_name");
  const legal = v(f, "legal_name") || company;
  const website = v(f, "website") || null;
  const companyPhone = v(f, "company_phone") || null;
  const companyEmail = v(f, "company_email") || null;
  const region = v(f, "region") || null;
  const doors = v(f, "doors_managed");
  const buildings = v(f, "buildings_managed");
  const notes = v(f, "notes") || null;
  const snapshotPhone = v(f, "phone") || companyPhone;
  const snapshotEmail = v(f, "email") || companyEmail;
  const contactName = v(f, "contact_name") || null;
  const hq1 = v(f, "hq_address_line_1") || null;
  const hq2 = v(f, "hq_address_line_2") || null;
  const hqCity = v(f, "hq_city") || null;
  const hqProvince = v(f, "hq_province") || null;
  const hqPostal = v(f, "hq_postal_code") || null;
  const linkedin = v(f, "linkedin_url") || null;
  const fax = v(f, "main_fax") || null;
  const companyAddress =
    [hq1, hq2, hqCity, hqProvince, hqPostal].filter(Boolean).join(", ") ||
    v(f, "property_address") ||
    null;

  let organizationId = t.organization_id as string | null;

  const orgPayload = {
    legal_name: legal || "Unknown company",
    operating_name: company || legal || null,
    website,
    phone: companyPhone,
    email: companyEmail,
    notes,
    primary_region: region,
    hq_city: hqCity,
    hq_province: hqProvince,
    hq_address_line_1: hq1,
    hq_address_line_2: hq2,
    hq_postal_code: hqPostal,
    linkedin_url: linkedin,
    main_fax: fax,
    doors_managed: doors ? Number(doors) : null,
    buildings_managed: buildings ? Number(buildings) : null,
    updated_at: new Date().toISOString(),
  };

  if (organizationId) {
    const { error } = await s
      .from("organizations")
      .update(orgPayload as never)
      .eq("id", organizationId)
      .eq("workspace_id", t.workspace_id);
    if (error) throw new Error(error.message);
  } else if (company || legal) {
    const { data, error } = await s
      .from("organizations")
      .insert({
        workspace_id: t.workspace_id,
        organization_type: "property_manager",
        status: "active",
        ...orgPayload,
      } as never)
      .select("id")
      .single();
    if (error) throw new Error(error.message);
    organizationId = data.id;
  }

  const { error } = await s
    .from("outreach_targets")
    .update({
      organization_id: organizationId,
      organization_name: company || t.organization_name,
      contact_name: contactName,
      phone: snapshotPhone,
      email: snapshotEmail,
      company_phone: companyPhone,
      company_email: companyEmail,
      company_website: website,
      company_address: companyAddress,
      property_address: companyAddress,
      region,
      notes,
      updated_at: new Date().toISOString(),
    } as never)
    .eq("id", id);
  if (error) throw new Error(error.message);

  await s.rpc("refresh_outreach_target_score" as never, { p_target_id: id } as never);

  revalidatePath("/targets");
  revalidatePath(`/targets/${id}`);
}

export async function addTargetContact(f: FormData) {
  const s = await createClient();
  const id = v(f, "target_id");
  const t = await loadTarget(s, id);
  await requireWorkspaceRole(s, t.workspace_id, ROLES.sales);

  if (!t.organization_id) {
    throw new Error("Save company info first so the contact has an account to attach to");
  }

  const full = v(f, "full_name");
  const { first_name, last_name } = splitName(full);
  const email = v(f, "email") || null;
  const phone = v(f, "phone") || null;
  const mobile = v(f, "mobile") || null;
  const title = v(f, "job_title") || null;
  const linkedin = v(f, "linkedin_url") || null;
  const extension = v(f, "phone_extension") || null;
  const relationship = v(f, "relationship_type") || "key_contact";
  const isPrimary = v(f, "is_primary") === "on" || v(f, "is_primary") === "true";

  const { data: contact, error: cErr } = await s
    .from("contacts")
    .insert({
      workspace_id: t.workspace_id,
      first_name,
      last_name,
      job_title: title,
      email,
      phone,
      mobile,
      linkedin_url: linkedin,
      phone_extension: extension,
      status: "active",
    } as never)
    .select("id")
    .single();
  if (cErr) throw new Error(cErr.message);

  const { error: linkErr } = await s.from("organization_contacts").insert({
    workspace_id: t.workspace_id,
    organization_id: t.organization_id,
    contact_id: contact.id,
    relationship_type: relationship,
    is_primary: isPrimary,
  });
  if (linkErr) throw new Error(linkErr.message);

  if (isPrimary) {
    const { error } = await s
      .from("outreach_targets")
      .update({
        contact_id: contact.id,
        contact_name: full || `${first_name} ${last_name}`.trim(),
        phone: phone || mobile || t.phone,
        email: email || t.email,
        updated_at: new Date().toISOString(),
      } as never)
      .eq("id", id);
    if (error) throw new Error(error.message);
  }

  await s.rpc("refresh_outreach_target_score" as never, { p_target_id: id } as never);
  revalidatePath("/targets");
  revalidatePath(`/targets/${id}`);
}

export async function setPrimaryTargetContact(f: FormData) {
  const s = await createClient();
  const id = v(f, "target_id");
  const contactId = v(f, "contact_id");
  const t = await loadTarget(s, id);
  await requireWorkspaceRole(s, t.workspace_id, ROLES.sales);
  if (!t.organization_id) throw new Error("No company on this target");

  await s
    .from("organization_contacts")
    .update({ is_primary: false })
    .eq("organization_id", t.organization_id);

  const { error: primErr } = await s
    .from("organization_contacts")
    .update({ is_primary: true })
    .eq("organization_id", t.organization_id)
    .eq("contact_id", contactId);
  if (primErr) throw new Error(primErr.message);

  const { data: c } = await s
    .from("contacts")
    .select("first_name,last_name,phone,mobile,email")
    .eq("id", contactId)
    .single();

  const { error } = await s
    .from("outreach_targets")
    .update({
      contact_id: contactId,
      contact_name: c ? `${c.first_name} ${c.last_name}`.trim() : t.contact_name,
      phone: c?.phone || c?.mobile || t.phone,
      email: c?.email || t.email,
      updated_at: new Date().toISOString(),
    } as never)
    .eq("id", id);
  if (error) throw new Error(error.message);

  await s.rpc("refresh_outreach_target_score" as never, { p_target_id: id } as never);
  revalidatePath("/targets");
  revalidatePath(`/targets/${id}`);
}

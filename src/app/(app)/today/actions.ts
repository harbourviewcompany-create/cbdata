"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireWorkspaceRole, ROLES } from "@/lib/authz";

const v = (f: FormData, k: string) => String(f.get(k) ?? "").trim();

const IMAGE_TYPES = new Set([
  "image/jpeg",
  "image/jpg",
  "image/png",
  "image/webp",
  "image/heic",
  "image/heif",
]);

function safeName(name: string) {
  return name.replace(/[^a-zA-Z0-9._-]/g, "_").slice(-80) || "photo.jpg";
}

export async function recordPhotoMetadata(input: {
  workspaceId: string;
  entityType: string;
  entityId: string;
  storagePath: string;
  photoType: string;
}) {
  const s = await createClient();
  const {
    data: { user },
  } = await s.auth.getUser();
  if (!user) throw new Error("Unauthorized");
  await requireWorkspaceRole(s, input.workspaceId, ROLES.field);
  const { error } = await s.from("photos").insert({
    workspace_id: input.workspaceId,
    entity_type: input.entityType,
    entity_id: input.entityId,
    storage_path: input.storagePath,
    photo_type: input.photoType,
    captured_at: new Date().toISOString(),
    uploaded_by: user.id,
  });
  if (error) throw new Error(error.message);
  revalidatePath("/today");
  revalidatePath("/work-orders");
  revalidatePath("/properties");
}

export async function uploadWorkOrderPhoto(f: FormData) {
  const s = await createClient();
  const {
    data: { user },
  } = await s.auth.getUser();
  if (!user) throw new Error("Unauthorized");

  const id = v(f, "work_order_id");
  const file = f.get("file");
  if (!id || !(file instanceof File) || file.size === 0) {
    throw new Error("Work order and photo file required");
  }
  if (file.size > 10 * 1024 * 1024) throw new Error("Photo must be under 10 MB");
  if (file.type && !IMAGE_TYPES.has(file.type)) {
    throw new Error("Only JPEG, PNG, WebP, or HEIC photos are allowed");
  }

  const { data: w } = await s.from("work_orders").select("workspace_id").eq("id", id).single();
  if (!w) throw new Error("Work order not found");
  await requireWorkspaceRole(s, w.workspace_id, ROLES.field);

  const path = `${w.workspace_id}/work_order/${id}/${crypto.randomUUID()}-${safeName(file.name)}`;
  const buf = Buffer.from(await file.arrayBuffer());
  const { error: upErr } = await s.storage.from("site-photos").upload(path, buf, {
    contentType: file.type || "image/jpeg",
    upsert: false,
  });
  if (upErr) throw new Error(upErr.message);

  await recordPhotoMetadata({
    workspaceId: w.workspace_id,
    entityType: "work_order",
    entityId: id,
    storagePath: path,
    photoType: "completion",
  });
}

export async function logVisit(f: FormData) {
  const s = await createClient();
  const {
    data: { user },
  } = await s.auth.getUser();
  if (!user) throw new Error("Unauthorized");
  const propertyId = v(f, "property_id");
  if (!propertyId) throw new Error("Property required");
  const { data: p } = await s.from("properties").select("workspace_id").eq("id", propertyId).single();
  if (!p) throw new Error("Property not found");
  await requireWorkspaceRole(s, p.workspace_id, ROLES.field);

  let photoPath: string | null = null;
  const file = f.get("file");
  if (file instanceof File && file.size > 0) {
    if (file.size > 10 * 1024 * 1024) throw new Error("Photo must be under 10 MB");
    if (file.type && !IMAGE_TYPES.has(file.type)) {
      throw new Error("Only JPEG, PNG, WebP, or HEIC photos are allowed");
    }
    photoPath = `${p.workspace_id}/property/${propertyId}/${crypto.randomUUID()}-${safeName(file.name)}`;
    const buf = Buffer.from(await file.arrayBuffer());
    const { error: upErr } = await s.storage.from("site-photos").upload(photoPath, buf, {
      contentType: file.type || "image/jpeg",
      upsert: false,
    });
    if (upErr) throw new Error(upErr.message);
  }

  const { error } = await s.rpc("log_property_visit" as never, {
    p_property_id: propertyId,
    p_notes: v(f, "notes") || null,
    p_photo_path: photoPath,
    p_issue_title: v(f, "issue_title") || null,
    p_issue_description: v(f, "issue_description") || null,
  } as never);
  if (error) throw new Error(error.message);
  revalidatePath("/today");
  revalidatePath("/properties");
  revalidatePath(`/properties/${propertyId}`);
}

export async function signedPhotoUrl(path: string) {
  const s = await createClient();
  const {
    data: { user },
  } = await s.auth.getUser();
  if (!user) throw new Error("Unauthorized");
  const { data, error } = await s.storage.from("site-photos").createSignedUrl(path, 60 * 30);
  if (error) throw new Error(error.message);
  return data.signedUrl;
}

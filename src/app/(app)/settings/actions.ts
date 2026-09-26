"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireWorkspace } from "@/lib/workspace";
import { requireWorkspaceRole, ROLES } from "@/lib/authz";
import type { Database } from "@/lib/database.types";

export async function switchWorkspace(f: FormData) {
  const ctx = await requireWorkspace();
  const id = String(f.get("workspace_id") ?? "").trim();
  if (!id) throw new Error("Workspace required");
  const s = await createClient();
  const { error } = await s.from("user_profiles").upsert(
    { id: ctx.user.id, active_workspace_id: id } as never,
    { onConflict: "id" },
  );
  if (error) throw new Error(error.message);
  revalidatePath("/", "layout");
}

export async function createInvite(f: FormData) {
  const ctx = await requireWorkspace();
  const s = await createClient();
  await requireWorkspaceRole(s, ctx.workspaceId, ROLES.admin);
  const email = String(f.get("email") ?? "").trim();
  const role = String(f.get("role") ?? "field_worker") as Database["public"]["Enums"]["membership_role"];
  const { error } = await s.rpc("create_workspace_invite" as never, {
    p_workspace_id: ctx.workspaceId,
    p_email: email,
    p_role: role,
  } as never);
  if (error) throw new Error(error.message);
  revalidatePath("/settings");
}

export async function runNightly() {
  const ctx = await requireWorkspace();
  const s = await createClient();
  await requireWorkspaceRole(s, ctx.workspaceId, ROLES.operations);
  const { error } = await s.rpc("run_nightly_ops" as never, {
    p_workspace_id: ctx.workspaceId,
  } as never);
  if (error) throw new Error(error.message);
  revalidatePath("/dashboard");
  revalidatePath("/work-orders");
  revalidatePath("/settings");
}

export async function acceptInvite(f: FormData) {
  const s = await createClient();
  const token = String(f.get("token") ?? "").trim();
  const { error } = await s.rpc("accept_workspace_invite" as never, { p_token: token } as never);
  if (error) throw new Error(error.message);
  revalidatePath("/", "layout");
}

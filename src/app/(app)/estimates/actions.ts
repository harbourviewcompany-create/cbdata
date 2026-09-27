"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireWorkspaceRole, ROLES } from "@/lib/authz";

export async function convertEstimate(f: FormData) {
  const s = await createClient();
  const id = String(f.get("id") ?? "").trim();
  const { data: e } = await s.from("estimates").select("workspace_id").eq("id", id).single();
  if (!e) throw new Error("Estimate not found");
  await requireWorkspaceRole(s, e.workspace_id, ROLES.sales);
  const { error } = await s.rpc("convert_estimate_to_contract" as never, {
    p_estimate_id: id,
  } as never);
  if (error) throw new Error(error.message);
  revalidatePath("/estimates");
  revalidatePath("/contracts");
  revalidatePath("/sales");
}

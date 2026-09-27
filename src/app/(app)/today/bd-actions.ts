"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

export async function logBdOutcome(formData: FormData) {
  const s = await createClient();
  const targetId = String(formData.get("target_id") ?? "");
  const outcome = String(formData.get("outcome") ?? "");
  const { error } = await s.rpc("log_bd_outcome" as never, {
    p_target_id: targetId,
    p_outcome: outcome,
  } as never);
  if (error) throw new Error(error.message);
  revalidatePath("/today");
  revalidatePath("/targets");
  revalidatePath(`/targets/${targetId}`);
  revalidatePath("/dashboard");
}

export async function claimTarget(formData: FormData) {
  const s = await createClient();
  const targetId = String(formData.get("target_id") ?? "");
  const { error } = await s.rpc("claim_outreach_target" as never, {
    p_target_id: targetId,
  } as never);
  if (error) throw new Error(error.message);
  revalidatePath("/today");
  revalidatePath("/targets");
}

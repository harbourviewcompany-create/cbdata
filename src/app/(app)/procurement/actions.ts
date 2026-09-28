"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

export async function runCanadaBuysScout() {
  const s = await createClient();
  const { data: { user } } = await s.auth.getUser();
  if (!user) throw new Error("Unauthorized");

  const { data: sessionData } = await s.auth.getSession();
  const accessToken = sessionData.session?.access_token;
  if (!accessToken) throw new Error("No active session");

  const { data: memberships, error: membershipError } = await s
    .from("workspace_memberships")
    .select("workspace_id")
    .eq("user_id", user.id)
    .eq("status", "active")
    .limit(1);
  if (membershipError || !memberships?.[0]?.workspace_id) throw new Error("No active workspace");

  const base = process.env.NEXT_PUBLIC_SUPABASE_URL;
  if (!base) throw new Error("Supabase URL is not configured");

  const response = await fetch(base + "/functions/v1/canadabuys-scout", {
    method: "POST",
    headers: {
      Authorization: "Bearer " + accessToken,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ workspace_id: memberships[0].workspace_id }),
    cache: "no-store",
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(payload.error || "CanadaBuys scout failed");

  revalidatePath("/procurement");
  revalidatePath("/targets");
  revalidatePath("/dashboard");
}

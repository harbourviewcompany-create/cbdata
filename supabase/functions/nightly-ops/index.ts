import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { checkBearerSecret, cronAuthResponse } from "../_shared/cron_auth.ts";

Deno.serve(async (req) => {
  const denied = cronAuthResponse(
    await checkBearerSecret(req.headers.get("authorization"), Deno.env.get("NIGHTLY_OPS_SECRET")),
  );
  if (denied) return denied;

  const url = Deno.env.get("SUPABASE_URL")!;
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const admin = createClient(url, key);
  const { data: workspaces, error } = await admin.from("workspaces").select("id").eq("status", "active");
  if (error) return new Response(error.message, { status: 500 });

  const results = [];
  for (const w of workspaces ?? []) {
    const { data, error: runErr } = await admin.rpc("run_nightly_ops", {
      p_workspace_id: w.id,
    });
    results.push({ workspace_id: w.id, data, error: runErr?.message ?? null });
  }
  return Response.json({ ok: true, results });
});

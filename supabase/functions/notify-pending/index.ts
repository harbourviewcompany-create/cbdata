import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { checkBearerSecret, cronAuthResponse } from "../_shared/cron_auth.ts";

Deno.serve(async (req) => {
  const denied = cronAuthResponse(
    await checkBearerSecret(req.headers.get("authorization"), Deno.env.get("NOTIFY_SECRET")),
  );
  if (denied) return denied;

  const hook = Deno.env.get("NOTIFY_WEBHOOK_URL");
  const url = Deno.env.get("SUPABASE_URL")!;
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const admin = createClient(url, key);

  const { data: rows, error } = await admin
    .from("notifications")
    .select("id,title,body,action_href,user_id,channel,workspace_id")
    .eq("status", "pending")
    .in("channel", ["email", "sms"])
    .limit(100);
  if (error) return new Response(error.message, { status: 500 });

  let sent = 0;
  for (const n of rows ?? []) {
    if (hook) {
      await fetch(hook, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(n),
      });
    }
    await admin
      .from("notifications")
      .update({ status: "sent", sent_at: new Date().toISOString() })
      .eq("id", n.id);
    sent += 1;
  }
  return Response.json({ ok: true, sent });
});

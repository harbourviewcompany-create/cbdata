import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cbdata-integration-key",
};

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

async function sha256(value: string): Promise<string> {
  const data = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function clean(value: unknown, max = 2000): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed ? trimmed.slice(0, max) : null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  const integrationKey = req.headers.get("x-cbdata-integration-key");
  if (!integrationKey) return json(401, { error: "missing_integration_key" });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) return json(500, { error: "integration_not_configured" });

  const hash = await sha256(integrationKey);
  const authHeaders = {
    apikey: serviceRoleKey,
    Authorization: `Bearer ${serviceRoleKey}`,
    "Content-Type": "application/json",
  };

  const credentialResponse = await fetch(
    `${supabaseUrl}/rest/v1/integration_credentials?provider=eq.wix&status=eq.active&key_hash=eq.${hash}&select=workspace_id&limit=1`,
    { headers: authHeaders },
  );
  if (!credentialResponse.ok) return json(500, { error: "credential_lookup_failed" });
  const credentials = await credentialResponse.json();
  if (!credentials.length) return json(401, { error: "invalid_integration_key" });

  const workspaceId = credentials[0].workspace_id;
  const payload = await req.json().catch(() => null);
  if (!payload || typeof payload !== "object") return json(400, { error: "invalid_json" });

  const wixSubmissionId = clean((payload as Record<string, unknown>).wixSubmissionId, 120);
  if (!wixSubmissionId) return json(400, { error: "wixSubmissionId_required" });

  const sourceResponse = await fetch(
    `${supabaseUrl}/rest/v1/lead_sources?workspace_id=eq.${workspaceId}&adapter=eq.wix&status=eq.active&select=id&limit=1`,
    { headers: authHeaders },
  );
  if (!sourceResponse.ok) return json(500, { error: "lead_source_lookup_failed" });
  const sources = await sourceResponse.json();

  const row = {
    workspace_id: workspaceId,
    lead_source_id: sources[0]?.id ?? null,
    channel_detail: "wix:cbcontracting.ca",
    submitted_name: clean((payload as any).name),
    submitted_email: clean((payload as any).email, 320)?.toLowerCase() ?? null,
    submitted_phone: clean((payload as any).phone, 60),
    message: clean((payload as any).message, 5000),
    utm_source: clean((payload as any).utm_source, 200),
    utm_campaign: clean((payload as any).utm_campaign, 200),
    status: "new",
    wix_submission_id: wixSubmissionId,
    raw_payload: payload,
  };

  const insertResponse = await fetch(
    `${supabaseUrl}/rest/v1/inbound_submissions?on_conflict=workspace_id,wix_submission_id`,
    {
      method: "POST",
      headers: { ...authHeaders, Prefer: "resolution=ignore-duplicates,return=representation" },
      body: JSON.stringify(row),
    },
  );

  if (!insertResponse.ok) {
    const detail = await insertResponse.text();
    return json(500, { error: "submission_persist_failed", detail });
  }

  const inserted = await insertResponse.json();
  if (inserted.length) {
    return json(201, { accepted: true, duplicate: false, submission_id: inserted[0].id });
  }

  const existingResponse = await fetch(
    `${supabaseUrl}/rest/v1/inbound_submissions?workspace_id=eq.${workspaceId}&wix_submission_id=eq.${encodeURIComponent(wixSubmissionId)}&select=id,status&limit=1`,
    { headers: authHeaders },
  );
  const existing = existingResponse.ok ? await existingResponse.json() : [];
  return json(200, {
    accepted: true,
    duplicate: true,
    submission_id: existing[0]?.id ?? null,
    status: existing[0]?.status ?? null,
  });
});
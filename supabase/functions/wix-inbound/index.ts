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

function fieldFromSubmissions(submissions: unknown, patterns: RegExp[]): string | null {
  if (!Array.isArray(submissions)) return null;
  for (const item of submissions) {
    if (!item || typeof item !== "object") continue;
    const row = item as Record<string, unknown>;
    const label = clean(row.label, 300)?.toLowerCase() ?? "";
    if (patterns.some((pattern) => pattern.test(label))) return clean(row.value, 5000);
  }
  return null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  const integrationKey =
    req.headers.get("x-cbdata-integration-key") ??
    new URL(req.url).searchParams.get("integration_key");
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
  const rawPayload = await req.json().catch(() => null);
  if (!rawPayload || typeof rawPayload !== "object") return json(400, { error: "invalid_json" });

  const raw = rawPayload as Record<string, unknown>;
  const payload = raw.data && typeof raw.data === "object" ? raw.data as Record<string, unknown> : raw;
  const submissions = payload.submissions;

  const wixSubmissionId =
    clean(payload.wixSubmissionId, 120) ??
    clean(payload.id, 120) ??
    clean(payload.submissionId, 120) ??
    clean(payload.entityId, 120) ??
    await sha256(JSON.stringify(rawPayload)).then((value) => `wix-auto-${value.slice(0, 48)}`);

  const submittedName =
    clean(payload.name) ??
    clean(payload.fullName) ??
    fieldFromSubmissions(submissions, [/^name$/, /full.?name/, /contact.?name/]);

  const submittedEmail =
    clean(payload.email, 320)?.toLowerCase() ??
    fieldFromSubmissions(submissions, [/e.?mail/])?.toLowerCase() ??
    null;

  const submittedPhone =
    clean(payload.phone, 60) ??
    fieldFromSubmissions(submissions, [/phone/, /mobile/, /tel/]);

  const message =
    clean(payload.message, 5000) ??
    clean(payload.inquiry, 5000) ??
    clean(payload.description, 5000) ??
    fieldFromSubmissions(submissions, [/message/, /inquiry/, /question/, /details/, /description/]);

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
    submitted_name: submittedName,
    submitted_email: submittedEmail,
    submitted_phone: submittedPhone,
    message,
    utm_source: clean(payload.utm_source, 200),
    utm_campaign: clean(payload.utm_campaign, 200),
    status: "new",
    wix_submission_id: wixSubmissionId,
    raw_payload: rawPayload,
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
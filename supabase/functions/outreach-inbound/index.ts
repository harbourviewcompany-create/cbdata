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

function clean(value: unknown, max = 10000): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed ? trimmed.slice(0, max) : null;
}

function normalizeEmail(value: unknown): string | null {
  const raw = clean(value, 500);
  if (!raw) return null;
  const bracket = raw.match(/<([^>]+@[^>]+)>/);
  const email = (bracket?.[1] ?? raw).trim().toLowerCase();
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ? email : null;
}

function valueAt(obj: Record<string, unknown>, keys: string[]): unknown {
  for (const key of keys) {
    if (obj[key] !== undefined && obj[key] !== null) return obj[key];
  }
  return null;
}

function parseTimestamp(value: unknown): string {
  const raw = clean(value, 100);
  if (!raw) return new Date().toISOString();
  const parsed = new Date(raw);
  return Number.isNaN(parsed.getTime()) ? new Date().toISOString() : parsed.toISOString();
}

function bytesToBase64(bytes: Uint8Array): string {
  let value = "";
  for (const byte of bytes) value += String.fromCharCode(byte);
  return btoa(value);
}

function base64ToBytes(value: string): Uint8Array {
  const decoded = atob(value);
  return Uint8Array.from(decoded, (char) => char.charCodeAt(0));
}

function constantTimeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

async function verifyResendSignature(req: Request, rawBody: string, secret: string): Promise<boolean> {
  const id = req.headers.get("svix-id");
  const timestamp = req.headers.get("svix-timestamp");
  const signature = req.headers.get("svix-signature");
  if (!id || !timestamp || !signature || !secret) return false;

  const timestampSeconds = Number(timestamp);
  if (!Number.isFinite(timestampSeconds)) return false;
  if (Math.abs(Math.floor(Date.now() / 1000) - timestampSeconds) > 300) return false;

  let keyBytes: Uint8Array;
  try {
    keyBytes = base64ToBytes(secret.startsWith("whsec_") ? secret.slice(6) : secret);
  } catch {
    return false;
  }

  const key = await crypto.subtle.importKey(
    "raw",
    keyBytes,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signedContent = new TextEncoder().encode(`${id}.${timestamp}.${rawBody}`);
  const mac = new Uint8Array(await crypto.subtle.sign("HMAC", key, signedContent));
  const expected = bytesToBase64(mac);

  return signature
    .split(" ")
    .map((part) => part.split(",", 2))
    .some(([version, value]) => version === "v1" && Boolean(value) && constantTimeEqual(value, expected));
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) return json(500, { error: "integration_not_configured" });

  const authHeaders = {
    apikey: serviceRoleKey,
    Authorization: `Bearer ${serviceRoleKey}`,
    "Content-Type": "application/json",
  };

  const rawBody = await req.text();
  let rawPayload: unknown;
  try {
    rawPayload = JSON.parse(rawBody);
  } catch {
    return json(400, { error: "invalid_json" });
  }
  if (!rawPayload || typeof rawPayload !== "object") return json(400, { error: "invalid_json" });

  const raw = rawPayload as Record<string, unknown>;
  const rawEventType = clean(valueAt(raw, ["type", "event_type", "eventType"]), 120);
  const hasResendSignature = Boolean(
    req.headers.get("svix-id") &&
    req.headers.get("svix-timestamp") &&
    req.headers.get("svix-signature")
  );

  let workspaceId: string | null = null;

  if (rawEventType === "email.received" && hasResendSignature) {
    const secretResponse = await fetch(
      `${supabaseUrl}/rest/v1/rpc/get_service_integration_secret`,
      {
        method: "POST",
        headers: authHeaders,
        body: JSON.stringify({ p_name: "resend_outreach_webhook_signing_secret" }),
      },
    );
    if (!secretResponse.ok) return json(500, { error: "webhook_secret_lookup_failed" });
    const signingSecret = await secretResponse.json();
    if (typeof signingSecret !== "string" || !signingSecret) {
      return json(500, { error: "webhook_secret_not_configured" });
    }
    if (!await verifyResendSignature(req, rawBody, signingSecret)) {
      return json(401, { error: "invalid_webhook_signature" });
    }

    const workspaceResponse = await fetch(
      `${supabaseUrl}/rest/v1/rpc/lookup_signed_integration_workspace`,
      {
        method: "POST",
        headers: authHeaders,
        body: JSON.stringify({ p_provider: "resend_webhook" }),
      },
    );
    if (!workspaceResponse.ok) return json(500, { error: "signed_workspace_lookup_failed" });
    const resolvedWorkspace = await workspaceResponse.json();
    if (typeof resolvedWorkspace !== "string" || !resolvedWorkspace) {
      return json(500, { error: "signed_workspace_unavailable" });
    }
    workspaceId = resolvedWorkspace;
  } else {
    const integrationKey =
      req.headers.get("x-cbdata-integration-key") ??
      new URL(req.url).searchParams.get("integration_key");
    if (!integrationKey) return json(401, { error: "missing_integration_key" });

    const keyHash = await sha256(integrationKey);
    const credentialResponse = await fetch(
      `${supabaseUrl}/rest/v1/rpc/lookup_integration_workspace`,
      {
        method: "POST",
        headers: authHeaders,
        body: JSON.stringify({ p_provider: "outreach_inbound", p_key_hash: keyHash }),
      },
    );
    if (!credentialResponse.ok) return json(500, { error: "credential_lookup_failed" });

    const resolvedWorkspace = await credentialResponse.json();
    if (typeof resolvedWorkspace !== "string" || !resolvedWorkspace) {
      return json(401, { error: "invalid_integration_key" });
    }
    workspaceId = resolvedWorkspace;
  }
  const nested =
    raw.data && typeof raw.data === "object" ? raw.data as Record<string, unknown> :
    raw.message && typeof raw.message === "object" ? raw.message as Record<string, unknown> :
    raw;

  const senderEmail = normalizeEmail(valueAt(nested, [
    "sender_email", "from_email", "from", "sender", "email",
  ]));
  const subject = clean(valueAt(nested, ["subject", "Subject"]), 1000);
  const eventType = clean(valueAt(raw, ["type", "event_type", "eventType"]), 120);
  const resendEmailId = clean(valueAt(nested, ["email_id", "emailId"]), 500);
  const body =
    clean(valueAt(nested, ["text", "body", "text_body", "plain", "content", "message"]), 50000) ??
    clean(valueAt(raw, ["text", "body", "text_body", "plain", "content"]), 50000);
  const metadataOnlyResend = eventType === "email.received" && Boolean(resendEmailId) && !body;
  if (!body && !metadataOnlyResend) return json(400, { error: "missing_reply_body" });

  const provider =
    clean(valueAt(nested, ["provider"]), 80) ??
    clean(valueAt(raw, ["provider"]), 80) ??
    (eventType === "email.received" ? "resend" : "webhook");
  const providerThreadId =
    clean(valueAt(nested, ["thread_id", "threadId", "conversation_id", "conversationId"]), 500) ??
    clean(valueAt(raw, ["thread_id", "threadId", "conversation_id", "conversationId"]), 500);
  let providerMessageId =
    clean(valueAt(nested, ["message_id", "messageId", "id", "event_id", "eventId"]), 500) ??
    clean(valueAt(raw, ["message_id", "messageId", "id", "event_id", "eventId"]), 500);
  if (!providerMessageId) {
    providerMessageId = `auto-${(await sha256(JSON.stringify(rawPayload))).slice(0, 48)}`;
  }
  const receivedAt = parseTimestamp(
    valueAt(nested, ["received_at", "receivedAt", "created_at", "createdAt", "timestamp", "date"]) ??
    valueAt(raw, ["received_at", "receivedAt", "created_at", "createdAt", "timestamp", "date"]),
  );

  const existingResponse = await fetch(
    `${supabaseUrl}/rest/v1/outreach_inbound_events?workspace_id=eq.${workspaceId}&provider=eq.${encodeURIComponent(provider)}&provider_message_id=eq.${encodeURIComponent(providerMessageId)}&select=id,status,reply_id&limit=1`,
    { headers: authHeaders },
  );
  if (existingResponse.ok) {
    const existing = await existingResponse.json();
    if (existing.length) {
      return json(200, {
        accepted: true,
        duplicate: true,
        event_id: existing[0].id,
        status: existing[0].status,
        reply_id: existing[0].reply_id,
      });
    }
  }

  const candidatesResponse = await fetch(
    `${supabaseUrl}/rest/v1/rpc/find_outreach_reply_targets`,
    {
      method: "POST",
      headers: authHeaders,
      body: JSON.stringify({
        p_workspace_id: workspaceId,
        p_sender_email: senderEmail,
        p_provider_thread_id: providerThreadId,
      }),
    },
  );
  if (!candidatesResponse.ok) {
    return json(500, { error: "target_match_failed" });
  }

  const candidates = await candidatesResponse.json() as Array<{
    target_id: string;
    pursuit_id: string | null;
    match_score: number;
    match_reason: string;
    last_touch_at: string | null;
  }>;

  let selected: typeof candidates[number] | null = null;
  if (candidates.length) {
    const bestScore = Math.max(...candidates.map((x) => Number(x.match_score ?? 0)));
    const best = candidates.filter((x) => Number(x.match_score ?? 0) === bestScore);
    const pursuits = new Set(best.map((x) => x.pursuit_id ?? x.target_id));
    if (pursuits.size === 1) selected = best[0];
  }

  const initialStatus = selected ? "matched" : candidates.length ? "ambiguous" : "unmatched";
  const eventStatus = metadataOnlyResend ? "pending_content" : initialStatus;
  const eventBody = body ?? `Resend inbound content pending retrieval (${resendEmailId})`;
  const eventRow = {
    workspace_id: workspaceId,
    provider,
    provider_message_id: providerMessageId,
    provider_thread_id: providerThreadId,
    sender_email: senderEmail,
    subject,
    body: eventBody,
    received_at: receivedAt,
    status: eventStatus,
    matched_target_id: selected?.target_id ?? null,
    matched_pursuit_id: selected?.pursuit_id ?? null,
    match_reason: selected?.match_reason ?? (candidates.length ? "multiple_candidate_pursuits" : "no_target_match"),
    raw_metadata: {
      payload: rawPayload,
      candidate_target_ids: candidates.map((x) => x.target_id),
      candidate_pursuit_ids: [...new Set(candidates.map((x) => x.pursuit_id).filter(Boolean))],
      event_type: eventType,
      resend_email_id: resendEmailId,
      content_pending: metadataOnlyResend,
    },
  };

  const eventResponse = await fetch(
    `${supabaseUrl}/rest/v1/outreach_inbound_events?on_conflict=workspace_id,provider,provider_message_id`,
    {
      method: "POST",
      headers: { ...authHeaders, Prefer: "resolution=ignore-duplicates,return=representation" },
      body: JSON.stringify(eventRow),
    },
  );
  if (!eventResponse.ok) {
    const detail = await eventResponse.text();
    return json(500, { error: "inbound_event_persist_failed", detail });
  }

  const inserted = await eventResponse.json();
  const eventId = inserted[0]?.id ?? null;

  if (metadataOnlyResend) {
    if (selected) {
      const pauseResponse = await fetch(
        `${supabaseUrl}/rest/v1/rpc/pause_outreach_sequences_for_inbound`,
        {
          method: "POST",
          headers: authHeaders,
          body: JSON.stringify({
            p_workspace_id: workspaceId,
            p_target_id: selected.target_id,
            p_reason: "resend_reply_pending_content",
          }),
        },
      );
      if (!pauseResponse.ok) {
        const detail = await pauseResponse.text();
        if (eventId) {
          await fetch(
            `${supabaseUrl}/rest/v1/outreach_inbound_events?id=eq.${eventId}`,
            {
              method: "PATCH",
              headers: authHeaders,
              body: JSON.stringify({
                status: "error",
                match_reason: "sequence_pause_failed",
                updated_at: new Date().toISOString(),
              }),
            },
          );
        }
        return json(500, { error: "sequence_pause_failed", detail, event_id: eventId });
      }
    }

    return json(202, {
      accepted: true,
      matched: Boolean(selected),
      status: "pending_content",
      event_id: eventId,
      candidates: candidates.length,
      resend_email_id: resendEmailId,
      sequence_paused: Boolean(selected),
    });
  }

  if (!selected) {
    return json(202, {
      accepted: true,
      matched: false,
      status: initialStatus,
      event_id: eventId,
      candidates: candidates.length,
    });
  }

  const ingestResponse = await fetch(
    `${supabaseUrl}/rest/v1/rpc/ingest_outreach_reply_system`,
    {
      method: "POST",
      headers: authHeaders,
      body: JSON.stringify({
        p_workspace_id: workspaceId,
        p_target_id: selected.target_id,
        p_body: body,
        p_sender_email: senderEmail,
        p_subject: subject,
        p_channel: "email",
        p_provider: provider,
        p_provider_message_id: providerMessageId,
        p_provider_thread_id: providerThreadId,
        p_received_at: receivedAt,
        p_raw_metadata: { source: "outreach_inbound_edge", inbound_event_id: eventId },
      }),
    },
  );

  if (!ingestResponse.ok) {
    const detail = await ingestResponse.text();
    if (eventId) {
      await fetch(
        `${supabaseUrl}/rest/v1/outreach_inbound_events?id=eq.${eventId}`,
        {
          method: "PATCH",
          headers: authHeaders,
          body: JSON.stringify({ status: "error", match_reason: "ingest_failed", updated_at: new Date().toISOString() }),
        },
      );
    }
    return json(500, { error: "reply_ingest_failed", detail, event_id: eventId });
  }

  const result = await ingestResponse.json();
  if (eventId) {
    await fetch(
      `${supabaseUrl}/rest/v1/outreach_inbound_events?id=eq.${eventId}`,
      {
        method: "PATCH",
        headers: authHeaders,
        body: JSON.stringify({
          status: "matched",
          reply_id: result.reply_id ?? null,
          matched_target_id: selected.target_id,
          matched_pursuit_id: selected.pursuit_id,
          match_reason: selected.match_reason,
          updated_at: new Date().toISOString(),
        }),
      },
    );
  }

  return json(201, {
    accepted: true,
    matched: true,
    event_id: eventId,
    ...result,
  });
});

// Bearer-secret check for cron/webhook-style edge functions that use the service role.
// Fails CLOSED: if the secret env var is unset or empty nobody is authorized, so a missing
// deployment secret can never turn the endpoint into an open service-role entry point.

const enc = new TextEncoder();

async function sha256(value: string): Promise<Uint8Array> {
  return new Uint8Array(await crypto.subtle.digest("SHA-256", enc.encode(value)));
}

/** Constant-time comparison of two strings (hashes first so lengths never leak). */
export async function safeEqual(a: string, b: string): Promise<boolean> {
  const [ha, hb] = await Promise.all([sha256(a), sha256(b)]);
  let diff = 0;
  for (let i = 0; i < ha.length; i++) diff |= ha[i] ^ hb[i];
  return diff === 0;
}

export type CronAuth = "ok" | "not_configured" | "unauthorized";

/**
 * - secret missing/blank       -> "not_configured" (caller should respond 503, never proceed)
 * - header is not Bearer <secret> -> "unauthorized" (401)
 */
export async function checkBearerSecret(
  authorizationHeader: string | null,
  secret: string | undefined | null,
): Promise<CronAuth> {
  if (!secret || secret.trim() === "") return "not_configured";
  const header = authorizationHeader ?? "";
  if (!header.startsWith("Bearer ")) return "unauthorized";
  return (await safeEqual(header.slice(7), secret)) ? "ok" : "unauthorized";
}

export function cronAuthResponse(result: CronAuth): Response | null {
  if (result === "ok") return null;
  if (result === "not_configured") return new Response("not_configured", { status: 503 });
  return new Response("unauthorized", { status: 401 });
}

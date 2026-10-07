import assert from "node:assert/strict";
import { checkBearerSecret, cronAuthResponse, safeEqual } from "../cron_auth.ts";
import type { FakeState } from "./fake_supabase.ts";

Deno.test("safeEqual", async () => {
  assert.equal(await safeEqual("abc", "abc"), true);
  assert.equal(await safeEqual("abc", "abd"), false);
  assert.equal(await safeEqual("abc", "abcd"), false);
  assert.equal(await safeEqual("", "x"), false);
});

Deno.test("fails closed when the secret is unset, empty or blank", async () => {
  for (const secret of [undefined, null, "", "   "]) {
    for (const hdr of [null, "", "Bearer ", "Bearer anything", "Bearer undefined", "Bearer null"]) {
      assert.equal(await checkBearerSecret(hdr, secret), "not_configured", `secret=${String(secret)} hdr=${hdr}`);
    }
  }
  assert.equal(cronAuthResponse("not_configured")?.status, 503);
});

Deno.test("rejects wrong, missing and malformed headers when configured", async () => {
  for (const hdr of [null, "", "Bearer ", "Bearer wrong", "bearer s3cret", "s3cret", "Basic s3cret", "Bearer s3cret ", "Bearer  s3cret"]) {
    assert.equal(await checkBearerSecret(hdr, "s3cret"), "unauthorized", String(hdr));
  }
  assert.equal(cronAuthResponse("unauthorized")?.status, 401);
});

Deno.test("accepts the exact bearer secret", async () => {
  assert.equal(await checkBearerSecret("Bearer s3cret", "s3cret"), "ok");
  assert.equal(cronAuthResponse("ok"), null);
});

// ---- handler level: nothing is read or written unless authorized ----
Deno.env.set("SUPABASE_URL", "http://localhost:54321");
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test-service-role");
type Handler = (req: Request) => Response | Promise<Response>;
const cache = new Map<string, Handler>();
async function load(path: string): Promise<Handler> {
  const c = cache.get(path); if (c) return c;
  let h: Handler | undefined; const orig = Deno.serve;
  // deno-lint-ignore no-explicit-any
  (Deno as any).serve = (f: Handler) => { h = f; return {}; };
  try { await import(path); } finally { (Deno as any).serve = orig; }
  cache.set(path, h!); return h!;
}

for (const [name, path, env] of [
  ["nightly-ops", "../../nightly-ops/index.ts", "NIGHTLY_OPS_SECRET"],
  ["notify-pending", "../../notify-pending/index.ts", "NOTIFY_SECRET"],
] as const) {
  Deno.test(`${name}: unset secret -> 503 and no database access, even with a bearer header`, async () => {
    const h = await load(path);
    Deno.env.delete(env);
    const st: FakeState = { user: null, memberships: [], touched: [] };
    (globalThis as unknown as { __fake: FakeState }).__fake = st;
    for (const hdr of [undefined, "Bearer x", "Bearer "]) {
      const res = await h(new Request("http://l/", { method: "POST", headers: hdr === undefined ? {} : { authorization: hdr } }));
      assert.equal(res.status, 503, `${name} ${hdr}`);
    }
    assert.deepEqual(st.touched, []);
  });

  Deno.test(`${name}: wrong secret -> 401 and no database access`, async () => {
    const h = await load(path);
    Deno.env.set(env, "s3cret");
    const st: FakeState = { user: null, memberships: [], touched: [] };
    (globalThis as unknown as { __fake: FakeState }).__fake = st;
    const res = await h(new Request("http://l/", { method: "POST", headers: { authorization: "Bearer nope" } }));
    assert.equal(res.status, 401);
    assert.deepEqual(st.touched, []);
    Deno.env.delete(env);
  });

  Deno.test(`${name}: correct secret passes the gate and reaches the database`, async () => {
    const h = await load(path);
    Deno.env.set(env, "s3cret");
    const st: FakeState = { user: null, memberships: [], touched: [] };
    (globalThis as unknown as { __fake: FakeState }).__fake = st;
    const res = await h(new Request("http://l/", { method: "POST", headers: { authorization: "Bearer s3cret" } }));
    assert.ok(res.status !== 401 && res.status !== 503, `status ${res.status}`);
    assert.ok(st.touched.length > 0);
    Deno.env.delete(env);
  });
}

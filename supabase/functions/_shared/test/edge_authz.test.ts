// Handler-level check: each service-role edge function must reject callers whose role is
// not allowed BEFORE touching any table other than workspace_memberships.
// Run: deno test --allow-env --config supabase/functions/_shared/test/deno.test.json supabase/functions/_shared/test/
import assert from "node:assert/strict";
import type { FakeState } from "./fake_supabase.ts";

const W = "00000000-0000-4000-8000-0000000000b1";
const OTHER = "00000000-0000-4000-8000-0000000000b2";

type Fn = { name: string; path: string; allowed: string[]; denied: string[] };
const LEAD = ["owner", "administrator", "operations_manager", "sales_manager"];
const NOT_LEAD = ["sales_rep", "read_only", "finance", "field_worker", "field_supervisor", "operations_supervisor", "sales_rep"];
const FUNCTIONS: Fn[] = [
  { name: "procurement-intake", path: "../../procurement-intake/index.ts", allowed: [...LEAD, "sales_rep"], denied: ["read_only", "finance", "field_worker", "field_supervisor", "operations_supervisor"] },
  { name: "tender-intelligence-engine", path: "../../tender-intelligence-engine/index.ts", allowed: LEAD, denied: NOT_LEAD },
  { name: "tender-document-intelligence", path: "../../tender-document-intelligence/index.ts", allowed: LEAD, denied: NOT_LEAD },
  { name: "procurement-coverage-engine", path: "../../procurement-coverage-engine/index.ts", allowed: LEAD, denied: NOT_LEAD },
  { name: "canadabuys-award-scout", path: "../../canadabuys-award-scout/index.ts", allowed: LEAD, denied: NOT_LEAD },
  { name: "canadabuys-scout", path: "../../canadabuys-scout/index.ts", allowed: LEAD, denied: NOT_LEAD },
  { name: "regional-tender-scout", path: "../../regional-tender-scout/index.ts", allowed: LEAD, denied: NOT_LEAD },
];

Deno.env.set("SUPABASE_URL", "http://localhost:54321");
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test-service-role");

type Handler = (req: Request) => Response | Promise<Response>;
const handlers = new Map<string, Handler>(); // modules import once; cache the captured handler
async function loadHandler(path: string): Promise<Handler> {
  const cached = handlers.get(path);
  if (cached) return cached;
  let captured: Handler | undefined;
  const original = Deno.serve;
  // deno-lint-ignore no-explicit-any
  (Deno as any).serve = (h: Handler) => { captured = h; return {}; };
  try { await import(path); } finally { (Deno as any).serve = original; }
  assert.ok(captured, "no Deno.serve handler captured for " + path);
  handlers.set(path, captured!);
  return captured!;
}

function call(handler: Handler, state: FakeState, workspace: string | null) {
  (globalThis as unknown as { __fake: FakeState }).__fake = state;
  const body = { workspace_id: workspace ?? undefined, tender_id: "t1", source_key: "s1", records: [{ external_id: "x" }] };
  return handler(new Request("http://localhost/fn", {
    method: "POST",
    headers: { authorization: "Bearer test-token", "content-type": "application/json" },
    body: JSON.stringify(body),
  }));
}

const GATE_ERRORS = ["workspace_access_denied", "insufficient_role", "unauthorized"];

for (const fn of FUNCTIONS) {
  Deno.test(`${fn.name}: disallowed roles get 403 insufficient_role and no table is written or read beyond memberships`, async () => {
    const handler = await loadHandler(fn.path);
    for (const role of fn.denied) {
      const state: FakeState = { user: { id: "u1" }, memberships: [{ workspace_id: W, role }], touched: [] };
      const res = await call(handler, state, W);
      const json = await res.json().catch(() => ({}));
      assert.equal(res.status, 403, `${fn.name}/${role}: status`);
      assert.equal(json.error, "insufficient_role", `${fn.name}/${role}: error`);
      const extra = state.touched.filter((t) => t.table !== "workspace_memberships");
      assert.deepEqual(extra, [], `${fn.name}/${role}: touched other tables`);
    }
  });

  Deno.test(`${fn.name}: allowed roles pass the gate`, async () => {
    const handler = await loadHandler(fn.path);
    for (const role of fn.allowed) {
      const state: FakeState = { user: { id: "u1" }, memberships: [{ workspace_id: W, role }], touched: [] };
      const res = await call(handler, state, W).catch(() => null);
      if (res) {
        const json = await res.clone().json().catch(() => ({}));
        assert.ok(!GATE_ERRORS.includes(json.error), `${fn.name}/${role}: blocked by gate (${json.error})`);
      }
      // reached past the gate: it queried something beyond memberships, or returned a non-gate response
      assert.ok(res !== null || state.touched.some((t) => t.table !== "workspace_memberships"), `${fn.name}/${role}: did not pass gate`);
    }
  });

  Deno.test(`${fn.name}: non-member and other-workspace callers get workspace_access_denied; bad token gets 401`, async () => {
    const handler = await loadHandler(fn.path);
    const none: FakeState = { user: { id: "u1" }, memberships: [], touched: [] };
    const r1 = await call(handler, none, W);
    assert.equal(r1.status, 403);
    assert.equal((await r1.json()).error, "workspace_access_denied");

    const wrongWs: FakeState = { user: { id: "u1" }, memberships: [{ workspace_id: OTHER, role: "owner" }], touched: [] };
    const r2 = await call(handler, wrongWs, W);
    assert.equal(r2.status, 403);
    assert.equal((await r2.json()).error, "workspace_access_denied");

    const noUser: FakeState = { user: null, memberships: [{ workspace_id: W, role: "owner" }], touched: [] };
    const r3 = await call(handler, noUser, W);
    assert.equal(r3.status, 401);
  });
}

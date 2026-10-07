import assert from "node:assert/strict";
import { authorizeMembership, PROCUREMENT_LEAD_ROLES, PROCUREMENT_ROLES } from "./authz.ts";

const W1 = "00000000-0000-4000-8000-0000000000a1";
const W2 = "00000000-0000-4000-8000-0000000000a2";

Deno.test("roles allowed for procurement writes", () => {
  for (const role of PROCUREMENT_ROLES) {
    const d = authorizeMembership([{ workspace_id: W1, role }], W1, PROCUREMENT_ROLES);
    assert.equal(d.ok, true, role);
  }
});

Deno.test("lead roles exclude sales_rep", () => {
  assert.equal(authorizeMembership([{ workspace_id: W1, role: "sales_rep" }], W1, PROCUREMENT_LEAD_ROLES).ok, false);
  assert.equal(authorizeMembership([{ workspace_id: W1, role: "sales_manager" }], W1, PROCUREMENT_LEAD_ROLES).ok, true);
});

Deno.test("read_only, finance, field roles are denied with insufficient_role", () => {
  for (const role of ["read_only", "finance", "field_worker", "field_supervisor", "operations_supervisor", "", "OWNER"]) {
    const d = authorizeMembership([{ workspace_id: W1, role }], W1, PROCUREMENT_ROLES);
    assert.deepEqual(d, { ok: false, status: 403, error: "insufficient_role" }, role);
  }
});

Deno.test("non-member, empty and null memberships are workspace_access_denied", () => {
  const denied = { ok: false, status: 403, error: "workspace_access_denied" };
  assert.deepEqual(authorizeMembership([], W1, PROCUREMENT_ROLES), denied);
  assert.deepEqual(authorizeMembership(null, W1, PROCUREMENT_ROLES), denied);
  assert.deepEqual(authorizeMembership(undefined, null, PROCUREMENT_ROLES), denied);
  assert.deepEqual(authorizeMembership([{ workspace_id: W2, role: "owner" }], W1, PROCUREMENT_ROLES), denied);
});

Deno.test("requested workspace is never swapped for another the caller is allowed in", () => {
  const ms = [{ workspace_id: W1, role: "read_only" }, { workspace_id: W2, role: "owner" }];
  assert.deepEqual(authorizeMembership(ms, W1, PROCUREMENT_ROLES), { ok: false, status: 403, error: "insufficient_role" });
  const ok = authorizeMembership(ms, W2, PROCUREMENT_ROLES);
  assert.deepEqual(ok, { ok: true, workspaceId: W2, role: "owner" });
});

Deno.test("no workspace requested: picks a workspace where the role is allowed, not the first row", () => {
  const ms = [{ workspace_id: W1, role: "read_only" }, { workspace_id: W2, role: "sales_rep" }];
  assert.deepEqual(authorizeMembership(ms, null, PROCUREMENT_ROLES), { ok: true, workspaceId: W2, role: "sales_rep" });
  assert.deepEqual(authorizeMembership([{ workspace_id: W1, role: "read_only" }], null, PROCUREMENT_ROLES),
    { ok: false, status: 403, error: "insufficient_role" });
});

Deno.test("malformed rows are ignored", () => {
  const ms = [{ workspace_id: "", role: "owner" }] as never;
  assert.equal(authorizeMembership(ms, null, PROCUREMENT_ROLES).ok, false);
});

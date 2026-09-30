import test from "node:test";
import assert from "node:assert/strict";
import { requireWorkspaceRole } from "../src/lib/authz.ts";

const PERMISSION_ERROR = "You do not have permission to perform this action";

function createSupabaseMock({
  user = { id: "user-1" },
  userError = null,
  rows = [{ role: "owner" }],
  queryError = null,
} = {}) {
  const filters = [];
  let fromCalls = 0;
  let getUserCalls = 0;

  const query = {
    select(columns) {
      assert.equal(columns, "role");
      return query;
    },
    eq(column, value) {
      filters.push([column, value]);
      return query;
    },
    limit(value) {
      filters.push(["limit", value]);
      return Promise.resolve({ data: rows, error: queryError });
    },
  };

  const client = {
    auth: {
      async getUser() {
        getUserCalls += 1;
        return { data: { user }, error: userError };
      },
    },
    from(table) {
      fromCalls += 1;
      assert.equal(table, "workspace_memberships");
      return query;
    },
  };

  return {
    client,
    filters,
    get fromCalls() {
      return fromCalls;
    },
    get getUserCalls() {
      return getUserCalls;
    },
  };
}

test("requires a workspace before reading auth state", async () => {
  const mock = createSupabaseMock();

  await assert.rejects(
    requireWorkspaceRole(mock.client, "", ["owner"]),
    /Workspace is required/,
  );

  assert.equal(mock.getUserCalls, 0);
  assert.equal(mock.fromCalls, 0);
});

test("fails closed when the caller cannot be authenticated", async () => {
  const mock = createSupabaseMock({
    user: null,
    userError: new Error("invalid session"),
  });

  await assert.rejects(
    requireWorkspaceRole(mock.client, "workspace-1", ["owner"]),
    /Unauthorized/,
  );

  assert.equal(mock.fromCalls, 0);
});

test("scopes the membership lookup to the verified caller", async () => {
  const mock = createSupabaseMock();

  const role = await requireWorkspaceRole(
    mock.client,
    "workspace-1",
    ["owner", "administrator"],
  );

  assert.equal(role, "owner");
  assert.deepEqual(mock.filters, [
    ["workspace_id", "workspace-1"],
    ["user_id", "user-1"],
    ["status", "active"],
    ["limit", 2],
  ]);
});

test("rejects callers with no active membership", async () => {
  const mock = createSupabaseMock({ rows: [] });

  await assert.rejects(
    requireWorkspaceRole(mock.client, "workspace-1", ["owner"]),
    new RegExp(PERMISSION_ERROR),
  );
});

test("rejects ambiguous duplicate active memberships", async () => {
  const mock = createSupabaseMock({
    rows: [{ role: "owner" }, { role: "owner" }],
  });

  await assert.rejects(
    requireWorkspaceRole(mock.client, "workspace-1", ["owner"]),
    new RegExp(PERMISSION_ERROR),
  );
});

test("rejects a single membership with a disallowed role", async () => {
  const mock = createSupabaseMock({ rows: [{ role: "field_worker" }] });

  await assert.rejects(
    requireWorkspaceRole(mock.client, "workspace-1", ["owner"]),
    new RegExp(PERMISSION_ERROR),
  );
});

test("fails closed on membership query errors", async () => {
  const mock = createSupabaseMock({
    rows: null,
    queryError: new Error("membership lookup failed"),
  });

  await assert.rejects(
    requireWorkspaceRole(mock.client, "workspace-1", ["owner"]),
    /membership lookup failed/,
  );
});

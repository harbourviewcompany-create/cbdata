// Test double for https://esm.sh/@supabase/supabase-js (mapped via deno.test.json).
// Behaviour is driven by globalThis.__fake set by the test.
export type FakeState = {
  user: { id: string } | null;
  memberships: { workspace_id: string; role: string }[];
  touched: { table: string; op: string }[];
};

export function createClient(..._args: unknown[]) {
  const state = (globalThis as unknown as { __fake: FakeState }).__fake;
  const builder = (table: string) => {
    let op = "select";
    const rows = () => (table === "workspace_memberships" ? state.memberships : []);
    const special: Record<string, unknown> = {
      maybeSingle: () => { state.touched.push({ table, op }); return Promise.resolve({ data: rows()[0] ?? null, error: null }); },
      then: (res: (v: unknown) => unknown, rej?: (e: unknown) => unknown) => {
        state.touched.push({ table, op });
        return Promise.resolve({ data: rows(), error: null, count: 0 }).then(res, rej);
      },
    };
    special.single = special.maybeSingle;
    // Any other method (select, eq, lt, gt, order, ...) chains; write verbs also record the op.
    const b: unknown = new Proxy(special, {
      get(target, prop: string) {
        if (prop in target) return target[prop];
        return (..._a: unknown[]) => {
          if (["insert", "update", "upsert", "delete"].includes(prop)) op = prop;
          return b;
        };
      },
    });
    return b;
  };
  return {
    auth: {
      getUser: (_token: string) =>
        Promise.resolve(state.user ? { data: { user: state.user }, error: null } : { data: { user: null }, error: { message: "bad" } }),
    },
    from: builder,
    rpc: (_n: string, _a?: unknown) => Promise.resolve({ data: null, error: null }),
    storage: { from: () => ({ upload: () => Promise.resolve({ data: null, error: null }) }) },
  };
}

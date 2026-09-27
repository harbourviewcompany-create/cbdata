import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getWorkspaceContext } from "@/lib/workspace";
import { createInvite, runNightly, switchWorkspace } from "./actions";

const ROLES = [
  "field_worker",
  "field_supervisor",
  "operations_supervisor",
  "operations_manager",
  "sales_rep",
  "sales_manager",
  "finance",
  "administrator",
  "read_only",
] as const;

export default async function SettingsPage() {
  const ctx = await getWorkspaceContext();
  if (!ctx) redirect("/login");
  const s = await createClient();

  const [{ data: members }, { data: memberships }] = await Promise.all([
    s
      .from("workspace_memberships")
      .select("id,user_id,role,status")
      .eq("workspace_id", ctx.workspaceId)
      .order("role"),
    s
      .from("workspace_memberships")
      .select("workspace_id,role,status,workspaces(id,name)")
      .eq("user_id", ctx.user.id)
      .eq("status", "active"),
  ]);

  return (
    <>
      <header className="page-intro">
        <div>
          <span className="eyebrow">ADMIN</span>
          <h1>Team &amp; workspace</h1>
          <p className="muted">
            Active workspace: {ctx.workspaceName}. Invite people, switch
            workspace, or refresh nightly ops.
          </p>
        </div>
      </header>

      <section className="table-panel">
        <h2>Switch workspace</h2>
        <form action={switchWorkspace} className="form-grid">
          <select name="workspace_id" defaultValue={ctx.workspaceId}>
            {(memberships ?? []).map((m) => {
              const ws = Array.isArray(m.workspaces) ? m.workspaces[0] : m.workspaces;
              return (
                <option key={m.workspace_id} value={m.workspace_id}>
                  {ws?.name ?? m.workspace_id} ({m.role})
                </option>
              );
            })}
          </select>
          <button type="submit">Use this workspace</button>
        </form>
      </section>

      <section className="table-panel" style={{ marginTop: 14 }}>
        <h2>Invite teammate</h2>
        <form action={createInvite} className="form-grid">
          <input name="email" type="email" required placeholder="email@company.com" />
          <select name="role" defaultValue="field_worker">
            {ROLES.map((r) => (
              <option key={r} value={r}>
                {r.replace(/_/g, " ")}
              </option>
            ))}
          </select>
          <button type="submit" className="primary">
            Create invite
          </button>
        </form>
        <p className="muted" style={{ marginTop: 8 }}>
          Share the token from the RPC result with the teammate at /invite.
        </p>
      </section>

      <section className="table-panel" style={{ marginTop: 14 }}>
        <h2>Members</h2>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>User</th>
                <th>Role</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {(members ?? []).map((m) => (
                <tr key={m.id}>
                  <td>{m.user_id.slice(0, 8)}</td>
                  <td>{m.role}</td>
                  <td>{m.status}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="table-panel" style={{ marginTop: 14 }}>
        <h2>Nightly ops</h2>
        <form action={runNightly}>
          <button type="submit" className="primary">
            Run snapshot + follow-ups now
          </button>
        </form>
      </section>
    </>
  );
}

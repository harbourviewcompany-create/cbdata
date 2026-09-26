import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { getWorkspaceContext } from "@/lib/workspace";

function timeLabel(v: string | null | undefined) {
  if (!v) return "—";
  return new Date(v).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

export default async function DispatchPage() {
  const ctx = await getWorkspaceContext();
  const s = await createClient();
  if (!ctx) {
    return (
      <div className="empty-card">
        <h2 style={{ marginTop: 0 }}>No workspace access</h2>
        <p className="muted">Contact an administrator to join a workspace.</p>
      </div>
    );
  }

  const today = new Date();
  const dayStart = new Date(today);
  dayStart.setHours(0, 0, 0, 0);
  const dayEnd = new Date(dayStart);
  dayEnd.setDate(dayEnd.getDate() + 1);

  const [{ data: rows }, { data: crews }, { data: emps }, { data: cons }, { data: eq }] =
    await Promise.all([
      s
        .from("work_orders")
        .select(
          "id,work_order_number,priority,status,scheduled_start,scheduled_end,property_id,properties(name),work_order_assignments(id,assignment_type,status,crew_id,employee_id,contractor_id,equipment_id)",
        )
        .eq("workspace_id", ctx.workspaceId)
        .not("scheduled_start", "is", null)
        .gte("scheduled_start", dayStart.toISOString())
        .lt("scheduled_start", dayEnd.toISOString())
        .order("scheduled_start"),
      s.from("crews").select("id,name"),
      s.from("employees").select("id,first_name,last_name"),
      s.from("contractors").select("id,organization_id"),
      s.from("equipment").select("id,name"),
    ]);

  const list = rows ?? [];
  const unassigned = list.filter(
    (r) =>
      !(r.work_order_assignments ?? []).some(
        (a: { status?: string }) => a.status === "assigned",
      ),
  ).length;
  const urgent = list.filter(
    (r) =>
      ["urgent", "emergency"].includes(String(r.priority)) &&
      !["completed", "cancelled"].includes(String(r.status)),
  ).length;
  const conflicts = list.filter((r) => {
    const active = (r.work_order_assignments ?? []).filter(
      (a: { status?: string }) => a.status === "assigned",
    );
    return active.length > 1;
  }).length;

  const resourceName = (a: {
    assignment_type?: string;
    crew_id?: string;
    employee_id?: string;
    contractor_id?: string;
    equipment_id?: string;
  }) => {
    if (a.assignment_type === "crew")
      return crews?.find((x) => x.id === a.crew_id)?.name ?? "Crew";
    if (a.assignment_type === "employee") {
      const e = emps?.find((x) => x.id === a.employee_id);
      return e ? `${e.first_name} ${e.last_name}` : "Employee";
    }
    if (a.assignment_type === "contractor")
      return `Contractor ${cons?.find((x) => x.id === a.contractor_id)?.organization_id ?? ""}`;
    return eq?.find((x) => x.id === a.equipment_id)?.name ?? "Equipment";
  };

  return (
    <>
      <header className="page-intro">
        <div>
          <span className="eyebrow">FIELD CONTROL / TODAY</span>
          <h2 className="page-title">Dispatch board</h2>
          <p className="muted">
            {today.toLocaleDateString()} · {list.length} scheduled job
            {list.length === 1 ? "" : "s"}
          </p>
        </div>
        <Link className="button" href="/work-orders">
          Work orders
        </Link>
      </header>

      <section className="metrics">
        <div className="metric">
          <span>Scheduled</span>
          <strong>{list.length}</strong>
          <small>Today</small>
        </div>
        <div className={`metric${unassigned ? " metric-alert" : ""}`}>
          <span>Unassigned</span>
          <strong>{unassigned}</strong>
          <small>Needs dispatch</small>
        </div>
        <div className={`metric${urgent ? " metric-alert" : ""}`}>
          <span>Priority</span>
          <strong>{urgent}</strong>
          <small>Urgent / emergency</small>
        </div>
        <div className="metric">
          <span>Multi-resource</span>
          <strong>{conflicts}</strong>
          <small>Review workload</small>
        </div>
      </section>

      <section className="table-panel">
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Time</th>
                <th>Work order</th>
                <th>Property</th>
                <th>Priority</th>
                <th>Status</th>
                <th>Resources</th>
                <th>Control</th>
              </tr>
            </thead>
            <tbody>
              {list.map((r) => {
                const aa = (r.work_order_assignments ?? []).filter(
                  (a: { status?: string }) => a.status === "assigned",
                );
                return (
                  <tr key={r.id}>
                    <td>
                      <strong>{timeLabel(r.scheduled_start as string | null)}</strong>
                      <br />
                      {r.scheduled_end
                        ? timeLabel(r.scheduled_end as string)
                        : "Open end"}
                    </td>
                    <td>{r.work_order_number}</td>
                    <td>
                      {(r.properties as { name?: string } | null)?.name ?? "—"}
                    </td>
                    <td>{r.priority}</td>
                    <td>{r.status}</td>
                    <td>
                      {aa.length
                        ? aa.map((a: { id?: string; assignment_type?: string }) => (
                            <span className="badge" key={a.id}>
                              {a.assignment_type}: {resourceName(a)}
                            </span>
                          ))
                        : (
                          <span className="badge">UNASSIGNED</span>
                        )}
                    </td>
                    <td>
                      <Link className="button compact" href="/work-orders">
                        Manage
                      </Link>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
        {!list.length ? (
          <p className="muted" style={{ padding: 16 }}>
            No jobs scheduled today. Create a work order with a start time to see
            it here.
          </p>
        ) : null}
      </section>
    </>
  );
}

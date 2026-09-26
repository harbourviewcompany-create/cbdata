import { notFound } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { getWorkspaceContext } from "@/lib/workspace";
import { updateProperty } from "../actions";

const fmt = (v: string | null | undefined) =>
  v ? new Date(v).toLocaleString() : "—";

export default async function PropertyDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const ctx = await getWorkspaceContext();
  const s = await createClient();
  if (!ctx) {
    return (
      <div className="empty-card">
        <h2 style={{ marginTop: 0 }}>No workspace access</h2>
      </div>
    );
  }

  const { data: p } = await s
    .from("properties")
    .select("*")
    .eq("id", id)
    .eq("workspace_id", ctx.workspaceId)
    .single();
  if (!p) notFound();

  const [{ data: contracts }, { data: work }, { data: issues }, { data: events }, { data: docs }] =
    await Promise.all([
      s.from("contracts").select("id,contract_number,name,status,start_date,end_date,contract_value").eq("property_id", id).order("end_date"),
      s.from("work_orders").select("id,work_order_number,status,scheduled_start,scheduled_end,priority,description").eq("property_id", id).order("scheduled_start", { ascending: false }).limit(100),
      s.from("issues").select("id,title,severity,status,due_at,reported_at").eq("property_id", id).order("reported_at", { ascending: false }).limit(100),
      s.from("audit_events").select("id,action,entity_type,occurred_at,actor_user_id").eq("entity_id", id).order("occurred_at", { ascending: false }).limit(30),
      s.from("documents").select("id,file_name,document_type,created_at").eq("entity_id", id).order("created_at", { ascending: false }).limit(20),
    ]);

  const openWork = (work ?? []).filter((x) => !["completed", "cancelled", "approved"].includes(String(x.status))).length;
  const openIssues = (issues ?? []).filter((x) => !["resolved", "closed"].includes(String(x.status))).length;
  const priorityIssues = (issues ?? []).filter((x) => ["critical", "high"].includes(String(x.severity)) && !["resolved", "closed"].includes(String(x.status))).length;
  const activeContracts = (contracts ?? []).filter((x) => ["active", "renewal_pending"].includes(String(x.status))).length;

  return (
    <>
      <header className="page-intro">
        <div>
          <span className="eyebrow">PROPERTY 360 / OPERATIONS</span>
          <h2 className="page-title">{p.name}</h2>
          <p className="muted">
            {p.address_line_1}
            {p.address_line_2 ? `, ${p.address_line_2}` : ""}, {p.city}, {p.province ?? ""} {p.postal_code ?? ""}
          </p>
        </div>
        <div className="topbar-actions">
          <Link className="button" href="/properties">All properties</Link>
          <Link className="primary compact" href="/work-orders">Create work</Link>
        </div>
      </header>

      <section className="metrics">
        <div className="metric"><span>Open work</span><strong>{openWork}</strong><small>Active jobs</small></div>
        <div className="metric"><span>Open issues</span><strong>{openIssues}</strong><small>Exceptions</small></div>
        <div className={`metric${priorityIssues ? " metric-alert" : ""}`}><span>Priority issues</span><strong>{priorityIssues}</strong><small>High / critical</small></div>
        <div className="metric"><span>Active contracts</span><strong>{activeContracts}</strong><small>In force</small></div>
      </section>

      <section className="panel" style={{ marginBottom: 14 }}>
        <div className="panel-head"><div><span className="eyebrow">EDIT</span><h3>Site details</h3></div></div>
        <form action={updateProperty} className="form-grid property-form">
          <input type="hidden" name="id" value={p.id} />
          <label className="field"><span>Name</span><input name="name" defaultValue={p.name} required /></label>
          <label className="field"><span>Type</span><input name="property_type" defaultValue={p.property_type} required /></label>
          <label className="field field-span-2"><span>Address</span><input name="address_line_1" defaultValue={p.address_line_1} required /></label>
          <label className="field"><span>Line 2</span><input name="address_line_2" defaultValue={p.address_line_2 ?? ""} /></label>
          <label className="field"><span>City</span><input name="city" defaultValue={p.city} required /></label>
          <label className="field"><span>Province</span><input name="province" defaultValue={p.province ?? ""} /></label>
          <label className="field"><span>Postal</span><input name="postal_code" defaultValue={p.postal_code ?? ""} /></label>
          <label className="field field-span-2"><span>Access notes</span><input name="access_notes" defaultValue={p.access_notes ?? ""} /></label>
          <label className="field field-span-2"><span>Site notes</span><input name="site_notes" defaultValue={p.site_notes ?? ""} /></label>
          <div className="field field-span-2 form-actions"><button type="submit" className="primary">Save property</button></div>
        </form>
      </section>

      <section className="grid-two">
        <article className="table-panel">
          <h2 style={{ padding: "16px 16px 0", margin: 0, fontSize: 16 }}>Work orders</h2>
          <div className="table-wrap"><table><thead><tr><th>WO</th><th>Status</th><th>Priority</th><th>Schedule</th></tr></thead>
          <tbody>
            {(work ?? []).length === 0 ? (
              <tr><td colSpan={4} className="muted">No work orders yet. <Link href="/work-orders">Create one →</Link></td></tr>
            ) : (work ?? []).map((w) => (
              <tr key={w.id}><td>{w.work_order_number}</td><td>{w.status}</td><td>{w.priority}</td><td>{fmt(w.scheduled_start as string | null)}</td></tr>
            ))}
          </tbody></table></div>
        </article>
        <article className="table-panel">
          <h2 style={{ padding: "16px 16px 0", margin: 0, fontSize: 16 }}>Issues</h2>
          <div className="table-wrap"><table><thead><tr><th>Issue</th><th>Severity</th><th>Status</th><th>Due</th></tr></thead>
          <tbody>
            {(issues ?? []).length === 0 ? (
              <tr><td colSpan={4} className="muted">No issues recorded.</td></tr>
            ) : (issues ?? []).map((i) => (
              <tr key={i.id}><td>{i.title}</td><td>{i.severity}</td><td>{i.status}</td><td>{fmt(i.due_at as string | null)}</td></tr>
            ))}
          </tbody></table></div>
        </article>
      </section>

      <section className="grid-two" style={{ marginTop: 14 }}>
        <article className="table-panel">
          <h2 style={{ padding: "16px 16px 0", margin: 0, fontSize: 16 }}>Contracts</h2>
          <div className="table-wrap"><table><thead><tr><th>Number</th><th>Name</th><th>Status</th><th>End</th></tr></thead>
          <tbody>
            {(contracts ?? []).length === 0 ? (
              <tr><td colSpan={4} className="muted">No contracts linked.</td></tr>
            ) : (contracts ?? []).map((c) => (
              <tr key={c.id}><td>{c.contract_number}</td><td>{c.name}</td><td>{c.status}</td><td>{c.end_date ?? "—"}</td></tr>
            ))}
          </tbody></table></div>
        </article>
        <article className="table-panel">
          <h2 style={{ padding: "16px 16px 0", margin: 0, fontSize: 16 }}>Activity</h2>
          <div className="table-wrap"><table><thead><tr><th>Action</th><th>Entity</th><th>When</th></tr></thead>
          <tbody>
            {(events ?? []).length === 0 ? (
              <tr><td colSpan={3} className="muted">No audit activity yet.</td></tr>
            ) : (events ?? []).map((e) => (
              <tr key={e.id}><td>{e.action}</td><td>{e.entity_type}</td><td>{fmt(e.occurred_at as string | null)}</td></tr>
            ))}
          </tbody></table></div>
          {(docs ?? []).length > 0 ? (
            <div style={{ padding: 16 }}>
              <h3 style={{ margin: "0 0 8px", fontSize: 13 }}>Documents</h3>
              {(docs ?? []).map((d) => (
                <div key={d.id} className="muted" style={{ fontSize: 12 }}>{d.file_name} · {d.document_type} · {fmt(d.created_at as string)}</div>
              ))}
            </div>
          ) : null}
        </article>
      </section>
    </>
  );
}

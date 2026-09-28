import { redirect } from "next/navigation";
import Link from "next/link";
import type { Route } from "next";
import { createClient } from "@/lib/supabase/server";
import { getWorkspaceContext } from "@/lib/workspace";

const money = (value: number | string) =>
  Number(value).toLocaleString("en-CA", { style: "currency", currency: "CAD" });

export default async function EstimatesPage() {
  const ctx = await getWorkspaceContext();
  if (!ctx) redirect("/login");
  const canManage = ["owner", "administrator", "sales_manager", "sales_rep"].includes(ctx.role ?? "");
  const s = await createClient();

  const [{ data: rows }, { data: orgs }] = await Promise.all([
    s.from("estimates")
      .select("id,estimate_number,estimate_kind,status,total,subtotal,estimated_margin,valid_until,organization_id,property_id,sent_at,accepted_at,site_verified_at,created_at")
      .eq("workspace_id", ctx.workspaceId)
      .order("created_at", { ascending: false })
      .limit(250),
    s.from("organizations")
      .select("id,legal_name,operating_name")
      .eq("workspace_id", ctx.workspaceId)
      .limit(500),
  ]);

  const orgName = (id: string) => {
    const org = orgs?.find((x) => x.id === id);
    return org?.operating_name ?? org?.legal_name ?? "—";
  };

  const all = rows ?? [];
  const draftCount = all.filter((r) => r.status === "draft").length;
  const sentCount = all.filter((r) => r.status === "sent").length;
  const acceptedCount = all.filter((r) => r.status === "accepted").length;
  const openValue = all
    .filter((r) => ["draft", "sent", "accepted"].includes(r.status))
    .reduce((sum, r) => sum + Number(r.subtotal), 0);

  return (
    <>
      <header className="page-intro">
        <div>
          <span className="eyebrow">GROWTH</span>
          <h1>Estimates</h1>
          <p className="muted">Build, verify, issue and convert estimates without losing scope or margin history.</p>
        </div>
        {canManage ? <Link className="button" href="/estimates/new">Price a deck job</Link> : null}
      </header>

      <section className="metrics">
        <div className="metric"><span>Drafts</span><strong>{draftCount}</strong><small>still editable</small></div>
        <div className="metric"><span>Sent</span><strong>{sentCount}</strong><small>awaiting decision</small></div>
        <div className="metric"><span>Accepted</span><strong>{acceptedCount}</strong><small>ready for contract</small></div>
        <div className="metric"><span>Open pre-tax value</span><strong>{money(openValue)}</strong><small>draft + sent + accepted</small></div>
      </section>

      <section className="table-panel" style={{ marginTop: 14 }}>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Estimate</th>
                <th>Customer</th>
                <th>Status</th>
                <th>Total</th>
                <th>Margin</th>
                <th>Verification</th>
                <th>Valid until</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {all.length ? all.map((row) => (
                <tr key={row.id}>
                  <td>
                    <Link href={`/estimates/${row.id}` as Route}>{row.estimate_number}</Link>
                    {row.estimate_kind === "deck" ? <span className="badge" style={{ marginLeft: 8 }}>deck</span> : null}
                  </td>
                  <td>{orgName(row.organization_id)}</td>
                  <td>{row.status}</td>
                  <td>{money(row.total)}</td>
                  <td>{Number(row.estimated_margin).toFixed(1)}%</td>
                  <td>{row.site_verified_at ? "verified" : row.status === "draft" ? "pending" : "—"}</td>
                  <td>{row.valid_until ?? "—"}</td>
                  <td><Link href={`/estimates/${row.id}` as Route}>Open</Link></td>
                </tr>
              )) : (
                <tr>
                  <td colSpan={8} className="muted">No estimates yet. Price a deck job to create the first auditable draft.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>
    </>
  );
}

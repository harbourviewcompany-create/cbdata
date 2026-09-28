import Link from "next/link";
import type { Route } from "next";
import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getWorkspaceContext } from "@/lib/workspace";
import { advanceEstimate, convertEstimate } from "../actions";

const money = (value: number | string) =>
  Number(value).toLocaleString("en-CA", { style: "currency", currency: "CAD" });

export default async function EstimateDetail({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const ctx = await getWorkspaceContext();
  if (!ctx) redirect("/login");

  const canManage = ["owner", "administrator", "sales_manager", "sales_rep"].includes(ctx.role ?? "");
  const canConvert = ["owner", "administrator", "sales_manager"].includes(ctx.role ?? "");
  const s = await createClient();

  const { data: row } = await s
    .from("estimates")
    .select(
      "id,estimate_number,estimate_kind,status,subtotal,tax,total,valid_until,sent_at,accepted_at,rejected_at,organization_id,property_id,estimated_direct_cost,estimated_gross_profit,estimated_margin,site_verified_at,site_verified_by,site_verification_notes",
    )
    .eq("id", id)
    .eq("workspace_id", ctx.workspaceId)
    .maybeSingle();
  if (!row) notFound();

  const [{ data: items }, { data: linkedContract }] = await Promise.all([
    s.from("estimate_items")
      .select("id,description,quantity,unit_price,line_total,estimated_material_cost,estimated_labor_cost,estimated_equipment_cost,estimated_subcontractor_cost")
      .eq("estimate_id", id)
      .eq("workspace_id", ctx.workspaceId)
      .order("sort_order"),
    s.from("contracts")
      .select("id,contract_number,status")
      .eq("workspace_id", ctx.workspaceId)
      .eq("source_estimate_id", id)
      .maybeSingle(),
  ]);

  const directLineCost = (item: NonNullable<typeof items>[number]) =>
    Number(item.estimated_material_cost)
    + Number(item.estimated_labor_cost)
    + Number(item.estimated_equipment_cost)
    + Number(item.estimated_subcontractor_cost);

  return (
    <>
      <header className="page-intro">
        <div>
          <span className="eyebrow">{row.estimate_kind === "deck" ? "DECK ESTIMATE" : "ESTIMATE"}</span>
          <h1>{row.estimate_number}</h1>
          <p className="muted">Status: {row.status}</p>
        </div>
        <div className="quote-actions">
          <Link className="button" href="/estimates">Back</Link>
          <Link className="button" href={`/estimates/${id}/quote` as Route}>Quote / PDF</Link>
        </div>
      </header>

      <section className="metrics">
        <div className="metric"><span>Customer total</span><strong>{money(row.total)}</strong><small>including HST</small></div>
        <div className="metric"><span>Direct cost</span><strong>{money(row.estimated_direct_cost)}</strong><small>estimated</small></div>
        <div className="metric"><span>Gross profit</span><strong>{money(row.estimated_gross_profit)}</strong><small>{Number(row.estimated_margin).toFixed(1)}% margin</small></div>
        <div className="metric"><span>Valid until</span><strong style={{ fontSize: 20 }}>{row.valid_until ?? "—"}</strong><small>{row.property_id ? "property linked" : "property not linked"}</small></div>
      </section>

      <section className="panel" style={{ marginTop: 14 }}>
        <div className="panel-head">
          <div>
            <span className="eyebrow">WORKFLOW</span>
            <h3>Estimate controls</h3>
          </div>
          {row.site_verified_at ? <span className="badge">Site verified</span> : <span className="badge">Verification pending</span>}
        </div>

        <div className="deck-audit-grid">
          <div><span>Site verified</span><strong>{row.site_verified_at ? new Date(row.site_verified_at).toLocaleString("en-CA") : "Not yet"}</strong></div>
          <div><span>Sent</span><strong>{row.sent_at ? new Date(row.sent_at).toLocaleString("en-CA") : "—"}</strong></div>
          <div><span>Accepted</span><strong>{row.accepted_at ? new Date(row.accepted_at).toLocaleString("en-CA") : "—"}</strong></div>
          <div><span>Rejected</span><strong>{row.rejected_at ? new Date(row.rejected_at).toLocaleString("en-CA") : "—"}</strong></div>
        </div>
        {row.site_verification_notes ? <p className="muted">Verification notes: {row.site_verification_notes}</p> : null}

        {canManage && row.status === "draft" && row.estimate_kind === "deck" ? (
          <Link className="button" href={`/estimates/${id}/edit` as Route} style={{ marginTop: 16, display: "inline-block" }}>
            Revise scope and pricing
          </Link>
        ) : null}

        {canManage && row.status === "draft" ? (
          <form action={advanceEstimate} className="deck-stage-form">
            <input type="hidden" name="id" value={row.id} />
            <input type="hidden" name="action" value="sent" />
            <label>
              <input type="checkbox" name="site_confirmed" required />
              I verified site measurements, foundation and guard requirements, exclusions, scope and price.
            </label>
            <label className="deck-wide">
              Verification notes
              <textarea name="site_verification_notes" maxLength={1000} placeholder="Measured height, footing/soil observations, access constraints, guard requirement, utility locates..." />
            </label>
            <button className="primary" type="submit">Verify site and mark sent</button>
          </form>
        ) : null}

        {canManage && row.status === "sent" ? (
          <div className="deck-stage-actions">
            <form action={advanceEstimate}>
              <input type="hidden" name="id" value={row.id} />
              <input type="hidden" name="action" value="accepted" />
              <button className="primary" type="submit">Record customer acceptance</button>
            </form>
            <form action={advanceEstimate}>
              <input type="hidden" name="id" value={row.id} />
              <input type="hidden" name="action" value="rejected" />
              <button type="submit">Record rejection</button>
            </form>
          </div>
        ) : null}

        {row.status === "accepted" ? (
          linkedContract ? (
            <p style={{ marginTop: 16 }}>
              Converted to <Link href={`/contracts/${linkedContract.id}` as Route}>{linkedContract.contract_number}</Link> ({linkedContract.status}).
            </p>
          ) : !row.property_id ? (
            <p className="deck-warning">A property must be linked before this accepted estimate can become a contract. Revise the draft/property linkage before issuing future estimates.</p>
          ) : canConvert ? (
            <form action={convertEstimate} style={{ marginTop: 16 }}>
              <input type="hidden" name="id" value={row.id} />
              <button className="primary" type="submit">Create draft contract</button>
            </form>
          ) : (
            <p className="muted" style={{ marginTop: 16 }}>A sales manager or administrator must convert this accepted estimate.</p>
          )
        ) : null}
      </section>

      <section className="table-panel" style={{ marginTop: 14 }}>
        <div className="table-wrap">
          <table>
            <thead><tr><th>Item</th><th>Price</th><th>Direct cost</th><th>Gross profit</th></tr></thead>
            <tbody>
              {(items ?? []).map((item) => {
                const cost = directLineCost(item);
                return (
                  <tr key={item.id}>
                    <td style={{ whiteSpace: "normal", minWidth: 360 }}>{item.description}</td>
                    <td>{money(item.line_total)}</td>
                    <td>{money(cost)}</td>
                    <td>{money(Number(item.line_total) - cost)}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </section>
    </>
  );
}

import Link from "next/link";
import type { Route } from "next";
import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getWorkspaceContext } from "@/lib/workspace";
import { advanceEstimate, convertEstimate } from "../actions";

const money = (n: number) => Number(n).toLocaleString("en-CA", { style: "currency", currency: "CAD" });

export default async function EstimateDetail({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const ctx = await getWorkspaceContext();
  if (!ctx) redirect("/login");
  const canManage = ["owner", "administrator", "sales_manager", "sales_rep"].includes(ctx.role ?? "");
  const s = await createClient();
  const { data: row } = await s
    .from("estimates")
    .select(
      "id,estimate_number,status,subtotal,tax,total,valid_until,sent_at,accepted_at,organization_id,estimated_direct_cost,estimated_gross_profit,estimated_margin",
    )
    .eq("id", id)
    .eq("workspace_id", ctx.workspaceId)
    .maybeSingle();
  if (!row) notFound();
  const { data: items } = await s
    .from("estimate_items")
    .select("id,description,quantity,unit_price,line_total,estimated_material_cost,estimated_labor_cost")
    .eq("estimate_id", id)
    .order("sort_order");

  return (
    <>
      <header className="page-intro">
        <div>
          <span className="eyebrow">ESTIMATE</span>
          <h1>{row.estimate_number}</h1>
          <p className="muted">{row.status}</p>
        </div>
        <Link className="button" href="/estimates">
          Back
        </Link>
        <Link className="button" href={`/estimates/${id}/quote` as Route}>Customer quote / PDF</Link>
      </header>
      <section className="panel">
        <dl className="checks" style={{ display: "grid", gap: 10 }}>
          <div>Subtotal <strong>{money(row.subtotal)}</strong></div>
          <div>Tax <strong>{money(row.tax)}</strong></div>
          <div>Total <strong>{money(row.total)}</strong></div>
          <div>Valid <strong>{row.valid_until ?? "\u2014"}</strong></div>
          <div>Direct cost <strong>{money(row.estimated_direct_cost)}</strong></div>
          <div>Gross profit <strong>{money(row.estimated_gross_profit)} ({row.estimated_margin}%)</strong></div>
        </dl>
        {canManage && row.status === "draft" && row.estimate_number.startsWith("DECK-") ?
          <Link className="button" href={`/estimates/${id}/edit`} style={{ marginTop: 16, display: "inline-block" }}>Revise scope and pricing</Link> : null}
        {canManage && row.status === "draft" ? (
          <form action={advanceEstimate} className="deck-stage-form">
            <input type="hidden" name="id" value={row.id} />
            <input type="hidden" name="action" value="sent" />
            <label><input type="checkbox" name="site_confirmed" required /> I verified site measurements, foundation and guard requirements, scope and price. The quote has been sent to the customer.</label>
            <button className="primary" type="submit">Mark sent</button>
          </form>
        ) : null}
        {canManage && row.status === "sent" ? (
          <form action={advanceEstimate} className="deck-stage-form">
            <input type="hidden" name="id" value={row.id} />
            <input type="hidden" name="action" value="accepted" />
            <button className="primary" type="submit">Record customer acceptance</button>
          </form>
        ) : null}
        {canManage && row.status === "accepted" ? (
          <form action={convertEstimate} style={{ marginTop: 16 }}>
            <input type="hidden" name="id" value={row.id} />
            <button className="primary" type="submit">
              Convert to contract
            </button>
          </form>
        ) : null}
      </section>
      <section className="table-panel" style={{ marginTop: 14 }}>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Item</th>
                <th>Qty</th>
                <th>Unit</th>
                <th>Line</th>
                <th>Direct cost</th>
              </tr>
            </thead>
            <tbody>
              {(items ?? []).map((i) => (
                <tr key={i.id}>
                  <td>{i.description}</td>
                  <td>{i.quantity}</td>
                  <td>{money(i.unit_price)}</td>
                  <td>{money(i.line_total)}</td>
                  <td>{money(i.estimated_material_cost + i.estimated_labor_cost)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </>
  );
}

import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getWorkspaceContext } from "@/lib/workspace";
import { convertEstimate } from "../actions";

const CONVERTIBLE = new Set(["draft", "sent", "accepted"]);

export default async function EstimateDetail({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const ctx = await getWorkspaceContext();
  if (!ctx) redirect("/login");
  const s = await createClient();
  const { data: row } = await s
    .from("estimates")
    .select(
      "id,estimate_number,status,subtotal,tax,total,valid_until,sent_at,accepted_at,organization_id,property_id",
    )
    .eq("id", id)
    .eq("workspace_id", ctx.workspaceId)
    .maybeSingle();
  if (!row) notFound();
  const { data: items } = await s
    .from("estimate_items")
    .select("id,description,quantity,unit_price,line_total,service_definition_id")
    .eq("estimate_id", id)
    .order("sort_order");

  const blockers: string[] = [];
  if (!row.property_id) blockers.push("Assign a property to this estimate.");
  if (!(items ?? []).length) blockers.push("Add at least one estimate line item.");
  if ((items ?? []).some((i) => !i.service_definition_id)) blockers.push("Assign a service definition to every line item.");
  const canConvert = CONVERTIBLE.has(row.status) && blockers.length === 0;

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
      </header>
      <section className="panel">
        <dl className="checks" style={{ display: "grid", gap: 10 }}>
          <div>Subtotal <strong>{row.subtotal}</strong></div>
          <div>Tax <strong>{row.tax}</strong></div>
          <div>Total <strong>{row.total}</strong></div>
          <div>Valid <strong>{row.valid_until ?? "\u2014"}</strong></div>
        </dl>
        {canConvert ? (
          <form action={convertEstimate} style={{ marginTop: 16 }}>
            <input type="hidden" name="id" value={row.id} />
            <button className="primary" type="submit">
              Convert to contract
            </button>
          </form>
        ) : CONVERTIBLE.has(row.status) ? (
          <div style={{ marginTop: 16 }}>
            <strong>Contract conversion blocked</strong>
            <ul className="muted" style={{ marginTop: 8, paddingLeft: 20 }}>
              {blockers.map((blocker) => <li key={blocker}>{blocker}</li>)}
            </ul>
          </div>
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
              </tr>
            </thead>
            <tbody>
              {(items ?? []).map((i) => (
                <tr key={i.id}>
                  <td>{i.description}</td>
                  <td>{i.quantity}</td>
                  <td>{i.unit_price}</td>
                  <td>{i.line_total}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </>
  );
}

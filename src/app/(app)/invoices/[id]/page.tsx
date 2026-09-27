import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getWorkspaceContext } from "@/lib/workspace";
import { issueInvoice, recordPayment } from "../actions";

export default async function InvoiceDetail({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const ctx = await getWorkspaceContext();
  if (!ctx) redirect("/login");
  const s = await createClient();
  const { data: row } = await s
    .from("invoices")
    .select(
      "id,invoice_number,status,subtotal,tax,total,invoice_date,due_date,work_order_id,organization_id",
    )
    .eq("id", id)
    .eq("workspace_id", ctx.workspaceId)
    .maybeSingle();
  if (!row) notFound();
  const [{ data: items }, { data: pays }] = await Promise.all([
    s.from("invoice_items").select("id,description,quantity,unit_price,total").eq("invoice_id", id),
    s.from("payments").select("id,amount,payment_date,payment_method").eq("invoice_id", id).order("payment_date"),
  ]);

  return (
    <>
      <header className="page-intro">
        <div>
          <span className="eyebrow">INVOICE</span>
          <h1>{row.invoice_number}</h1>
          <p className="muted">{row.status}</p>
        </div>
        <Link className="button" href="/invoices">
          Back
        </Link>
      </header>
      <section className="panel">
        <dl className="checks" style={{ display: "grid", gap: 10 }}>
          <div>Date <strong>{row.invoice_date}</strong></div>
          <div>Due <strong>{row.due_date ?? "—"}</strong></div>
          <div>Total <strong>{row.total}</strong></div>
        </dl>
        {row.status === "draft" ? (
          <form action={issueInvoice} style={{ marginTop: 16 }}>
            <input type="hidden" name="id" value={row.id} />
            <button className="primary">Issue invoice</button>
          </form>
        ) : null}
        {["issued", "partially_paid", "overdue"].includes(row.status) ? (
          <form action={recordPayment} className="form-grid" style={{ marginTop: 16 }}>
            <input type="hidden" name="id" value={row.id} />
            <input name="amount" type="number" step="0.01" required placeholder="Payment amount" />
            <select name="method" defaultValue="e_transfer">
              <option value="e_transfer">e-Transfer</option>
              <option value="cheque">Cheque</option>
              <option value="card">Card</option>
              <option value="cash">Cash</option>
            </select>
            <button className="primary">Record payment</button>
          </form>
        ) : null}
      </section>
      <section className="table-panel" style={{ marginTop: 14 }}>
        <h2>Lines</h2>
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
                  <td>{i.total}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
      <section className="table-panel" style={{ marginTop: 14 }}>
        <h2>Payments</h2>
        <ul className="queue-list">
          {(pays ?? []).length ? (
            pays!.map((p) => (
              <li key={p.id}>
                <strong>
                  {Number(p.amount).toLocaleString("en-CA", {
                    style: "currency",
                    currency: "CAD",
                  })}
                </strong>
                <span className="muted">
                  {p.payment_date} · {p.payment_method ?? "—"}
                </span>
              </li>
            ))
          ) : (
            <li className="muted">No payments recorded.</li>
          )}
        </ul>
      </section>
    </>
  );
}

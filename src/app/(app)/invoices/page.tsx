import { redirect } from "next/navigation";
import Link from "next/link";
import type { Route } from "next";
import { createClient } from "@/lib/supabase/server";
import { getWorkspaceContext } from "@/lib/workspace";
import { issueInvoice, recordPayment } from "./actions";

export default async function InvoicesPage() {
  const ctx = await getWorkspaceContext();
  if (!ctx) redirect("/login");
  const s = await createClient();
  const [{ data: rows }, { data: orgs }] = await Promise.all([
    s
      .from("invoices")
      .select(
        "id,invoice_number,status,total,invoice_date,due_date,organization_id,work_order_id",
      )
      .eq("workspace_id", ctx.workspaceId)
      .order("invoice_date", { ascending: false })
      .limit(200),
    s.from("organizations").select("id,legal_name,operating_name").eq("workspace_id", ctx.workspaceId),
  ]);

  const orgName = (id: string) => {
    const o = orgs?.find((x) => x.id === id);
    return o?.operating_name ?? o?.legal_name ?? "\u2014";
  };

  return (
    <>
      <header className="page-intro">
        <div>
          <span className="eyebrow">MONEY</span>
          <h1>Invoices</h1>
          <p className="muted">Issue drafts and record payments. One invoice per work order.</p>
        </div>
      </header>
      <section className="table-panel">
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Invoice</th>
                <th>Customer</th>
                <th>Status</th>
                <th>Total</th>
                <th>Due</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {(rows ?? []).length ? (
                rows!.map((r) => (
                  <tr key={r.id}>
                    <td>
                      <Link href={`/invoices/${r.id}` as Route}>{r.invoice_number}</Link>
                    </td>
                    <td>{orgName(r.organization_id)}</td>
                    <td>{r.status}</td>
                    <td>
                      {Number(r.total).toLocaleString("en-CA", {
                        style: "currency",
                        currency: "CAD",
                      })}
                    </td>
                    <td>{r.due_date ?? "\u2014"}</td>
                    <td>
                      <div className="stack-actions">
                        {r.status === "draft" ? (
                          <form action={issueInvoice}>
                            <input type="hidden" name="id" value={r.id} />
                            <button type="submit">Issue</button>
                          </form>
                        ) : null}
                        {["issued", "partially_paid", "overdue"].includes(r.status) ? (
                          <form action={recordPayment} className="actions">
                            <input type="hidden" name="id" value={r.id} />
                            <input
                              name="amount"
                              type="number"
                              step="0.01"
                              required
                              placeholder="Amount"
                            />
                            <select name="method" defaultValue="e_transfer">
                              <option value="e_transfer">e-Transfer</option>
                              <option value="cheque">Cheque</option>
                              <option value="card">Card</option>
                              <option value="cash">Cash</option>
                            </select>
                            <button type="submit">Record payment</button>
                          </form>
                        ) : null}
                      </div>
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={6} className="muted">
                    No invoices yet. Completing a work order creates one.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>
    </>
  );
}

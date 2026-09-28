import Link from "next/link";
import type { Route } from "next";
import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getWorkspaceContext } from "@/lib/workspace";
import { PrintQuoteButton } from "./PrintQuoteButton";

const money = (value: number | string) =>
  Number(value).toLocaleString("en-CA", { style: "currency", currency: "CAD" });

export default async function CustomerQuote({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const ctx = await getWorkspaceContext();
  if (!ctx) redirect("/login");

  const s = await createClient();
  const { data: estimate } = await s
    .from("estimates")
    .select("id,estimate_number,status,subtotal,tax,total,valid_until,organization_id,sent_at,accepted_at")
    .eq("id", id)
    .eq("workspace_id", ctx.workspaceId)
    .maybeSingle();
  if (!estimate) notFound();

  const [{ data: customer }, { data: items }] = await Promise.all([
    s.from("organizations")
      .select("legal_name,operating_name")
      .eq("id", estimate.organization_id)
      .eq("workspace_id", ctx.workspaceId)
      .maybeSingle(),
    s.from("estimate_items")
      .select("id,description,line_total")
      .eq("estimate_id", id)
      .eq("workspace_id", ctx.workspaceId)
      .order("sort_order"),
  ]);

  return (
    <>
      <div className="quote-actions">
        <Link className="button" href={`/estimates/${id}` as Route}>Back to estimate</Link>
        <PrintQuoteButton />
      </div>
      <article className="quote-sheet">
        {estimate.status === "draft" ? <div className="quote-draft-banner">DRAFT — NOT ISSUED</div> : null}
        <header>
          <div><small>CB CONTRACTING</small><h1>Project estimate</h1></div>
          <div className="quote-meta">
            <strong>{estimate.estimate_number}</strong>
            <span>Valid until {estimate.valid_until ?? "to be confirmed"}</span>
          </div>
        </header>

        <p><strong>Prepared for</strong><br />{customer?.operating_name ?? customer?.legal_name ?? "Customer"}</p>

        <h2>Scope of work</h2>
        <table>
          <thead><tr><th>Work item and assumptions</th><th>Price</th></tr></thead>
          <tbody>
            {(items ?? []).map((item) => (
              <tr key={item.id}>
                <td>{item.description}</td>
                <td>{money(item.line_total)}</td>
              </tr>
            ))}
          </tbody>
        </table>

        <dl>
          <div><dt>Subtotal</dt><dd>{money(estimate.subtotal)}</dd></div>
          <div><dt>HST (13%)</dt><dd>{money(estimate.tax)}</dd></div>
          <div className="quote-grand"><dt>Total</dt><dd>{money(estimate.total)}</dd></div>
        </dl>

        <p className="quote-note">
          Price is based on the scope and assumptions above. Permit drawings, engineering and municipal fees are separate unless expressly included. Changes to verified dimensions, foundations, stairs, guards, access or site conditions may require a revised estimate.
        </p>
        <footer>
          Estimate status: {estimate.status}
          {estimate.sent_at ? ` · issued ${new Date(estimate.sent_at).toLocaleDateString("en-CA")}` : ""}
          {estimate.accepted_at ? ` · accepted ${new Date(estimate.accepted_at).toLocaleDateString("en-CA")}` : ""}.
        </footer>
      </article>
    </>
  );
}

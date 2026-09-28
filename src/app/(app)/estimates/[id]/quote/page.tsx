import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getWorkspaceContext } from "@/lib/workspace";
import { PrintQuoteButton } from "./PrintQuoteButton";

const money = (value: number) => Number(value).toLocaleString("en-CA", { style: "currency", currency: "CAD" });

export default async function CustomerQuote({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const ctx = await getWorkspaceContext();
  if (!ctx) redirect("/login");
  const s = await createClient();
  const { data: estimate } = await s.from("estimates")
    .select("id,estimate_number,status,subtotal,tax,total,valid_until,organization_id")
    .eq("id", id).eq("workspace_id", ctx.workspaceId).maybeSingle();
  if (!estimate) notFound();
  const [{ data: customer }, { data: items }] = await Promise.all([
    s.from("organizations").select("legal_name,operating_name").eq("id", estimate.organization_id)
      .eq("workspace_id", ctx.workspaceId).maybeSingle(),
    s.from("estimate_items").select("id,description").eq("estimate_id", id)
      .eq("workspace_id", ctx.workspaceId).order("sort_order"),
  ]);
  return <><div className="quote-actions"><Link className="button" href={`/estimates/${id}`}>Back to estimate</Link><PrintQuoteButton /></div>
    <article className="quote-sheet">
      <header><div><small>CB CONTRACTING</small><h1>Project estimate</h1></div>
        <div className="quote-meta"><strong>{estimate.estimate_number}</strong><span>Valid until {estimate.valid_until ?? "to be confirmed"}</span></div></header>
      <p><strong>Prepared for</strong><br />{customer?.operating_name ?? customer?.legal_name ?? "Customer"}</p>
      <h2>Scope of work</h2>
      <table><thead><tr><th>Work item and assumptions</th></tr></thead><tbody>
        {(items ?? []).filter((item) => !item.description.startsWith("Project coordination and allowance"))
          .map((item) => <tr key={item.id}><td>{item.description}</td></tr>)}
      </tbody></table>
      <dl><div><dt>Subtotal</dt><dd>{money(estimate.subtotal)}</dd></div>
        <div><dt>HST (13%)</dt><dd>{money(estimate.tax)}</dd></div>
        <div className="quote-grand"><dt>Total</dt><dd>{money(estimate.total)}</dd></div></dl>
      <p className="quote-note">Price is based on the scope above. Final deck height, stairs, guards, foundation design and site conditions must be verified before this estimate is issued. Permit drawings and municipal fees are separate unless expressly included in the work items. Changes to the confirmed scope may require a revised estimate.</p>
      <footer>Estimate status: {estimate.status}. Acceptance is recorded by CB Contracting after customer approval.</footer>
    </article></>;
}

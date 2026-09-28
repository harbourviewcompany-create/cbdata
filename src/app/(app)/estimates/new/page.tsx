import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getWorkspaceContext } from "@/lib/workspace";
import { DeckEstimateForm } from "./DeckEstimateForm";
import { createEstimateCustomer } from "../actions";

export default async function NewDeckEstimate() {
  const ctx = await getWorkspaceContext();
  if (!ctx) redirect("/login");
  if (!["owner", "administrator", "sales_manager", "sales_rep"].includes(ctx.role ?? "")) redirect("/estimates");
  const s = await createClient();
  const [{ data: organizations }, { data: properties }] = await Promise.all([
    s.from("organizations").select("id,legal_name,operating_name").eq("workspace_id", ctx.workspaceId).order("legal_name").limit(500),
    s.from("properties").select("id,name,address_line_1,primary_customer_organization_id").eq("workspace_id", ctx.workspaceId).order("name").limit(500),
  ]);
  return <><header className="page-intro"><div><span className="eyebrow">ESTIMATES / NEW</span>
    <h1>Price a deck job</h1><p className="muted">Build a measured draft, review costs, and move it through approval.</p></div>
    <Link className="button" href="/estimates">Back to estimates</Link></header>
    <details className="panel deck-customer-panel" open={!organizations?.length}>
      <summary>New customer</summary>
      <form action={createEstimateCustomer} className="deck-customer-form">
        <label>Customer name <input name="customer_name" required minLength={2} maxLength={180} placeholder="Customer or company name" /></label>
        <button type="submit">Add customer</button>
      </form>
    </details>
    <DeckEstimateForm defaultExpiry={new Intl.DateTimeFormat("sv-SE", { timeZone: "America/Toronto" }).format(new Date(Date.now() + 30 * 86_400_000))}
      customers={(organizations ?? []).map((o) => ({ id: o.id, name: o.operating_name ?? o.legal_name }))}
      properties={(properties ?? []).map((p) => ({ id: p.id, name: `${p.name} · ${p.address_line_1}`, customerId: p.primary_customer_organization_id }))} />
  </>;
}

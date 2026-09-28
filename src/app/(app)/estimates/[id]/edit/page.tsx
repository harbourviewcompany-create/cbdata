import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getWorkspaceContext } from "@/lib/workspace";
import { updateDeckEstimate } from "../../actions";
import { GUARD_LINE } from "../../deck-pricing";

export default async function EditDeckEstimate({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const ctx = await getWorkspaceContext();
  if (!ctx) redirect("/login");
  if (!["owner", "administrator", "sales_manager", "sales_rep"].includes(ctx.role ?? "")) redirect("/estimates");
  const s = await createClient();
  const { data: estimate } = await s.from("estimates")
    .select("id,estimate_number,status,valid_until")
    .eq("id", id).eq("workspace_id", ctx.workspaceId).maybeSingle();
  if (!estimate || estimate.status !== "draft" || !estimate.estimate_number.startsWith("DECK-")) notFound();
  const { data: items } = await s.from("estimate_items")
    .select("id,description,unit_price,estimated_material_cost,estimated_labor_cost")
    .eq("estimate_id", id).eq("workspace_id", ctx.workspaceId).order("sort_order");
  if (!items?.length) notFound();
  const hasGuards = items.some((item) => item.description.startsWith(GUARD_LINE.label));
  return <><header className="page-intro"><div><span className="eyebrow">REVISE DRAFT</span>
    <h1>{estimate.estimate_number}</h1><p className="muted">Update scope and direct costs after the site visit. Totals recalculate when saved.</p></div>
    <Link className="button" href={`/estimates/${id}`}>Cancel</Link></header>
    <form action={updateDeckEstimate} className="panel">
      <input type="hidden" name="id" value={id} /><input type="hidden" name="count" value={items.length} />
      <label className="deck-expiry">Valid until <input name="valid_until" type="date" required defaultValue={estimate.valid_until ?? ""} /></label>
      <div className="table-wrap"><table><thead><tr><th>Scope and assumptions</th><th>Price</th><th>Materials</th><th>Labour</th></tr></thead><tbody>
        {items.map((item, i) => <tr key={item.id}>
          <td><textarea className="deck-description" name={`item_${i}_description`} maxLength={1000} required defaultValue={item.description} aria-label={`Item ${i+1} scope`} /></td>
          {(["price", "material", "labor"] as const).map((field) =>
            <td key={field}><input className="deck-money-input" type="number" min="0" max="9999999" step="0.01" required
              name={`item_${i}_${field}`} aria-label={`Item ${i+1} ${field}`}
              defaultValue={field === "price" ? item.unit_price : field === "material" ? item.estimated_material_cost : item.estimated_labor_cost} /></td>)}
        </tr>)}
      </tbody></table></div>
      {!hasGuards ? <div className="deck-add-guards">
        <label><input type="checkbox" name="add_guards" /> Add pressure-treated deck guards after site measurement</label>
        <div className="deck-form-grid">
          <label>Guard price <input type="number" name="guards_price" min="0" step="0.01" defaultValue={GUARD_LINE.price} /></label>
          <label>Guard materials <input type="number" name="guards_material" min="0" step="0.01" defaultValue={GUARD_LINE.material} /></label>
          <label>Guard labour <input type="number" name="guards_labor" min="0" step="0.01" defaultValue={GUARD_LINE.labor} /></label>
        </div>
      </div> : null}
      <p className="muted">HST remains 13%. Item direct costs must not exceed their price.</p>
      <button className="primary" type="submit">Save revised draft</button>
    </form>
  </>;
}

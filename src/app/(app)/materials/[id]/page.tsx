import Link from "next/link";
import type { Route } from "next";
import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getWorkspaceContext } from "@/lib/workspace";
import {
  addMaterialRequestItem,
  recordManualMaterialQuote,
  removeMaterialRequestItem,
  runMaterialPriceScan,
  saveMaterialSupplierTerms,
  selectMaterialPricePlan,
  updateMaterialRequestSettings,
} from "../actions";

const money = (value: number | string | null | undefined) =>
  value == null
    ? "—"
    : Number(value).toLocaleString("en-CA", { style: "currency", currency: "CAD" });

const age = (value: string | null | undefined) => {
  if (!value) return "—";
  const days = Math.max(0, Math.floor((Date.now() - new Date(value).getTime()) / 86_400_000));
  if (days === 0) return "today";
  if (days === 1) return "1 day ago";
  return `${days} days ago`;
};

export default async function MaterialRequestDetail({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const ctx = await getWorkspaceContext();
  if (!ctx) redirect("/login");

  const allowed = ["owner", "administrator", "operations_manager", "sales_manager", "sales_rep"];
  if (!allowed.includes(ctx.role ?? "")) redirect("/dashboard");

  const s = await createClient();
  const { data: request } = await (s as any)
    .from("material_requests")
    .select("*")
    .eq("workspace_id", ctx.workspaceId)
    .eq("id", id)
    .maybeSingle();
  if (!request) notFound();

  const [
    { data: requestItems },
    { data: catalog },
    { data: suppliers },
    { data: supplierTerms },
    { data: runs },
  ] = await Promise.all([
    (s as any)
      .from("material_request_items")
      .select("*")
      .eq("workspace_id", ctx.workspaceId)
      .eq("request_id", id)
      .order("sort_order"),
    (s as any)
      .from("material_catalog_items")
      .select("*")
      .eq("workspace_id", ctx.workspaceId)
      .eq("active", true)
      .order("category")
      .order("description"),
    (s as any)
      .from("material_suppliers")
      .select("*")
      .eq("workspace_id", ctx.workspaceId)
      .eq("active", true)
      .order("name"),
    (s as any)
      .from("material_request_supplier_terms")
      .select("*")
      .eq("workspace_id", ctx.workspaceId)
      .eq("request_id", id),
    (s as any)
      .from("material_price_runs")
      .select("*")
      .eq("workspace_id", ctx.workspaceId)
      .eq("request_id", id)
      .order("started_at", { ascending: false })
      .limit(10),
  ]);

  const latestRun = runs?.[0] ?? null;
  const [{ data: results }, { data: plans }] = latestRun
    ? await Promise.all([
        (s as any)
          .from("material_price_run_results")
          .select("*")
          .eq("workspace_id", ctx.workspaceId)
          .eq("run_id", latestRun.id)
          .order("request_item_id")
          .order("rank"),
        (s as any)
          .from("material_price_plans")
          .select("*")
          .eq("workspace_id", ctx.workspaceId)
          .eq("run_id", latestRun.id)
          .order("total"),
      ])
    : [{ data: [] }, { data: [] }];

  const catalogById = new Map((catalog ?? []).map((x: any) => [x.id, x]));
  const requestItemById = new Map((requestItems ?? []).map((x: any) => [x.id, x]));
  const supplierById = new Map((suppliers ?? []).map((x: any) => [x.id, x]));
  const termsBySupplier = new Map((supplierTerms ?? []).map((x: any) => [x.supplier_id, x]));
  const bestPlan = plans?.[0] ?? null;
  const selectedPlan = plans?.find((p: any) => p.is_selected) ?? null;
  const covered = new Set((results ?? []).map((r: any) => r.request_item_id)).size;
  const staleCount = (results ?? []).filter((r: any) => r.stale).length;

  return (
    <>
      <header className="page-intro">
        <div>
          <span className="eyebrow">MATERIAL PRICE INTELLIGENCE</span>
          <h1>{request.name}</h1>
          <p className="muted">
            {request.region} · {request.waste_pct}% waste · {request.delivery_mode}
            {request.estimate_id ? " · linked to estimate" : ""}
          </p>
        </div>
        <div className="quote-actions">
          <Link className="button" href="/materials">Back</Link>
          {request.estimate_id ? <Link className="button" href={`/estimates/${request.estimate_id}` as Route}>Estimate</Link> : null}
          <form action={runMaterialPriceScan}>
            <input type="hidden" name="request_id" value={id} />
            <button className="primary" type="submit" disabled={!(requestItems ?? []).length}>Refresh supplier prices</button>
          </form>
        </div>
      </header>

      <section className="metrics">
        <div className="metric"><span>Takeoff items</span><strong>{requestItems?.length ?? 0}</strong><small>{covered} covered in latest scan</small></div>
        <div className="metric"><span>Best plan</span><strong>{money(bestPlan?.total)}</strong><small>{bestPlan?.plan_type?.replaceAll("_", " ") ?? "run pricing"}</small></div>
        <div className="metric"><span>Selected plan</span><strong>{money(selectedPlan?.total)}</strong><small>{selectedPlan ? "approved for buying" : "not selected"}</small></div>
        <div className="metric"><span>Price health</span><strong>{staleCount}</strong><small>stale supplier quotes in latest comparison</small></div>
      </section>

      <section className="panel" style={{ marginTop: 14 }}>
        <div className="panel-head">
          <div><span className="eyebrow">REQUEST SETTINGS</span><h3>Waste and fulfilment</h3></div>
          <span className="muted">Changes recalculate using current supplier evidence.</span>
        </div>
        <form action={updateMaterialRequestSettings} className="form-grid" style={{ marginTop: 16 }}>
          <input type="hidden" name="request_id" value={id} />
          <label className="field"><span>Waste %</span><input name="waste_pct" type="number" min="0" max="50" step="0.5" defaultValue={request.waste_pct} required /></label>
          <label className="field"><span>Fulfilment</span><select name="delivery_mode" defaultValue={request.delivery_mode}><option value="pickup">Pickup</option><option value="delivery">Delivery</option></select></label>
          <label className="field field-span-2"><span>Notes</span><input name="notes" maxLength={500} defaultValue={request.notes ?? ""} /></label>
          <div className="form-actions"><button type="submit">Save & recalculate</button></div>
        </form>
        {request.status === "approved" ? <p className="muted" style={{ marginTop: 10 }}>Approved requests are locked. Change a takeoff line or supplier terms first to invalidate the approval.</p> : null}
      </section>

      <section className="panel" style={{ marginTop: 14 }}>
        <div className="panel-head">
          <div><span className="eyebrow">TAKEOFF</span><h3>Add material</h3></div>
          <span className="muted">Quantities are increased by {request.waste_pct}% when plans are calculated.</span>
        </div>
        <form action={addMaterialRequestItem} className="form-grid" style={{ marginTop: 16 }}>
          <input type="hidden" name="request_id" value={id} />
          <label className="field field-span-2">
            <span>Material</span>
            <select name="material_item_id" required defaultValue="">
              <option value="" disabled>Select lumber</option>
              {(catalog ?? []).map((item: any) => <option key={item.id} value={item.id}>{item.description}</option>)}
            </select>
          </label>
          <label className="field"><span>Quantity</span><input name="quantity" type="number" min="0.001" step="1" required /></label>
          <label className="field"><span>Line note</span><input name="notes" maxLength={300} placeholder="joists @ 16 in. O.C." /></label>
          <div className="form-actions"><button type="submit" className="primary">Add line</button></div>
        </form>
      </section>

      <section className="table-panel" style={{ marginTop: 14 }}>
        <div className="panel-head" style={{ marginBottom: 14 }}>
          <div><span className="eyebrow">BILL OF MATERIALS</span><h3>Current takeoff</h3></div>
        </div>
        <div className="table-wrap">
          <table>
            <thead><tr><th>Material</th><th>Qty</th><th>With waste</th><th>Notes</th><th></th></tr></thead>
            <tbody>
              {(requestItems ?? []).length ? (requestItems ?? []).map((line: any) => {
                const item: any = catalogById.get(line.material_item_id);
                const withWaste = Math.ceil(Number(line.quantity) * (1 + Number(request.waste_pct || 0) / 100));
                return (
                  <tr key={line.id}>
                    <td><strong>{item?.description ?? line.material_item_id}</strong><div className="muted">{item?.category ?? "material"}</div></td>
                    <td>{line.quantity}</td>
                    <td>{withWaste}</td>
                    <td style={{ whiteSpace: "normal" }}>{line.notes ?? "—"}</td>
                    <td>
                      <form action={removeMaterialRequestItem}>
                        <input type="hidden" name="request_id" value={id} />
                        <input type="hidden" name="request_item_id" value={line.id} />
                        <button type="submit">Remove</button>
                      </form>
                    </td>
                  </tr>
                );
              }) : <tr><td colSpan={5} className="muted">Add the takeoff above, then refresh supplier prices.</td></tr>}
            </tbody>
          </table>
        </div>
      </section>

      <section className="table-panel" style={{ marginTop: 14 }}>
        <div className="panel-head" style={{ marginBottom: 14 }}>
          <div><span className="eyebrow">QUOTE OVERRIDES</span><h3>Contractor desk / local supplier quotes</h3></div>
          <span className="muted">Use this for Ottawa store quotes or suppliers without reliable public web pricing.</span>
        </div>
        {(requestItems ?? []).length ? (
          <div className="checks">
            {(requestItems ?? []).map((line: any) => {
              const item: any = catalogById.get(line.material_item_id);
              return (
                <details key={line.id}>
                  <summary><strong>{item?.description ?? "Material"}</strong> · record supplier quote</summary>
                  <form action={recordManualMaterialQuote} className="form-grid" style={{ marginTop: 12 }}>
                    <input type="hidden" name="request_id" value={id} />
                    <input type="hidden" name="request_item_id" value={line.id} />
                    <label className="field"><span>Supplier</span><select name="supplier_id" required>{(suppliers ?? []).map((x: any) => <option key={x.id} value={x.id}>{x.name}</option>)}</select></label>
                    <label className="field"><span>Price each</span><input name="price_each" type="number" min="0.01" step="0.01" required /></label>
                    <label className="field"><span>Store / desk</span><input name="store_label" placeholder="Ottawa contractor desk" /></label>
                    <label className="field"><span>Stock</span><select name="stock_status" defaultValue="quoted"><option value="quoted">Quoted</option><option value="in_stock">In stock</option><option value="limited">Limited</option><option value="order">Special order</option></select></label>
                    <label className="field"><span>Quote valid until</span><input name="valid_until" type="date" /></label>
                    <label className="field"><span>Evidence URL</span><input name="evidence_url" type="url" placeholder="https://…" /></label>
                    <label className="field field-span-2"><span>Quote note</span><input name="quote_note" maxLength={500} placeholder="Quote number, rep name, pickup terms…" /></label>
                    <div className="form-actions"><button type="submit">Save quote & recalculate</button></div>
                  </form>
                </details>
              );
            })}
          </div>
        ) : <p className="muted">Add material lines first.</p>}
      </section>

      <section className="table-panel" style={{ marginTop: 14 }}>
        <div className="panel-head" style={{ marginBottom: 14 }}>
          <div><span className="eyebrow">SUPPLIER TERMS</span><h3>Delivery quotes and validity</h3></div>
          <span className="muted">Delivery plans cannot be approved until every used supplier has a current verified fee.</span>
        </div>
        <div className="checks">
          {(suppliers ?? []).map((supplier: any) => {
            const terms: any = termsBySupplier.get(supplier.id);
            const expired = terms?.valid_until && String(terms.valid_until) < new Intl.DateTimeFormat("sv-SE", { timeZone: "America/Toronto" }).format(new Date());
            return (
              <details key={supplier.id}>
                <summary>
                  <strong>{supplier.name}</strong>
                  {" · "}
                  {terms?.delivery_verified && !expired ? "delivery verified" : "delivery not verified"}
                  {terms?.valid_until ? ` · valid to ${terms.valid_until}` : ""}
                </summary>
                <form action={saveMaterialSupplierTerms} className="form-grid" style={{ marginTop: 12 }}>
                  <input type="hidden" name="request_id" value={id} />
                  <input type="hidden" name="supplier_id" value={supplier.id} />
                  <label className="field"><span>Delivery fee</span><input name="delivery_fee" type="number" min="0" step="0.01" defaultValue={terms?.delivery_fee ?? ""} placeholder="0.00" /></label>
                  <label className="field"><span>Valid until</span><input name="valid_until" type="date" defaultValue={terms?.valid_until ?? ""} /></label>
                  <label className="field"><span>Quote reference</span><input name="quote_reference" maxLength={120} defaultValue={terms?.quote_reference ?? ""} placeholder="Quote # / rep" /></label>
                  <label className="field"><span>Evidence URL</span><input name="evidence_url" type="url" defaultValue={terms?.evidence_url ?? ""} placeholder="https://…" /></label>
                  <label className="field field-span-2"><span>Notes</span><input name="notes" maxLength={500} defaultValue={terms?.notes ?? ""} placeholder="Minimum order, lead time, delivery window…" /></label>
                  <label className="field"><span><input name="delivery_verified" type="checkbox" defaultChecked={Boolean(terms?.delivery_verified && !expired)} /> Delivery fee verified</span></label>
                  <div className="form-actions"><button type="submit">Save terms & recalculate</button></div>
                </form>
              </details>
            );
          })}
        </div>
      </section>

      <section className="table-panel" style={{ marginTop: 14 }}>
        <div className="panel-head" style={{ marginBottom: 14 }}>
          <div><span className="eyebrow">PRICE COMPARISON</span><h3>Supplier-by-supplier results</h3></div>
          <span className="muted">{latestRun ? `Scan ${new Date(latestRun.started_at).toLocaleString("en-CA")} · ${latestRun.status}` : "No scan yet"}</span>
        </div>
        <div className="table-wrap">
          <table>
            <thead><tr><th>Material</th><th>Supplier</th><th>Unit</th><th>Effective</th><th>Qty + waste</th><th>Extended</th><th>Rank</th><th>Evidence</th></tr></thead>
            <tbody>
              {(results ?? []).length ? (results ?? []).map((r: any) => {
                const requestItem: any = requestItemById.get(r.request_item_id);
                const item: any = requestItem ? catalogById.get(requestItem.material_item_id) : null;
                const supplier: any = supplierById.get(r.supplier_id);
                return (
                  <tr key={r.id}>
                    <td style={{ whiteSpace: "normal", minWidth: 260 }}>{item?.description ?? "Material"}</td>
                    <td><strong>{supplier?.name ?? "Supplier"}</strong><div className="muted">{r.stock_status ?? "stock verify"}</div></td>
                    <td>{money(r.unit_price)}</td>
                    <td>{money(r.effective_unit_price)}</td>
                    <td>{r.quantity_with_waste}</td>
                    <td><strong>{money(r.extended_price)}</strong></td>
                    <td>#{r.rank}</td>
                    <td>
                      {r.evidence_url ? <a href={r.evidence_url} target="_blank" rel="noreferrer">Source</a> : "Manual"}
                      <div className="muted">{r.stale ? "STALE · " : ""}{r.confidence} · {age(r.observed_at)}</div>
                    </td>
                  </tr>
                );
              }) : <tr><td colSpan={8} className="muted">No supplier comparison yet. Refresh supplier prices or record a manual quote.</td></tr>}
            </tbody>
          </table>
        </div>
      </section>

      <section className="table-panel" style={{ marginTop: 14 }}>
        <div className="panel-head" style={{ marginBottom: 14 }}>
          <div><span className="eyebrow">BUY PLAN</span><h3>Cheapest purchasing options</h3></div>
          <span className="muted">Delivery is charged once per supplier used.</span>
        </div>
        <div className="table-wrap">
          <table>
            <thead><tr><th>Plan</th><th>Supplier(s)</th><th>Materials</th><th>Delivery</th><th>Total</th><th>Savings</th><th></th></tr></thead>
            <tbody>
              {(plans ?? []).length ? (plans ?? []).map((p: any, index: number) => {
                const supplierNames = Array.isArray(p.suppliers)
                  ? p.suppliers.map((x: any) => x.name).filter(Boolean).join(", ")
                  : p.supplier_id
                    ? String((supplierById.get(p.supplier_id) as any)?.name ?? "Supplier")
                    : "Split suppliers";
                const deliveryUnverified =
                  request.delivery_mode === "delivery"
                  && Array.isArray(p.suppliers)
                  && p.suppliers.some((x: any) => x.delivery_verified === false);
                return (
                  <tr key={p.id}>
                    <td><strong>{index === 0 ? "Lowest total" : p.plan_type.replaceAll("_", " ")}</strong>{p.is_selected ? <div className="badge">Selected</div> : null}</td>
                    <td style={{ whiteSpace: "normal" }}>{supplierNames}</td>
                    <td>{money(p.material_subtotal)}</td>
                    <td>{deliveryUnverified ? <span className="muted">Verify quote</span> : money(p.delivery_total)}</td>
                    <td>
                      <strong>{money(p.total)}</strong>
                      {deliveryUnverified ? <div className="muted">materials + known delivery only</div> : null}
                    </td>
                    <td>{money(p.savings_vs_baseline)}</td>
                    <td>
                      {p.is_selected ? "Approved" : (
                        <form action={selectMaterialPricePlan}>
                          <input type="hidden" name="request_id" value={id} />
                          <input type="hidden" name="plan_id" value={p.id} />
                          <button type="submit" className={index === 0 ? "primary" : "button"}>Select plan</button>
                        </form>
                      )}
                    </td>
                  </tr>
                );
              }) : <tr><td colSpan={7} className="muted">A complete buy plan appears once every takeoff line has at least one usable supplier price.</td></tr>}
            </tbody>
          </table>
        </div>
      </section>

      <section className="panel" style={{ marginTop: 14 }}>
        <div className="panel-head"><div><span className="eyebrow">RUN HISTORY</span><h3>Pricing evidence trail</h3></div></div>
        <div className="checks">
          {(runs ?? []).length ? (runs ?? []).map((run: any) => (
            <div key={run.id}>
              <strong>{new Date(run.started_at).toLocaleString("en-CA")} · {run.status}</strong>
              <div className="muted">
                {run.products_checked} products checked · {run.fresh_quotes} fresh · {run.reused_quotes} reused · {(Array.isArray(run.errors) ? run.errors.length : 0)} errors
              </div>
            </div>
          )) : <p className="muted">No pricing runs yet.</p>}
        </div>
      </section>
    </>
  );
}

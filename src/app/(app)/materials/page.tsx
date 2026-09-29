import Link from "next/link";
import type { Route } from "next";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getWorkspaceContext } from "@/lib/workspace";
import { createMaterialRequest } from "./actions";

const money = (value: number | string | null) =>
  value == null
    ? "—"
    : Number(value).toLocaleString("en-CA", { style: "currency", currency: "CAD" });

export default async function MaterialsPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const ctx = await getWorkspaceContext();
  if (!ctx) redirect("/login");

  const allowed = ["owner", "administrator", "operations_manager", "sales_manager", "sales_rep"];
  if (!allowed.includes(ctx.role ?? "")) redirect("/dashboard");

  const params = await searchParams;
  const defaultEstimateId = typeof params.estimate_id === "string" ? params.estimate_id : "";
  const s = await createClient();
  const [{ data: requests, error }, { data: estimates }, { data: sourceProducts }] = await Promise.all([
    (s as any)
      .from("v_material_request_summary")
      .select("*")
      .eq("workspace_id", ctx.workspaceId)
      .order("created_at", { ascending: false })
      .limit(200),
    (s as any)
      .from("estimates")
      .select("id,estimate_number,status,estimate_kind")
      .eq("workspace_id", ctx.workspaceId)
      .in("status", ["draft", "sent", "accepted"])
      .order("created_at", { ascending: false })
      .limit(250),
    (s as any)
      .from("material_supplier_products")
      .select("id,pricing_mode,product_url,last_checked_at,last_error")
      .eq("workspace_id", ctx.workspaceId)
      .eq("active", true),
  ]);

  const rows = requests ?? [];
  const priced = rows.filter((r: any) => r.latest_run_status === "completed" || r.latest_run_status === "partial").length;
  const approved = rows.filter((r: any) => r.status === "approved").length;
  const bestCurrent = rows
    .filter((r: any) => r.best_total != null)
    .reduce((sum: number, r: any) => sum + Number(r.best_total || 0), 0);
  const sourceRows = sourceProducts ?? [];
  const liveSources = sourceRows.filter((p: any) => p.pricing_mode === "live_page").length;
  const sourceErrors = sourceRows.filter((p: any) => Boolean(p.last_error)).length;
  const checkedSources = sourceRows.filter((p: any) => Boolean(p.last_checked_at)).length;

  return (
    <>
      <header className="page-intro">
        <div>
          <span className="eyebrow">ESTIMATING / SOURCING</span>
          <h1>Material Price Intelligence</h1>
          <p className="muted">
            Compare Ottawa supplier pricing, preserve quote evidence, account for waste and delivery,
            and choose the lowest-cost purchasing plan before locking estimate materials.
          </p>
        </div>
      </header>

      <section className="metrics">
        <div className="metric"><span>Requests</span><strong>{rows.length}</strong><small>material takeoffs</small></div>
        <div className="metric"><span>Priced</span><strong>{priced}</strong><small>with supplier coverage</small></div>
        <div className="metric"><span>Approved</span><strong>{approved}</strong><small>buy plans selected</small></div>
        <div className="metric"><span>Current best totals</span><strong>{money(bestCurrent)}</strong><small>across priced requests</small></div>
      </section>

      <section className="panel" style={{ marginTop: 14 }}>
        <div className="panel-head">
          <div><span className="eyebrow">SOURCE HEALTH</span><h3>Retailer price coverage</h3></div>
          <span className="muted">{sourceRows.length} configured mappings</span>
        </div>
        <div className="deck-audit-grid" style={{ marginTop: 14 }}>
          <div><span>Live product pages</span><strong>{liveSources}</strong></div>
          <div><span>Checked at least once</span><strong>{checkedSources}</strong></div>
          <div><span>Current source errors</span><strong>{sourceErrors}</strong></div>
          <div><span>Manual-only mappings</span><strong>{sourceRows.length - liveSources}</strong></div>
        </div>
        <p className="muted" style={{ marginTop: 12 }}>
          Live pages provide market pricing evidence. Ottawa store availability and contractor-desk quotes can override them in each request.
        </p>
      </section>

      <section className="panel" style={{ marginTop: 14 }}>
        <div className="panel-head">
          <div>
            <span className="eyebrow">NEW TAKEOFF</span>
            <h3>Create a material pricing request</h3>
          </div>
        </div>
        <form action={createMaterialRequest} className="form-grid" style={{ marginTop: 16 }}>
          <label className="field field-span-2">
            <span>Request name</span>
            <input name="name" required maxLength={180} placeholder="12 × 16 pressure-treated deck" />
          </label>
          <label className="field">
            <span>Estimate</span>
            <select name="estimate_id" defaultValue={defaultEstimateId}>
              <option value="">Not linked yet</option>
              {(estimates ?? []).map((e: any) => (
                <option key={e.id} value={e.id}>
                  {e.estimate_number} · {e.estimate_kind ?? "general"} · {e.status}
                </option>
              ))}
            </select>
          </label>
          <label className="field">
            <span>Region</span>
            <input name="region" defaultValue="Ottawa, ON" required />
          </label>
          <label className="field">
            <span>Waste %</span>
            <input name="waste_pct" type="number" min="0" max="50" step="0.5" defaultValue="5" required />
          </label>
          <label className="field">
            <span>Fulfilment</span>
            <select name="delivery_mode" defaultValue="pickup">
              <option value="pickup">Pickup</option>
              <option value="delivery">Delivery</option>
            </select>
          </label>
          <label className="field field-span-2">
            <span>Notes</span>
            <input name="notes" maxLength={500} placeholder="Deck dimensions, preferred board lengths, site constraints…" />
          </label>
          <div className="form-actions"><button type="submit" className="primary">Create request</button></div>
        </form>
      </section>

      <section className="table-panel" style={{ marginTop: 14 }}>
        <div className="panel-head" style={{ marginBottom: 14 }}>
          <div><span className="eyebrow">REQUESTS</span><h3>Material sourcing queue</h3></div>
        </div>
        {error ? (
          <p className="error">Material pricing tables are not available yet. Apply the material price intelligence migration. ({error.message})</p>
        ) : (
          <div className="table-wrap">
            <table>
              <thead><tr><th>Request</th><th>Estimate</th><th>Status</th><th>Items</th><th>Latest scan</th><th>Best total</th><th></th></tr></thead>
              <tbody>
                {rows.length ? rows.map((r: any) => (
                  <tr key={r.id}>
                    <td><strong>{r.name}</strong><div className="muted">{r.region} · {r.waste_pct}% waste · {r.delivery_mode}</div></td>
                    <td>{r.estimate_id ? <Link href={`/estimates/${r.estimate_id}` as Route}>Open estimate</Link> : "—"}</td>
                    <td><span className="pill">{r.status}</span></td>
                    <td>{r.item_count ?? 0}</td>
                    <td>{r.latest_run_at ? <>{new Date(r.latest_run_at).toLocaleString("en-CA")}<div className="muted">{r.latest_run_status}</div></> : "Never"}</td>
                    <td><strong>{money(r.best_total)}</strong></td>
                    <td><Link className="button" href={`/materials/${r.id}` as Route}>Open</Link></td>
                  </tr>
                )) : (
                  <tr><td colSpan={7} className="muted">No material requests yet. Create one above and add the deck takeoff.</td></tr>
                )}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </>
  );
}

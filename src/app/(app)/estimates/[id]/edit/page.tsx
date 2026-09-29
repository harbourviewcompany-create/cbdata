import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getWorkspaceContext } from "@/lib/workspace";
import { updateDeckEstimate } from "../../actions";
import { GUARD_LINE } from "../../deck-pricing";
import { parseLegacyDeckSpec } from "../../deck-takeoff";

export default async function EditDeckEstimate({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const ctx = await getWorkspaceContext();
  if (!ctx) redirect("/login");
  if (!["owner", "administrator", "sales_manager", "sales_rep"].includes(ctx.role ?? "")) {
    redirect("/estimates");
  }

  const s = await createClient();
  const { data: estimate } = await s
    .from("estimates")
    .select("id,estimate_number,status,valid_until,organization_id,property_id")
    .eq("id", id)
    .eq("workspace_id", ctx.workspaceId)
    .maybeSingle();
  if (!estimate || estimate.status !== "draft" || !estimate.estimate_number.startsWith("DECK-")) {
    notFound();
  }

  const [{ data: items }, { data: properties }, { data: spec }] = await Promise.all([
    s.from("estimate_items")
      .select("id,description,unit_price,estimated_material_cost,estimated_labor_cost")
      .eq("estimate_id", id)
      .eq("workspace_id", ctx.workspaceId)
      .order("sort_order"),
    s.from("properties")
      .select("id,name,address_line_1,primary_customer_organization_id")
      .eq("workspace_id", ctx.workspaceId)
      .order("name")
      .limit(500),
    (s as any)
      .from("deck_estimate_specs")
      .select("*")
      .eq("workspace_id", ctx.workspaceId)
      .eq("estimate_id", id)
      .maybeSingle(),
  ]);
  if (!items?.length) notFound();

  const customerProperties = (properties ?? []).filter(
    (p) => !p.primary_customer_organization_id || p.primary_customer_organization_id === estimate.organization_id,
  );
  const hasGuards = items.some((item) => item.description.startsWith(GUARD_LINE.label));
  const legacySpec = parseLegacyDeckSpec(items[0]?.description ?? "");
  const deckSpec = spec ?? legacySpec ?? {
    width_ft: 12,
    depth_ft: 12,
    stair_width_ft: 4,
    steps: 4,
    footings: 4,
    height_in: null,
    include_guards: hasGuards,
    site_reference: "",
    landing: "",
    site_notes: "",
    joist_spacing_in: 16,
  };

  return (
    <>
      <header className="page-intro">
        <div>
          <span className="eyebrow">REVISE DRAFT</span>
          <h1>{estimate.estimate_number}</h1>
          <p className="muted">Revise scope, direct costs, property linkage and expiry before site verification.</p>
        </div>
        <Link className="button" href={`/estimates/${id}`}>Cancel</Link>
      </header>

      <form action={updateDeckEstimate} className="panel">
        <input type="hidden" name="id" value={id} />
        <input type="hidden" name="count" value={items.length} />

        <div className="deck-form-grid" style={{ marginBottom: 18 }}>
          <label>
            Property
            <select name="property_id" defaultValue={estimate.property_id ?? ""}>
              <option value="">Link later</option>
              {customerProperties.map((p) => (
                <option key={p.id} value={p.id}>{p.name} · {p.address_line_1}</option>
              ))}
            </select>
          </label>
          <label>
            Valid until
            <input name="valid_until" type="date" required defaultValue={estimate.valid_until ?? ""} />
          </label>
        </div>

        <section className="panel" style={{ marginBottom: 18 }}>
          <div className="panel-head">
            <div><span className="eyebrow">STRUCTURED SCOPE</span><h3>Deck measurements for material takeoff</h3></div>
            <span className="muted">These values drive the generated lumber BOM.</span>
          </div>
          <div className="deck-form-grid" style={{ marginTop: 14 }}>
            <label>Deck width (ft)<input name="width_ft" type="number" min="4" max="80" step="0.5" required defaultValue={deckSpec.width_ft} /></label>
            <label>Deck depth (ft)<input name="depth_ft" type="number" min="4" max="80" step="0.5" required defaultValue={deckSpec.depth_ft} /></label>
            <label>Joist spacing (in O.C.)<input name="joist_spacing_in" type="number" min="8" max="24" step="1" required defaultValue={deckSpec.joist_spacing_in ?? 16} /></label>
            <label>Stair width (ft)<input name="stair_width_ft" type="number" min="2" max="16" step="0.5" required defaultValue={deckSpec.stair_width_ft} /></label>
            <label>Estimated steps<input name="steps" type="number" min="0" max="30" step="1" required defaultValue={deckSpec.steps} /></label>
            <label>Estimated footings<input name="footings" type="number" min="1" max="40" step="1" required defaultValue={deckSpec.footings} /></label>
            <label>Deck height (in)<input name="height_in" type="number" min="0" max="180" step="0.5" defaultValue={deckSpec.height_in ?? ""} /></label>
            <label>Landing<input name="landing" maxLength={80} defaultValue={deckSpec.landing ?? ""} /></label>
            <label className="deck-wide">Site reference<input name="site_reference" maxLength={180} defaultValue={deckSpec.site_reference ?? ""} /></label>
            <label className="deck-wide">Site notes<textarea name="site_notes" maxLength={600} defaultValue={deckSpec.site_notes ?? ""} /></label>
          </div>
          {hasGuards ? <input type="hidden" name="include_guards" value="on" /> : null}
        </section>

        <div className="table-wrap">
          <table>
            <thead><tr><th>Scope and assumptions</th><th>Price</th><th>Materials</th><th>Labour</th></tr></thead>
            <tbody>
              {items.map((item, i) => (
                <tr key={item.id}>
                  <td>
                    <textarea
                      className="deck-description"
                      name={`item_${i}_description`}
                      maxLength={1000}
                      required
                      defaultValue={item.description}
                      aria-label={`Item ${i + 1} scope`}
                    />
                  </td>
                  {(["price", "material", "labor"] as const).map((field) => (
                    <td key={field}>
                      <input
                        className="deck-money-input"
                        type="number"
                        min="0"
                        max="9999999"
                        step="0.01"
                        required
                        name={`item_${i}_${field}`}
                        aria-label={`Item ${i + 1} ${field}`}
                        defaultValue={
                          field === "price"
                            ? item.unit_price
                            : field === "material"
                              ? item.estimated_material_cost
                              : item.estimated_labor_cost
                        }
                      />
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {!hasGuards ? (
          <div className="deck-add-guards">
            <label><input type="checkbox" name="add_guards" /> Add pressure-treated deck guards after site measurement</label>
            <div className="deck-form-grid">
              <label>Guard price<input type="number" name="guards_price" min="0" step="0.01" defaultValue={GUARD_LINE.price} /></label>
              <label>Guard materials<input type="number" name="guards_material" min="0" step="0.01" defaultValue={GUARD_LINE.material} /></label>
              <label>Guard labour<input type="number" name="guards_labor" min="0" step="0.01" defaultValue={GUARD_LINE.labor} /></label>
            </div>
          </div>
        ) : null}

        <p className="muted">Saving a revision clears prior site verification so the revised scope must be re-verified before sending.</p>
        <button className="primary" type="submit">Save revised draft</button>
      </form>
    </>
  );
}

import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { getWorkspaceContext } from "@/lib/workspace";
import { createProperty } from "./actions";

const PROPERTY_TYPES = [
  "residential",
  "multi_family",
  "condo",
  "commercial",
  "industrial",
  "mixed_use",
  "other",
];

export default async function PropertiesPage() {
  const ctx = await getWorkspaceContext();
  const s = await createClient();

  if (!ctx) {
    return (
      <div className="empty-card">
        <h2 style={{ marginTop: 0 }}>No workspace access</h2>
        <p className="muted">Contact an administrator to join a workspace.</p>
      </div>
    );
  }

  const { data, error } = await s
    .from("property_360")
    .select(
      "id,name,city,province,status,customer_name,active_contracts,open_work_orders,open_issues",
    )
    .eq("workspace_id", ctx.workspaceId)
    .order("name")
    .limit(200);

  const rows = data ?? [];
  const isEmpty = rows.length === 0;

  return (
    <>
      <div className="page-intro">
        <div>
          <span className="eyebrow">PROPERTY CONTROL</span>
          <h2 className="page-title">Properties</h2>
          <p className="muted">
            Sites you service. Add a property to unlock work orders, issues, and
            contracts for that location.
          </p>
        </div>
      </div>

      <section className="panel" id="add-property">
        <div className="panel-head">
          <div>
            <span className="eyebrow">{isEmpty ? "START HERE" : "ADD"}</span>
            <h3>{isEmpty ? "Add your first property" : "Add property"}</h3>
          </div>
        </div>
        <form action={createProperty} className="form-grid property-form">
          <label className="field">
            <span>Property name *</span>
            <input name="name" required placeholder="e.g. Oakridge Tower" />
          </label>
          <label className="field">
            <span>Type *</span>
            <select name="property_type" required defaultValue="multi_family">
              {PROPERTY_TYPES.map((t) => (
                <option key={t} value={t}>
                  {t.replace(/_/g, " ")}
                </option>
              ))}
            </select>
          </label>
          <label className="field field-span-2">
            <span>Street address *</span>
            <input
              name="address_line_1"
              required
              placeholder="123 Main Street"
            />
          </label>
          <label className="field">
            <span>Unit / line 2</span>
            <input name="address_line_2" placeholder="Suite 200" />
          </label>
          <label className="field">
            <span>City *</span>
            <input name="city" required placeholder="Vancouver" />
          </label>
          <label className="field">
            <span>Province / state</span>
            <input name="province" placeholder="BC" />
          </label>
          <label className="field">
            <span>Postal code</span>
            <input name="postal_code" placeholder="V6B 1A1" />
          </label>
          <label className="field">
            <span>Country</span>
            <input name="country" defaultValue="Canada" />
          </label>
          <label className="field">
            <span>Status</span>
            <select name="status" defaultValue="prospect">
              <option value="prospect">Prospect</option>
              <option value="active">Active</option>
              <option value="inactive">Inactive</option>
            </select>
          </label>
          <label className="field">
            <span>Customer / bill-to (optional)</span>
            <input
              name="customer_name"
              placeholder="Creates a customer organization"
            />
          </label>
          <label className="field">
            <span>Property manager (optional)</span>
            <input
              name="manager_name"
              placeholder="Creates a property manager organization"
            />
          </label>
          <label className="field field-span-2">
            <span>Site notes</span>
            <input name="site_notes" placeholder="Gate code, parking, hazards…" />
          </label>
          <label className="field field-span-2">
            <span>Access notes</span>
            <input name="access_notes" placeholder="Who to call on arrival" />
          </label>
          <div className="field field-span-2 form-actions">
            <button type="submit" className="primary">
              {isEmpty ? "Create first property" : "Create property"}
            </button>
          </div>
        </form>
      </section>

      <section className="table-panel" style={{ marginTop: 14 }}>
        <div className="panel-head" style={{ padding: "16px 18px 0" }}>
          <div>
            <span className="eyebrow">PORTFOLIO</span>
            <h3 style={{ margin: "6px 0 12px" }}>
              {rows.length} propert{rows.length === 1 ? "y" : "ies"}
            </h3>
          </div>
        </div>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Property</th>
                <th>Customer</th>
                <th>Location</th>
                <th>Status</th>
                <th>Contracts</th>
                <th>Work</th>
                <th>Issues</th>
              </tr>
            </thead>
            <tbody>
              {isEmpty ? (
                <tr>
                  <td colSpan={7} className="muted">
                    No properties yet. Use the form above — after you save, you
                    can open the property and create work orders.
                  </td>
                </tr>
              ) : (
                rows.map((r) => (
                  <tr key={r.id}>
                    <td>
                      <Link href={`/properties/${r.id}`}>{r.name}</Link>
                    </td>
                    <td>{r.customer_name ?? "—"}</td>
                    <td>
                      {r.city}
                      {r.province ? `, ${r.province}` : ""}
                    </td>
                    <td>
                      <span className="pill">{r.status}</span>
                    </td>
                    <td>{r.active_contracts}</td>
                    <td>{r.open_work_orders}</td>
                    <td>{r.open_issues}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
        {error ? <p className="error">{error.message}</p> : null}
      </section>
    </>
  );
}

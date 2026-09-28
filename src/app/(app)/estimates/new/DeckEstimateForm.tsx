"use client";

import { useState } from "react";
import { createDeckEstimate } from "../actions";
import { DECK_LINES, GUARD_LINE, HST_RATE } from "../deck-pricing";

type Customer = { id: string; name: string };
type Property = { id: string; name: string; customerId: string | null };

const money = (value: number) => value.toLocaleString("en-CA", { style: "currency", currency: "CAD" });

export function DeckEstimateForm({ customers, properties, defaultExpiry }: { customers: Customer[]; properties: Property[]; defaultExpiry: string }) {
  const [customerId, setCustomerId] = useState("");
  const [includeGuards, setIncludeGuards] = useState(false);
  const [prices, setPrices] = useState<Record<string, string>>(
    Object.fromEntries([...DECK_LINES, GUARD_LINE].map((line) => [line.key, String(line.price)])),
  );
  const subtotal = [...DECK_LINES, ...(includeGuards ? [GUARD_LINE] : [])]
    .reduce((sum, line) => sum + (Number(prices[line.key]) || 0), 0);
  const tax = Math.round(subtotal * HST_RATE * 100) / 100;

  return (
    <form action={createDeckEstimate} className="deck-estimate-form">
      <section className="panel">
        <h2>1. Customer and site</h2>
        <p className="muted">Start a draft. Confirm the actual deck height, footings and guard requirements on site before sending.</p>
        <div className="deck-form-grid">
          <label>Customer <select name="organization_id" required value={customerId} onChange={(e) => setCustomerId(e.target.value)}>
            <option value="">Select customer</option>{customers.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select></label>
          <label>Property (optional) <select name="property_id"><option value="">No linked property</option>
            {properties.filter((p) => !p.customerId || p.customerId === customerId).map((p) =>
              <option key={p.id} value={p.id}>{p.name}</option>)}
          </select></label>
          <label>Site address / job reference <input name="site_reference" required maxLength={180} defaultValue="1220 Foxborough Private" /></label>
          <label>Quote valid until <input name="valid_until" type="date" required defaultValue={defaultExpiry} /></label>
        </div>
      </section>
      <section className="panel">
        <h2>2. Measure and define the work</h2>
        <div className="deck-form-grid">
          <label>Deck width (ft) <input name="width_ft" type="number" min="4" max="40" step="0.5" required defaultValue="12" /></label>
          <label>Deck depth (ft) <input name="depth_ft" type="number" min="4" max="40" step="0.5" required defaultValue="12" /></label>
          <label>Landing within deck <input name="landing" maxLength={80} defaultValue="4 ft × 10 ft, within deck footprint" /></label>
          <label>Stair width (ft) <input name="stair_width_ft" type="number" min="2" max="12" step="0.5" required defaultValue="4" /></label>
          <label>Estimated steps <input name="steps" type="number" min="1" max="20" required defaultValue="4" /></label>
          <label>Estimated footings <input name="footings" type="number" min="1" max="12" required defaultValue="4" /></label>
          <label>Deck height above grade (in; confirm on site) <input name="height_in" type="number" min="0" max="120" step="0.5" placeholder="Unknown" /></label>
          <label className="deck-wide">Scope and site notes (shown on customer quote) <textarea name="site_notes" maxLength={400} placeholder="Access, soil, utilities, footing design, attachment to house, demolition..." /></label>
        </div>
        <label className="deck-checkbox"><input name="include_guards" type="checkbox" checked={includeGuards} onChange={(e) => setIncludeGuards(e.target.checked)} />
          Include pressure-treated deck guards (allowance up to 30 linear feet)
        </label>
      </section>
      <section className="panel">
        <h2>3. Price the scope</h2>
        <p className="muted">Starting allowances are from the 12 × 12 ft deck example. Edit each price and direct cost for this site. HST is calculated at 13%.</p>
        <div className="table-wrap"><table><thead><tr><th>Work item</th><th>Price</th><th>Materials</th><th>Labour</th></tr></thead><tbody>
          {[...DECK_LINES, ...(includeGuards ? [GUARD_LINE] : [])].map((line) => <tr key={line.key}>
            <td>{line.label}</td>
            {(["price", "material", "labor"] as const).map((field) => <td key={field}>
              <input className="deck-money-input" aria-label={`${line.label} ${field}`} name={`${line.key}_${field}`}
                type="number" min="0" max="9999999" step="0.01" required
                value={field === "price" ? prices[line.key] : undefined}
                defaultValue={field === "price" ? undefined : line[field]}
                onChange={field === "price" ? (e) => setPrices({ ...prices, [line.key]: e.target.value }) : undefined} />
            </td>)}
          </tr>)}
        </tbody></table></div>
        <div className="deck-totals"><span>Subtotal <strong>{money(subtotal)}</strong></span>
          <span>HST (13%) <strong>{money(tax)}</strong></span>
          <span>Total <strong>{money(subtotal + tax)}</strong></span></div>
        <p className="muted">This is a preliminary quote. Permit drawings and City fees are separate; changing dimensions may require repricing.</p>
        <button className="primary" type="submit" disabled={!customers.length}>Save draft estimate</button>
      </section>
    </form>
  );
}

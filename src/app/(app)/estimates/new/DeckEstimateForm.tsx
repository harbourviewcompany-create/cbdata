"use client";

import { useMemo, useState } from "react";
import { createDeckEstimate } from "../actions";
import { DECK_LINES, GUARD_LINE, HST_RATE, TARGET_GROSS_MARGIN } from "../deck-pricing";

type Customer = { id: string; name: string };
type Property = { id: string; name: string; customerId: string | null };
type CostField = "price" | "material" | "labor";

const money = (value: number) =>
  value.toLocaleString("en-CA", { style: "currency", currency: "CAD" });

export function DeckEstimateForm({
  customers,
  properties,
  defaultExpiry,
}: {
  customers: Customer[];
  properties: Property[];
  defaultExpiry: string;
}) {
  const [customerId, setCustomerId] = useState("");
  const [includeGuards, setIncludeGuards] = useState(false);
  const [amounts, setAmounts] = useState<Record<string, string>>(() =>
    Object.fromEntries(
      [...DECK_LINES, GUARD_LINE].flatMap((line) =>
        (["price", "material", "labor"] as const).map((field) => [
          `${line.key}_${field}`,
          String(line[field]),
        ]),
      ),
    ),
  );

  const lines = useMemo(
    () => [...DECK_LINES, ...(includeGuards ? [GUARD_LINE] : [])],
    [includeGuards],
  );
  const number = (key: string) => Number(amounts[key]) || 0;
  const subtotal = lines.reduce((sum, line) => sum + number(`${line.key}_price`), 0);
  const directCost = lines.reduce(
    (sum, line) => sum + number(`${line.key}_material`) + number(`${line.key}_labor`),
    0,
  );
  const tax = Math.round(subtotal * HST_RATE * 100) / 100;
  const grossProfit = subtotal - directCost;
  const margin = subtotal > 0 ? (grossProfit / subtotal) * 100 : 0;
  const filteredProperties = properties.filter(
    (p) => !p.customerId || p.customerId === customerId,
  );

  const setAmount = (key: string, value: string) =>
    setAmounts((current) => ({ ...current, [key]: value }));

  return (
    <form action={createDeckEstimate} className="deck-estimate-form">
      <section className="panel">
        <div className="panel-head">
          <div>
            <span className="eyebrow">STEP 1</span>
            <h2>Customer and site</h2>
          </div>
          <span className="badge">Draft only</span>
        </div>
        <p className="muted">
          Build the estimate now. Site verification is recorded separately before the quote can be marked sent.
        </p>
        <div className="deck-form-grid">
          <label>
            Customer
            <select
              name="organization_id"
              required
              value={customerId}
              onChange={(e) => setCustomerId(e.target.value)}
            >
              <option value="">Select customer</option>
              {customers.map((c) => (
                <option key={c.id} value={c.id}>{c.name}</option>
              ))}
            </select>
          </label>
          <label>
            Property
            <select name="property_id" disabled={!customerId}>
              <option value="">Link later</option>
              {filteredProperties.map((p) => (
                <option key={p.id} value={p.id}>{p.name}</option>
              ))}
            </select>
          </label>
          <label>
            Site address / job reference
            <input name="site_reference" required maxLength={180} placeholder="1220 Foxborough Private" />
          </label>
          <label>
            Quote valid until
            <input name="valid_until" type="date" required defaultValue={defaultExpiry} />
          </label>
        </div>
      </section>

      <section className="panel">
        <span className="eyebrow">STEP 2</span>
        <h2>Measure and define the work</h2>
        <div className="deck-form-grid">
          <label>Deck width (ft)<input name="width_ft" type="number" min="4" max="40" step="0.5" required defaultValue="12" /></label>
          <label>Deck depth (ft)<input name="depth_ft" type="number" min="4" max="40" step="0.5" required defaultValue="12" /></label>
          <label>Landing within deck<input name="landing" maxLength={80} defaultValue="4 ft × 10 ft, within deck footprint" /></label>
          <label>Stair width (ft)<input name="stair_width_ft" type="number" min="2" max="12" step="0.5" required defaultValue="4" /></label>
          <label>Estimated steps<input name="steps" type="number" min="1" max="20" required defaultValue="4" /></label>
          <label>Estimated footings<input name="footings" type="number" min="1" max="20" required defaultValue="4" /></label>
          <label>Deck height above grade (in)<input name="height_in" type="number" min="0" max="120" step="0.5" placeholder="Confirm on site" /></label>
          <label className="deck-wide">
            Scope and site notes shown on quote
            <textarea name="site_notes" maxLength={600} placeholder="Access, soil, utilities, demolition, attachment, exclusions..." />
          </label>
        </div>
        <label className="deck-checkbox">
          <input
            name="include_guards"
            type="checkbox"
            checked={includeGuards}
            onChange={(e) => setIncludeGuards(e.target.checked)}
          />
          Include pressure-treated deck guards allowance
        </label>
      </section>

      <section className="panel">
        <div className="panel-head">
          <div>
            <span className="eyebrow">STEP 3</span>
            <h2>Price and margin</h2>
          </div>
          <span className={`badge ${margin < TARGET_GROSS_MARGIN ? "deck-margin-warning" : ""}`}>
            {margin.toFixed(1)}% gross margin
          </span>
        </div>
        <p className="muted">
          Baseline allowances are for the 12 × 12 example. Reprice for actual size, access, soil, demolition and structural requirements.
        </p>
        <div className="table-wrap">
          <table>
            <thead><tr><th>Work item</th><th>Price</th><th>Materials</th><th>Labour</th><th>GP</th></tr></thead>
            <tbody>
              {lines.map((line) => {
                const price = number(`${line.key}_price`);
                const cost = number(`${line.key}_material`) + number(`${line.key}_labor`);
                return (
                  <tr key={line.key}>
                    <td>{line.label}</td>
                    {(["price", "material", "labor"] as CostField[]).map((field) => {
                      const key = `${line.key}_${field}`;
                      return (
                        <td key={field}>
                          <input
                            className="deck-money-input"
                            aria-label={`${line.label} ${field}`}
                            name={key}
                            type="number"
                            min="0"
                            max="9999999"
                            step="0.01"
                            required
                            value={amounts[key]}
                            onChange={(e) => setAmount(key, e.target.value)}
                          />
                        </td>
                      );
                    })}
                    <td>{money(price - cost)}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>

        <div className="deck-metrics">
          <div><span>Subtotal</span><strong>{money(subtotal)}</strong></div>
          <div><span>Direct cost</span><strong>{money(directCost)}</strong></div>
          <div><span>Gross profit</span><strong>{money(grossProfit)}</strong></div>
          <div><span>Gross margin</span><strong>{margin.toFixed(1)}%</strong></div>
          <div><span>HST (13%)</span><strong>{money(tax)}</strong></div>
          <div><span>Customer total</span><strong>{money(subtotal + tax)}</strong></div>
        </div>

        {margin < TARGET_GROSS_MARGIN ? (
          <p className="deck-warning">
            Margin is below the {TARGET_GROSS_MARGIN}% working target. Review labour, materials, contingency and coordination allowance before issuing.
          </p>
        ) : null}

        <p className="muted">
          Permit drawings, engineering and municipal fees are separate unless expressly included in the line items.
        </p>
        <button className="primary" type="submit" disabled={!customers.length || subtotal <= 0}>
          Save draft estimate
        </button>
      </section>
    </form>
  );
}

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import {
  createContract,
  renewContract,
  transitionContract,
  generateWorkOrdersFromContract,
} from "./actions";

export default async function Page() {
  const s = await createClient();
  const {
    data: { user },
  } = await s.auth.getUser();
  if (!user) redirect("/login");

  const [{ data: rows }, { data: props }, { data: orgs }] = await Promise.all([
    s
      .from("contracts")
      .select(
        "id,contract_number,name,status,start_date,end_date,contract_value,property_id",
      )
      .order("end_date", { ascending: true, nullsFirst: false })
      .limit(200),
    s.from("properties").select("id,name").order("name"),
    s
      .from("organizations")
      .select("id,legal_name,operating_name")
      .order("name")
      .limit(200),
  ]);

  return (
    <>
      <header className="page-intro">
        <div>
          <span className="eyebrow">REVENUE RETENTION</span>
          <h2 className="page-title">Contracts</h2>
          <p className="muted">
            Create agreements, push status, renew, and auto-generate work from
            active schedules.
          </p>
        </div>
      </header>

      <section className="table-panel">
        <h2>Create contract</h2>
        <form action={createContract} className="form-grid">
          <input name="name" required placeholder="Contract name" />
          <select name="property_id" required>
            <option value="">Property</option>
            {props?.map((p) => (
              <option key={p.id} value={p.id}>
                {p.name}
              </option>
            ))}
          </select>
          <select name="organization_id" required>
            <option value="">Customer</option>
            {orgs?.map((o) => (
              <option key={o.id} value={o.id}>
                {o.operating_name ?? o.legal_name}
              </option>
            ))}
          </select>
          <input name="start_date" type="date" required />
          <input name="end_date" type="date" />
          <input
            name="contract_value"
            type="number"
            step="0.01"
            required
            placeholder="Value"
          />
          <input name="billing_frequency" placeholder="Billing frequency" />
          <input name="renewal_type" placeholder="Renewal type" />
          <button type="submit">Create draft</button>
        </form>
      </section>

      <section className="table-panel" style={{ marginTop: 14 }}>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Contract</th>
                <th>Status</th>
                <th>Property</th>
                <th>End</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {(rows ?? []).map((r) => (
                <tr key={r.id}>
                  <td>
                    {r.contract_number}
                    <br />
                    {r.name}
                  </td>
                  <td>{r.status}</td>
                  <td>
                    {props?.find((p) => p.id === r.property_id)?.name ?? "—"}
                  </td>
                  <td>{r.end_date ?? "—"}</td>
                  <td>
                    <div className="stack-actions">
                      <form action={transitionContract} className="actions">
                        <input type="hidden" name="id" value={r.id} />
                        <select name="status" defaultValue={r.status}>
                          {[
                            "draft",
                            "pending_signature",
                            "active",
                            "suspended",
                            "expired",
                            "renewal_pending",
                            "terminated",
                          ].map((x) => (
                            <option key={x} value={x}>
                              {x}
                            </option>
                          ))}
                        </select>
                        <button type="submit">Transition</button>
                      </form>
                      <form action={renewContract} className="actions">
                        <input type="hidden" name="id" value={r.id} />
                        <input name="start_date" type="date" required />
                        <input name="end_date" type="date" />
                        <input
                          name="contract_value"
                          type="number"
                          step="0.01"
                          placeholder="Value"
                        />
                        <button type="submit">Renew</button>
                      </form>
                      {["active", "renewal_pending"].includes(r.status) ? (
                        <form action={generateWorkOrdersFromContract}>
                          <input type="hidden" name="id" value={r.id} />
                          <input type="hidden" name="days_ahead" value="14" />
                          <button type="submit" className="primary">
                            Generate WOs (14d)
                          </button>
                        </form>
                      ) : null}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </>
  );
}

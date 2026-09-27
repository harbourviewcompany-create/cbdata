import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getWorkspaceContext } from "@/lib/workspace";
import { convertTarget, logTouch } from "../actions";
import { addTargetContact, saveTargetAccount, setPrimaryTargetContact } from "../account-actions";

type PropertyIntelRow = {
  property_id: string; name: string; address_line_1: string; address_line_2: string | null; city: string; province: string | null; postal_code: string | null; property_type: string; building_count: number | null; unit_count: number | null; floor_count: number | null; estimated_sqft: number | null; parking_spaces: number | null; construction_year: number | null; grounds_scope: string | null; snow_scope: string | null; janitorial_scope: string | null; capital_projects_signal: string | null; vendor_signal: string | null; procurement_signal: string | null; seasonal_priority: string | null; access_complexity: string | null; liability_signal: string | null; intelligence_score: number | null; intelligence_summary: string | null; primary_source_url: string | null; primary_source_label: string | null; data_confidence: string | null; verified_at: string | null; contact_count: number | null; permit_count: number | null; recent_permit_count: number | null; recent_permit_value: number | null;
};

type PropertyContactRow = {
  id: string;
  property_id: string;
  relationship_type: string;
  is_primary: boolean;
  emergency_contact: boolean;
  notes: string | null;
  contacts: { id: string; first_name: string; last_name: string; job_title: string | null; email: string | null; phone: string | null; mobile: string | null } | { id: string; first_name: string; last_name: string; job_title: string | null; email: string | null; phone: string | null; mobile: string | null }[] | null;
};

type PropertyEvidenceRow = {
  id: string;
  property_id: string;
  source_type: string;
  source_url: string | null;
  source_title: string | null;
  observed_at: string;
  published_at: string | null;
  summary: string | null;
  confidence: string | null;
};

function fmt(v: string | null | undefined) {
  if (!v) return "—";
  try {
    return new Date(v).toLocaleString();
  } catch {
    return v;
  }
}

function freshness(v: string | null | undefined) {
  if (!v) return "unverified";
  const days = Math.max(0, Math.floor((Date.now() - new Date(v).getTime()) / 86400000));
  if (days === 0) return "verified today";
  if (days === 1) return "verified 1d ago";
  return "verified " + days + "d ago";
}

export default async function TargetDetail({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const ctx = await getWorkspaceContext();
  if (!ctx) redirect("/login");
  const s = await createClient();

  const { data: row } = await s
    .from("outreach_targets")
    .select(
      "id,status,score,score_reason,next_action,next_action_due_at,last_touch_at,organization_name,contact_name,phone,email,notes,region,organization_id,contact_id,property_address",
    )
    .eq("id", id)
    .eq("workspace_id", ctx.workspaceId)
    .maybeSingle();
  if (!row) notFound();

  const [{ data: org }, { data: links }, { data: touches }, { data: properties }, { data: linkedProperties }] = await Promise.all([
    row.organization_id
      ? s
          .from("organizations")
          .select(
            "id,legal_name,operating_name,organization_type,website,phone,email,notes,doors_managed,buildings_managed,primary_region,status",
          )
          .eq("id", row.organization_id)
          .maybeSingle()
      : Promise.resolve({ data: null }),
    row.organization_id
      ? s
          .from("organization_contacts")
          .select("id,contact_id,relationship_type,is_primary,contacts(id,first_name,last_name,job_title,email,phone,mobile)")
          .eq("organization_id", row.organization_id)
          .eq("workspace_id", ctx.workspaceId)
      : Promise.resolve({ data: [] }),
    s
      .from("outreach_touches")
      .select("id,channel,outcome,notes,occurred_at")
      .eq("outreach_target_id", id)
      .order("occurred_at", { ascending: false })
      .limit(20),
    row.organization_id
      ? (s as any)
          .from("v_property_intelligence")
          .select("property_id,name,address_line_1,address_line_2,city,province,postal_code,property_type,building_count,unit_count,floor_count,estimated_sqft,lot_area_sqft,parking_spaces,construction_year,grounds_scope,snow_scope,janitorial_scope,capital_projects_signal,vendor_signal,procurement_signal,seasonal_priority,access_complexity,liability_signal,intelligence_score,intelligence_summary,primary_source_url,primary_source_label,data_confidence,verified_at,contact_count,permit_count,recent_permit_count,recent_permit_value")
          .eq("workspace_id", ctx.workspaceId)
          .or(`owner_organization_id.eq.${row.organization_id},management_organization_id.eq.${row.organization_id},primary_customer_organization_id.eq.${row.organization_id}`)
          .order("intelligence_score", { ascending: false, nullsFirst: false })
          .order("name")
          .limit(100)
      : Promise.resolve({ data: [] }),
    (s as any)
      .from("outreach_target_properties")
      .select("property_id,is_primary,relationship_type")
      .eq("outreach_target_id", id)
      .eq("workspace_id", ctx.workspaceId),
  ]);

  const propertyMap = new Map<string, PropertyIntelRow>();
  for (const p of (properties ?? []) as PropertyIntelRow[]) propertyMap.set(p.property_id, p);
  const linkedIds = ((linkedProperties ?? []) as Array<{ property_id: string }>).map((x) => x.property_id);
  if (linkedIds.length) {
    const { data: linkedIntel } = await (s as any)
      .from("v_property_intelligence")
      .select("property_id,name,address_line_1,address_line_2,city,province,postal_code,property_type,building_count,unit_count,floor_count,estimated_sqft,lot_area_sqft,parking_spaces,construction_year,grounds_scope,snow_scope,janitorial_scope,capital_projects_signal,vendor_signal,procurement_signal,seasonal_priority,access_complexity,liability_signal,intelligence_score,intelligence_summary,primary_source_url,primary_source_label,data_confidence,verified_at,contact_count,permit_count,recent_permit_count,recent_permit_value")
      .in("property_id", linkedIds);
    for (const p of (linkedIntel ?? []) as PropertyIntelRow[]) propertyMap.set(p.property_id, p);
  }
  const propertyRows = Array.from(propertyMap.values());

  const propertyIds = propertyRows.map((p) => p.property_id);
  const [{ data: propertyContacts }, { data: propertyEvidence }] = propertyIds.length
    ? await Promise.all([
        (s as any)
          .from("property_contacts")
          .select("id,property_id,relationship_type,is_primary,emergency_contact,notes,contacts(id,first_name,last_name,job_title,email,phone,mobile)")
          .eq("workspace_id", ctx.workspaceId)
          .in("property_id", propertyIds)
          .order("is_primary", { ascending: false }),
        (s as any)
          .from("property_intelligence_sources")
          .select("id,property_id,source_type,source_url,source_title,observed_at,published_at,summary,confidence")
          .eq("workspace_id", ctx.workspaceId)
          .in("property_id", propertyIds)
          .order("observed_at", { ascending: false }),
      ])
    : [{ data: [] }, { data: [] }];

  const contactsByProperty = new Map<string, PropertyContactRow[]>();
  for (const pc of (propertyContacts ?? []) as PropertyContactRow[]) {
    const list = contactsByProperty.get(pc.property_id) ?? [];
    list.push(pc);
    contactsByProperty.set(pc.property_id, list);
  }
  const evidenceByProperty = new Map<string, PropertyEvidenceRow[]>();
  for (const ev of (propertyEvidence ?? []) as PropertyEvidenceRow[]) {
    const list = evidenceByProperty.get(ev.property_id) ?? [];
    list.push(ev);
    evidenceByProperty.set(ev.property_id, list);
  }

  const companyName = org?.operating_name || org?.legal_name || row.organization_name || "Target";

  return (
    <>
      <header className="page-intro">
        <div>
          <span className="eyebrow">PM TARGET</span>
          <h1>{companyName}</h1>
          <p className="muted">
            {row.next_action ?? "No next action"} · score {row.score ?? "—"} · {row.status}
          </p>
        </div>
        <Link className="button" href="/targets">
          Back to queue
        </Link>
      </header>

      <section className="grid-two">
        <article className="panel">
          <div className="panel-head">
            <h3>Company</h3>
          </div>
          <form action={saveTargetAccount} className="form-grid">
            <input type="hidden" name="target_id" value={row.id} />
            <label>
              Operating name
              <input name="company_name" defaultValue={org?.operating_name || row.organization_name || ""} required />
            </label>
            <label>
              Legal name
              <input name="legal_name" defaultValue={org?.legal_name || ""} />
            </label>
            <label>
              Website
              <input name="website" defaultValue={org?.website || ""} placeholder="https://" />
            </label>
            <label>
              Company phone
              <input name="company_phone" defaultValue={org?.phone || ""} />
            </label>
            <label>
              Company email
              <input name="company_email" type="email" defaultValue={org?.email || ""} />
            </label>
            <label>
              Region
              <input name="region" defaultValue={org?.primary_region || row.region || ""} />
            </label>
            <label>
              Doors managed
              <input name="doors_managed" type="number" min="0" defaultValue={org?.doors_managed ?? ""} />
            </label>
            <label>
              Buildings
              <input name="buildings_managed" type="number" min="0" defaultValue={org?.buildings_managed ?? ""} />
            </label>
            <label>
              Snapshot contact name
              <input name="contact_name" defaultValue={row.contact_name || ""} />
            </label>
            <label>
              Snapshot phone
              <input name="phone" defaultValue={row.phone || ""} />
            </label>
            <label>
              Snapshot email
              <input name="email" type="email" defaultValue={row.email || ""} />
            </label>
            <label>
              Notes
              <textarea name="notes" defaultValue={row.notes || org?.notes || ""} rows={3} />
            </label>
            <button className="primary">Save company</button>
          </form>
          <p className="muted" style={{ marginTop: 8 }}>
            Saving creates or updates the linked organization. Snapshot phone/email stay on the target for list imports.
          </p>
        </article>

        <article className="panel">
          <div className="panel-head">
            <h3>Key contacts</h3>
          </div>
          <ul className="queue-list">
            {(links ?? []).length === 0 ? (
              <li className="muted">No roster yet. Add the facilities / property manager first.</li>
            ) : (
              (links ?? []).map((link) => {
                const c = (Array.isArray(link.contacts) ? link.contacts[0] : link.contacts) as {
                  id?: string;
                  first_name?: string;
                  last_name?: string;
                  job_title?: string | null;
                  email?: string | null;
                  phone?: string | null;
                  mobile?: string | null;
                } | null;
                if (!c) return null;
                return (
                  <li key={link.id}>
                    <strong>
                      {c.first_name} {c.last_name}
                      {link.is_primary ? " · primary" : ""}
                    </strong>
                    <span className="muted">
                      {link.relationship_type}
                      {c.job_title ? ` · ${c.job_title}` : ""}
                    </span>
                    <span className="muted">
                      {c.phone || c.mobile || "no phone"} · {c.email || "no email"}
                    </span>
                    {!link.is_primary ? (
                      <form action={setPrimaryTargetContact}>
                        <input type="hidden" name="target_id" value={row.id} />
                        <input type="hidden" name="contact_id" value={c.id} />
                        <button type="submit">Make primary</button>
                      </form>
                    ) : null}
                  </li>
                );
              })
            )}
          </ul>
          <form action={addTargetContact} className="form-grid" style={{ marginTop: 16 }}>
            <input type="hidden" name="target_id" value={row.id} />
            <input name="full_name" required placeholder="Full name" />
            <input name="job_title" placeholder="Job title" />
            <select name="relationship_type" defaultValue="property_manager">
              <option value="property_manager">property_manager</option>
              <option value="facilities">facilities</option>
              <option value="board">board</option>
              <option value="owner">owner</option>
              <option value="accounts_payable">accounts_payable</option>
              <option value="key_contact">key_contact</option>
            </select>
            <input name="phone" placeholder="Desk phone" />
            <input name="mobile" placeholder="Mobile" />
            <input name="email" type="email" placeholder="Email" />
            <label style={{ display: "flex", gap: 8, alignItems: "center" }}>
              <input type="checkbox" name="is_primary" />
              Primary contact for outreach
            </label>
            <button>Add contact</button>
          </form>
        </article>
      </section>

      <section className="panel" style={{ marginTop: 14 }}>
        <div className="panel-head">
          <div>
            <span className="eyebrow">PROPERTY 360</span>
            <h3>Property-level intelligence</h3>
          </div>
        </div>
        <p className="muted" style={{ marginTop: 6 }}>
          Physical footprint, service scope, capital signals and permit activity tied to this account.
          Only sourced intelligence is shown; blank fields mean the property has not been enriched yet.
        </p>
        <div className="table-wrap" style={{ marginTop: 12 }}>
          <table className="targets-table">
            <thead><tr>
              <th>Property</th><th>Footprint</th><th>Service signals</th><th>Buying / risk signals</th><th>Decision makers</th><th>Evidence</th>
            </tr></thead>
            <tbody>
              {propertyRows.length === 0 ? (
                <tr><td colSpan={6} className="muted">No properties linked to this organization yet.</td></tr>
              ) : propertyRows.map((p) => (
                <tr key={p.property_id}>
                  <td>
                    <strong>{p.name}</strong>
                    <div className="muted" style={{fontSize:12}}>
                      {[p.address_line_1,p.address_line_2,p.city,p.province,p.postal_code].filter(Boolean).join(", ")}
                    </div>
                    <div className="muted" style={{fontSize:11,marginTop:4}}>
                      {p.property_type ?? "type n/a"}{p.construction_year ? ` · built ${p.construction_year}` : ""}{p.data_confidence ? ` · ${p.data_confidence} confidence` : ""}
                    </div>
                  </td>
                  <td>
                    <div>{p.building_count ?? 0} buildings{p.unit_count != null ? ` · ${p.unit_count} units` : ""}</div>
                    <div className="muted" style={{fontSize:12}}>
                      {p.floor_count ?? "—"} floors{p.estimated_sqft ? ` · ${Number(p.estimated_sqft).toLocaleString()} sq ft` : ""}{p.parking_spaces != null ? ` · ${p.parking_spaces} parking` : ""}
                    </div>
                    <div className="muted" style={{fontSize:12}}>
                      {p.permit_count ?? 0} permits{p.recent_permit_count ? ` · ${p.recent_permit_count} in 24mo` : ""}{p.recent_permit_value ? ` · ${Number(p.recent_permit_value).toLocaleString()} recent value` : ""}
                    </div>
                  </td>
                  <td>
                    <div>{p.grounds_scope ?? "grounds: unknown"}</div>
                    <div>{p.snow_scope ?? "snow: unknown"}</div>
                    <div>{p.janitorial_scope ?? "janitorial: unknown"}</div>
                    {p.seasonal_priority ? <div className="muted" style={{fontSize:12}}>season: {p.seasonal_priority}</div> : null}
                  </td>
                  <td>
                    <div>{p.vendor_signal ?? "vendor relationship: unknown"}</div>
                    <div>{p.procurement_signal ?? "procurement: unknown"}</div>
                    <div>{p.capital_projects_signal ?? "capital projects: unknown"}</div>
                    <div className="muted" style={{fontSize:12}}>
                      {p.access_complexity ? `access: ${p.access_complexity} · ` : ""}{p.liability_signal ? `liability: ${p.liability_signal}` : ""}
                    </div>
                  </td>
                  <td>
                    {(() => {
                      const contacts = contactsByProperty.get(p.property_id) ?? [];
                      return contacts.length ? contacts.slice(0, 3).map((pc) => {
                        const c = (Array.isArray(pc.contacts) ? pc.contacts[0] : pc.contacts);
                        if (!c) return null;
                        return (
                          <div key={pc.id} className="property-contact">
                            <strong>{c.first_name} {c.last_name}</strong>
                            <span className="muted">{pc.relationship_type}{pc.is_primary ? " · primary" : ""}{c.job_title ? " · " + c.job_title : ""}</span>
                            {(c.phone || c.mobile) ? <a href={"tel:" + (c.phone || c.mobile)}>{c.phone || c.mobile}</a> : null}
                            {c.email ? <a href={"mailto:" + c.email}>{c.email}</a> : null}
                          </div>
                        );
                      }) : <span className="muted">No property-specific contact verified.</span>;
                    })()}
                  </td>
                  <td>
                    {p.intelligence_score != null ? <strong>{p.intelligence_score}/100</strong> : <span className="muted">not scored</span>}
                    <div className="evidence-freshness">{freshness(p.verified_at)}</div>
                    {p.intelligence_summary ? <div className="muted" style={{fontSize:12,marginTop:4}}>{p.intelligence_summary}</div> : null}
                    {(() => {
                      const evidence = evidenceByProperty.get(p.property_id) ?? [];
                      return evidence.length ? (
                        <div className="evidence-list">
                          {evidence.slice(0, 2).map((ev) => (
                            <div key={ev.id}>
                              {ev.source_url ? <a href={ev.source_url} target="_blank" rel="noreferrer">{ev.source_title ?? ev.source_type}</a> : <span>{ev.source_title ?? ev.source_type}</span>}
                              <span className="muted"> · {freshness(ev.observed_at)}</span>
                            </div>
                          ))}
                          {evidence.length > 2 ? <span className="muted">+{evidence.length - 2} more sources</span> : null}
                        </div>
                      ) : p.primary_source_url ? (
                        <div style={{fontSize:12,marginTop:5}}><a href={p.primary_source_url} target="_blank" rel="noreferrer">{p.primary_source_label ?? "primary source"}</a></div>
                      ) : <span className="muted">No evidence source linked.</span>;
                    })()}
                    <div className="muted" style={{fontSize:11,marginTop:4}}>{p.contact_count ?? 0} property contacts · {(evidenceByProperty.get(p.property_id) ?? []).length} evidence records</div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="grid-two" style={{ marginTop: 14 }}>
        <article className="panel">
          <div className="panel-head">
            <h3>Log a touch</h3>
          </div>
          <form action={logTouch} className="form-grid">
            <input type="hidden" name="target_id" value={row.id} />
            <select name="channel" defaultValue="call">
              <option value="call">call</option>
              <option value="email">email</option>
              <option value="sms">sms</option>
              <option value="door_knock">door_knock</option>
              <option value="mail">mail</option>
              <option value="other">other</option>
            </select>
            <input name="outcome" placeholder="Reached / voicemail / booked" />
            <input name="notes" placeholder="What was said" />
            <input name="next_action" placeholder="Next action" defaultValue={row.next_action ?? ""} />
            <input name="next_action_due_at" type="datetime-local" />
            <select name="new_status" defaultValue="">
              <option value="">Keep status ({row.status})</option>
              <option value="contacted">contacted</option>
              <option value="responded">responded</option>
              <option value="rejected">rejected</option>
              <option value="do_not_contact">do_not_contact</option>
            </select>
            <button className="primary">Save touch</button>
          </form>
          <form action={convertTarget} style={{ marginTop: 12 }}>
            <input type="hidden" name="target_id" value={row.id} />
            <button>Convert to lead</button>
          </form>
        </article>
        <article className="panel">
          <div className="panel-head">
            <h3>History</h3>
          </div>
          <p className="muted" style={{ fontSize: 12 }}>
            {row.score_reason ?? "Score not computed yet"}
          </p>
          <ul className="queue-list">
            {(touches ?? []).length === 0 ? (
              <li className="muted">No touches logged.</li>
            ) : (
              (touches ?? []).map((t) => (
                <li key={t.id}>
                  <strong>
                    {t.channel} · {fmt(t.occurred_at)}
                  </strong>
                  <span className="muted">{t.outcome ?? t.notes ?? ""}</span>
                </li>
              ))
            )}
          </ul>
        </article>
      </section>
    </>
  );
}

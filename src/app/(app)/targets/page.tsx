import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { convertTarget, logTouch, refreshScores, updateTargetStatus, ensurePmSequence, enrollTarget, processSequences } from "./actions";

type TargetIntel = { propertyCount:number; unitCount:number; buildingCount:number; highSignalCount:number; recentPermitCount:number; services:string[]; buyingSignals:string[]; };

type QueueRow = {
  id: string;
  workspace_id: string;
  outreach_list_id: string;
  list_name: string | null;
  status: string;
  score: number | null;
  score_reason: string | null;
  priority: string;
  region: string | null;
  next_action: string | null;
  next_action_due_at: string | null;
  last_touch_at: string | null;
  owner_user_id: string | null;
  organization_id: string | null;
  organization_display_name: string | null;
  organization_type: string | null;
  doors_managed: number | null;
  buildings_managed: number | null;
  organization_website: string | null;
  organization_phone: string | null;
  organization_email: string | null;
  organization_address: string | null;
  contact_id: string | null;
  contact_display_name: string | null;
  contact_job_title: string | null;
  contact_phone: string | null;
  contact_email: string | null;
  converted_lead_id: string | null;
  notes: string | null;
  linked_property_count: number | null;
  touch_count: number | null;
  updated_at: string;
};

const STATUSES = [
  "queued",
  "contacted",
  "responded",
  "converted",
  "rejected",
  "do_not_contact",
] as const;

function fmtDate(v: string | null) {
  if (!v) return "—";
  try {
    return new Date(v).toLocaleDateString();
  } catch {
    return v;
  }
}

export default async function TargetsPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const s = await createClient();
  const {
    data: { user },
  } = await s.auth.getUser();
  if (!user) redirect("/login");

  const params = await searchParams;
  const statusFilter = typeof params.status === "string" ? params.status : "";
  const regionFilter = typeof params.region === "string" ? params.region : "";
  const q = typeof params.q === "string" ? params.q.trim().toLowerCase() : "";

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  let query = (s as any)
    .from("v_outreach_target_queue")
    .select("*")
    .order("score", { ascending: false, nullsFirst: false })
    .order("next_action_due_at", { ascending: true, nullsFirst: false })
    .limit(200);

  if (statusFilter) query = query.eq("status", statusFilter);
  if (regionFilter) query = query.ilike("region", regionFilter);

  const [{ data: rows, error }, { data: sequences }] = await Promise.all([
    query,
    (s as any).from("outreach_sequences").select("id,name,is_active").eq("is_active", true).order("name"),
  ]);
  if (error) {
    return (
      <main className="list-shell">
        <header className="list-header">
          <Link className="back" href="/dashboard">
            ← Command
          </Link>
          <span className="eyebrow">BUSINESS DEVELOPMENT</span>
          <h1>Targets</h1>
        </header>
        <section className="table-panel">
          <p className="muted">
            Could not load target queue. Apply migration{" "}
            <code>20260926140000_pm_target_account_outreach</code> and ensure RLS
            allows workspace members. ({error.message})
          </p>
        </section>
      </main>
    );
  }

  const all = (rows ?? []) as QueueRow[];
  const filtered = q
    ? all.filter((r) => {
        const hay = [
          r.organization_display_name,
          r.contact_display_name,
          r.contact_email,
          r.region,
          r.next_action,
        ]
          .filter(Boolean)
          .join(" ")
          .toLowerCase();
        return hay.includes(q);
      })
    : all;

  const listId = filtered[0]?.outreach_list_id ?? all[0]?.outreach_list_id ?? "";

  const visibleOrgIds = Array.from(new Set(filtered.map((r) => r.organization_id).filter(Boolean) as string[]));
  const { data: propertyIntelRows } = visibleOrgIds.length
    ? await (s as any).from("v_property_intelligence").select("property_id,owner_organization_id,management_organization_id,primary_customer_organization_id,unit_count,building_count,intelligence_score,grounds_scope,snow_scope,janitorial_scope,procurement_signal,capital_projects_signal,vendor_signal,recent_permit_count").eq("workspace_id", all[0]?.workspace_id ?? "").limit(500)
    : { data: [] };

  const intelByOrg = new Map<string, TargetIntel>();
  const addIntel = (orgId: string, p: any) => {
    const current = intelByOrg.get(orgId) ?? {propertyCount:0,unitCount:0,buildingCount:0,highSignalCount:0,recentPermitCount:0,services:[],buyingSignals:[]};
    current.propertyCount += 1;
    current.unitCount += Number(p.unit_count ?? 0);
    current.buildingCount += Number(p.building_count ?? 0);
    current.recentPermitCount += Number(p.recent_permit_count ?? 0);
    if (p.intelligence_score != null && Number(p.intelligence_score) >= 80) current.highSignalCount += 1;
    if (p.grounds_scope && !current.services.includes("grounds")) current.services.push("grounds");
    if (p.snow_scope && !current.services.includes("snow")) current.services.push("snow");
    if (p.janitorial_scope && !current.services.includes("janitorial")) current.services.push("janitorial");
    if (p.procurement_signal && !current.buyingSignals.includes("procurement")) current.buyingSignals.push("procurement");
    if (p.capital_projects_signal && !current.buyingSignals.includes("capital")) current.buyingSignals.push("capital");
    if (p.vendor_signal && !current.buyingSignals.includes("vendor")) current.buyingSignals.push("vendor");
    intelByOrg.set(orgId, current);
  };
  for (const p of (propertyIntelRows ?? [])) {
    const matchedOrgIds = new Set<string>();
    for (const key of ["owner_organization_id","management_organization_id","primary_customer_organization_id"]) {
      const orgId = p[key] as string | null;
      if (orgId && visibleOrgIds.includes(orgId)) matchedOrgIds.add(orgId);
    }
    for (const orgId of matchedOrgIds) addIntel(orgId, p);
  }
  const visibleIntel = filtered.map((r) => r.organization_id ? intelByOrg.get(r.organization_id) : undefined).filter(Boolean) as TargetIntel[];
  const intelProperties = visibleIntel.reduce((n, x) => n + x.propertyCount, 0);
  const intelSignals = visibleIntel.reduce((n, x) => n + x.highSignalCount, 0);
  const buyingSignalTargets = visibleIntel.filter((x) => x.buyingSignals.length > 0).length;
  const namedContactCount = filtered.filter((r) => Boolean(r.contact_display_name)).length;
  const regions = Array.from(
    new Set(all.map((r) => r.region).filter(Boolean) as string[]),
  ).sort();

  const openCount = all.filter((r) =>
    ["queued", "contacted", "responded"].includes(r.status),
  ).length;
  const convertedCount = all.filter((r) => r.status === "converted").length;

  return (
    <main className="list-shell">
      <header className="list-header">
        <Link className="back" href="/dashboard">
          ← Command
        </Link>
        <span className="eyebrow">BUSINESS DEVELOPMENT</span>
        <h1>PM Targets</h1>
        <p className="muted" style={{ marginTop: 8, maxWidth: 640 }}>
          Account queue for property management companies. Score ranks who to
          call next. Log touches, advance status, convert to a lead when the
          conversation is real.
        </p>
      </header>

      <section className="metrics" style={{ marginBottom: 18 }}>
        <div className="metric">
          <span>In queue</span>
          <strong>{openCount}</strong>
        </div>
        <div className="metric">
          <span>Converted</span>
          <strong>{convertedCount}</strong>
        </div>
        <div className="metric">
          <span>Showing</span>
          <strong>{filtered.length}</strong>
        </div>
        <div className="metric intel-metric"><span>Linked properties</span><strong>{intelProperties}</strong></div>
        <div className="metric intel-metric"><span>High-signal sites</span><strong>{intelSignals}</strong></div>
        <div className="metric intel-metric"><span>Buying signals</span><strong>{buyingSignalTargets}</strong></div>
        <div className="metric intel-metric"><span>Named contacts</span><strong>{namedContactCount}</strong></div>
      </section>

      <section className="panel" style={{ marginBottom: 18 }}>
        <div className="panel-head"><div><span className="eyebrow">AUTOMATION</span><h3>Sequence engine</h3></div></div>
        <div className="hero-cta" style={{ marginTop: 12 }}>
          <form action={ensurePmSequence}><button type="submit" className="button">Ensure PM Intro sequence</button></form>
          <form action={processSequences}><button type="submit" className="primary">Run due sequence steps</button></form>
        </div>
        <p className="muted" style={{ marginTop: 10 }}>Creates call/email/follow-up tasks and notifications for enrolled targets.</p>
      </section>
      <section className="table-panel" style={{ marginBottom: 18 }}>
        <form method="get" className="form-grid">
          <input name="q" placeholder="Search company or contact" defaultValue={q} />
          <select name="status" defaultValue={statusFilter}>
            <option value="">All statuses</option>
            {STATUSES.map((st) => (
              <option key={st} value={st}>
                {st}
              </option>
            ))}
          </select>
          <select name="region" defaultValue={regionFilter}>
            <option value="">All regions</option>
            {regions.map((r) => (
              <option key={r} value={r}>
                {r}
              </option>
            ))}
          </select>
          <button type="submit" className="button">
            Filter
          </button>
        </form>
        {listId ? (
          <form action={refreshScores} style={{ marginTop: 12 }}>
            <input type="hidden" name="list_id" value={listId} />
            <button type="submit" className="button">
              Refresh scores (this list)
            </button>
          </form>
        ) : null}
      </section>

      <section className="table-panel">
        <div className="table-wrap">
          <div className="targets-grid" role="table" aria-label="PM target accounts">
            <div className="targets-grid-row targets-grid-head" role="row">
              <div role="columnheader">Score</div><div role="columnheader">Company</div><div role="columnheader">Contact</div><div role="columnheader">Status</div><div role="columnheader">Next action</div><div role="columnheader">Actions</div>
            </div>
            {filtered.length === 0 ? (
              <div className="targets-grid-row targets-grid-empty" role="row"><div role="cell" className="muted">No targets yet. Seed <code>supabase/seed/001_pm_targets_example.sql</code> after the migration, or add outreach targets manually.</div></div>
            ) : filtered.map((r) => (
              <div className="targets-grid-row" role="row" key={r.id}>
                <div className="score-cell" role="cell"><span className={`score-chip ${(r.score ?? 0) >= 80 ? "score-high" : (r.score ?? 0) >= 60 ? "score-medium" : "score-low"}`}>{r.score ?? "—"}</span></div>
                <div className="company-cell" role="cell">
                  <Link href={`/targets/${r.id}`} className="target-company"><strong>{r.organization_display_name ?? "—"}</strong></Link>
                  {r.region ? <span className="region-tag">{r.region}</span> : null}
                  {r.organization_id && intelByOrg.get(r.organization_id) ? (() => {
                    const i = intelByOrg.get(r.organization_id)!;
                    return <div className="portfolio-intel">{i.propertyCount} site{i.propertyCount === 1 ? "" : "s"}{i.buildingCount ? " · " + i.buildingCount + " building" + (i.buildingCount === 1 ? "" : "s") : ""}{i.unitCount ? " · " + i.unitCount.toLocaleString() + " units" : ""}</div>;
                  })() : null}
                  <div className="company-meta">{r.organization_website ? <a href={r.organization_website} target="_blank" rel="noreferrer">website</a> : null}{r.organization_phone ? <a href={`tel:${r.organization_phone}`}>{r.organization_phone}</a> : null}</div>
                </div>
                <div className="contact-cell" role="cell">
                  <strong>{r.contact_display_name ?? "No named contact"}</strong>
                  {r.contact_job_title ? <span className="contact-role">{r.contact_job_title}</span> : null}
                  {r.contact_phone ? <a href={`tel:${r.contact_phone}`} className="contact-line"><span aria-hidden="true">☎</span>{r.contact_phone}</a> : null}
                  {(r.contact_email ?? r.organization_email) ? <a href={`mailto:${r.contact_email ?? r.organization_email}`} className="contact-line"><span aria-hidden="true">✉</span>{r.contact_email ?? r.organization_email}</a> : null}
                </div>
                <div className="status-cell" role="cell"><span className="pill">{r.status}</span><span className="status-meta">{r.touch_count ? `${r.touch_count} touch${r.touch_count === 1 ? "" : "es"} · last ${fmtDate(r.last_touch_at)}` : "No touches yet"}</span></div>
                <div className="next-action-cell" role="cell">
                  <div className="next-action-text" title={r.next_action ?? "—"}>{r.next_action ?? "—"}</div>
                  {r.organization_id && intelByOrg.get(r.organization_id) ? (() => {
                    const i = intelByOrg.get(r.organization_id)!;
                    const services = i.services.slice(0, 3).join(" · ");
                    const buying = i.buyingSignals.slice(0, 2).join(" · ");
                    return <div className="intel-line">{[services, buying].filter(Boolean).join(" · ") || "Property intelligence pending"}</div>;
                  })() : null}
                  {r.next_action_due_at ? <div className="next-action-due">due {fmtDate(r.next_action_due_at)}</div> : null}
                </div>
                <div className="row-actions-cell" role="cell">
                  <div className="row-actions">
                    <form action={logTouch}><input type="hidden" name="target_id" value={r.id}/><input type="hidden" name="channel" value="call"/><input type="hidden" name="new_status" value="contacted"/><button type="submit" className="primary log-touch-button">Log touch</button></form>
                    <div className="action-menu">
                      <button type="button" className="action-menu-trigger" aria-label={`More actions for ${r.organization_display_name ?? "target"}`}>⋯</button>
                      <div className="action-menu-popover">
                        <form action={logTouch} className="action-menu-form"><input type="hidden" name="target_id" value={r.id}/><label>Channel<select name="channel" defaultValue="call"><option value="call">Call</option><option value="email">Email</option><option value="sms">SMS</option><option value="door_knock">Door knock</option><option value="mail">Mail</option><option value="other">Other</option></select></label><label>Status<select name="new_status" defaultValue="contacted">{STATUSES.map(st => <option key={st} value={st}>{st}</option>)}</select></label><label>Outcome<input name="outcome" placeholder="Outcome"/></label><label>Notes<input name="notes" placeholder="Notes"/></label><label>Next action<input name="next_action" placeholder="Next action" defaultValue={r.next_action ?? ""}/></label><button type="submit" className="button">Save touch details</button></form>
                        <div className="action-menu-divider"/>
                        <form action={updateTargetStatus} className="action-menu-form"><input type="hidden" name="target_id" value={r.id}/><label>Status<select name="status" defaultValue={r.status}>{STATUSES.map(st => <option key={st} value={st}>{st}</option>)}</select></label><button type="submit" className="button">Set status</button></form>
                        {(sequences as {id:string;name:string}[] | null)?.length && ["queued","contacted","responded"].includes(r.status) ? <form action={enrollTarget} className="action-menu-form"><input type="hidden" name="target_id" value={r.id}/><label>Sequence<select name="sequence_id" required>{(sequences as {id:string;name:string}[]).map(seq => <option key={seq.id} value={seq.id}>{seq.name}</option>)}</select></label><button type="submit" className="button">Enroll sequence</button></form> : null}
                        {["queued","contacted","responded"].includes(r.status) ? <form action={convertTarget}><input type="hidden" name="target_id" value={r.id}/><button type="submit" className="primary action-menu-full-button">Convert to lead</button></form> : r.converted_lead_id ? <span className="muted action-menu-lead">Lead {r.converted_lead_id.slice(0,8)}…</span> : null}
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>
    </main>
  );
}

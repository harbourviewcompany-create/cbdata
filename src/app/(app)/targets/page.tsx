import Link from "next/link";
import type { Route } from "next";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { convertTarget, logTouch, refreshScores, updateTargetStatus, ensurePmSequence, enrollTarget, processSequences } from "./actions";

type QueueRow = {
  id: string;
  outreach_list_id: string;
  status: string;
  score: number | null;
  region: string | null;
  next_action: string | null;
  next_action_due_at: string | null;
  last_touch_at: string | null;
  organization_display_name: string | null;
  organization_website: string | null;
  organization_phone: string | null;
  organization_email: string | null;
  contact_display_name: string | null;
  contact_job_title: string | null;
  contact_phone: string | null;
  contact_email: string | null;
  converted_lead_id: string | null;
  touch_count: number | null;
};

const STATUSES = [
  "queued",
  "contacted",
  "responded",
  "converted",
  "rejected",
  "do_not_contact",
] as const;

const QUEUE_COLUMNS =
  "id,outreach_list_id,status,score,region,next_action,next_action_due_at,last_touch_at,organization_display_name,organization_website,organization_phone,organization_email,contact_display_name,contact_job_title,contact_phone,contact_email,converted_lead_id,touch_count";

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
  const term = q.replace(/[%_,()]/g, " ").trim();

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const db = s as any;
  let query = db
    .from("v_outreach_target_queue")
    .select(QUEUE_COLUMNS)
    .order("score", { ascending: false, nullsFirst: false })
    .order("next_action_due_at", { ascending: true, nullsFirst: false })
    .limit(80);

  if (statusFilter) query = query.eq("status", statusFilter);
  if (regionFilter) query = query.ilike("region", regionFilter);
  if (term) {
    query = query.or(
      `organization_display_name.ilike.%${term}%,contact_display_name.ilike.%${term}%,contact_email.ilike.%${term}%,region.ilike.%${term}%,next_action.ilike.%${term}%`,
    );
  }

  const [{ data: rows, error }, { data: sequences }, openRes, convertedRes, { data: regionRows }] =
    await Promise.all([
      query,
      db.from("outreach_sequences").select("id,name").eq("is_active", true).order("name"),
      db
        .from("v_outreach_target_queue")
        .select("id", { count: "exact", head: true })
        .in("status", ["queued", "contacted", "responded"]),
      db
        .from("v_outreach_target_queue")
        .select("id", { count: "exact", head: true })
        .eq("status", "converted"),
      db.from("v_outreach_target_queue").select("region").not("region", "is", null).limit(80),
    ]);
  if (error) {
    return (
      <main className="list-shell">
        <header className="list-header">
          <Link className="back" href={"/dashboard" as Route}>
            ← Command
          </Link>
          <span className="eyebrow">BUSINESS DEVELOPMENT</span>
          <h1>Targets</h1>
        </header>
        <section className="table-panel">
          <p className="muted">
            Could not load target queue. ({error.message})
          </p>
        </section>
      </main>
    );
  }

  const filtered = (rows ?? []) as QueueRow[];
  const listId = filtered[0]?.outreach_list_id ?? "";
  const regions = Array.from(
    new Set((regionRows ?? []).map((r: { region: string | null }) => r.region).filter(Boolean) as string[]),
  ).sort();
  const openCount = openRes.count ?? 0;
  const convertedCount = convertedRes.count ?? 0;

  return (
    <main className="list-shell">
      <header className="list-header">
        <Link className="back" href={"/dashboard" as Route}>
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
                  <Link href={`/targets/${r.id}` as Route} className="target-company"><strong>{r.organization_display_name ?? "—"}</strong></Link>
                  {r.region ? <span className="region-tag">{r.region}</span> : null}
                  <div className="company-meta">{r.organization_website ? <a href={r.organization_website} target="_blank" rel="noreferrer">website</a> : null}{r.organization_phone ? <a href={`tel:${r.organization_phone}`}>{r.organization_phone}</a> : null}</div>
                </div>
                <div className="contact-cell" role="cell">
                  <strong>{r.contact_display_name ?? "No named contact"}</strong>
                  {r.contact_job_title ? <span className="contact-role">{r.contact_job_title}</span> : null}
                  {r.contact_phone ? <a href={`tel:${r.contact_phone}`} className="contact-line"><span aria-hidden="true">☎</span>{r.contact_phone}</a> : null}
                  {(r.contact_email ?? r.organization_email) ? <a href={`mailto:${r.contact_email ?? r.organization_email}`} className="contact-line"><span aria-hidden="true">✉</span>{r.contact_email ?? r.organization_email}</a> : null}
                </div>
                <div className="status-cell" role="cell"><span className="pill">{r.status}</span><span className="status-meta">{r.touch_count ? `${r.touch_count} touch${r.touch_count === 1 ? "" : "es"} · last ${fmtDate(r.last_touch_at)}` : "No touches yet"}</span></div>
                <div className="next-action-cell" role="cell"><div className="next-action-text" title={r.next_action ?? "—"}>{r.next_action ?? "—"}</div>{r.next_action_due_at ? <div className="next-action-due">due {fmtDate(r.next_action_due_at)}</div> : null}</div>
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

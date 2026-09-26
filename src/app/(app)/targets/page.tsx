import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { convertTarget, logTouch, refreshScores, updateTargetStatus, ensurePmSequence, enrollTarget, processSequences } from "./actions";

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
          <table>
            <thead>
              <tr>
                <th>Score</th>
                <th>Company</th>
                <th>Contact</th>
                <th>Status</th>
                <th>Next action</th>
                <th>Touches</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filtered.length === 0 ? (
                <tr>
                  <td colSpan={7} className="muted">
                    No targets yet. Seed{" "}
                    <code>supabase/seed/001_pm_targets_example.sql</code> after
                    the migration, or add outreach targets manually.
                  </td>
                </tr>
              ) : (
                filtered.map((r) => (
                  <tr key={r.id}>
                    <td>
                      <strong>{r.score ?? "—"}</strong>
                      <div className="muted" style={{ fontSize: 12 }}>
                        {r.doors_managed != null
                          ? `${r.doors_managed} doors`
                          : "doors n/a"}
                        {r.linked_property_count
                          ? ` · ${r.linked_property_count} props`
                          : ""}
                      </div>
                    </td>
                    <td>
                      <strong>{r.organization_display_name ?? "—"}</strong>
                      <div className="muted" style={{ fontSize: 12 }}>
                        {r.region ?? "—"}
                        {r.list_name ? ` · ${r.list_name}` : ""}
                      </div>
                    </td>
                    <td>
                      <div>{r.contact_display_name ?? "—"}</div>
                      <div className="muted" style={{ fontSize: 12 }}>
                        {r.contact_job_title ?? ""}
                        {r.contact_phone ? ` · ${r.contact_phone}` : ""}
                      </div>
                      <div className="muted" style={{ fontSize: 12 }}>
                        {r.contact_email ?? ""}
                      </div>
                    </td>
                    <td>
                      <span className="pill">{r.status}</span>
                      <div className="muted" style={{ fontSize: 12 }}>
                        last {fmtDate(r.last_touch_at)}
                      </div>
                    </td>
                    <td>
                      <div>{r.next_action ?? "—"}</div>
                      <div className="muted" style={{ fontSize: 12 }}>
                        due {fmtDate(r.next_action_due_at)}
                      </div>
                    </td>
                    <td>{r.touch_count ?? 0}</td>
                    <td>
                      <div className="stack-actions">
                        <form action={logTouch} className="mini-form">
                          <input type="hidden" name="target_id" value={r.id} />
                          <select name="channel" defaultValue="call">
                            <option value="call">call</option>
                            <option value="email">email</option>
                            <option value="sms">sms</option>
                            <option value="door_knock">door_knock</option>
                            <option value="mail">mail</option>
                            <option value="other">other</option>
                          </select>
                          <select name="new_status" defaultValue="contacted">
                            <option value="contacted">→ contacted</option>
                            <option value="responded">→ responded</option>
                            <option value="rejected">→ rejected</option>
                            <option value="do_not_contact">→ do not contact</option>
                            <option value="queued">→ queued</option>
                          </select>
                          <input name="outcome" placeholder="Outcome" />
                          <input name="notes" placeholder="Notes" />
                          <input
                            name="next_action"
                            placeholder="Next action"
                            defaultValue={r.next_action ?? ""}
                          />
                          <button type="submit" className="button">
                            Log touch
                          </button>
                        </form>

                        <form action={updateTargetStatus} className="mini-form">
                          <input type="hidden" name="target_id" value={r.id} />
                          <select name="status" defaultValue={r.status}>
                            {STATUSES.map((st) => (
                              <option key={st} value={st}>
                                {st}
                              </option>
                            ))}
                          </select>
                          <button type="submit" className="button">
                            Set status
                          </button>
                        </form>

                        {(sequences as {id:string;name:string}[] | null)?.length ? (
                          <form action={enrollTarget} className="mini-form">
                            <input type="hidden" name="target_id" value={r.id} />
                            <select name="sequence_id" required>
                              {(sequences as {id:string;name:string}[]).map(seq => (
                                <option key={seq.id} value={seq.id}>{seq.name}</option>
                              ))}
                            </select>
                            <button type="submit" className="button">Enroll sequence</button>
                          </form>
                        ) : null}
                        {r.status !== "converted" && r.status !== "do_not_contact" ? (
                          <form action={convertTarget}>
                            <input type="hidden" name="target_id" value={r.id} />
                            <button type="submit" className="primary">
                              Convert to lead
                            </button>
                          </form>
                        ) : r.converted_lead_id ? (
                          <span className="muted" style={{ fontSize: 12 }}>
                            Lead {r.converted_lead_id.slice(0, 8)}…
                          </span>
                        ) : null}
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>
    </main>
  );
}

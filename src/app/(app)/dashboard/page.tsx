import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { getWorkspaceContext } from "@/lib/workspace";

export const revalidate = 15;

type Snapshot = {
  workspace_id: string;
  property_count: number;
  open_work_count: number;
  open_issue_count: number;
  renewal_count: number;
  needs_dispatch_count: number;
  open_task_count: number;
  overdue_task_count: number;
  updated_at: string;
};

type Action = {
  action_type: string;
  title: string;
  detail: string | null;
  entity_id: string;
  due_at: string | null;
  priority_score: number;
  href: string;
};

export default async function DashboardPage() {
  const ctx = await getWorkspaceContext();

  if (!ctx) {
    return (
      <div className="empty-card">
        <span className="eyebrow">ACCESS</span>
        <h2 style={{ margin: "8px 0 10px" }}>No workspace yet</h2>
        <p className="muted">
          Your account is signed in, but it is not a member of a CBData workspace.
          Ask an administrator to add you, then refresh this page.
        </p>
      </div>
    );
  }

  const supabase = await createClient();
  const { workspaceId, user } = ctx;

  const [{ data: snapshot }, { data: recentWork }, { data: recentIssues }, { data: nextActions }] =
    await Promise.all([
      supabase
        .from("workspace_ops_snapshots" as never)
        .select(
          "workspace_id, property_count, open_work_count, open_issue_count, renewal_count, needs_dispatch_count, open_task_count, overdue_task_count, updated_at",
        )
        .eq("workspace_id", workspaceId)
        .maybeSingle(),
      supabase
        .from("open_work_exceptions")
        .select("id, description, status, priority, scheduled_start, work_order_number")
        .eq("workspace_id", workspaceId)
        .order("scheduled_start", { ascending: true, nullsFirst: false })
        .limit(5),
      supabase
        .from("open_issue_queue")
        .select("id, title, severity, status, reported_at, issue_type")
        .eq("workspace_id", workspaceId)
        .order("reported_at", { ascending: false })
        .limit(5),
      supabase.rpc("next_actions" as never, {
        p_workspace_id: workspaceId,
        p_limit: 25,
      } as never),
    ]);

  const metrics = (snapshot as unknown as Snapshot | null) ?? {
    workspace_id: workspaceId,
    property_count: 0,
    open_work_count: 0,
    open_issue_count: 0,
    renewal_count: 0,
    needs_dispatch_count: 0,
    open_task_count: 0,
    overdue_task_count: 0,
    updated_at: new Date(0).toISOString(),
  };

  const actions = (nextActions as unknown as Action[] | null) ?? [];
  const isEmpty =
    metrics.property_count === 0 &&
    metrics.open_work_count === 0 &&
    metrics.open_issue_count === 0 &&
    metrics.renewal_count === 0;

  const displayName =
    user.email?.split("@")[0]?.replace(/[._]/g, " ") ?? "there";
  const greeting = greetingForNow();

  return (
    <>
      <section className="hero hero-friendly">
        <div>
          <p className="eyebrow">
            {greeting.toUpperCase()}
            {displayName ? ` · ${displayName}` : ""}
          </p>
          <h2>
            {isEmpty
              ? "Let's get your operation on the board."
              : "Here's what needs attention today."}
          </h2>
          <p>
            {isEmpty
              ? "Start with properties and customers, then schedule work and track issues from one place."
              : "The command center prioritizes exceptions, issues, renewals, dispatch, and follow-up work."}
          </p>
        </div>
        <div className="hero-cta">
          <Link className="primary" href={isEmpty ? "/properties" : "/work-orders"}>
            {isEmpty ? "Add your first property" : "Open work board"}
          </Link>
          <Link className="button" href="/targets">PM targets</Link>
        </div>
      </section>

      <section className="metrics" aria-label="Key counts">
        <Metric label="Properties" value={metrics.property_count} href="/properties" emptyHint="Add sites you service" />
        <Metric label="Work exceptions" value={metrics.open_work_count} href="/work-orders" emptyHint="No blockers" alert={metrics.open_work_count > 0} />
        <Metric label="Open issues" value={metrics.open_issue_count} href="/issues" emptyHint="All clear" alert={metrics.open_issue_count > 0} />
        <Metric label="Renewals due" value={metrics.renewal_count} href="/contracts" emptyHint="None upcoming" alert={metrics.renewal_count > 0} />
      </section>

      <section className="panel" style={{ marginBottom: 14 }}>
        <div className="panel-head">
          <div>
            <span className="eyebrow">ACTION OS</span>
            <h3>What to do next</h3>
          </div>
          <span className="muted">Snapshot updated {formatAge(metrics.updated_at)}</span>
        </div>
        {actions.length ? (
          <ul className="queue-list">
            {actions.map((action, index) => (
              <li key={`${action.action_type}-${action.entity_id}-${index}`}>
                <Link href={action.href}>
                  <strong>{action.title}</strong>
                  <span className="muted">
                    {action.action_type} · priority {action.priority_score}
                    {action.detail ? ` · ${action.detail}` : ""}
                  </span>
                </Link>
              </li>
            ))}
          </ul>
        ) : (
          <p className="muted empty-queue">
            No urgent actions. Assignment gaps, critical issues, renewals, PM follow-ups, and open tasks appear here automatically.
          </p>
        )}
      </section>

      {isEmpty ? (
        <section className="panel setup-panel">
          <div className="panel-head">
            <div>
              <span className="eyebrow">GETTING STARTED</span>
              <h3>Three steps to a useful command center</h3>
            </div>
          </div>
          <ol className="setup-steps">
            <li>
              <div><strong>Add properties &amp; customers</strong><p className="muted">Sites you service, who pays, and who manages the building.</p></div>
              <Link className="button" href="/properties">Open properties</Link>
            </li>
            <li>
              <div><strong>Create work orders</strong><p className="muted">Schedule, assign, and close jobs so nothing sits in email.</p></div>
              <Link className="button" href="/work-orders">Open work orders</Link>
            </li>
            <li>
              <div><strong>Build your PM target list</strong><p className="muted">Find property managers, log outreach, and convert conversations to leads.</p></div>
              <Link className="button" href="/targets">Open targets</Link>
            </li>
          </ol>
        </section>
      ) : (
        <section className="grid-two">
          <article className="panel">
            <div className="panel-head">
              <div><span className="eyebrow">NEEDS ATTENTION</span><h3>Work exceptions</h3></div>
              <Link href="/work-orders">View all</Link>
            </div>
            <QueueList
              empty="No open work exceptions."
              rows={(recentWork ?? []).map((r) => ({
                id: String(r.id),
                title: r.work_order_number ? `${r.work_order_number} — ${r.description ?? "Work order"}` : (r.description ?? "Work order"),
                meta: [r.status, r.priority, r.scheduled_start].filter(Boolean).join(" · "),
                href: `/work-orders/${r.id}`,
              }))}
            />
          </article>
          <article className="panel">
            <div className="panel-head">
              <div><span className="eyebrow">ISSUES</span><h3>Open issue queue</h3></div>
              <Link href="/issues">View all</Link>
            </div>
            <QueueList
              empty="No open issues."
              rows={(recentIssues ?? []).map((r) => ({
                id: String(r.id),
                title: String(r.title ?? "Issue"),
                meta: [r.issue_type, r.severity, r.status].filter(Boolean).join(" · "),
                href: `/issues/${r.id}`,
              }))}
            />
          </article>
        </section>
      )}

      <section className="panel" style={{ marginBottom: 14 }}>
        <div className="panel-head">
          <div><span className="eyebrow">TODAY</span><h3>Field control</h3></div>
          <Link href="/dispatch">Open dispatch →</Link>
        </div>
        <div className="checks" style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 10 }}>
          <div>Needs dispatch <strong>{metrics.needs_dispatch_count}</strong></div>
          <div>Open tasks <strong>{metrics.open_task_count}</strong></div>
          <div>Overdue tasks <strong>{metrics.overdue_task_count}</strong></div>
          <div>Open issues <strong>{metrics.open_issue_count}</strong></div>
        </div>
      </section>

      <section className="quick-actions" aria-label="Quick actions">
        <h3 className="section-label">Quick actions</h3>
        <div className="quick-grid">
          <Link className="quick-card" href="/properties"><strong>Properties</strong><span>Coverage and site notes</span></Link>
          <Link className="quick-card" href="/work-orders"><strong>Work orders</strong><span>Schedule and complete jobs</span></Link>
          <Link className="quick-card" href="/dispatch"><strong>Dispatch</strong><span>Who is where today</span></Link>
          <Link className="quick-card" href="/targets"><strong>PM targets</strong><span>Outreach and pipeline</span></Link>
          <Link className="quick-card" href="/sales"><strong>Sales</strong><span>Opportunities</span></Link>
          <Link className="quick-card" href="/contracts"><strong>Contracts</strong><span>Active and renewals</span></Link>
        </div>
      </section>
    </>
  );
}

function Metric({ label, value, href, emptyHint, alert }: {
  label: string; value: number; href: string; emptyHint: string; alert?: boolean;
}) {
  return (
    <Link className={`metric${alert && value > 0 ? " metric-alert" : ""}`} href={href}>
      <span>{label}</span>
      <strong>{value}</strong>
      <small>{value === 0 ? emptyHint : "Open →"}</small>
    </Link>
  );
}

function QueueList({ rows, empty }: {
  rows: { id: string; title: string; meta: string; href: string }[]; empty: string;
}) {
  if (!rows.length) return <p className="muted empty-queue">{empty}</p>;
  return (
    <ul className="queue-list">
      {rows.map((r) => (
        <li key={r.id}>
          <Link href={r.href}><strong>{r.title}</strong><span className="muted">{r.meta}</span></Link>
        </li>
      ))}
    </ul>
  );
}

function formatAge(value: string) {
  const date = new Date(value);
  if (!Number.isFinite(date.getTime())) return "not available";
  const seconds = Math.max(0, Math.round((Date.now() - date.getTime()) / 1000));
  if (seconds < 60) return "just now";
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  return `${Math.round(minutes / 60)}h ago`;
}

function greetingForNow() {
  const h = new Date().getHours();
  if (h < 12) return "Good morning";
  if (h < 17) return "Good afternoon";
  return "Good evening";
}

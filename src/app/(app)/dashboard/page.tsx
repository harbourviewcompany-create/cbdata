import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { getWorkspaceContext } from "@/lib/workspace";

export default async function DashboardPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const params = await searchParams;
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

  if (params.no_workspace === "1" && !ctx) {
    /* handled above */
  }

  const supabase = await createClient();
  const { workspaceId, user } = ctx;

  const [properties, work, issues, renewals, recentWork, recentIssues] =
    await Promise.all([
      supabase
        .from("property_360")
        .select("id", { count: "exact", head: true })
        .eq("workspace_id", workspaceId),
      supabase
        .from("open_work_exceptions")
        .select("id", { count: "exact", head: true })
        .eq("workspace_id", workspaceId),
      supabase
        .from("open_issue_queue")
        .select("id", { count: "exact", head: true })
        .eq("workspace_id", workspaceId),
      supabase
        .from("contract_renewal_queue")
        .select("id", { count: "exact", head: true })
        .eq("workspace_id", workspaceId),
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
    ]);

  const propertyCount = properties.count ?? 0;
  const workCount = work.count ?? 0;
  const issueCount = issues.count ?? 0;
  const renewalCount = renewals.count ?? 0;
  const isEmpty =
    propertyCount === 0 &&
    workCount === 0 &&
    issueCount === 0 &&
    renewalCount === 0;

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
              : workCount + issueCount > 0
                ? "Here's what needs attention today."
                : "You're clear on exceptions — keep coverage tight."}
          </h2>
          <p>
            {isEmpty
              ? "Start with properties and customers, then schedule work and track issues from one place."
              : "Exceptions, open issues, and upcoming renewals surface here before they become misses."}
          </p>
        </div>
        <div className="hero-cta">
          {isEmpty ? (
            <Link className="primary" href="/properties">
              Add your first property
            </Link>
          ) : (
            <Link className="primary" href="/work-orders">
              Open work board
            </Link>
          )}
          <Link className="button" href="/targets">
            PM targets
          </Link>
        </div>
      </section>

      <section className="metrics" aria-label="Key counts">
        <Metric
          label="Properties"
          value={propertyCount}
          href="/properties"
          emptyHint="Add sites you service"
        />
        <Metric
          label="Work exceptions"
          value={workCount}
          href="/work-orders"
          emptyHint="No blockers"
          alert={workCount > 0}
        />
        <Metric
          label="Open issues"
          value={issueCount}
          href="/issues"
          emptyHint="All clear"
          alert={issueCount > 0}
        />
        <Metric
          label="Renewals due"
          value={renewalCount}
          href="/contracts"
          emptyHint="None upcoming"
          alert={renewalCount > 0}
        />
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
              <div>
                <strong>Add properties &amp; customers</strong>
                <p className="muted">
                  Sites you service, who pays, and who manages the building.
                </p>
              </div>
              <Link className="button" href="/properties">
                Open properties
              </Link>
            </li>
            <li>
              <div>
                <strong>Create work orders</strong>
                <p className="muted">
                  Schedule, assign, and close jobs so nothing sits in email.
                </p>
              </div>
              <Link className="button" href="/work-orders">
                Open work orders
              </Link>
            </li>
            <li>
              <div>
                <strong>Build your PM target list</strong>
                <p className="muted">
                  Find property managers, log outreach, convert conversations to
                  leads.
                </p>
              </div>
              <Link className="button" href="/targets">
                Open targets
              </Link>
            </li>
          </ol>
        </section>
      ) : (
        <section className="grid-two">
          <article className="panel">
            <div className="panel-head">
              <div>
                <span className="eyebrow">NEEDS ATTENTION</span>
                <h3>Work exceptions</h3>
              </div>
              <Link href="/work-orders">View all</Link>
            </div>
            <QueueList
              empty="No open work exceptions. New jobs and delays will show up here."
              rows={(recentWork.data ?? []).map((r) => {
                const num = (r as { work_order_number?: string }).work_order_number;
                const desc = (r as { description?: string }).description;
                return {
                  id: String(r.id),
                  title: num ? `${num} — ${desc ?? "Work order"}` : (desc ?? "Work order"),
                  meta: [r.status, r.priority, (r as { scheduled_start?: string }).scheduled_start]
                    .filter(Boolean)
                    .join(" · "),
                  href: "/work-orders",
                };
              })}
            />
          </article>
          <article className="panel">
            <div className="panel-head">
              <div>
                <span className="eyebrow">ISSUES</span>
                <h3>Open issue queue</h3>
              </div>
              <Link href="/issues">View all</Link>
            </div>
            <QueueList
              empty="No open issues. Customer complaints and field problems will land here."
              rows={(recentIssues.data ?? []).map((r) => ({
                id: String(r.id),
                title: String(r.title ?? "Issue"),
                meta: [
                  (r as { issue_type?: string }).issue_type,
                  r.severity,
                  r.status,
                ]
                  .filter(Boolean)
                  .join(" · "),
                href: "/issues",
              }))}
            />
          </article>
        </section>
      )}

      <section className="quick-actions" aria-label="Quick actions">
        <h3 className="section-label">Quick actions</h3>
        <div className="quick-grid">
          <Link className="quick-card" href="/properties">
            <strong>Properties</strong>
            <span>Coverage and site notes</span>
          </Link>
          <Link className="quick-card" href="/work-orders">
            <strong>Work orders</strong>
            <span>Schedule and complete jobs</span>
          </Link>
          <Link className="quick-card" href="/dispatch">
            <strong>Dispatch</strong>
            <span>Who is where today</span>
          </Link>
          <Link className="quick-card" href="/targets">
            <strong>PM targets</strong>
            <span>Outreach and pipeline</span>
          </Link>
          <Link className="quick-card" href="/sales">
            <strong>Sales</strong>
            <span>Opportunities</span>
          </Link>
          <Link className="quick-card" href="/contracts">
            <strong>Contracts</strong>
            <span>Active and renewals</span>
          </Link>
        </div>
      </section>
    </>
  );
}

function Metric({
  label,
  value,
  href,
  emptyHint,
  alert,
}: {
  label: string;
  value: number;
  href: string;
  emptyHint: string;
  alert?: boolean;
}) {
  return (
    <Link
      className={`metric${alert && value > 0 ? " metric-alert" : ""}`}
      href={href as never}
    >
      <span>{label}</span>
      <strong>{value}</strong>
      <small>{value === 0 ? emptyHint : "Open →"}</small>
    </Link>
  );
}

function QueueList({
  rows,
  empty,
}: {
  rows: { id: string; title: string; meta: string; href: string }[];
  empty: string;
}) {
  if (!rows.length) return <p className="muted empty-queue">{empty}</p>;
  return (
    <ul className="queue-list">
      {rows.map((r) => (
        <li key={r.id}>
          <Link href={r.href as never}>
            <strong>{r.title}</strong>
            <span className="muted">{r.meta}</span>
          </Link>
        </li>
      ))}
    </ul>
  );
}

function greetingForNow() {
  const h = new Date().getHours();
  if (h < 12) return "Good morning";
  if (h < 17) return "Good afternoon";
  return "Good evening";
}

import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export default async function DashboardPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const { data: memberships } = await supabase
    .from("workspace_memberships")
    .select("workspace_id, role, workspaces(id,name,status)")
    .eq("user_id", user.id);

  const workspace = memberships?.[0]?.workspaces;
  const workspaceId = Array.isArray(workspace) ? workspace[0]?.id : workspace?.id;
  if (!workspaceId) {
    return <main className="empty-shell"><h1>No workspace access</h1><p>Contact a CBData administrator to be added to a workspace.</p></main>;
  }

  const [properties, work, issues, renewals] = await Promise.all([
    supabase.from("property_360").select("id", { count: "exact", head: true }).eq("workspace_id", workspaceId),
    supabase.from("open_work_exceptions").select("id", { count: "exact", head: true }).eq("workspace_id", workspaceId),
    supabase.from("open_issue_queue").select("id", { count: "exact", head: true }).eq("workspace_id", workspaceId),
    supabase.from("contract_renewal_queue").select("id", { count: "exact", head: true }).eq("workspace_id", workspaceId),
  ]);

  return (
    <main className="app-shell">
      <aside className="sidebar">
        <div className="brand"><span>CB</span><div><strong>CBData</strong><small>OPERATIONS</small></div></div>
        <nav>
          <Link className="active" href="/dashboard">Command</Link>
          <Link href="/properties">Properties</Link>
          <Link href="/work-orders">Work orders</Link>
          <Link href="/issues">Issues</Link>
          <Link href="/sales">Sales</Link>
          <Link href="/contracts">Contracts</Link>
        </nav>
      </aside>
      <section className="workspace">
        <header className="topbar">
          <div><span className="eyebrow">OPERATIONS COMMAND</span><h1>{Array.isArray(workspace) ? workspace[0]?.name : workspace?.name}</h1></div>
          <div className="user-pill">{user.email}</div>
        </header>
        <div className="content">
          <section className="hero"><div><p className="eyebrow">LIVE CONTROL SURFACE</p><h2>Run the business from the work in front of you.</h2><p>Operational exceptions, property coverage, issues and renewals are surfaced before they become misses.</p></div><Link className="primary compact" href="/work-orders">Open work board</Link></section>
          <section className="metrics">
            <Metric label="Properties" value={properties.count ?? 0} href="/properties" />
            <Metric label="Work exceptions" value={work.count ?? 0} href="/work-orders" />
            <Metric label="Open issues" value={issues.count ?? 0} href="/issues" />
            <Metric label="Renewals" value={renewals.count ?? 0} href="/contracts" />
          </section>
          <section className="grid-two">
            <article className="panel"><div className="panel-head"><div><span className="eyebrow">NEXT CONTROL</span><h3>Operational queue</h3></div><Link href="/work-orders">View all</Link></div><p className="muted">The next build step is to turn these live queues into executable workflows: assign, schedule, dispatch, prove completion, review and close.</p></article>
            <article className="panel"><div className="panel-head"><div><span className="eyebrow">DATA FOUNDATION</span><h3>Canonical backend connected</h3></div></div><ul className="checks"><li>Workspace-scoped access</li><li>RLS enforced</li><li>Operational views</li><li>Typed database contract</li></ul></article>
          </section>
        </div>
      </section>
    </main>
  );
}

function Metric({label,value,href}:{label:string;value:number;href:string}) {
  return <Link className="metric" href={href as any}><span>{label}</span><strong>{value}</strong><small>Open →</small></Link>;
}
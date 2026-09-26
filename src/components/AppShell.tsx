import Link from "next/link";
import { SidebarNav } from "@/components/SidebarNav";

export function AppShell({
  children,
  workspaceName,
  userEmail,
  role,
  title,
  eyebrow = "OPERATIONS",
  actions,
}: {
  children: React.ReactNode;
  workspaceName: string;
  userEmail?: string | null;
  role?: string | null;
  title?: string;
  eyebrow?: string;
  actions?: React.ReactNode;
}) {
  return (
    <main className="app-shell">
      <aside className="sidebar">
        <div className="brand">
          <span>CB</span>
          <div>
            <strong>CBData</strong>
            <small>OPERATIONS</small>
          </div>
        </div>
        <SidebarNav />
        <div className="sidebar-foot">
          {userEmail ? (
            <div className="user-pill sidebar-user" title={userEmail}>
              {userEmail}
            </div>
          ) : null}
          {role ? (
            <span className="role-chip">{role.replace(/_/g, " ")}</span>
          ) : null}
          <form action="/auth/signout" method="post" className="signout-form">
            <button type="submit" className="button signout-btn">
              Sign out
            </button>
          </form>
        </div>
      </aside>
      <section className="workspace">
        <header className="topbar">
          <div>
            <span className="eyebrow">{eyebrow}</span>
            <h1>{title ?? workspaceName}</h1>
          </div>
          <div className="topbar-actions">
            {actions}
            <Link className="button" href="/properties">
              Properties
            </Link>
            <Link className="primary compact" href="/work-orders">
              Work board
            </Link>
          </div>
        </header>
        <div className="content">{children}</div>
      </section>
    </main>
  );
}

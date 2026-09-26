import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getWorkspaceContext } from "@/lib/workspace";

export default async function IssueDetail({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const ctx = await getWorkspaceContext();
  if (!ctx) redirect("/login");
  const supabase = await createClient();
  const { data: row } = await supabase
    .from("issues")
    .select("id, title, description, status, severity, issue_type, reported_at, due_at, resolution_notes")
    .eq("id", id)
    .eq("workspace_id", ctx.workspaceId)
    .maybeSingle();
  if (!row) notFound();

  return (
    <>
      <header className="page-intro">
        <div>
          <span className="eyebrow">ISSUE</span>
          <h1>{row.title}</h1>
          <p className="muted">{row.description}</p>
        </div>
        <Link className="button" href="/issues">
          Back to queue
        </Link>
      </header>
      <section className="panel">
        <dl className="checks" style={{ display: "grid", gap: 10 }}>
          <div>Type <strong>{row.issue_type}</strong></div>
          <div>Severity <strong>{row.severity}</strong></div>
          <div>Status <strong>{row.status}</strong></div>
          <div>Reported <strong>{row.reported_at}</strong></div>
          <div>Due <strong>{row.due_at ?? "—"}</strong></div>
        </dl>
        {row.resolution_notes ? (
          <p className="muted" style={{ marginTop: 12 }}>
            {row.resolution_notes}
          </p>
        ) : null}
      </section>
    </>
  );
}

import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getWorkspaceContext } from "@/lib/workspace";

export default async function TargetDetail({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const ctx = await getWorkspaceContext();
  if (!ctx) redirect("/login");
  const supabase = await createClient();
  const { data: row } = await supabase
    .from("outreach_targets")
    .select(
      "id, status, score, next_action, next_action_due_at, last_touch_at, organization_name, contact_name, notes",
    )
    .eq("id", id)
    .eq("workspace_id", ctx.workspaceId)
    .maybeSingle();
  if (!row) notFound();

  return (
    <>
      <header className="page-intro">
        <div>
          <span className="eyebrow">PM TARGET</span>
          <h1>{row.organization_name ?? row.contact_name ?? "Target"}</h1>
          <p className="muted">{row.next_action ?? "No next action"}</p>
        </div>
        <Link className="button" href="/targets">
          Back to targets
        </Link>
      </header>
      <section className="panel">
        <dl className="checks" style={{ display: "grid", gap: 10 }}>
          <div>Status <strong>{row.status}</strong></div>
          <div>Score <strong>{row.score ?? "—"}</strong></div>
          <div>Due <strong>{row.next_action_due_at ?? "—"}</strong></div>
          <div>Last touch <strong>{row.last_touch_at ?? "—"}</strong></div>
        </dl>
        {row.notes ? <p className="muted" style={{ marginTop: 12 }}>{row.notes}</p> : null}
      </section>
    </>
  );
}

import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getWorkspaceContext } from "@/lib/workspace";

export default async function WorkOrderDetail({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const ctx = await getWorkspaceContext();
  if (!ctx) redirect("/login");
  const supabase = await createClient();
  const { data: row } = await supabase
    .from("work_orders")
    .select(
      "id, work_order_number, status, priority, scheduled_start, scheduled_end, description, site_instructions, property_id, completed_at",
    )
    .eq("id", id)
    .eq("workspace_id", ctx.workspaceId)
    .maybeSingle();
  if (!row) notFound();

  return (
    <>
      <header className="page-intro">
        <div>
          <span className="eyebrow">WORK ORDER</span>
          <h1>{row.work_order_number}</h1>
          <p className="muted">{row.description}</p>
        </div>
        <Link className="button" href="/work-orders">
          Back to board
        </Link>
      </header>
      <section className="panel">
        <dl className="checks" style={{ display: "grid", gap: 10 }}>
          <div>Status <strong>{row.status}</strong></div>
          <div>Priority <strong>{row.priority}</strong></div>
          <div>Start <strong>{row.scheduled_start ?? "—"}</strong></div>
          <div>End <strong>{row.scheduled_end ?? "—"}</strong></div>
          <div>Completed <strong>{row.completed_at ?? "—"}</strong></div>
        </dl>
        {row.site_instructions ? (
          <p className="muted" style={{ marginTop: 12 }}>
            {row.site_instructions}
          </p>
        ) : null}
      </section>
    </>
  );
}

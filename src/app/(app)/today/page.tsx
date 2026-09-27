import Link from "next/link";
import type { Route } from "next";
import { requireWorkspace } from "@/lib/workspace";
import { createClient } from "@/lib/supabase/server";
import { startWorkOrder, completeWorkOrder } from "../work-orders/actions";
import { uploadWorkOrderPhoto } from "./actions";
import { loadPhotoStrips, PhotoStripView } from "@/components/PhotoStrip";

export default async function TodayPage() {
  const ctx = await requireWorkspace();
  const s = await createClient();
  const start = new Date();
  start.setHours(0, 0, 0, 0);
  const end = new Date(start);
  end.setDate(end.getDate() + 1);

  const { data: rows } = await s
    .from("work_orders")
    .select("id,work_order_number,status,priority,scheduled_start,description,property_id")
    .eq("workspace_id", ctx.workspaceId)
    .gte("scheduled_start", start.toISOString())
    .lt("scheduled_start", end.toISOString())
    .neq("status", "cancelled")
    .order("scheduled_start");

  const jobs = rows ?? [];
  const propertyIds = Array.from(new Set(jobs.map((r) => r.property_id).filter(Boolean) as string[]));
  const jobIds = jobs.map((r) => r.id);

  const [{ data: props }, photoMap] = await Promise.all([
    propertyIds.length
      ? s.from("properties").select("id,name,address_line_1").in("id", propertyIds)
      : Promise.resolve({ data: [] as { id: string; name: string; address_line_1: string }[] }),
    loadPhotoStrips({
      workspaceId: ctx.workspaceId,
      entityType: "work_order",
      entityIds: jobIds,
      perEntity: 3,
    }),
  ]);

  const propById = new Map((props ?? []).map((p) => [p.id, p]));

  return (
    <>
      <header className="page-intro">
        <div>
          <span className="eyebrow">FIELD</span>
          <h1>Today</h1>
          <p className="muted">Jobs on the board for this calendar day. Start, photo, complete.</p>
        </div>
        <Link className="button" href={"/work-orders" as Route}>Full board</Link>
      </header>
      <section className="table-panel">
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Job</th>
                <th>Site</th>
                <th>When</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {jobs.map((r) => {
                const p = r.property_id ? propById.get(r.property_id) : undefined;
                return (
                  <tr key={r.id}>
                    <td>
                      <Link href={`/work-orders/${r.id}` as Route}>{r.work_order_number}</Link>
                      <div className="muted">{r.description}</div>
                    </td>
                    <td>{p ? `${p.name} · ${p.address_line_1}` : "\u2014"}</td>
                    <td>{r.scheduled_start ?? "\u2014"}</td>
                    <td>{r.status} · {r.priority}</td>
                    <td>
                      <div className="actions">
                        {["scheduled", "assigned", "en_route"].includes(r.status) ? (
                          <form action={startWorkOrder}>
                            <input type="hidden" name="id" value={r.id} />
                            <button>Start</button>
                          </form>
                        ) : null}
                        <form action={uploadWorkOrderPhoto}>
                          <input type="hidden" name="work_order_id" value={r.id} />
                          <input type="file" name="file" accept="image/jpeg,image/png,image/webp,image/heic" required />
                          <button>Upload photo</button>
                        </form>
                        <PhotoStripView photos={photoMap.get(r.id)} />
                        {r.status === "in_progress" ? (
                          <form action={completeWorkOrder}>
                            <input type="hidden" name="id" value={r.id} />
                            <input name="notes" placeholder="Completion notes" />
                            <button>Complete</button>
                          </form>
                        ) : null}
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
        {!jobs.length ? <p className="muted empty-queue">No jobs scheduled today.</p> : null}
      </section>
    </>
  );
}

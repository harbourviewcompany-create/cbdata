import { redirect } from "next/navigation";
import Link from "next/link";
import type { Route } from "next";
import { createClient } from "@/lib/supabase/server";
import { getWorkspaceContext } from "@/lib/workspace";
import { convertEstimate } from "./actions";

export default async function EstimatesPage() {
  const ctx = await getWorkspaceContext();
  if (!ctx) redirect("/login");
  const canManage = ["owner", "administrator", "sales_manager", "sales_rep"].includes(ctx.role ?? "");
  const s = await createClient();
  const [{ data: rows }, { data: orgs }] = await Promise.all([
    s
      .from("estimates")
      .select(
        "id,estimate_number,status,total,valid_until,organization_id,property_id,opportunity_id,sent_at",
      )
      .eq("workspace_id", ctx.workspaceId)
      .order("created_at", { ascending: false })
      .limit(200),
    s.from("organizations").select("id,legal_name,operating_name").eq("workspace_id", ctx.workspaceId),
  ]);

  const orgName = (id: string) => {
    const o = orgs?.find((x) => x.id === id);
    return o?.operating_name ?? o?.legal_name ?? "\u2014";
  };

  return (
    <>
      <header className="page-intro">
        <div>
          <span className="eyebrow">GROWTH</span>
          <h1>Estimates</h1>
          <p className="muted">Review quotes and convert accepted estimates into contracts.</p>
        </div>
        {canManage ? <Link className="button" href="/estimates/new">Price a deck job</Link> : null}
      </header>
      <section className="table-panel">
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Estimate</th>
                <th>Customer</th>
                <th>Status</th>
                <th>Total</th>
                <th>Valid until</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {(rows ?? []).length ? (
                rows!.map((r) => (
                  <tr key={r.id}>
                    <td>
                      <Link href={`/estimates/${r.id}` as Route}>{r.estimate_number}</Link>
                    </td>
                    <td>{orgName(r.organization_id)}</td>
                    <td>{r.status}</td>
                    <td>
                      {Number(r.total).toLocaleString("en-CA", {
                        style: "currency",
                        currency: "CAD",
                      })}
                    </td>
                    <td>{r.valid_until ?? "\u2014"}</td>
                    <td>
                      {canManage && r.status === "accepted" ? (
                        <form action={convertEstimate}>
                          <input type="hidden" name="id" value={r.id} />
                          <button type="submit">Convert to contract</button>
                        </form>
                      ) : null}
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={6} className="muted">
                    No estimates yet. Price a deck job to create the first draft.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>
    </>
  );
}

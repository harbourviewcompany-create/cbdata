import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getWorkspaceContext } from "@/lib/workspace";

export default async function ContractDetail({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const ctx = await getWorkspaceContext();
  if (!ctx) redirect("/login");
  const supabase = await createClient();
  const { data: row } = await supabase
    .from("contracts")
    .select("id, contract_number, name, status, start_date, end_date, contract_value")
    .eq("id", id)
    .eq("workspace_id", ctx.workspaceId)
    .maybeSingle();
  if (!row) notFound();

  return (
    <>
      <header className="page-intro">
        <div>
          <span className="eyebrow">CONTRACT</span>
          <h1>{row.name}</h1>
          <p className="muted">{row.contract_number}</p>
        </div>
        <Link className="button" href="/contracts">
          Back to contracts
        </Link>
      </header>
      <section className="panel">
        <dl className="checks" style={{ display: "grid", gap: 10 }}>
          <div>Status <strong>{row.status}</strong></div>
          <div>Start <strong>{row.start_date ?? "—"}</strong></div>
          <div>End <strong>{row.end_date ?? "—"}</strong></div>
          <div>Value <strong>{row.contract_value ?? "—"}</strong></div>
        </dl>
      </section>
    </>
  );
}

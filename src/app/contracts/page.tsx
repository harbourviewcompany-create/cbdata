import { redirect } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/server";

export default async function ContractsPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");
  const { data, error } = await supabase.from("contract_renewal_queue").select("id,contract_number,name,status,start_date,end_date,contract_value,billing_frequency,renewal_type").order("end_date").limit(100);
  return <main className="list-shell"><header className="list-header"><div><Link className="back" href="/dashboard">← Command</Link><span className="eyebrow">REVENUE RETENTION</span><h1>Contract renewals</h1></div><span className="count">{data?.length ?? 0} shown</span></header><section className="table-panel">{error?<p className="error">{error.message}</p>:!data?.length?<p className="muted">No renewal records are available to this workspace.</p>:<div className="table-wrap"><table><thead><tr>{["Contract","Name","Status","Start","End","Value","Billing","Renewal"].map(x=><th key={x}>{x}</th>)}</tr></thead><tbody>{data.map(row=><tr key={row.id}><td>{row.contract_number}</td><td>{row.name}</td><td>{row.status}</td><td>{row.start_date}</td><td>{row.end_date}</td><td>{row.contract_value ?? "—"}</td><td>{row.billing_frequency ?? "—"}</td><td>{row.renewal_type ?? "—"}</td></tr>)}</tbody></table></div>}</section></main>;
}
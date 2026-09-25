import { redirect } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/server";

export default async function IssuesPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");
  const { data, error } = await supabase.from("open_issue_queue").select("id,title,issue_type,severity,status,reported_at,due_at,customer_visible").order("severity",{ascending:false}).limit(100);
  return <Queue title="Issue queue" eyebrow="EXCEPTIONS & QUALITY" rows={data ?? []} error={error?.message} columns={[
    ["title","Issue"],["issue_type","Type"],["severity","Severity"],["status","Status"],["reported_at","Reported"],["due_at","Due"],["customer_visible","Customer visible"]
  ]} />;
}

function Queue({title,eyebrow,rows,error,columns}:{title:string;eyebrow:string;rows:Record<string,unknown>[];error?:string;columns:[string,string][]}) {
  return <main className="list-shell"><header className="list-header"><div><Link className="back" href="/dashboard">← Command</Link><span className="eyebrow">{eyebrow}</span><h1>{title}</h1></div><span className="count">{rows.length} open</span></header><section className="table-panel">{error?<p className="error">{error}</p>:rows.length===0?<p className="muted">No open issues.</p>:<div className="table-wrap"><table><thead><tr>{columns.map(([,label])=><th key={label}>{label}</th>)}</tr></thead><tbody>{rows.map((row,i)=><tr key={String(row.id ?? i)}>{columns.map(([key])=><td key={key}>{String(row[key] ?? "—")}</td>)}</tr>)}</tbody></table></div>}</section></main>;
}
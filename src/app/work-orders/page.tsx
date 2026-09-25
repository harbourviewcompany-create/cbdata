import { redirect } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/server";

export default async function WorkOrdersPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");
  const { data, error } = await supabase.from("open_work_exceptions").select("id,work_order_number,source_type,priority,status,scheduled_start,estimated_duration_minutes,description").order("scheduled_start",{ascending:true,nullsFirst:false}).limit(100);
  return <Queue title="Work exceptions" eyebrow="FIELD OPERATIONS" rows={data ?? []} error={error?.message} columns={[
    ["work_order_number","Work order"],["priority","Priority"],["status","Status"],["scheduled_start","Scheduled"],["estimated_duration_minutes","Est. min"],["description","Description"]
  ]} />;
}

function Queue({title,eyebrow,rows,error,columns}:{title:string;eyebrow:string;rows:Record<string,unknown>[];error?:string;columns:[string,string][]}) {
  return <main className="list-shell"><header className="list-header"><div><Link className="back" href="/dashboard">← Command</Link><span className="eyebrow">{eyebrow}</span><h1>{title}</h1></div><span className="count">{rows.length} open</span></header><section className="table-panel">{error?<p className="error">{error}</p>:rows.length===0?<p className="muted">No open work exceptions.</p>:<div className="table-wrap"><table><thead><tr>{columns.map(([,label])=><th key={label}>{label}</th>)}</tr></thead><tbody>{rows.map((row,i)=><tr key={String(row.id ?? i)}>{columns.map(([key])=><td key={key}>{String(row[key] ?? "—")}</td>)}</tr>)}</tbody></table></div>}</section></main>;
}
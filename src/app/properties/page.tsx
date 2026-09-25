import { redirect } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/server";

export default async function PropertiesPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");
  const { data, error } = await supabase.from("property_360").select("id,name,address_line_1,city,province,postal_code,status,customer_name,active_contracts,open_work_orders,open_issues").order("name").limit(100);
  return <ListPage title="Properties" eyebrow="PROPERTY CONTROL" href="/dashboard" rows={data ?? []} error={error?.message} columns={[
    ["name","Property"],["customer_name","Customer"],["city","City"],["status","Status"],["active_contracts","Contracts"],["open_work_orders","Work"],["open_issues","Issues"]
  ]} />;
}

function ListPage({title,eyebrow,href,rows,error,columns}:{title:string;eyebrow:string;href:string;rows:Record<string,unknown>[];error?:string;columns:[string,string][]}) {
  return <main className="list-shell"><header className="list-header"><div><Link className="back" href={href}>← Command</Link><span className="eyebrow">{eyebrow}</span><h1>{title}</h1></div><span className="count">{rows.length} shown</span></header><section className="table-panel">{error ? <p className="error">{error}</p> : rows.length===0 ? <p className="muted">No records are available to this workspace yet.</p> : <div className="table-wrap"><table><thead><tr>{columns.map(([,label])=><th key={label}>{label}</th>)}</tr></thead><tbody>{rows.map((row,i)=><tr key={String(row.id ?? i)}>{columns.map(([key])=><td key={key}>{String(row[key] ?? "—")}</td>)}</tr>)}</tbody></table></div>}</section></main>;
}
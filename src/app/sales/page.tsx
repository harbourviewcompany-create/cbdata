import { redirect } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { transitionOpportunity } from "./actions";
const nextStage: Record<string,string>={new:"qualified",qualified:"site_visit",site_visit:"estimating",estimating:"proposal",proposal:"negotiation",negotiation:"won"};
export default async function SalesPage(){
const s=await createClient(); const {data:{user}}=await s.auth.getUser(); if(!user) redirect("/login");
const {data:rows}=await s.from("opportunities").select("id,name,stage,status,estimated_value,estimated_close_date,probability").eq("status","open").order("estimated_close_date",{ascending:true,nullsFirst:false}).limit(100);
return <main className="list-shell"><header className="list-header"><div><Link className="back" href="/dashboard">← Command</Link><span className="eyebrow">SALES PIPELINE</span><h1>Opportunities</h1></div></header><section className="table-panel"><div className="table-wrap"><table><thead><tr><th>Opportunity</th><th>Stage</th><th>Value</th><th>Close</th><th>Probability</th><th>Action</th></tr></thead><tbody>{rows?.map(r=><tr key={r.id}><td>{r.name}</td><td><span className="badge">{r.stage}</span></td><td>{r.estimated_value}</td><td>{r.estimated_close_date??"—"}</td><td>{r.probability??"—"}%</td><td><form action={transitionOpportunity} className="actions">{nextStage[r.stage]&&<><input type="hidden" name="id" value={r.id}/><input type="hidden" name="stage" value={nextStage[r.stage]}/><button>Advance</button></>}{r.stage!=="lost"&&<><input type="hidden" name="id" value={r.id}/><input type="hidden" name="stage" value="lost"/><button>Mark lost</button></>}</form></td></tr>)}</tbody></table></div></section></main>;
}
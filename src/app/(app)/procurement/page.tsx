/* eslint-disable @typescript-eslint/no-explicit-any */
import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { requireWorkspace } from "@/lib/workspace";
import { runCanadaBuysScout } from "./actions";
import "./procurement.css";

function fmtDate(value:string|null){ if(!value) return "—"; return new Date(value).toLocaleDateString("en-CA",{year:"numeric",month:"short",day:"numeric"}); }
function daysLeft(value:string|null){ if(!value) return null; const end=new Date(value+"T23:59:59Z").getTime(); return Math.ceil((end-Date.now())/86400000); }
function urgencyLabel(value:string|null){ const d=daysLeft(value); if(d===null) return "no deadline"; if(d<0) return "closed"; if(d===0) return "closes today"; if(d===1) return "1 day"; return `${d} days`; }

export default async function ProcurementPage(){
  const ctx=await requireWorkspace();
  const s=await createClient();

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const {data:tenders}=await (s as any).from("tender_records").select("id,external_id,title,buyer_name,category,region,published_date,closing_date,source_url,status,matched_organization_id,lead_id,response_mode,registration_required,fit_score,fit_note,last_verified_at,action_state,next_action,next_action_due_at").eq("workspace_id",ctx.workspaceId).eq("source","CanadaBuys").order("closing_date",{ascending:true}).limit(100);
  const leadIds=(tenders??[]).map((t:any)=>t.lead_id).filter(Boolean);
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const {data:leadRows}=await (s as any).from("leads").select("id,contact_id,property_id").eq("workspace_id",ctx.workspaceId).in("id",leadIds.length?leadIds:["00000000-0000-0000-0000-000000000000"]);
  const contactIds=(leadRows??[]).map((x:any)=>x.contact_id).filter(Boolean);
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const {data:contacts}=await (s as any).from("contacts").select("id,first_name,last_name,job_title,email,phone,mobile,source_url,source_label,source_confidence").eq("workspace_id",ctx.workspaceId).in("id",contactIds.length?contactIds:["00000000-0000-0000-0000-000000000000"]);
  const contactByLead=new Map<string, { first_name:string|null; last_name:string|null; job_title:string|null; email:string|null; phone:string|null; mobile:string|null; source_url:string|null; source_label:string|null; source_confidence:string|null } | undefined>((leadRows??[]).map((x:any)=>[x.id,(contacts??[]).find((c:any)=>c.id===x.contact_id) as { first_name:string|null; last_name:string|null; job_title:string|null; email:string|null; phone:string|null; mobile:string|null; source_url:string|null; source_label:string|null; source_confidence:string|null } | undefined]));
  const {data:tenderProperties}=await (s as any).from("tender_properties").select("tender_record_id,property_id,scope_note,evidence_url,evidence_label,source_confidence").eq("workspace_id",ctx.workspaceId).in("tender_record_id",(tenders??[]).map((t:any)=>t.id).length?(tenders??[]).map((t:any)=>t.id):["00000000-0000-0000-0000-000000000000"]);
  const propertyIds=(tenderProperties??[]).map((x:any)=>x.property_id).filter(Boolean);
  const {data:properties}=await (s as any).from("properties").select("id,name,address_line_1,city,province,property_type").eq("workspace_id",ctx.workspaceId).in("id",propertyIds.length?propertyIds:["00000000-0000-0000-0000-000000000000"]);
  const propertyById=new Map((properties??[]).map((p:any)=>[p.id,p]));
  const propertiesByTender=new Map<string,any[]>();
  for(const row of tenderProperties??[]){ const p=propertyById.get(row.property_id); if(p) propertiesByTender.set(row.tender_record_id,[...(propertiesByTender.get(row.tender_record_id)??[]),{...p,...row}]); }
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const {data:runs}=await (s as any).from("canadabuys_runs").select("id,started_at,finished_at,status,fetched_count,qualifying_count,inserted_count,updated_count,lead_created_count,error_count,error_message").eq("workspace_id",ctx.workspaceId).order("started_at",{ascending:false}).limit(8);

  const open=(tenders??[]).filter((t:any)=>t.closing_date && new Date(t.closing_date+"T23:59:59Z")>=new Date());
  const registration=open.filter((t:any)=>t.registration_required).length;
  const formal=open.filter((t:any)=>["formal_rfp","formal_tender","registration_required"].includes(t.response_mode)).length;
  const actionCount=open.filter((t:any)=>t.next_action).length;
  const propertyCoverage=open.filter((t:any)=>(propertiesByTender.get(t.id)??[]).length).length;

  return <main className="list-shell">
    <header className="list-header"><Link className="back" href="/dashboard">← Command</Link><span className="eyebrow">GROWTH / PROCUREMENT</span><h1>CanadaBuys Scout</h1><p className="muted" style={{maxWidth:760,marginTop:8}}>Live prospecting for Ottawa / National Capital Region grounds, landscaping, snow, maintenance, janitorial, cleaning, facility, property, repair and caretaking notices. Results are deduplicated against existing tender records and linked to buyer organizations, leads, contacts and property intelligence.</p></header>

    <section className="metrics" style={{marginBottom:18}}>
      <div className="metric"><span>Open notices</span><strong>{open.length}</strong></div>
      <div className="metric"><span>Formal response</span><strong>{formal}</strong></div>
      <div className="metric"><span>Registration flags</span><strong>{registration}</strong></div>
      <div className="metric"><span>Property coverage</span><strong>{propertyCoverage}</strong></div>
    </section>

    <section className="panel" style={{marginBottom:18}}>
      <div className="panel-head"><div><span className="eyebrow">SOURCE CONTROL</span><h3>Run CanadaBuys Scout</h3></div></div>
      <p className="muted" style={{marginTop:8}}>Checks the current CanadaBuys tender index across the configured service terms, verifies candidate notice pages, and writes only open NCR matches.</p>
      <form action={runCanadaBuysScout} style={{marginTop:14}}><button className="primary" type="submit">Run live scout</button></form>
    </section>

    <section className="table-panel" style={{marginBottom:18}}>
      <div className="panel-head"><div><span className="eyebrow">OPEN PIPELINE</span><h3>Qualifying CanadaBuys notices</h3></div><span className="muted">{actionCount} with active next action</span></div>
      <div className="table-wrap"><div className="targets-grid procurement-grid">
        <div className="targets-grid-row targets-grid-head"><div>Close</div><div>Notice</div><div>Buyer</div><div>Fit</div><div>Coverage</div><div>Action</div></div>
        {open.length===0 ? <div className="targets-grid-row"><div className="muted">No open qualifying notices have been ingested yet.</div></div> : open.map((t:any)=><div className="targets-grid-row" key={t.id}>
          <div><strong>{fmtDate(t.closing_date)}</strong><span className="status-meta">{urgencyLabel(t.closing_date)}</span>{t.published_date?<span className="status-meta">opened {fmtDate(t.published_date)}</span>:null}</div>
          <div><strong>{t.title}</strong><span className="status-meta">{t.category||"Service"} · {t.external_id}</span></div>
          <div><strong>{t.buyer_name||"—"}</strong><span className="status-meta">{t.region||"NCR"}</span></div>
          <div><span className="score-chip score-high">{t.fit_score??"—"}</span><span className="status-meta">{t.fit_note||"Fit note pending"}</span></div>
          <div>{(propertiesByTender.get(t.id)??[]).length?<>{(propertiesByTender.get(t.id)??[]).map((p:any)=><span className="status-meta" key={p.property_id}>{p.name}</span>)}</>:<span className="status-meta">property mapping gap</span>}</div>
          <div className="row-actions"><span className="pill">{t.action_state||"new"}</span><a className="button" href={t.source_url} target="_blank" rel="noreferrer">Open notice</a>{t.lead_id?<Link className="button" href="/sales">Lead</Link>:null}</div>
        </div>)}
      </div></div>
    </section>

    <section className="table-panel" style={{marginBottom:18}}>
      <div className="panel-head"><div><span className="eyebrow">BUYER INTELLIGENCE</span><h3>Contact coverage</h3></div></div>
      <div className="table-wrap"><div className="targets-grid procurement-grid">
        <div className="targets-grid-row targets-grid-head"><div>Notice</div><div>Buyer</div><div>Primary contact</div><div>Evidence</div><div>Gap</div><div>Next action</div></div>
        {open.map((t:any)=>{const c=contactByLead.get(t.lead_id); return <div className="targets-grid-row" key={t.id}>
          <div><strong>{t.external_id}</strong><span className="status-meta">{fmtDate(t.closing_date)}</span></div>
          <div>{t.buyer_name||"—"}</div>
          <div>{c?<><strong>{c.first_name} {c.last_name}</strong><span className="status-meta">{c.job_title||"Buyer contact"} · {c.email||"no email"}</span></>:<span className="status-meta">contact gap</span>}</div>
          <div>{c?<span className="status-meta">{c.source_label||"source"} · {c.source_confidence||"unknown"}{c.source_confidence==="reported"?" · verify":""}</span>:<span className="status-meta">unverified</span>}</div>
          <div>{!c?"Find procurement/contact authority":c.source_confidence==="reported"?"Verify named contact":"—"}</div>
          <div><strong>{t.next_action||"Assign next bid-review step"}</strong>{t.next_action_due_at?<span className="status-meta">due {fmtDate(t.next_action_due_at)}</span>:null}</div>
        </div>})}
      </div></div>
    </section>

    <section className="table-panel" style={{marginBottom:18}}>
      <div className="panel-head"><div><span className="eyebrow">PROPERTY INTELLIGENCE</span><h3>Facility coverage behind the notices</h3></div></div>
      <div className="table-wrap"><div className="targets-grid procurement-grid">
        <div className="targets-grid-row targets-grid-head"><div>Notice</div><div>Property</div><div>Address</div><div>Type</div><div>Evidence</div><div>Scope note</div></div>
        {open.flatMap((t:any)=>(propertiesByTender.get(t.id)??[]).map((p:any)=><div className="targets-grid-row" key={t.id+":"+p.property_id}>
          <div><strong>{t.external_id}</strong><span className="status-meta">{fmtDate(t.closing_date)}</span></div>
          <div><strong>{p.name}</strong></div><div>{[p.address_line_1,p.city,p.province].filter(Boolean).join(", ")}</div><div>{p.property_type||"—"}</div>
          <div><a href={p.evidence_url} target="_blank" rel="noreferrer">{p.evidence_label||"Source"}</a><span className="status-meta">{p.source_confidence||"—"}</span></div>
          <div className="status-meta">{p.scope_note||"—"}</div>
        </div>))}
      </div></div>
    </section>

    <section className="table-panel"><div className="panel-head"><div><span className="eyebrow">RUN HISTORY</span><h3>Scout health</h3></div></div><div className="table-wrap"><div className="targets-grid procurement-grid">
      <div className="targets-grid-row targets-grid-head"><div>Run</div><div>Status</div><div>Fetched</div><div>Qualified</div><div>Writes</div><div>Leads</div></div>
      {(runs??[]).map((r:any)=><div className="targets-grid-row" key={r.id}><div><strong>{fmtDate(r.started_at)}</strong><span className="status-meta">{r.finished_at?fmtDate(r.finished_at):"running"}</span></div><div><span className="pill">{r.status}</span>{r.error_message?<span className="status-meta">{r.error_message}</span>:null}</div><div>{r.fetched_count}</div><div>{r.qualifying_count}</div><div>{Number(r.inserted_count||0)+Number(r.updated_count||0)}</div><div>{r.lead_created_count}</div></div>)}
    </div></div></section>
  </main>;
}

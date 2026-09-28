/* eslint-disable @typescript-eslint/no-explicit-any */
import Link from "next/link";
import type { Route } from "next";
import { createClient } from "@/lib/supabase/server";
import { requireWorkspace } from "@/lib/workspace";
import { runCanadaBuysScout, updateSupplierRegistration, updateTenderStage } from "./actions";
import "./procurement.css";

function fmtDate(value:string|null){ if(!value) return "—"; return new Date(value).toLocaleDateString("en-CA",{year:"numeric",month:"short",day:"numeric"}); }
function daysLeft(value:string|null){ if(!value) return null; const end=new Date(value+"T23:59:59Z").getTime(); return Math.ceil((end-Date.now())/86400000); }
function urgencyLabel(value:string|null){ const d=daysLeft(value); if(d===null) return "no deadline"; if(d<0) return "closed"; if(d===0) return "closes today"; if(d===1) return "1 day"; return `${d} days`; }

const STAGES=["new","qualifying","pursuing","pricing","review","submitted","won","lost","no_bid"];

export default async function ProcurementPage(){
  const ctx=await requireWorkspace();
  const s=await createClient();

  const {data:tenders}=await (s as any).from("tender_records")
    .select("id,external_id,title,buyer_name,category,region,published_date,closing_date,source,source_url,status,matched_organization_id,lead_id,response_mode,registration_required,fit_score,fit_note,last_verified_at,action_state,next_action,next_action_due_at")
    .eq("workspace_id",ctx.workspaceId).gte("closing_date",new Date().toISOString().slice(0,10)).order("closing_date",{ascending:true}).limit(150);

  const leadIds=(tenders??[]).map((t:any)=>t.lead_id).filter(Boolean);
  const {data:leadRows}=await (s as any).from("leads").select("id,contact_id,property_id").eq("workspace_id",ctx.workspaceId).in("id",leadIds.length?leadIds:["00000000-0000-0000-0000-000000000000"]);
  const contactIds=(leadRows??[]).map((x:any)=>x.contact_id).filter(Boolean);
  const {data:contacts}=await (s as any).from("contacts").select("id,first_name,last_name,job_title,email,phone,mobile,source_url,source_label,source_confidence").eq("workspace_id",ctx.workspaceId).in("id",contactIds.length?contactIds:["00000000-0000-0000-0000-000000000000"]);
  const contactByLead=new Map<string,any>((leadRows??[]).map((x:any)=>[x.id,(contacts??[]).find((c:any)=>c.id===x.contact_id)]));

  const tenderIds=(tenders??[]).map((t:any)=>t.id);
  const {data:tenderProperties}=await (s as any).from("tender_properties").select("tender_record_id,property_id,scope_note,evidence_url,evidence_label,source_confidence").eq("workspace_id",ctx.workspaceId).in("tender_record_id",tenderIds.length?tenderIds:["00000000-0000-0000-0000-000000000000"]);
  const propertyIds=(tenderProperties??[]).map((x:any)=>x.property_id).filter(Boolean);
  const {data:properties}=await (s as any).from("properties").select("id,name,address_line_1,city,province,property_type").eq("workspace_id",ctx.workspaceId).in("id",propertyIds.length?propertyIds:["00000000-0000-0000-0000-000000000000"]);
  const propertyById=new Map((properties??[]).map((p:any)=>[p.id,p]));
  const propertiesByTender=new Map<string,any[]>();
  for(const row of tenderProperties??[]){ const p=propertyById.get(row.property_id); if(p) propertiesByTender.set(row.tender_record_id,[...(propertiesByTender.get(row.tender_record_id)??[]),{...p,...row}]); }

  const {data:runs}=await (s as any).from("canadabuys_runs").select("id,started_at,finished_at,status,fetched_count,qualifying_count,inserted_count,updated_count,lead_created_count,error_count,error_message").eq("workspace_id",ctx.workspaceId).order("started_at",{ascending:false}).limit(8);
  const {data:sources}=await (s as any).from("tender_sources").select("source_key,display_name,source_url,ingestion_mode,last_run_at,last_success_at,last_error").eq("workspace_id",ctx.workspaceId).eq("enabled",true).order("display_name");
  const {data:registrations}=await (s as any).from("supplier_registrations").select("id,source_key,registration_name,status,account_reference,expires_on,evidence_url,notes,updated_at").eq("workspace_id",ctx.workspaceId).order("registration_name");

  const open=(tenders??[]).filter((t:any)=>t.closing_date && new Date(t.closing_date+"T23:59:59Z")>=new Date());
  const urgent=open.filter((t:any)=>{const d=daysLeft(t.closing_date); return d!==null && d<=7;}).length;
  const pursuing=open.filter((t:any)=>["pursuing","pricing","review","submitted"].includes(t.action_state)).length;
  const highFit=open.filter((t:any)=>Number(t.fit_score||0)>=75).length;
  const sourceCounts=new Map<string,number>(); for(const t of open) sourceCounts.set(t.source||"Other",(sourceCounts.get(t.source||"Other")||0)+1);

  return <main className="list-shell">
    <header className="list-header">
      <Link className="back" href="/dashboard">← Command</Link>
      <span className="eyebrow">GROWTH / PROCUREMENT</span>
      <h1>Tender Intelligence</h1>
      <p className="muted tender-intro">One operating queue for public and institutional opportunities: discovery, fit, buyer/property intelligence, bid/no-bid, compliance, pricing, submission and award follow-up.</p>
    </header>

    <section className="metrics" style={{marginBottom:18}}>
      <div className="metric"><span>Open tenders</span><strong>{open.length}</strong></div>
      <div className="metric"><span>High fit ≥75</span><strong>{highFit}</strong></div>
      <div className="metric"><span>Closing ≤7 days</span><strong>{urgent}</strong></div>
      <div className="metric"><span>Active pursuits</span><strong>{pursuing}</strong></div>
    </section>

    <section className="source-strip">
      {(sources??[]).map((source:any)=><div key={source.source_key}>
        <strong>{source.display_name}</strong>
        <span>{source.ingestion_mode.replace("_"," ")}{source.source_key==="canadabuys" ? ` · ${sourceCounts.get("CanadaBuys")||0} open` : ""}</span>
        {source.last_success_at?<span>last success {fmtDate(source.last_success_at)}</span>:null}
        {source.last_error?<span>{source.last_error}</span>:null}
      </div>)}
      <form action={runCanadaBuysScout}><button className="primary" type="submit">Run CanadaBuys scout</button></form>
    </section>

    <section className="table-panel" style={{marginBottom:18}}>
      <div className="panel-head"><div><span className="eyebrow">SUPPLIER READINESS</span><h3>Registrations and prequalification</h3></div><span className="muted">{(registrations??[]).filter((r:any)=>r.status==="active"||r.status==="not_required").length}/{(registrations??[]).length} ready</span></div>
      <div className="tender-list">
        {(registrations??[]).map((r:any)=><div className="tender-list-row" key={r.id}>
          <div><strong>{r.registration_name}</strong><span className="status-meta">{r.source_key} · {r.status.replace("_"," ")}</span>{r.notes?<span className="status-meta wrap">{r.notes}</span>:null}</div>
          <form action={updateSupplierRegistration} className="supplier-registration-form">
            <input type="hidden" name="registration_id" value={r.id}/>
            <select name="status" defaultValue={r.status}>{["unknown","not_required","required","in_progress","active","expired","blocked"].map(x=><option key={x} value={x}>{x.replace("_"," ")}</option>)}</select>
            <input name="account_reference" defaultValue={r.account_reference||""} placeholder="Account / vendor #"/>
            <input name="evidence_url" defaultValue={r.evidence_url||""} placeholder="Evidence URL"/>
            <input name="notes" defaultValue={r.notes||""} placeholder="Notes"/>
            <button className="button" type="submit">Save</button>
          </form>
        </div>)}
      </div>
    </section>

    <section className="panel bid-process">
      <div className="panel-head"><div><span className="eyebrow">BID OPERATING SYSTEM</span><h3>Required pursuit flow</h3></div></div>
      <div className="bid-steps">
        {["1 Review","2 Qualify","3 Site visit / questions","4 Takeoff + compliance","5 Price","6 Final review","7 Submit","8 Award / debrief"].map((x)=><span key={x}>{x}</span>)}
      </div>
      <p className="muted">Move each opportunity through the stage control below. “No bid” is a valid outcome; the goal is to avoid spending estimating time on tenders CB cannot win or deliver profitably.</p>
    </section>

    <section className="table-panel" style={{marginBottom:18}}>
      <div className="panel-head"><div><span className="eyebrow">OPEN PIPELINE</span><h3>Active tender queue</h3></div><span className="muted">{open.filter((t:any)=>t.next_action).length} with a next action</span></div>
      <div className="table-wrap"><div className="targets-grid procurement-grid">
        <div className="targets-grid-row targets-grid-head"><div>Close</div><div>Opportunity</div><div>Buyer / source</div><div>Fit</div><div>Coverage</div><div>Bid control</div></div>
        {open.length===0 ? <div className="targets-grid-row"><div className="muted">No open qualifying tenders have been ingested yet.</div></div> : open.map((t:any)=><div className="targets-grid-row" key={t.id}>
          <div><strong>{fmtDate(t.closing_date)}</strong><span className="status-meta">{urgencyLabel(t.closing_date)}</span>{t.published_date?<span className="status-meta">opened {fmtDate(t.published_date)}</span>:null}</div>
          <div><strong>{t.title}</strong><span className="status-meta">{t.category||"Service"} · {t.external_id}</span><span className="status-meta">{t.next_action||"Review solicitation and mandatory requirements"}</span></div>
          <div><strong>{t.buyer_name||"—"}</strong><span className="status-meta">{t.source||"Unknown source"} · {t.region||"NCR"}</span></div>
          <div><span className="score-chip score-high">{t.fit_score??"—"}</span><span className="status-meta">{t.fit_note||"Fit note pending"}</span></div>
          <div>{(propertiesByTender.get(t.id)??[]).length?<>{(propertiesByTender.get(t.id)??[]).map((p:any)=><span className="status-meta" key={p.property_id}>{p.name}</span>)}</>:<span className="status-meta">property mapping gap</span>}</div>
          <div className="bid-control">
            <form action={updateTenderStage}>
              <input type="hidden" name="tender_id" value={t.id}/>
              <select name="stage" defaultValue={t.action_state||"new"} aria-label="Bid stage">{STAGES.map(stage=><option value={stage} key={stage}>{stage.replace("_"," ")}</option>)}</select>
              <button className="button" type="submit">Update</button>
            </form>
            <Link className="button" href={`/procurement/${t.id}` as Route}>Review bid</Link>
            {t.source_url?<a className="button" href={t.source_url} target="_blank" rel="noreferrer">Source</a>:null}
            {t.lead_id?<Link className="button" href="/sales">Lead</Link>:null}
          </div>
        </div>)}
      </div></div>
    </section>

    <section className="table-panel" style={{marginBottom:18}}>
      <div className="panel-head"><div><span className="eyebrow">BUYER INTELLIGENCE</span><h3>Contact and compliance gaps</h3></div></div>
      <div className="table-wrap"><div className="targets-grid procurement-grid">
        <div className="targets-grid-row targets-grid-head"><div>Notice</div><div>Buyer</div><div>Primary contact</div><div>Evidence</div><div>Gap</div><div>Next action</div></div>
        {open.map((t:any)=>{const c=contactByLead.get(t.lead_id); return <div className="targets-grid-row" key={t.id}>
          <div><strong>{t.external_id}</strong><span className="status-meta">{fmtDate(t.closing_date)}</span></div>
          <div>{t.buyer_name||"—"}</div>
          <div>{c?<><strong>{c.first_name} {c.last_name}</strong><span className="status-meta">{c.job_title||"Buyer contact"} · {c.email||"no email"}</span></>:<span className="status-meta">contact gap</span>}</div>
          <div>{c?<span className="status-meta">{c.source_label||"source"} · {c.source_confidence||"unknown"}</span>:<span className="status-meta">unverified</span>}</div>
          <div>{!c?"Find procurement/contact authority":t.registration_required?"Confirm registration + mandatory requirements":"Check site visit, insurance, bonding and security"}</div>
          <div><strong>{t.next_action||"Assign next bid-review step"}</strong>{t.next_action_due_at?<span className="status-meta">due {fmtDate(t.next_action_due_at)}</span>:null}</div>
        </div>})}
      </div></div>
    </section>

    <section className="table-panel" style={{marginBottom:18}}>
      <div className="panel-head"><div><span className="eyebrow">PROPERTY INTELLIGENCE</span><h3>Facilities behind the tenders</h3></div></div>
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

    <section className="table-panel"><div className="panel-head"><div><span className="eyebrow">SOURCE HEALTH</span><h3>CanadaBuys scout runs</h3></div></div><div className="table-wrap"><div className="targets-grid procurement-grid">
      <div className="targets-grid-row targets-grid-head"><div>Run</div><div>Status</div><div>Fetched</div><div>Qualified</div><div>Writes</div><div>Leads</div></div>
      {(runs??[]).map((r:any)=><div className="targets-grid-row" key={r.id}><div><strong>{fmtDate(r.started_at)}</strong><span className="status-meta">{r.finished_at?fmtDate(r.finished_at):"running"}</span></div><div><span className="pill">{r.status}</span>{r.error_message?<span className="status-meta">{r.error_message}</span>:null}</div><div>{r.fetched_count}</div><div>{r.qualifying_count}</div><div>{Number(r.inserted_count||0)+Number(r.updated_count||0)}</div><div>{r.lead_created_count}</div></div>)}
    </div></div></section>
  </main>;
}

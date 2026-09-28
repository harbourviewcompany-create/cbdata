/* eslint-disable @typescript-eslint/no-explicit-any */
import Link from "next/link";
import type { Route } from "next";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { requireWorkspace } from "@/lib/workspace";
import {
  addTenderDeadline,
  addTenderRequirement,
  confirmTenderSubmission,
  createEstimateFromTender,
  markAddendaChecked,
  saveNoBidReason,
  saveTenderScorecard,
  updateTenderDeadline,
  updateTenderRequirement,
  updateTenderStage,
} from "../actions";
import "../procurement.css";

const STAGES=["new","qualifying","pursuing","pricing","review","submitted","won","lost","no_bid"];

function money(value:any,currency="CAD"){
  if(value===null||value===undefined||value==="") return "—";
  return new Intl.NumberFormat("en-CA",{style:"currency",currency,maximumFractionDigits:0}).format(Number(value));
}
function fmt(value:string|null){
  if(!value) return "—";
  return new Date(value).toLocaleString("en-CA",{year:"numeric",month:"short",day:"numeric",hour:"numeric",minute:"2-digit"});
}

export default async function TenderDetailPage({params}:{params:Promise<{id:string}>}){
  const {id}=await params;
  const ctx=await requireWorkspace();
  const s=await createClient();

  const {data:tender}=await (s as any).from("tender_records").select("*").eq("workspace_id",ctx.workspaceId).eq("id",id).maybeSingle();
  if(!tender) notFound();

  const [{data:reqs},{data:deadlines},{data:docs},{data:history},{data:links},{data:estimate}]=await Promise.all([
    (s as any).from("tender_requirements").select("*").eq("workspace_id",ctx.workspaceId).eq("tender_record_id",id).order("mandatory",{ascending:false}).order("created_at"),
    (s as any).from("tender_deadlines").select("*").eq("workspace_id",ctx.workspaceId).eq("tender_record_id",id).order("due_at"),
    (s as any).from("tender_documents").select("*").eq("workspace_id",ctx.workspaceId).eq("tender_record_id",id).eq("is_current",true).order("created_at"),
    (s as any).from("tender_stage_history").select("*").eq("workspace_id",ctx.workspaceId).eq("tender_record_id",id).order("created_at",{ascending:false}).limit(20),
    (s as any).from("tender_properties").select("property_id,scope_note,evidence_url,evidence_label,properties(name,address_line_1,city,province,property_type)").eq("workspace_id",ctx.workspaceId).eq("tender_record_id",id),
    tender.estimate_id ? (s as any).from("estimates").select("id,estimate_number,total,estimated_direct_cost,estimated_gross_profit,estimated_margin,status").eq("workspace_id",ctx.workspaceId).eq("id",tender.estimate_id).maybeSingle() : Promise.resolve({data:null}),
  ]);

  const mandatory=(reqs??[]).filter((r:any)=>r.mandatory);
  const incomplete=mandatory.filter((r:any)=>!["complete","not_applicable"].includes(r.status));
  const openDeadlines=(deadlines??[]).filter((d:any)=>d.status==="open");
  const nextDeadline=openDeadlines[0];
  const score=tender.fit_breakdown??{};
  const scoreFields=[
    ["capability","Capability fit",20],
    ["geography","Geographic fit",10],
    ["contract_size","Contract size",15],
    ["experience","Relevant experience",15],
    ["equipment","Equipment availability",10],
    ["labor_capacity","Labour capacity",10],
    ["compliance","Compliance readiness",10],
    ["competitive_position","Competitive position",5],
    ["margin_potential","Margin potential",5],
  ] as const;

  return <main className="list-shell">
    <header className="list-header">
      <Link className="back" href="/procurement">← Tender Intelligence</Link>
      <span className="eyebrow">{tender.source} / {tender.external_id}</span>
      <h1>{tender.title}</h1>
      <p className="muted tender-intro">{tender.buyer_name||"Buyer not matched"} · closes {tender.closing_date||"date unknown"} · {tender.region||"region unknown"}</p>
    </header>

    <section className="metrics" style={{marginBottom:18}}>
      <div className="metric"><span>Fit</span><strong>{tender.fit_score??"—"}</strong></div>
      <div className="metric"><span>Mandatory gaps</span><strong>{incomplete.length}</strong></div>
      <div className="metric"><span>Next deadline</span><strong className="metric-small">{nextDeadline?fmt(nextDeadline.due_at):"—"}</strong></div>
      <div className="metric"><span>Estimate</span><strong>{estimate?money(estimate.total,tender.currency):"Not started"}</strong></div>
    </section>

    {incomplete.length>0?<section className="panel tender-blocker">
      <strong>Submission blocked</strong>
      <span>{incomplete.length} mandatory requirement{incomplete.length===1?" is":"s are"} incomplete.</span>
    </section>:null}

    <section className="tender-detail-grid">
      <div className="panel">
        <div className="panel-head"><div><span className="eyebrow">BID / NO-BID</span><h3>Structured fit score</h3></div><strong>{tender.fit_score??0}/100</strong></div>
        <form action={saveTenderScorecard}>
          <input type="hidden" name="tender_id" value={id}/>
          <div className="scorecard-grid">
            {scoreFields.map(([key,label,max])=><label key={key}><span>{label} <small>/ {max}</small></span><input type="number" name={key} min="0" max={max} step="1" defaultValue={Number(score[key]??0)}/></label>)}
          </div>
          <label className="stacked-field"><span>Fit rationale</span><textarea name="fit_note" defaultValue={tender.fit_note||""} placeholder="Why this opportunity fits CB, major risks, relationship position, and assumptions."/></label>
          <button className="primary" type="submit">Save scorecard</button>
        </form>
      </div>
      <div className="panel">
        <div className="panel-head"><div><span className="eyebrow">DECISION CONTROL</span><h3>No-bid / submission evidence</h3></div></div>
        <form action={saveNoBidReason} className="stacked-form">
          <input type="hidden" name="tender_id" value={id}/>
          <label className="stacked-field"><span>No-bid reason</span><textarea name="no_bid_reason" defaultValue={tender.no_bid_reason||""} placeholder="Required before moving the tender to No Bid."/></label>
          <button className="button" type="submit">Save no-bid reason</button>
        </form>
        <hr className="panel-rule"/>
        <form action={confirmTenderSubmission} className="stacked-form">
          <input type="hidden" name="tender_id" value={id}/>
          <label className="stacked-field"><span>Submission method</span><input name="submission_method" defaultValue={tender.submission_method||""} placeholder="MERX, SAP Business Network, email, portal"/></label>
          <label className="stacked-field"><span>Receipt / confirmation #</span><input name="submission_reference" defaultValue={tender.submission_reference||""} placeholder="Required"/></label>
          <label className="stacked-field"><span>Receipt URL</span><input name="submission_receipt_url" defaultValue={tender.submission_receipt_url||""} placeholder="https://..."/></label>
          <button className="primary" type="submit" disabled={incomplete.length>0||!estimate}>Confirm submitted</button>
          {tender.submission_confirmed_at?<span className="status-meta">Confirmed {fmt(tender.submission_confirmed_at)}</span>:null}
        </form>
      </div>
    </section>

    <section className="panel" style={{marginBottom:18}}>
      <div className="panel-head"><div><span className="eyebrow">ADDENDA CONTROL</span><h3>Last-minute requirement changes</h3></div></div>
      <form action={markAddendaChecked} className="inline-form">
        <input type="hidden" name="tender_id" value={id}/>
        <label>Addenda count <input name="addenda_count" type="number" min="0" defaultValue={Number(tender.addenda_count||0)}/></label>
        <button className="button" type="submit">Mark addenda checked now</button>
        <span className="status-meta">Last checked {fmt(tender.last_addenda_checked_at)}</span>
      </form>
    </section>

    <section className="tender-detail-grid">
      <div className="panel">
        <div className="panel-head"><div><span className="eyebrow">BID CONTROL</span><h3>Pursuit</h3></div></div>
        <form action={updateTenderStage} className="inline-form">
          <input type="hidden" name="tender_id" value={id}/>
          <select name="stage" defaultValue={tender.action_state||"new"}>{STAGES.map(x=><option key={x} value={x}>{x.replace("_"," ")}</option>)}</select>
          <button className="primary" type="submit">Update stage</button>
        </form>
        <dl className="tender-kv">
          <div><dt>Next action</dt><dd>{tender.next_action||"—"}</dd></div>
          <div><dt>Estimated value</dt><dd>{money(tender.estimated_value,tender.currency)}</dd></div>
          <div><dt>Incumbent</dt><dd>{tender.incumbent_name||"Unknown"}</dd></div>
          <div><dt>Previous award</dt><dd>{money(tender.previous_award_value,tender.currency)}</dd></div>
          <div><dt>Registration</dt><dd>{tender.registration_required?"Required":"Not flagged"}</dd></div>
          <div><dt>Addenda</dt><dd>{tender.addenda_count||0}</dd></div>
        </dl>
        <div className="bid-control">
          {tender.source_url?<a className="button" href={tender.source_url} target="_blank" rel="noreferrer">Open source notice</a>:null}
          {estimate?<Link className="button" href={`/estimates/${estimate.id}` as Route}>Open {estimate.estimate_number}</Link>:
          <form action={createEstimateFromTender}><input type="hidden" name="tender_id" value={id}/><button className="primary" type="submit">Send to estimating</button></form>}
        </div>
      </div>

      <div className="panel">
        <div className="panel-head"><div><span className="eyebrow">ESTIMATE</span><h3>Commercial position</h3></div></div>
        {estimate?<dl className="tender-kv">
          <div><dt>Status</dt><dd>{estimate.status}</dd></div>
          <div><dt>Bid price</dt><dd>{money(estimate.total,tender.currency)}</dd></div>
          <div><dt>Direct cost</dt><dd>{money(estimate.estimated_direct_cost,tender.currency)}</dd></div>
          <div><dt>Gross profit</dt><dd>{money(estimate.estimated_gross_profit,tender.currency)}</dd></div>
          <div><dt>Margin</dt><dd>{Number(estimate.estimated_margin||0).toLocaleString("en-CA",{style:"percent",maximumFractionDigits:1})}</dd></div>
        </dl>:<p className="muted">No estimate is linked yet. Match the buyer organization, then send this tender to estimating.</p>}
      </div>
    </section>

    <section className="table-panel" style={{marginBottom:18}}>
      <div className="panel-head"><div><span className="eyebrow">COMPLIANCE</span><h3>Mandatory requirements</h3></div></div>
      <div className="tender-list">
        {(reqs??[]).map((r:any)=><div className="tender-list-row" key={r.id}>
          <div><strong>{r.title}</strong><span className="status-meta">{r.requirement_type}{r.mandatory?" · mandatory":""}</span>{r.description?<span className="status-meta wrap">{r.description}</span>:null}</div>
          <form action={updateTenderRequirement} className="inline-form">
            <input type="hidden" name="tender_id" value={id}/><input type="hidden" name="requirement_id" value={r.id}/>
            <select name="status" defaultValue={r.status}>{["pending","in_progress","complete","blocked","not_applicable"].map(x=><option key={x} value={x}>{x.replace("_"," ")}</option>)}</select>
            <button className="button" type="submit">Save</button>
          </form>
        </div>)}
      </div>
      <form action={addTenderRequirement} className="tender-add-form">
        <input type="hidden" name="tender_id" value={id}/>
        <input name="title" placeholder="Requirement, e.g. $5M CGL certificate" required/>
        <select name="requirement_type" defaultValue="compliance"><option value="compliance">Compliance</option><option value="site_visit">Site visit</option><option value="bonding">Bonding</option><option value="insurance">Insurance</option><option value="security">Security</option><option value="reference">Reference</option><option value="form">Form</option><option value="other">Other</option></select>
        <label><input type="checkbox" name="mandatory" defaultChecked/> Mandatory</label>
        <button className="button" type="submit">Add requirement</button>
      </form>
    </section>

    <section className="table-panel" style={{marginBottom:18}}>
      <div className="panel-head"><div><span className="eyebrow">DEADLINES</span><h3>Bid calendar</h3></div></div>
      <div className="tender-list">
        {(deadlines??[]).map((d:any)=><div className="tender-list-row" key={d.id}>
          <div><strong>{d.title}</strong><span className="status-meta">{fmt(d.due_at)} · {d.deadline_type}{d.mandatory?" · mandatory":""}</span></div>
          <form action={updateTenderDeadline} className="inline-form">
            <input type="hidden" name="tender_id" value={id}/><input type="hidden" name="deadline_id" value={d.id}/>
            <select name="status" defaultValue={d.status}>{["open","complete","missed","not_applicable"].map(x=><option key={x} value={x}>{x.replace("_"," ")}</option>)}</select>
            <button className="button" type="submit">Save</button>
          </form>
        </div>)}
      </div>
      <form action={addTenderDeadline} className="tender-add-form">
        <input type="hidden" name="tender_id" value={id}/>
        <input name="title" placeholder="Deadline, e.g. mandatory site visit" required/>
        <select name="deadline_type" defaultValue="questions"><option value="site_visit">Site visit</option><option value="questions">Questions</option><option value="addenda">Addenda check</option><option value="review">Final review</option><option value="submission">Submission</option><option value="other">Other</option></select>
        <input name="due_at" type="datetime-local" required/>
        <label><input type="checkbox" name="mandatory"/> Mandatory</label>
        <button className="button" type="submit">Add deadline</button>
      </form>
    </section>

    <section className="tender-detail-grid">
      <div className="table-panel">
        <div className="panel-head"><div><span className="eyebrow">FACILITIES</span><h3>Property coverage</h3></div></div>
        <div className="tender-list">{(links??[]).length?(links??[]).map((x:any)=><div className="tender-list-row" key={x.property_id}><div><strong>{x.properties?.name||"Property"}</strong><span className="status-meta">{[x.properties?.address_line_1,x.properties?.city,x.properties?.province].filter(Boolean).join(", ")}</span><span className="status-meta wrap">{x.scope_note||"Scope not mapped"}</span></div></div>):<p className="muted pad">No facility mapping yet.</p>}</div>
      </div>
      <div className="table-panel">
        <div className="panel-head"><div><span className="eyebrow">DOCUMENTS / HISTORY</span><h3>Evidence trail</h3></div></div>
        <div className="tender-list">
          {(docs??[]).map((d:any)=><div className="tender-list-row" key={d.id}><div><strong>{d.title}</strong><span className="status-meta">{d.document_type}{d.version?` · ${d.version}`:""}</span></div>{d.source_url?<a className="button" href={d.source_url} target="_blank" rel="noreferrer">Open</a>:null}</div>)}
          {(history??[]).map((h:any)=><div className="tender-list-row" key={h.id}><div><strong>{h.from_stage||"new"} → {h.to_stage}</strong><span className="status-meta">{fmt(h.created_at)}</span></div></div>)}
        </div>
      </div>
    </section>
  </main>;
}

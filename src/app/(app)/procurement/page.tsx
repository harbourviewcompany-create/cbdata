/* eslint-disable @typescript-eslint/no-explicit-any */
import Link from "next/link";
import type { Route } from "next";
import { createClient } from "@/lib/supabase/server";
import { requireWorkspace } from "@/lib/workspace";
import { addManualTender, runCanadaBuysScout, runRegionalTenderScout, runTenderIntelligence, updateFutureOpportunityStatus, updateSupplierRegistration, updateTenderStage } from "./actions";
import "./procurement.css";

function fmtDate(value:string|null){ if(!value) return "—"; return new Date(value).toLocaleDateString("en-CA",{year:"numeric",month:"short",day:"numeric"}); }
function daysLeft(value:string|null){ if(!value) return null; const end=new Date(value+"T23:59:59Z").getTime(); return Math.ceil((end-Date.now())/86400000); }
function urgencyLabel(value:string|null){ const d=daysLeft(value); if(d===null) return "no deadline"; if(d<0) return "closed"; if(d===0) return "closes today"; if(d===1) return "1 day"; return `${d} days`; }
function tenderKey(t:any){ const n=(v:any)=>String(v??"").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"").replace(/[^a-z0-9]+/g," ").trim(); return [n(t.buyer_name),n(t.title),t.closing_date||""].join("|"); }

const STAGES=["new","qualifying","pursuing","pricing","review","submitted","won","lost","no_bid"];

export default async function ProcurementPage(){
  const ctx=await requireWorkspace();
  const s=await createClient();

  const {data:tenders}=await (s as any).from("tender_records")
    .select("id,external_id,title,buyer_name,category,region,published_date,closing_date,source,source_url,status,matched_organization_id,lead_id,response_mode,registration_required,fit_score,fit_note,last_verified_at,action_state,next_action,next_action_due_at")
    .eq("workspace_id",ctx.workspaceId).gte("closing_date",new Date().toISOString().slice(0,10)).order("closing_date",{ascending:true}).limit(150);

  const tenderIdsForReadiness=(tenders??[]).map((t:any)=>t.id);
  const {data:readinessRows}=await (s as any).from("v_tender_bid_readiness").select("*").eq("workspace_id",ctx.workspaceId).in("tender_record_id",tenderIdsForReadiness.length?tenderIdsForReadiness:["00000000-0000-0000-0000-000000000000"]);
  const readinessByTender=new Map<string,any>((readinessRows??[]).map((r:any)=>[r.tender_record_id,r]));

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
  const {data:regionalRuns}=await (s as any).from("tender_scout_runs").select("id,source_key,source_name,started_at,finished_at,status,fetched_count,qualifying_count,inserted_count,updated_count,lead_created_count,error_count,error_message").eq("workspace_id",ctx.workspaceId).order("started_at",{ascending:false}).limit(20);
  const {data:sources}=await (s as any).from("tender_sources").select("source_key,display_name,source_url,ingestion_mode,coverage_tier,adapter_status,buyer_scope,last_run_at,last_success_at,last_error,last_verified_at,source_category,discovery_priority,registration_url,contact_strategy,supports_awards,supports_small_jobs,geographic_scope").eq("workspace_id",ctx.workspaceId).eq("enabled",true).order("discovery_priority",{ascending:false}).order("display_name");
  const {data:sourceHealth}=await (s as any).from("v_procurement_source_health").select("*").eq("workspace_id",ctx.workspaceId).order("display_name");
  const {data:radarRows}=await (s as any).from("v_growth_opportunity_radar_deduped")
    .select("opportunity_key,origin,source_label,buyer_name,title,opportunity_type,region,published_at,deadline_at,source_url,service_fit,score,status,matched_organization_id,outreach_target_id,pursuit_id,contact_name,contact_email,next_action,priority_bucket,is_actionable,duplicate_count")
    .eq("workspace_id",ctx.workspaceId).eq("is_actionable",true)
    .order("score",{ascending:false}).order("deadline_at",{ascending:true,nullsFirst:false}).limit(120);
  const {data:inboxRows}=await (s as any).from("v_procurement_inbox").select("id,title,buyer_name,source_key,closing_at,bid_score,bid_recommendation,bid_score_breakdown,inbox_bucket,promoted_tender_record_id,source_url,qualification_gap_count,submission_gap_count,hard_blocker_count,auto_next_action,auto_next_action_due_at,duplicate_count").eq("workspace_id",ctx.workspaceId).in("inbox_bucket",["deadline","qualification_gap","best_new","needs_review","watching"]).order("bid_score",{ascending:false}).limit(60);
  const {data:registrations}=await (s as any).from("supplier_registrations").select("id,source_key,registration_name,status,account_reference,expires_on,evidence_url,notes,updated_at").eq("workspace_id",ctx.workspaceId).order("registration_name");
  const [{data:intelligenceRows},{data:subtradeRows},{data:futureRows},{data:cycleRows}]=await Promise.all([
    (s as any).from("tender_pursuit_intelligence").select("tender_record_id,pursuit_mode,scope_fit,eligibility,commercial_attractiveness,geographic_fit,timing,competition,strategic_value,subtrade_potential,overall_score,rationale,next_best_action").eq("workspace_id",ctx.workspaceId),
    (s as any).from("tender_subtrade_opportunities").select("id,tender_record_id,trade,package_title,scope_summary,fit_score,pursuit_status,suggested_action,due_at,target_primes").eq("workspace_id",ctx.workspaceId).in("pursuit_status",["identified","researching_primes","outreach","pricing"]).order("fit_score",{ascending:false}).limit(100),
    (s as any).from("v_procurement_pursuit_queue").select("id,buyer_name,title,service_category,expected_publish_start,expected_publish_end,fit_score,confidence,status,pursuit_priority,contact_readiness_status,vendor_readiness_status,next_action,next_action_at,target_id,routed_at,primary_source_key,registration_url,supplier_registration_status,supplier_registration_expires_on,incumbent_name,award_value,currency").eq("workspace_id",ctx.workspaceId).in("status",["watch","research","pre_position"]).order("expected_publish_start",{ascending:true}).limit(100),
    (s as any).from("procurement_contract_cycles").select("id,buyer_name,service_category,incumbent_name,award_value,currency,contract_end_date,expected_rebid_date,confidence,status,evidence_url").eq("workspace_id",ctx.workspaceId).order("expected_rebid_date",{ascending:true}).limit(100),
  ]);
  const intelligenceByTender=new Map<string,any>((intelligenceRows??[]).map((x:any)=>[x.tender_record_id,x]));

  const openRaw=(tenders??[]).filter((t:any)=>t.closing_date && new Date(t.closing_date+"T23:59:59Z")>=new Date() && !["no_bid","lost","won"].includes(t.action_state));
  const canonicalOpen=new Map<string,any>();
  for(const t of openRaw){ const k=tenderKey(t); const current=canonicalOpen.get(k); if(!current||Number(t.fit_score||0)>Number(current.fit_score||0)) canonicalOpen.set(k,t); }
  const open=Array.from(canonicalOpen.values());
  const urgent=open.filter((t:any)=>{const d=daysLeft(t.closing_date); return d!==null && d<=7;}).length;
  const pursuing=open.filter((t:any)=>["pursuing","pricing","review","submitted"].includes(t.action_state)).length;
  const highFit=open.filter((t:any)=>Number(t.fit_score||0)>=75).length;
  const primeBids=(intelligenceRows??[]).filter((x:any)=>x.pursuit_mode==="prime_bid").length;
  const subtradePursuits=(subtradeRows??[]).filter((x:any)=>Number(x.fit_score||0)>=70).length;
  const futurePipeline=(futureRows??[]).length;
  const sourceCounts=new Map<string,number>(); for(const t of openRaw) sourceCounts.set(t.source||"Other",(sourceCounts.get(t.source||"Other")||0)+1);

  const inbox=inboxRows??[];
  const radar=radarRows??[];
  const radarProcurement=radar.filter((x:any)=>x.origin==="procurement").length;
  const radarWorkLeads=radar.filter((x:any)=>x.origin==="work_lead").length;
  const radarSignals=radar.filter((x:any)=>x.origin==="signal").length;
  const radarHighPriority=radar.filter((x:any)=>Number(x.score||0)>=85).length;
  const radarContactNow=radar.filter((x:any)=>["contact_now","best_new","needs_review"].includes(x.priority_bucket)).length;
  const health=sourceHealth??[];
  const sourceIssues=health.filter((x:any)=>["failing","stale","never_scanned"].includes(x.health_status));
  const manualSources=health.filter((x:any)=>x.health_status==="manual_only");
  const secondaryCoverage=health.filter((x:any)=>x.health_status==="secondary_coverage");
  const inboxCounts=new Map<string,number>(); for(const x of inbox) inboxCounts.set(x.inbox_bucket,(inboxCounts.get(x.inbox_bucket)||0)+1);

  return <main className="list-shell">
    <header className="list-header">
      <Link className="back" href="/dashboard">← Command</Link>
      <span className="eyebrow">GROWTH / PROCUREMENT</span>
      <h1>Tender Intelligence</h1>
      <p className="muted tender-intro">One operating queue for public and institutional opportunities: discovery, fit, buyer/property intelligence, bid/no-bid, compliance, pricing, submission and award follow-up.</p>
      <div style={{marginTop:12}}><Link className="button" href={"/procurement/coverage" as Route}>Regional Coverage Engine</Link></div>
    </header>

    <section className="panel" style={{marginBottom:18}}>
      <div className="panel-head">
        <div><span className="eyebrow">ALL OPPORTUNITIES</span><h3>Opportunity Radar</h3></div>
        <span className="muted">{radar.length} deduplicated actionable opportunities</span>
      </div>
      <p className="muted" style={{marginTop:8,maxWidth:980}}>
        One ranked feed combining formal procurement, private tenders/subcontractor networks, and property/account opportunity signals. Duplicate sightings collapse to the richest record.
      </p>
      <div className="metrics" style={{marginTop:14,marginBottom:14}}>
        <div className="metric"><span>All actionable</span><strong>{radar.length}</strong></div>
        <div className="metric"><span>Procurement</span><strong>{radarProcurement}</strong></div>
        <div className="metric"><span>Private work</span><strong>{radarWorkLeads}</strong></div>
        <div className="metric"><span>Signals</span><strong>{radarSignals}</strong></div>
        <div className="metric"><span>Score ≥85</span><strong>{radarHighPriority}</strong></div>
        <div className="metric"><span>Act now</span><strong>{radarContactNow}</strong></div>
      </div>
      <div className="tender-list">
        {radar.slice(0,15).map((o:any)=><div className="tender-list-row" key={o.opportunity_key}>
          <div>
            <strong>{o.title}</strong>
            <span className="status-meta">{o.buyer_name||"Unknown buyer"} · {o.origin.replaceAll("_"," ")} · {o.source_label}</span>
            <span className="status-meta">{o.priority_bucket.replaceAll("_"," ")}{o.deadline_at?" · deadline "+fmtDate(o.deadline_at):""}{Number(o.duplicate_count||0)>1?" · "+o.duplicate_count+" sightings merged":""}</span>
            {o.next_action?<span className="status-meta wrap"><strong>Next:</strong> {o.next_action}</span>:null}
          </div>
          <div style={{display:"flex",gap:8,alignItems:"center",flexWrap:"wrap",justifyContent:"flex-end"}}>
            <span className="score-chip score-high">{Math.round(Number(o.score||0))}</span>
            <span className="pill">{o.opportunity_type.replaceAll("_"," ")}</span>
            {o.outreach_target_id?<Link className="button" href={("/targets/"+o.outreach_target_id) as Route}>Account</Link>:null}
            {o.source_url?<a className="button" href={o.source_url} target="_blank" rel="noreferrer">Source</a>:null}
          </div>
        </div>)}
        {!radar.length?<div className="muted">No actionable opportunities are currently in the radar.</div>:null}
      </div>
    </section>

    <section className="panel" style={{marginBottom:18}}>
      <div className="panel-head"><div><span className="eyebrow">PROCUREMENT INBOX</span><h3>What needs attention now</h3></div><span className="muted">{sourceIssues.length} source issues · {manualSources.length} manual · {secondaryCoverage.length} secondary · {inbox.length} prioritized opportunities</span></div>
      <div className="metrics" style={{marginBottom:14}}>
        <div className="metric"><span>Deadline</span><strong>{inboxCounts.get("deadline")||0}</strong></div>
        <div className="metric"><span>Qualification gaps</span><strong>{inboxCounts.get("qualification_gap")||0}</strong></div>
        <div className="metric"><span>Best new</span><strong>{inboxCounts.get("best_new")||0}</strong></div>
        <div className="metric"><span>Needs review</span><strong>{inboxCounts.get("needs_review")||0}</strong></div>
        <div className="metric"><span>Watching</span><strong>{inboxCounts.get("watching")||0}</strong></div>
        <div className="metric"><span>Source issues</span><strong>{sourceIssues.length}</strong></div>
      </div>
      <div className="tender-list">
        {inbox.slice(0,12).map((o:any)=><div className="tender-list-row" key={o.id}>
          <div>
            <strong>{o.title}</strong>
            <span className="status-meta">{o.buyer_name||"Unknown buyer"} · {o.inbox_bucket.replaceAll("_"," ")}{Number(o.duplicate_count||0)>1?" · "+o.duplicate_count+" sources":""}</span>
            <span className="status-meta">{o.closing_at ? "closes "+fmtDate(o.closing_at) : "deadline not published"}{Number(o.qualification_gap_count||0)>0?" · "+o.qualification_gap_count+" qualification gap"+(Number(o.qualification_gap_count)===1?"":"s"):""}{Number(o.submission_gap_count||0)>0?" · "+o.submission_gap_count+" submission gap"+(Number(o.submission_gap_count)===1?"":"s"):""}</span>
            {o.auto_next_action?<span className="status-meta wrap"><strong>Next:</strong> {o.auto_next_action}{o.auto_next_action_due_at?" · due "+fmtDate(o.auto_next_action_due_at):""}</span>:null}
          </div>
          <div style={{display:"flex",gap:8,alignItems:"center",flexWrap:"wrap"}}><span className="score-chip score-high">{Math.round(Number(o.bid_score||0))}</span><span className="pill">{o.bid_recommendation}</span>{Number(o.hard_blocker_count||0)>0?<span className="pill">blocked</span>:null}{o.promoted_tender_record_id?<Link className="button" href={("/procurement/"+o.promoted_tender_record_id) as Route}>Open pursuit</Link>:o.source_url?<a className="button" href={o.source_url} target="_blank" rel="noreferrer">Review source</a>:null}</div>
        </div>)}
        {inbox.length===0?<div className="muted">No prioritized procurement items currently require attention.</div>:null}
      </div>
      {sourceIssues.length||manualSources.length||secondaryCoverage.length?<div style={{marginTop:12}}>
        <strong>Source health</strong>
        <p className="muted">{sourceIssues.slice(0,6).map((x:any)=>x.display_name+": "+x.health_status).join(" · ")}{secondaryCoverage.length?(sourceIssues.length?" · ":"")+secondaryCoverage.length+" secondary coverage route"+(secondaryCoverage.length===1?"":"s"):""}{manualSources.length?((sourceIssues.length||secondaryCoverage.length)?" · ":"")+manualSources.length+" manual-only source"+(manualSources.length===1?"":"s"):""}</p>
        {manualSources.length?<p className="muted"><strong>Manual portal gaps:</strong> {manualSources.map((x:any)=>x.display_name).join(" · ")}</p>:null}
      </div>:null}
    </section>

    <section className="panel" style={{marginBottom:18}}>
      <div className="panel-head"><div><span className="eyebrow">DIRECT PURSUIT INTAKE</span><h3>Add a tender outside the normal regional scout</h3></div><span className="muted">Use for a known CanadaBuys / SAP / MERX opportunity you want CB to pursue.</span></div>
      <form action={addManualTender} className="manual-tender-form">
        <input name="external_id" placeholder="Tender / solicitation ID" required/>
        <input name="title" placeholder="Opportunity title" required/>
        <input name="buyer_name" placeholder="Buyer"/>
        <input name="region" placeholder="Delivery region"/>
        <input name="category" placeholder="Category"/>
        <input name="closing_date" type="date"/>
        <input name="source_url" placeholder="Source URL"/>
        <select name="source" defaultValue="CanadaBuys"><option>CanadaBuys</option><option>SAP Business Network</option><option>MERX</option><option>Bids & Tenders</option><option>Manual</option></select>
        <select name="response_mode" defaultValue="formal_rfp"><option value="formal_rfp">RFP / RISO</option><option value="formal_tender">Formal tender</option><option value="rfq">RFQ</option><option value="registration_required">Registration required</option></select>
        <button className="primary" type="submit">Create pursuit</button>
      </form>
    </section>

    <section className="metrics" style={{marginBottom:18}}>
      <div className="metric"><span>Open tenders</span><strong>{open.length}</strong></div>
      <div className="metric"><span>High fit ≥75</span><strong>{highFit}</strong></div>
      <div className="metric"><span>Closing ≤7 days</span><strong>{urgent}</strong></div>
      <div className="metric"><span>Active pursuits</span><strong>{pursuing}</strong></div>
      <div className="metric"><span>Submission ready</span><strong>{open.filter((t:any)=>readinessByTender.get(t.id)?.ready_to_submit).length}</strong></div>
      <div className="metric"><span>Prime-bid fit</span><strong>{primeBids}</strong></div>
      <div className="metric"><span>Subtrade plays</span><strong>{subtradePursuits}</strong></div>
      <div className="metric"><span>Future pipeline</span><strong>{futurePipeline}</strong></div>
    </section>

    <section className="source-strip">
      {(sources??[]).map((source:any)=><div key={source.source_key}>
        <strong>{source.display_name}</strong>
        <span>{(source.source_category||"public_tender").replaceAll("_"," ")} · priority {source.discovery_priority??50} · {source.coverage_tier||source.ingestion_mode.replace("_"," ")} · {source.adapter_status||"unverified"}{source.supports_small_jobs?" · small jobs":""}{source.source_key==="canadabuys" ? ` · ${sourceCounts.get("CanadaBuys")||0} open` : ""}</span>
        {source.buyer_scope?<span>{source.buyer_scope}</span>:null}
        {source.contact_strategy?<span><strong>Strategy:</strong> {source.contact_strategy}</span>:null}
        {source.registration_url?<a href={source.registration_url} target="_blank" rel="noreferrer">Registration / portal ↗</a>:null}
        {source.last_success_at?<span>last success {fmtDate(source.last_success_at)}</span>:null}
        {source.last_error?<span>{source.last_error}</span>:null}
      </div>)}
      <div style={{display:"flex",gap:8,flexWrap:"wrap"}}><form action={runRegionalTenderScout}><button className="primary" type="submit">Scan + refresh intelligence</button></form><form action={runCanadaBuysScout}><button className="button" type="submit">CanadaBuys only</button></form><form action={runTenderIntelligence}><button className="button" type="submit">Refresh intelligence</button></form></div>
    </section>

    <section className="table-panel" style={{marginBottom:18}}>
      <div className="panel-head"><div><span className="eyebrow">SUPPLIER READINESS</span><h3>Registrations and prequalification</h3></div><div style={{display:"flex",gap:8,alignItems:"center",flexWrap:"wrap"}}><span className="muted">{(registrations??[]).filter((r:any)=>r.status==="active"||r.status==="not_required").length}/{(registrations??[]).length} ready</span><Link className="button" href="/procurement/registration">Registration checklist</Link></div></div>
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
          <div>{(()=>{const intel=intelligenceByTender.get(t.id);return <><span className="score-chip score-high">{intel?.overall_score??t.fit_score??"—"}</span><span className="status-meta">{intel?.pursuit_mode?.replaceAll("_"," ")||"discovery fit"}</span><span className="status-meta">{intel?.next_best_action||t.fit_note||"Fit note pending"}</span></>;})()}</div>
          <div>{(propertiesByTender.get(t.id)??[]).length?<>{(propertiesByTender.get(t.id)??[]).map((p:any)=><span className="status-meta" key={p.property_id}>{p.name}</span>)}</>:<span className="status-meta">property mapping gap</span>}</div>
          <div className="bid-control">
            <span className="status-meta">{readinessByTender.get(t.id)?.ready_to_submit?"submission ready":"gates open"}{readinessByTender.get(t.id)?(" · "+Number(readinessByTender.get(t.id).mandatory_requirement_gaps||0)+" req · "+Number(readinessByTender.get(t.id).unacknowledged_amendments||0)+" amend · "+Number(readinessByTender.get(t.id).high_open_risks||0)+" risk"):""}</span>
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

    <section className="table-panel" style={{marginBottom:18}}>
      <div className="panel-head"><div><span className="eyebrow">SUBTRADE ENGINE</span><h3>Downstream packages hidden inside prime tenders</h3></div><span className="muted">{(subtradeRows??[]).length} active packages</span></div>
      <div className="table-wrap"><div className="targets-grid procurement-grid">
        <div className="targets-grid-row targets-grid-head"><div>Fit</div><div>Package</div><div>Parent tender</div><div>Status</div><div>Due</div><div>Next action</div></div>
        {(subtradeRows??[]).map((x:any)=>{const t=(tenders??[]).find((r:any)=>r.id===x.tender_record_id);return <div className="targets-grid-row" key={x.id}>
          <div><span className="score-chip score-high">{x.fit_score}</span></div>
          <div><strong>{x.package_title}</strong><span className="status-meta">{x.trade.replaceAll("_"," ")}</span><span className="status-meta">{x.scope_summary||"Scope review required"}</span></div>
          <div>{t?<><Link href={`/procurement/${t.id}` as Route}>{t.title}</Link><span className="status-meta">{t.buyer_name||"—"}</span></>:<span className="muted">Tender unavailable</span>}</div>
          <div><span className="pill">{x.pursuit_status.replaceAll("_"," ")}</span></div>
          <div>{fmtDate(x.due_at)}</div>
          <div><strong>{x.suggested_action||"Identify bidding primes and estimator contacts"}</strong></div>
        </div>})}
        {!(subtradeRows??[]).length?<div className="targets-grid-row"><div className="muted">Refresh intelligence to extract subtrade packages.</div></div>:null}
      </div></div>
    </section>

    <section className="table-panel" style={{marginBottom:18}}>
      <div className="panel-head"><div><span className="eyebrow">FUTURE OPPORTUNITIES</span><h3>Contract cycles and predicted rebids</h3></div><span className="muted">{(futureRows??[]).length} pre-tender signals · {(cycleRows??[]).length} tracked cycles</span></div>
      <div className="table-wrap"><div className="targets-grid procurement-grid">
        <div className="targets-grid-row targets-grid-head"><div>Window</div><div>Opportunity</div><div>Buyer</div><div>Fit</div><div>Readiness</div><div>Pre-position action</div></div>
        {(futureRows??[]).map((x:any)=><div className="targets-grid-row" key={x.id}>
          <div><strong>{fmtDate(x.expected_publish_start)}</strong><span className="status-meta">to {fmtDate(x.expected_publish_end)}</span></div>
          <div><strong>{x.title}</strong><span className="status-meta">{x.service_category}{x.incumbent_name?` · incumbent ${x.incumbent_name}`:""}</span></div>
          <div>{x.buyer_name}</div>
          <div><span className="score-chip score-high">{x.fit_score}</span></div>
          <div><span className="pill">{x.pursuit_priority||x.confidence}</span><span className="status-meta">contact {x.contact_readiness_status||"unknown"} · vendor {x.vendor_readiness_status||"unknown"}</span><span className="status-meta">registration {x.supplier_registration_status||"unknown"} · {x.target_id?"target routed":"target pending"}</span>{x.registration_url&&x.vendor_readiness_status!=="ready"?<a href={x.registration_url} target="_blank" rel="noreferrer">Open registration</a>:null}<form action={updateFutureOpportunityStatus} className="inline-form"><input type="hidden" name="future_id" value={x.id}/><select name="status" defaultValue={x.status}>{["watch","research","pre_position","published","converted","closed"].map(v=><option key={v} value={v}>{v.replaceAll("_"," ")}</option>)}</select><button className="button" type="submit">Update</button></form></div>
          <div><strong>{x.next_action||"Research buyer and incumbent"}</strong>{x.next_action_at?<span className="status-meta">start {fmtDate(x.next_action_at)}</span>:null}</div>
        </div>)}
        {!(futureRows??[]).length?<div className="targets-grid-row"><div className="muted">Award and contract-cycle data will populate pre-tender opportunities here.</div></div>:null}
      </div></div>
    </section>

    <section className="table-panel" style={{marginBottom:18}}><div className="panel-head"><div><span className="eyebrow">SOURCE HEALTH</span><h3>Regional scout runs</h3></div></div><div className="table-wrap"><div className="targets-grid procurement-grid">
      <div className="targets-grid-row targets-grid-head"><div>Source</div><div>Status</div><div>Fetched</div><div>Qualified</div><div>Writes</div><div>Leads</div></div>
      {(regionalRuns??[]).map((r:any)=><div className="targets-grid-row" key={r.id}><div><strong>{r.source_name}</strong><span className="status-meta">{fmtDate(r.started_at)}</span></div><div><span className="pill">{r.status}</span>{r.error_message?<span className="status-meta">{r.error_message}</span>:null}</div><div>{r.fetched_count}</div><div>{r.qualifying_count}</div><div>{Number(r.inserted_count||0)+Number(r.updated_count||0)}</div><div>{r.lead_created_count}</div></div>)}
    </div></div></section>

    <section className="table-panel"><div className="panel-head"><div><span className="eyebrow">CANADABUYS</span><h3>Federal scout runs</h3></div></div><div className="table-wrap"><div className="targets-grid procurement-grid">
      <div className="targets-grid-row targets-grid-head"><div>Run</div><div>Status</div><div>Fetched</div><div>Qualified</div><div>Writes</div><div>Leads</div></div>
      {(runs??[]).map((r:any)=><div className="targets-grid-row" key={r.id}><div><strong>{fmtDate(r.started_at)}</strong><span className="status-meta">{r.finished_at?fmtDate(r.finished_at):"running"}</span></div><div><span className="pill">{r.status}</span>{r.error_message?<span className="status-meta">{r.error_message}</span>:null}</div><div>{r.fetched_count}</div><div>{r.qualifying_count}</div><div>{Number(r.inserted_count||0)+Number(r.updated_count||0)}</div><div>{r.lead_created_count}</div></div>)}
    </div></div></section>
  </main>;
}

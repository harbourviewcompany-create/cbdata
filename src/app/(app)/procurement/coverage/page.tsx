/* eslint-disable @typescript-eslint/no-explicit-any */
import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { requireWorkspace } from "@/lib/workspace";
import { runProcurementCoverageEngine } from "../actions";

function fmtDate(v:string|null){if(!v)return "—";return new Date(v).toLocaleDateString("en-CA",{year:"numeric",month:"short",day:"numeric"});}
function fmtDateTime(v:string|null){if(!v)return "—";return new Date(v).toLocaleString("en-CA",{year:"numeric",month:"short",day:"numeric",hour:"numeric",minute:"2-digit"});}

export default async function ProcurementCoveragePage(){
  const ctx=await requireWorkspace();
  const s=await createClient();

  const [{data:buyers},{data:opportunities},{data:runs},{data:sources}]=await Promise.all([
    (s as any).from("v_procurement_buyer_coverage").select("*").eq("workspace_id",ctx.workspaceId).order("watch_priority",{ascending:false}).limit(250),
    (s as any).from("procurement_opportunities").select("id,source_key,external_id,buyer_name,title,opportunity_type,region,published_at,closing_at,source_url,service_fit,relevance_score,classification_status,matched_target_id,promoted_tender_record_id").eq("workspace_id",ctx.workspaceId).order("relevance_score",{ascending:false,nullsFirst:false}).order("closing_at",{ascending:true,nullsFirst:false}).limit(250),
    (s as any).from("procurement_coverage_runs").select("*").eq("workspace_id",ctx.workspaceId).order("started_at",{ascending:false}).limit(12),
    (s as any).from("tender_sources").select("source_key,display_name,ingestion_mode,enabled,last_run_at,last_success_at,last_error").eq("workspace_id",ctx.workspaceId).eq("enabled",true).order("display_name")
  ]);

  const now=Date.now();
  const open=(opportunities??[]).filter((o:any)=>!o.closing_at||new Date(o.closing_at).getTime()>=now);
  const actionable=open.filter((o:any)=>["actionable","promoted"].includes(o.classification_status));
  const watch=open.filter((o:any)=>o.classification_status==="watch");
  const gaps=(buyers??[]).filter((b:any)=>b.coverage_status==="gap"||b.coverage_status==="partial");
  const monitored=(buyers??[]).filter((b:any)=>b.coverage_status==="monitored").length;
  const targeted=(buyers??[]).filter((b:any)=>b.has_target).length;
  const staleSources=(sources??[]).filter((x:any)=>!x.last_success_at||(now-new Date(x.last_success_at).getTime())>48*3600000);

  return <main className="list-shell">
    <header className="list-header">
      <Link className="back" href="/procurement">← Tender Intelligence</Link>
      <span className="eyebrow">REGIONAL PROCUREMENT</span>
      <h1>Coverage Engine</h1>
      <p className="muted tender-intro">Ingest the regional procurement universe first, then classify, score, promote, and route the best buyers and opportunities into Targets and Tender Intelligence.</p>
      <div style={{display:"flex",gap:8,flexWrap:"wrap",marginTop:12}}>
        <form action={runProcurementCoverageEngine}><button className="primary" type="submit">Run coverage engine</button></form>
        <Link className="button" href="/targets">Open targets</Link>
      </div>
    </header>

    <section className="metrics" style={{marginBottom:18}}>
      <div className="metric"><span>Buyer universe</span><strong>{(buyers??[]).length}</strong></div>
      <div className="metric"><span>Monitored</span><strong>{monitored}</strong></div>
      <div className="metric"><span>Coverage gaps</span><strong>{gaps.length}</strong></div>
      <div className="metric"><span>Buyer targets</span><strong>{targeted}</strong></div>
      <div className="metric"><span>Open universe</span><strong>{open.length}</strong></div>
      <div className="metric"><span>Actionable</span><strong>{actionable.length}</strong></div>
      <div className="metric"><span>Watch</span><strong>{watch.length}</strong></div>
      <div className="metric"><span>Stale sources</span><strong>{staleSources.length}</strong></div>
    </section>

    <section className="table-panel" style={{marginBottom:18}}>
      <div className="panel-head"><div><span className="eyebrow">BUYER UNIVERSE</span><h3>Regional buyer coverage</h3></div><span className="muted">{monitored}/{(buyers??[]).length} fully monitored</span></div>
      <div className="table-wrap"><div className="targets-grid procurement-grid">
        <div className="targets-grid-row targets-grid-head"><div>Buyer</div><div>Sector / region</div><div>Coverage</div><div>Open</div><div>Intelligence</div><div>Target</div></div>
        {(buyers??[]).map((b:any)=><div className="targets-grid-row" key={b.id}>
          <div><strong>{b.display_name}</strong><span className="status-meta">priority {b.watch_priority}</span></div>
          <div><strong>{b.sector}</strong><span className="status-meta">{b.region||b.jurisdiction||"—"}</span></div>
          <div><span className="pill">{b.coverage_status}</span><span className="status-meta">{b.primary_source_key||"source gap"}</span></div>
          <div><strong>{b.open_opportunity_count||0}</strong><span className="status-meta">{b.actionable_count||0} actionable · best {b.best_open_score??"—"}</span></div>
          <div><span className="status-meta">{(b.service_fit||[]).slice(0,4).join(" · ")||"fit pending"}</span><span className="status-meta">contacts {b.known_contact_count||0} · rebid {b.expected_rebid_date?fmtDate(b.expected_rebid_date):"—"}</span></div>
          <div>{b.has_target?<><strong>Targeted</strong><span className="status-meta">score {b.target_score??"—"}</span></>:<span className="status-meta">target gap</span>}</div>
        </div>)}
      </div></div>
    </section>

    <section className="table-panel" style={{marginBottom:18}}>
      <div className="panel-head"><div><span className="eyebrow">RAW → ACTIONABLE</span><h3>Regional opportunity universe</h3></div><span className="muted">Low relevance stays searchable instead of being discarded.</span></div>
      <div className="table-wrap"><div className="targets-grid procurement-grid">
        <div className="targets-grid-row targets-grid-head"><div>Close</div><div>Opportunity</div><div>Buyer / source</div><div>Score</div><div>Classification</div><div>Route</div></div>
        {open.slice(0,120).map((o:any)=><div className="targets-grid-row" key={o.id}>
          <div><strong>{fmtDate(o.closing_at)}</strong><span className="status-meta">{o.opportunity_type.replaceAll("_"," ")}</span></div>
          <div><strong>{o.title}</strong><span className="status-meta">{o.external_id}</span><span className="status-meta">{(o.service_fit||[]).slice(0,4).join(" · ")||"indirect buyer fit"}</span></div>
          <div><strong>{o.buyer_name||"—"}</strong><span className="status-meta">{o.source_key} · {o.region||"NCR"}</span></div>
          <div><span className="score-chip score-high">{o.relevance_score??"—"}</span></div>
          <div><span className="pill">{o.classification_status}</span></div>
          <div>{o.promoted_tender_record_id?<Link className="button" href={"/procurement/"+o.promoted_tender_record_id}>Tender</Link>:o.matched_target_id?<Link className="button" href="/targets">Target</Link>:o.source_url?<a className="button" href={o.source_url} target="_blank" rel="noreferrer">Source</a>:<span className="status-meta">archive</span>}</div>
        </div>)}
      </div></div>
    </section>

    <section className="table-panel" style={{marginBottom:18}}>
      <div className="panel-head"><div><span className="eyebrow">COVERAGE GAPS</span><h3>Where the engine is still blind</h3></div></div>
      <div className="table-wrap"><div className="targets-grid procurement-grid">
        <div className="targets-grid-row targets-grid-head"><div>Buyer</div><div>Status</div><div>Priority</div><div>Source</div><div>Contacts</div><div>Next signal</div></div>
        {gaps.map((b:any)=><div className="targets-grid-row" key={b.id}>
          <div><strong>{b.display_name}</strong></div><div><span className="pill">{b.coverage_status}</span></div><div>{b.watch_priority}</div><div>{b.primary_source_key||"missing"}</div><div>{b.known_contact_count||0}</div><div>{b.next_expected_procurement_at?fmtDate(b.next_expected_procurement_at):"Add live source / award history"}</div>
        </div>)}
      </div></div>
    </section>

    <section className="table-panel" style={{marginBottom:18}}>
      <div className="panel-head"><div><span className="eyebrow">SOURCE HEALTH</span><h3>Coverage source freshness</h3></div></div>
      <div className="tender-list">
        {(sources??[]).map((x:any)=><div className="tender-list-row" key={x.source_key}>
          <div><strong>{x.display_name}</strong><span className="status-meta">{x.ingestion_mode.replaceAll("_"," ")} · last success {fmtDateTime(x.last_success_at)}</span>{x.last_error?<span className="status-meta wrap">{x.last_error}</span>:null}</div>
          <span className="pill">{!x.last_success_at?"never":(now-new Date(x.last_success_at).getTime())>48*3600000?"stale":"fresh"}</span>
        </div>)}
      </div>
    </section>

    <section className="table-panel">
      <div className="panel-head"><div><span className="eyebrow">ENGINE RUNS</span><h3>Classification and routing history</h3></div></div>
      <div className="table-wrap"><div className="targets-grid procurement-grid">
        <div className="targets-grid-row targets-grid-head"><div>Run</div><div>Status</div><div>Classified</div><div>Actionable</div><div>Targets</div><div>Promoted</div></div>
        {(runs??[]).map((r:any)=><div className="targets-grid-row" key={r.id}><div><strong>{fmtDateTime(r.started_at)}</strong></div><div><span className="pill">{r.status}</span></div><div>{r.opportunities_classified}</div><div>{r.actionable_count}</div><div>{r.targets_created}</div><div>{r.tenders_promoted}</div></div>)}
      </div></div>
    </section>
  </main>;
}

import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { runCanadaBuysScout } from "./actions";

function fmtDate(value:string|null){ if(!value) return "—"; return new Date(value).toLocaleDateString("en-CA",{year:"numeric",month:"short",day:"numeric"}); }

export default async function ProcurementPage(){
  const s=await createClient();
  const {data:{user}}=await s.auth.getUser();
  if(!user) return null;

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const {data:tenders}=await (s as any).from("tender_records")
    .select("id,external_id,title,buyer_name,category,region,published_date,closing_date,source_url,status,matched_organization_id,lead_id,response_mode,registration_required,fit_score,fit_note,last_verified_at")
    .eq("source","CanadaBuys")
    .order("closing_date",{ascending:true})
    .limit(100);

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const {data:runs}=await (s as any).from("canadabuys_runs")
    .select("id,started_at,finished_at,status,fetched_count,qualifying_count,inserted_count,updated_count,lead_created_count,error_count,error_message")
    .order("started_at",{ascending:false})
    .limit(8);

  const open=(tenders??[]).filter((t:any)=>t.closing_date && new Date(t.closing_date+"T23:59:59Z")>=new Date());
  const registration=open.filter((t:any)=>t.registration_required).length;
  const formal=open.filter((t:any)=>["formal_rfp","formal_tender","registration_required"].includes(t.response_mode)).length;

  return <main className="list-shell">
    <header className="list-header">
      <Link className="back" href="/dashboard">← Command</Link>
      <span className="eyebrow">GROWTH / PROCUREMENT</span>
      <h1>CanadaBuys Scout</h1>
      <p className="muted" style={{maxWidth:760,marginTop:8}}>
        Live prospecting for Ottawa / National Capital Region grounds, landscaping, snow, maintenance, janitorial, cleaning, facility, property, repair and caretaking notices. Results are deduplicated against existing tender records and linked to buyer organizations and leads.
      </p>
    </header>

    <section className="metrics" style={{marginBottom:18}}>
      <div className="metric"><span>Open notices</span><strong>{open.length}</strong></div>
      <div className="metric"><span>Formal response</span><strong>{formal}</strong></div>
      <div className="metric"><span>Registration flags</span><strong>{registration}</strong></div>
      <div className="metric"><span>Linked leads</span><strong>{open.filter((t:any)=>t.lead_id).length}</strong></div>
    </section>

    <section className="panel" style={{marginBottom:18}}>
      <div className="panel-head"><div><span className="eyebrow">SOURCE CONTROL</span><h3>Run CanadaBuys Scout</h3></div></div>
      <p className="muted" style={{marginTop:8}}>Checks the current CanadaBuys tender index across the configured service terms, verifies candidate notice pages, and writes only open NCR matches.</p>
      <form action={runCanadaBuysScout} style={{marginTop:14}}><button className="primary" type="submit">Run live scout</button></form>
    </section>

    <section className="table-panel" style={{marginBottom:18}}>
      <div className="panel-head"><div><span className="eyebrow">OPEN PIPELINE</span><h3>Qualifying CanadaBuys notices</h3></div></div>
      <div className="table-wrap">
        <div className="targets-grid procurement-grid">
          <div className="targets-grid-row targets-grid-head"><div>Close</div><div>Notice</div><div>Buyer</div><div>Fit</div><div>Response</div><div>Action</div></div>
          {open.length===0 ? <div className="targets-grid-row"><div className="muted">No open qualifying notices have been ingested yet.</div></div> : open.map((t:any)=>
            <div className="targets-grid-row" key={t.id}>
              <div><strong>{fmtDate(t.closing_date)}</strong>{t.published_date?<span className="status-meta">opened {fmtDate(t.published_date)}</span>:null}</div>
              <div><strong>{t.title}</strong><span className="status-meta">{t.category||"Service"} · {t.external_id}</span></div>
              <div><strong>{t.buyer_name||"—"}</strong><span className="status-meta">{t.region||"NCR"}</span></div>
              <div><span className="score-chip score-high">{t.fit_score??"—"}</span><span className="status-meta">{t.fit_note||"Fit note pending"}</span></div>
              <div><span className="pill">{t.response_mode||"review"}</span>{t.registration_required?<span className="region-tag">registration</span>:null}</div>
              <div className="row-actions"><a className="button" href={t.source_url} target="_blank" rel="noreferrer">Open notice</a>{t.lead_id?<Link className="button" href={"/sales"}>Lead</Link>:null}</div>
            </div>
          )}
        </div>
      </div>
    </section>

    <section className="table-panel">
      <div className="panel-head"><div><span className="eyebrow">RUN HISTORY</span><h3>Scout health</h3></div></div>
      <div className="table-wrap">
        <div className="targets-grid procurement-grid">
          <div className="targets-grid-row targets-grid-head"><div>Run</div><div>Status</div><div>Fetched</div><div>Qualified</div><div>Writes</div><div>Leads</div></div>
          {(runs??[]).map((r:any)=><div className="targets-grid-row" key={r.id}>
            <div><strong>{fmtDate(r.started_at)}</strong><span className="status-meta">{r.finished_at?fmtDate(r.finished_at):"running"}</span></div>
            <div><span className="pill">{r.status}</span>{r.error_message?<span className="status-meta">{r.error_message}</span>:null}</div>
            <div>{r.fetched_count}</div><div>{r.qualifying_count}</div><div>{Number(r.inserted_count||0)+Number(r.updated_count||0)}</div><div>{r.lead_created_count}</div>
          </div>)}
        </div>
      </div>
    </section>
  </main>;
}

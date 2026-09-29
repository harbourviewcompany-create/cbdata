import Link from "next/link";
// Production reconciliation marker: outreach command queue is on main.
import type { Route } from "next";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { generateDraft, generateAdaptiveFollowup, approveDraft, markSent, classifyReply, enrollDefaultSequence, runDueSequences } from "./actions";

type QueueRow = {
  id:string; organization_display_name:string|null; contact_display_name:string|null;
  contact_email:string|null; contact_phone:string|null; contact_job_title:string|null;
  score:number|null; outreach_readiness_score:number; contact_confidence_score:number;
  property_count:number; high_signal_property_count:number; open_signal_count:number;
  why_now:string|null; service_fit:string[]|null; recommended_action:string;
  next_action:string|null; next_action_due_at:string|null; status:string;
  latest_draft_id:string|null; latest_draft_state:string|null; latest_draft_subject:string|null;
  latest_draft_body:string|null; latest_draft_channel:string|null;
};

function due(v:string|null){ if(!v) return "—"; return new Date(v).toLocaleDateString(); }
function mailto(email:string|null,subject:string|null,body:string|null){
  if(!email) return null;
  return `mailto:${email}?subject=${encodeURIComponent(subject ?? "")}&body=${encodeURIComponent(body ?? "")}`;
}

export default async function OutreachPage({
  searchParams,
}:{ searchParams:Promise<Record<string,string|string[]|undefined>> }) {
  const s=await createClient();
  const {data:{user}}=await s.auth.getUser();
  if(!user) redirect("/login");
  const params=await searchParams;
  const action=typeof params.action==="string"?params.action:"";
  let query=(s as any).from("v_outreach_execution_queue").select("*")
    .in("status",["queued","contacted","responded"])
    .order("outreach_readiness_score",{ascending:false})
    .order("score",{ascending:false,nullsFirst:false})
    .limit(150);
  if(action==="research") query=query.in("recommended_action",["research","verify_contact"]);
  else if(action) query=query.eq("recommended_action",action);
  const {data,error}=await query;
  const rows=(data ?? []) as QueueRow[];
  const {data:commandRows}=await (s as any).rpc("get_daily_outreach_command_queue",{p_limit:20});
  const targetIds=rows.map(r=>r.id);
  const {data:coverageRows}=await (s as any).from("v_outreach_contact_coverage").select("*").in("outreach_target_id",targetIds.length?targetIds:["00000000-0000-0000-0000-000000000000"]);
  const {data:gapRows}=await (s as any).from("v_contact_enrichment_queue").select("*").order("priority_score",{ascending:false}).limit(50);
  const coverageByTarget=new Map<string,any>((coverageRows??[]).map((x:any)=>[x.outreach_target_id,x]));
  const ready=rows.filter(r=>r.outreach_readiness_score>=80).length;
  const drafts=rows.filter(r=>r.recommended_action==="review_draft").length;
  const sends=rows.filter(r=>r.recommended_action==="send").length;
  const followups=rows.filter(r=>r.recommended_action==="follow_up").length;
  const research=rows.filter(r=>["research","verify_contact"].includes(r.recommended_action)).length;

  return <main className="list-shell">
    <header className="list-header">
      <Link className="back" href={"/dashboard" as Route}>← Command</Link>
      <span className="eyebrow">GROWTH EXECUTION</span>
      <h1>Outreach</h1>
      <p className="muted" style={{marginTop:8,maxWidth:760}}>
        Evidence-driven queue: who to contact, why now, what to send, and the next action after every touch.
      </p>
    </header>

    <section className="panel" style={{marginBottom:18}}>
      <div className="panel-head"><div><span className="eyebrow">TODAY</span><h3>Outreach Command Queue</h3></div><span className="muted">{commandRows?.length??0} highest-value actions</span></div>
      <div style={{display:"grid",gap:8}}>
        {(commandRows??[]).slice(0,10).map((r:any)=><div key={r.outreach_target_id} style={{display:"grid",gridTemplateColumns:"64px minmax(180px,1fr) 130px minmax(180px,1.2fr) auto",gap:12,alignItems:"center",padding:"10px 0",borderBottom:"1px solid var(--line)"}}>
          <strong style={{fontSize:22}}>{r.command_score}</strong>
          <div><Link href={`/targets/${r.outreach_target_id}` as Route}><strong>{r.organization_display_name}</strong></Link><div className="muted" style={{fontSize:11}}>{r.contact_display_name??"No named contact"} · {r.priority_reason}</div></div>
          <span className="pill">{String(r.next_touch_type).replaceAll("_"," ")}</span>
          <span className="muted" style={{fontSize:11}}>{r.why_now??"Account readiness"}</span>
          {r.next_touch_type==="introduction"?<form action={generateDraft}><input type="hidden" name="target_id" value={r.outreach_target_id}/><input type="hidden" name="channel" value="email"/><input type="hidden" name="objective" value="introduction"/><button className="primary" type="submit">Draft</button></form>:<form action={generateAdaptiveFollowup}><input type="hidden" name="target_id" value={r.outreach_target_id}/><input type="hidden" name="channel" value="email"/><button className="primary" type="submit">Draft next touch</button></form>}
        </div>)}
      </div>
    </section>

    <section className="metrics" style={{marginBottom:18}}>
      <div className="metric"><span>Ready ≥80</span><strong>{ready}</strong></div>
      <div className="metric"><span>Drafts to review</span><strong>{drafts}</strong></div>
      <div className="metric"><span>Approved to send</span><strong>{sends}</strong></div>
      <div className="metric"><span>Follow-ups due</span><strong>{followups}</strong></div>
      <div className="metric"><span>Needs enrichment</span><strong>{research}</strong></div>
    </section>

    {(gapRows?.length??0)>0?<section className="panel" style={{marginBottom:18}}>
      <div className="panel-head"><div><span className="eyebrow">CONTACT EXPANSION</span><h3>Buying-committee gaps</h3></div><span className="muted">{gapRows?.length??0} prioritized research tasks</span></div>
      <div style={{display:"grid",gap:8}}>
        {(gapRows??[]).slice(0,8).map((g:any)=><div key={g.id} style={{display:"grid",gridTemplateColumns:"minmax(180px,1fr) 140px 80px minmax(240px,1.4fr)",gap:12,alignItems:"center",padding:"8px 0",borderBottom:"1px solid var(--line)"}}>
          <strong>{g.organization_name}</strong><span className="pill">{g.missing_role.replaceAll("_"," ")}</span><strong>{g.priority_score}</strong><span className="muted" style={{fontSize:11}}>{g.research_query}</span>
        </div>)}
      </div>
    </section>:null}

    <section className="panel" style={{marginBottom:18}}>
      <div className="hero-cta" style={{display:"flex",gap:8,flexWrap:"wrap"}}>
        <Link className="button" href={"/outreach" as Route}>All</Link>
        <Link className="button" href={"/outreach?action=generate_draft" as Route}>Need draft</Link>
        <Link className="button" href={"/outreach?action=review_draft" as Route}>Review</Link>
        <Link className="button" href={"/outreach?action=send" as Route}>Send</Link>
        <Link className="button" href={"/outreach?action=follow_up" as Route}>Follow up</Link>
        <Link className="button" href={"/outreach?action=research" as Route}>Research</Link>
        <form action={runDueSequences}><button className="primary" type="submit">Run due sequence steps</button></form>
      </div>
    </section>

    {error ? <section className="table-panel"><p className="muted">{error.message}</p></section> : null}

    <section className="table-panel">
      <div style={{display:"grid",gap:10}}>
        {rows.map(r=>{
          const emailLink=mailto(r.contact_email,r.latest_draft_subject,r.latest_draft_body);
          const legacyDraft=!!r.latest_draft_body && /snow, grounds, janitorial|if you are reviewing contractors/i.test(r.latest_draft_body);
          return <article key={r.id} className="outreach-queue-card">
            <div className="outreach-queue-summary">
              <div>
                <span className="eyebrow">SCORE</span>
                <strong style={{display:"block",fontSize:26}}>{r.outreach_readiness_score}</strong>
                <span className="muted" style={{fontSize:11}}>contact {r.contact_confidence_score}</span>
              </div>
              <div>
                <Link href={`/targets/${r.id}` as Route}><strong>{r.organization_display_name ?? "Target"}</strong></Link>
                <div className="muted" style={{fontSize:12,marginTop:4}}>{r.contact_display_name ?? "No named contact"}</div>
                <div className="muted" style={{fontSize:11}}>{r.contact_job_title ?? ""}</div>
                {(()=>{const cv=coverageByTarget.get(r.id);return cv?<div className="muted" style={{fontSize:11,marginTop:4}}>buying committee {cv.contact_count}/4 · coverage {cv.contact_coverage_score}%{!cv.has_decision_maker?" · decision-maker gap":""}{!cv.has_operations?" · operations gap":""}{!cv.has_procurement?" · procurement gap":""}</div>:null;})()}
                {r.contact_email ? <a href={`mailto:${r.contact_email}`} style={{fontSize:11}}>{r.contact_email}</a> : null}
              </div>
              <div>
                <span className="eyebrow">FIT &amp; TIMING</span>
                <div style={{fontSize:12,lineHeight:1.45,marginTop:4}}>{r.why_now ?? "Target intelligence available"}</div>
                <div className="muted" style={{fontSize:11,marginTop:5}}>
                  {r.property_count} properties · {r.high_signal_property_count} strong-fit properties · {r.open_signal_count ? `${r.open_signal_count} open signals` : "No verified buying trigger"}
                  {r.service_fit?.length ? ` · ${r.service_fit.join(" / ")}` : ""}
                </div>
              </div>
              <div>
                <span className="eyebrow">NEXT</span>
                <strong style={{display:"block",fontSize:12,marginTop:4,textTransform:"capitalize"}}>{r.recommended_action.replaceAll("_"," ")}</strong>
                <div className="muted" style={{fontSize:11,marginTop:4}}>{r.next_action ?? "—"} · {due(r.next_action_due_at)}</div>
              </div>
            </div>

            {r.latest_draft_body ? <details name="outreach-draft-review" className="outreach-draft-review">
              <summary>Review {r.latest_draft_state} message{r.latest_draft_subject ? ` · ${r.latest_draft_subject}` : ""}</summary>
              <div style={{marginTop:10,padding:12,border:"1px solid var(--line)",borderRadius:10,whiteSpace:"pre-wrap",fontSize:12,lineHeight:1.5}}>
                {r.latest_draft_subject ? <strong style={{display:"block",marginBottom:8}}>{r.latest_draft_subject}</strong> : null}
                {r.latest_draft_body}
              </div>
              {legacyDraft ? <p className="outreach-draft-warning">This older draft uses a generic service list. Rewrite it before approval.</p> : null}
            </details> : null}

            <div className="outreach-queue-actions">
              {(!r.latest_draft_id || r.latest_draft_state==="draft" || (legacyDraft && r.latest_draft_state==="approved") || r.recommended_action==="generate_draft") ? <form action={generateDraft} className="outreach-rewrite-form">
                <input type="hidden" name="target_id" value={r.id}/>
                <select name="objective" defaultValue="referral">
                  <option value="referral">Referral / right person</option><option value="introduction">Introduction</option>
                  <option value="meeting">Meeting</option><option value="site_walk">Site walkthrough</option>
                  <option value="vendor_registration">Vendor registration</option><option value="quote">Quote opportunity</option>
                </select>
                <select name="channel" defaultValue={r.latest_draft_channel ?? "email"} aria-label="Draft channel">
                  <option value="email">Email</option><option value="linkedin">LinkedIn</option>
                  <option value="call">Call opener</option><option value="voicemail">Voicemail</option><option value="sms">SMS</option>
                </select>
                <button className={r.latest_draft_id ? "button" : "primary"} type="submit">{r.latest_draft_id ? "Rewrite draft" : "Generate draft"}</button>
              </form> : null}
              {r.latest_draft_id && r.latest_draft_state==="draft" && !legacyDraft ? <form action={approveDraft}>
                <input type="hidden" name="target_id" value={r.id}/>
                <input type="hidden" name="draft_id" value={r.latest_draft_id}/>
                <button className="primary" type="submit">Approve message</button>
              </form> : null}
              {r.latest_draft_id && r.latest_draft_state==="approved" && !legacyDraft && r.latest_draft_channel==="email" && emailLink ? <a className="primary" href={emailLink}>Open email</a> : null}
              {r.latest_draft_id && r.latest_draft_state==="approved" && !legacyDraft ? <form action={markSent}>
                <input type="hidden" name="target_id" value={r.id}/>
                <input type="hidden" name="draft_id" value={r.latest_draft_id}/>
                <input type="hidden" name="provider" value="manual"/>
                <button className="button" type="submit">Mark sent + schedule follow-up</button>
              </form> : null}
              <form action={enrollDefaultSequence}>
                <input type="hidden" name="target_id" value={r.id}/>
                <button className="button" type="submit">Enroll 7-touch</button>
              </form>
              <details>
                <summary className="button" style={{cursor:"pointer"}}>Log reply</summary>
                <form action={classifyReply} style={{display:"grid",gap:8,minWidth:320,marginTop:8}}>
                  <input type="hidden" name="target_id" value={r.id}/>
                  <select name="channel" defaultValue={r.latest_draft_channel ?? "email"} aria-label="Reply channel">
                    <option value="email">Email</option><option value="linkedin">LinkedIn</option>
                    <option value="sms">SMS</option><option value="call">Call</option>
                    <option value="voicemail">Voicemail</option><option value="other">Other</option>
                  </select>
                  <select name="classification" defaultValue="interested">
                    <option value="interested">Interested</option><option value="request_quote">Request quote</option>
                    <option value="request_call">Request call</option><option value="referral">Referral</option>
                    <option value="under_contract">Under contract</option><option value="future_renewal">Future renewal</option>
                    <option value="wrong_person">Wrong person</option><option value="out_of_office">Out of office</option>
                    <option value="bounce">Bounce</option><option value="not_interested">Not interested</option><option value="other">Other</option>
                  </select>
                  <input name="summary" placeholder="Reply summary"/>
                  <input name="renewal_date" type="date"/>
                  <input name="referred_contact" placeholder="Referred contact"/>
                  <button className="button" type="submit">Save reply + next action</button>
                </form>
              </details>
            </div>
          </article>;
        })}
        {!rows.length ? <p className="muted">No outreach actions match this view.</p> : null}
      </div>
    </section>
  </main>;
}

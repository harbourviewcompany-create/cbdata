import Link from "next/link";
import type { Route } from "next";
import { customerNowAction, customerNowLane, customerNowScore } from "@/lib/customer-now";
import { approveDraft, generateDraft, markSent } from "./actions";

type FocusPursuit = {
  pursuit_id:string;
  primary_target_id:string;
  organization_display_name:string;
  contact_display_name:string|null;
  contact_job_title:string|null;
  contact_email:string|null;
  contact_phone:string|null;
  service_fit:string[]|null;
  why_now:string|null;
  next_action:string|null;
  next_action_due_at:string|null;
  needs_response_count:number;
  latest_reply_classification:string|null;
  latest_draft_id:string|null;
  latest_draft_state:string|null;
  latest_draft_subject:string|null;
  latest_draft_body:string|null;
  latest_draft_channel:string|null;
  latest_draft_quality_passed:boolean;
  opportunity_id:string|null;
  total_score:number;
  command_score:number;
  contact_coverage_score:number;
  high_signal_property_count:number;
  open_signal_count:number;
  stage:string;
  pursuit_status:string;
};

type FocusLead = {
  id:string;
  buyer_name:string;
  opportunity_title:string;
  region:string|null;
  inbox_bucket:string;
  conversion_score:number|string;
  deadline_at:string|null;
  contact_email:string|null;
  contact_phone:string|null;
};

function when(value:string|null|undefined) {
  if (!value) return "No due date";
  const date=new Date(value);
  const now=Date.now();
  const days=Math.ceil((date.getTime()-now)/86400000);
  if(days<0) return "Overdue";
  if(days===0) return "Today";
  if(days===1) return "Tomorrow";
  return new Intl.DateTimeFormat("en-CA",{month:"short",day:"numeric"}).format(date);
}

function mailto(email:string|null,subject:string|null,body:string|null) {
  if(!email) return null;
  return "mailto:"+email+"?subject="+encodeURIComponent(subject??"")+"&body="+encodeURIComponent(body??"");
}

function laneLabel(lane:string) {
  switch(lane){
    case "reply_now": return "Reply";
    case "send_now": return "Send";
    case "approve_now": return "Approve";
    case "call_now": return "Call";
    case "draft_now": return "Write";
    default: return "Research";
  }
}

export default function OutreachFocus({
  pursuits,
  workLeads,
  matchedReplies,
  pendingInbound,
  safeDue,
  blockedDue,
  researchOpen,
  pipeline,
  won,
}:{
  pursuits:FocusPursuit[];
  workLeads:FocusLead[];
  matchedReplies:number;
  pendingInbound:number;
  safeDue:number;
  blockedDue:number;
  researchOpen:number;
  pipeline:number;
  won:number;
}) {
  const top=pursuits.slice(0,8);
  const ready=top.filter(p=>customerNowLane(p)!=="research").length;
  const attention=matchedReplies+pendingInbound;
  const leadPreview=workLeads
    .filter(l=>["contact_now","review","research_contact"].includes(l.inbox_bucket))
    .slice(0,4);

  return <div className="outreach-focus">
    <section className="outreach-focus-hero">
      <div>
        <span className="eyebrow">TODAY</span>
        <h2>{attention>0?attention+" repl"+(attention===1?"y":"ies")+" need attention":ready+" accounts are ready to work"}</h2>
        <p>Do the next useful thing. Replies first, then ready-to-contact accounts, then new leads.</p>
      </div>
      <div className="outreach-focus-money">
        <span>Pipeline <strong>{pipeline.toLocaleString("en-CA",{style:"currency",currency:"CAD",maximumFractionDigits:0})}</strong></span>
        <span>Won <strong>{won.toLocaleString("en-CA",{style:"currency",currency:"CAD",maximumFractionDigits:0})}</strong></span>
      </div>
    </section>

    <section className="outreach-focus-stats">
      <Link href={"/outreach?view=replies" as Route} className={attention?"outreach-focus-stat urgent":"outreach-focus-stat"}>
        <span>Replies</span><strong>{attention}</strong><small>{matchedReplies} ready · {pendingInbound} processing</small>
      </Link>
      <div className="outreach-focus-stat">
        <span>Ready now</span><strong>{ready}</strong><small>top {top.length} accounts</small>
      </div>
      <Link href={"/outreach?view=work" as Route} className="outreach-focus-stat">
        <span>New leads</span><strong>{leadPreview.length}</strong><small>highest priority</small>
      </Link>
    </section>

    {attention>0?<section className="outreach-attention">
      <div>
        <span className="eyebrow">FIRST</span>
        <strong>Handle replies before sending more outreach.</strong>
        <p>{matchedReplies} classified repl{matchedReplies===1?"y":"ies"} and {pendingInbound} inbound message{pendingInbound===1?"":"s"} waiting on content or matching.</p>
      </div>
      <Link className="primary" href={"/outreach?view=replies" as Route}>Open replies</Link>
    </section>:null}

    <section className="panel outreach-next">
      <div className="panel-head">
        <div><span className="eyebrow">NEXT BEST ACTIONS</span><h3>Work this list</h3></div>
        <span className="muted">Only the top {top.length}</span>
      </div>

      <div className="outreach-action-list">
        {top.map((p,index)=>{
          const lane=customerNowLane(p);
          const email=mailto(p.contact_email,p.latest_draft_subject,p.latest_draft_body);
          return <article className="outreach-action-row" key={p.pursuit_id}>
            <div className="outreach-action-rank">{index+1}</div>
            <div className="outreach-action-main">
              <div className="outreach-action-title">
                <Link href={("/targets/"+p.primary_target_id) as Route}>{p.organization_display_name}</Link>
                <span className="pill">{laneLabel(lane)}</span>
              </div>
              <div className="outreach-action-person">
                {p.contact_display_name??"Direct contact needed"}{p.contact_job_title?" · "+p.contact_job_title:""}
              </div>
              <div className="outreach-action-why">{p.why_now??customerNowAction(p)}</div>
              <div className="outreach-action-meta">
                <span>{p.service_fit?.slice(0,2).join(" · ")||"Service fit pending"}</span>
                <span>{when(p.next_action_due_at)}</span>
                <span>{customerNowScore(p)}/100</span>
              </div>
            </div>
            <div className="outreach-action-cta">
              {lane==="reply_now"?<Link className="primary" href={"/outreach?view=replies" as Route}>Review reply</Link>:null}
              {lane==="send_now"&&email?<a className="primary" href={email}>Open email</a>:null}
              {lane==="send_now"&&p.latest_draft_id?<form action={markSent}>
                <input type="hidden" name="target_id" value={p.primary_target_id}/>
                <input type="hidden" name="draft_id" value={p.latest_draft_id}/>
                <input type="hidden" name="provider" value="manual"/>
                <button className="button">Mark sent</button>
              </form>:null}
              {lane==="approve_now"&&p.latest_draft_id?<form action={approveDraft}>
                <input type="hidden" name="target_id" value={p.primary_target_id}/>
                <input type="hidden" name="draft_id" value={p.latest_draft_id}/>
                <button className="primary">Approve draft</button>
              </form>:null}
              {lane==="call_now"&&p.contact_phone?<a className="primary" href={"tel:"+p.contact_phone}>Call</a>:null}
              {lane==="draft_now"?<form action={generateDraft}>
                <input type="hidden" name="target_id" value={p.primary_target_id}/>
                <input type="hidden" name="channel" value="email"/>
                <input type="hidden" name="objective" value="quote"/>
                <button className="primary">Write email</button>
              </form>:null}
              {lane==="research"?<Link className="primary" href={"/outreach?view=research" as Route}>Find contact</Link>:null}
              <Link className="outreach-text-link" href={("/targets/"+p.primary_target_id) as Route}>Details</Link>
            </div>
          </article>;
        })}
        {!top.length?<div className="outreach-focus-empty">No active accounts need outreach right now.</div>:null}
      </div>

      {pursuits.length>top.length?<div className="outreach-focus-footer">
        <Link className="button" href={"/outreach?view=accounts" as Route}>View all {pursuits.length} accounts</Link>
      </div>:null}
    </section>

    {leadPreview.length?<section className="panel outreach-lead-preview">
      <div className="panel-head">
        <div><span className="eyebrow">NEW WORK</span><h3>Leads worth reviewing</h3></div>
        <Link href={"/outreach?view=work" as Route}>View all leads</Link>
      </div>
      <div className="outreach-lead-list">
        {leadPreview.map(lead=><Link href={"/outreach?view=work" as Route} className="outreach-lead-row" key={lead.id}>
          <div><strong>{lead.opportunity_title}</strong><span>{lead.buyer_name}{lead.region?" · "+lead.region:""}</span></div>
          <div><strong>{Math.round(Number(lead.conversion_score??0))}</strong><span>fit</span></div>
        </Link>)}
      </div>
    </section>:null}

    <details className="outreach-automation">
      <summary>Automation & background work</summary>
      <div>
        <span>{safeDue} safe sequence step{safeDue===1?"":"s"} due</span>
        <span>{blockedDue} blocked by safety rules</span>
        <span>{researchOpen} contact research task{researchOpen===1?"":"s"} open</span>
      </div>
    </details>
  </div>;
}

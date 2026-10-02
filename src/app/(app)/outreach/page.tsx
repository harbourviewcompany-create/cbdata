import Link from "next/link";
import type { Route } from "next";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getWorkspaceContext } from "@/lib/workspace";
import { customerNowAction, customerNowLane, customerNowScore, rankCustomerNow } from "@/lib/customer-now";
import {
  activateCustomerNowSprint,
  acceptResearchCandidate,
  approveDraft,
  classifyReply,
  createOpportunityFromPursuit,
  enrollDefaultSequence,
  generateDraft,
  handleReply,
  linkEstimateToPursuit,
  markSent,
  promoteWorkLead,
  dismissWorkLead,
  scanWorkLeads,
  toggleWorkLeadSource,
  queueContactResearch,
  resolveInboundEvent,
  runDueSequences,
  updatePursuitNextAction,
} from "./actions";

type PursuitRow = {
  workspace_id:string; pursuit_id:string; primary_target_id:string;
  organization_display_name:string; organization_id:string|null;
  owner_user_id:string|null; next_action_owner_user_id:string|null;
  primary_property_id:string|null; opportunity_id:string|null;
  stage:string; pursuit_status:string; next_action:string|null; next_action_due_at:string|null;
  estimated_value:number|string|null; contact_display_name:string|null; contact_email:string|null;
  contact_phone:string|null; contact_job_title:string|null; property_count:number;
  high_signal_property_count:number; open_signal_count:number; why_now:string|null;
  service_fit:string[]|null; latest_draft_id:string|null; latest_draft_state:string|null;
  latest_draft_subject:string|null; latest_draft_body:string|null; latest_draft_channel:string|null;
  latest_draft_quality_score:number; latest_draft_quality_passed:boolean;
  latest_draft_quality_notes:Record<string,unknown>|null;
  latest_draft_evidence:Record<string,unknown>|null; latest_draft_strategy:string|null;
  contact_count:number; contact_coverage_score:number; has_decision_maker:boolean;
  has_operations:boolean; has_procurement:boolean; has_property_contact:boolean;
  fit_score:number; timing_score:number; evidence_score:number; contact_score:number;
  committee_score:number; relationship_score:number; total_score:number;
  improvement_recommendations:string[]|null; reply_count:number; needs_response_count:number;
  latest_reply_at:string|null; latest_reply_id:string|null; latest_reply_classification:string|null;
  latest_reply_confidence:number|string|null; latest_reply_summary:string|null;
  latest_reply_body:string|null; latest_reply_needs_response:boolean|null;
  recommended_action:string; command_score:number;
};

type ReplyRow = {
  reply_id:string; pursuit_id:string|null; outreach_target_id:string;
  organization_display_name:string|null; contact_display_name:string|null;
  contact_email:string|null; contact_job_title:string|null; channel:string; received_at:string;
  classification:string; classification_confidence:number|string|null; classification_reason:string|null;
  summary:string|null; body:string|null; needs_response:boolean; sequence_paused:boolean;
  pursuit_stage:string|null; next_action:string|null; next_action_due_at:string|null;
  opportunity_id:string|null; sender_email:string|null; subject:string|null;
};

type InboundEventRow = {
  id:string; provider:string; provider_message_id:string|null; provider_thread_id:string|null;
  sender_email:string|null; subject:string|null; body:string; received_at:string;
  status:string; matched_target_id:string|null; matched_pursuit_id:string|null;
  reply_id:string|null; match_reason:string|null; raw_metadata:Record<string,unknown>|null;
};

type InboundCandidateRow = {
  id:string; pursuit_id:string|null; organization_name:string|null;
  contact_name:string|null; email:string|null;
};

type TimelineRow = {
  pursuit_id:string; event_id:string; event_type:string; title:string;
  detail:string|null; occurred_at:string; actor_user_id:string|null;
  metadata:Record<string,unknown>|null;
};

type ResearchRow = {
  id:string; outreach_target_id:string; organization_name:string; missing_role:string;
  status:string; priority_score:number; research_priority_score:number;
  research_urgency_rank:number; research_priority_reason:string|null; research_query:string|null;
  candidate_name:string|null; candidate_title:string|null; candidate_email:string|null;
  candidate_phone:string|null; confidence:string|null; evidence_url:string|null;
  evidence_label:string|null; attempt_count:number; next_attempt_at:string|null;
};

type AnalyticsRow = {
  dimension:string; dimension_key:string; pursuits:number; sent:number; replies:number;
  positive_replies:number; opportunities:number; estimates:number;
  pipeline_value:number|string; won_value:number|string; reply_rate:number|string;
};

type EstimateRow = {
  id:string; estimate_number:string; organization_id:string;
  opportunity_id:string|null; status:string; total:number|string;
};

type WorkLeadRow = {
  id:string; source_key:string; source_label:string; buyer_name:string;
  opportunity_title:string; opportunity_type:string; response_mode:string;
  description:string|null; region:string|null; source_url:string;
  contact_name:string|null; contact_email:string|null; contact_phone:string|null;
  published_at:string|null; deadline_at:string|null; service_fit:string[]|null;
  fit_score:number|string; speed_score:number|string; conversion_score:number|string;
  status:string; outreach_target_id:string|null; pursuit_id:string|null;
  inbox_bucket:string; recommended_next_action:string; last_seen_at:string;
};

type WorkSourceHealthRow = {
  id:string; source_key:string; display_name:string; source_url:string; source_kind:string;
  enabled:boolean; last_run_at:string|null; last_success_at:string|null; last_error:string|null;
  consecutive_failures:number; last_result_count:number; health_state:string; health_reason:string;
};

type WorkScoutRunRow = {
  id:string; started_at:string; finished_at:string|null; status:string;
  discovered_count:number; upserted_count:number; promoted_count:number;
  draft_count:number; error_count:number;
};

function due(v:string|null|undefined) {
  if (!v) return "—";
  return new Intl.DateTimeFormat("en-CA",{month:"short",day:"numeric",year:"numeric"}).format(new Date(v));
}
function moment(v:string|null|undefined) {
  if (!v) return "—";
  return new Intl.DateTimeFormat("en-CA",{month:"short",day:"numeric",hour:"numeric",minute:"2-digit"}).format(new Date(v));
}
function localInput(v:string|null|undefined) {
  if (!v) return "";
  const d=new Date(v);
  const pad=(n:number)=>String(n).padStart(2,"0");
  return d.getFullYear()+"-"+pad(d.getMonth()+1)+"-"+pad(d.getDate())+"T"+pad(d.getHours())+":"+pad(d.getMinutes());
}
function money(v:number|string|null|undefined) {
  return Number(v??0).toLocaleString("en-CA",{style:"currency",currency:"CAD",maximumFractionDigits:0});
}
function pct(v:number|string|null|undefined) { return Number(v??0).toFixed(0)+"%"; }
function mailto(email:string|null,subject:string|null,body:string|null) {
  if (!email) return null;
  return "mailto:"+email+"?subject="+encodeURIComponent(subject??"")+"&body="+encodeURIComponent(body??"");
}
function human(v:string|null|undefined) { return v ? v.replaceAll("_"," ") : "—"; }
function confidence(v:number|string|null|undefined) {
  if (v===null || v===undefined) return "—";
  return Math.round(Number(v)*100)+"%";
}

const views=[
  ["command","Command Queue"],["work","Work Leads"],["replies","Replies"],["drafts","Drafts"],
  ["research","Research"],["accounts","Accounts"],["analytics","Analytics"],
] as const;

export default async function OutreachPage({
  searchParams,
}:{searchParams:Promise<Record<string,string|string[]|undefined>>}) {
  const ctx=await getWorkspaceContext();
  if(!ctx) redirect("/login");
  const s=await createClient();
  const params=await searchParams;
  const requested=typeof params.view==="string"?params.view:"command";
  const view=views.some(([key])=>key===requested)?requested:"command";
  const analyticsDimension=typeof params.dimension==="string"?params.dimension:"target";
  const ws=ctx.workspaceId;

  const [
    pursuitResult,replyResult,inboundResult,researchResult,timelineResult,analyticsResult,safetyResult,estimateResult,workLeadResult,workSourceResult,workRunResult,
  ]=await Promise.all([
    (s as any).from("v_outreach_pursuit_queue").select("*")
      .eq("workspace_id",ws).order("command_score",{ascending:false}).limit(250),
    (s as any).from("v_outreach_reply_inbox").select("*")
      .eq("workspace_id",ws).order("needs_response",{ascending:false}).order("received_at",{ascending:false}).limit(250),
    (s as any).from("outreach_inbound_events").select("*")
      .eq("workspace_id",ws).in("status",["unmatched","ambiguous","error"])
      .order("received_at",{ascending:false}).limit(100),
    (s as any).from("v_contact_enrichment_queue").select("*")
      .eq("workspace_id",ws).order("research_priority_score",{ascending:false}).order("research_urgency_rank",{ascending:false}).limit(150),
    (s as any).from("v_outreach_timeline").select("*")
      .eq("workspace_id",ws).order("occurred_at",{ascending:false}).limit(800),
    (s as any).from("v_outreach_conversion_analytics").select("*")
      .eq("workspace_id",ws).order("won_value",{ascending:false}).limit(500),
    (s as any).from("v_outreach_sequence_safety").select("*")
      .eq("workspace_id",ws).eq("due_now",true).limit(250),
    (s as any).from("estimates").select("id,estimate_number,organization_id,opportunity_id,status,total")
      .eq("workspace_id",ws).order("created_at",{ascending:false}).limit(250),
    (s as any).from("v_outreach_work_lead_inbox").select("*")
      .eq("workspace_id",ws).order("conversion_score",{ascending:false}).order("deadline_at",{ascending:true,nullsFirst:false}).limit(250),
    (s as any).from("v_outreach_work_source_health").select("*")
      .eq("workspace_id",ws).order("display_name",{ascending:true}),
    (s as any).from("outreach_work_scout_runs").select("id,started_at,finished_at,status,discovered_count,upserted_count,promoted_count,draft_count,error_count")
      .eq("workspace_id",ws).order("started_at",{ascending:false}).limit(1).maybeSingle(),
  ]);

  const pursuits=(pursuitResult.data??[]) as PursuitRow[];
  const replies=(replyResult.data??[]) as ReplyRow[];
  const inboundEvents=(inboundResult.data??[]) as InboundEventRow[];
  const research=(researchResult.data??[]) as ResearchRow[];
  const timeline=(timelineResult.data??[]) as TimelineRow[];
  const analytics=(analyticsResult.data??[]) as AnalyticsRow[];
  const safety=(safetyResult.data??[]) as any[];
  const estimates=(estimateResult.data??[]) as EstimateRow[];
  const workLeads=(workLeadResult.data??[]) as WorkLeadRow[];
  const workSources=(workSourceResult.data??[]) as WorkSourceHealthRow[];
  const latestWorkRun=(workRunResult.data??null) as WorkScoutRunRow|null;
  const timelineByPursuit=new Map<string,TimelineRow[]>();
  for(const event of timeline){
    if(!timelineByPursuit.has(event.pursuit_id)) timelineByPursuit.set(event.pursuit_id,[]);
    timelineByPursuit.get(event.pursuit_id)!.push(event);
  }

  const unhandledReplies=replies.filter(r=>r.needs_response);
  const unresolvedInbound=inboundEvents.filter(e=>["unmatched","ambiguous","error"].includes(e.status));
  const candidateIds=[...new Set(unresolvedInbound.flatMap(e=>{
    const ids=e.raw_metadata?.candidate_target_ids;
    return Array.isArray(ids)?ids.filter((id):id is string=>typeof id==="string"):[];
  }))];
  let inboundCandidates:InboundCandidateRow[]=[];
  if(candidateIds.length){
    const {data}=await (s as any).from("outreach_targets")
      .select("id,pursuit_id,organization_name,contact_name,email")
      .eq("workspace_id",ws).in("id",candidateIds);
    inboundCandidates=(data??[]) as InboundCandidateRow[];
  }
  const inboundCandidateMap=new Map(inboundCandidates.map(x=>[x.id,x]));
  const draftRows=pursuits.filter(p=>p.latest_draft_id);
  const activeAccounts=pursuits.filter(p=>!["won","lost","archived"].includes(p.pursuit_status));
  const safeDue=safety.filter(x=>x.safe_to_execute).length;
  const blockedDue=safety.length-safeDue;
  const pipeline=pursuits.reduce((sum,p)=>sum+Number(p.estimated_value??0),0);
  const won=analytics.filter(a=>a.dimension==="target").reduce((sum,a)=>sum+Number(a.won_value??0),0);
  const analyticsRows=analytics.filter(a=>a.dimension===analyticsDimension);
  const customerNow=rankCustomerNow(activeAccounts).slice(0,12);
  const customerNowReady=customerNow.filter(p=>customerNowLane(p)!=="research").length;
  const customerNowCallable=customerNow.filter(p=>Boolean(p.contact_phone)).length;
  const customerNowEmailReady=customerNow.filter(p=>Boolean(p.contact_email)).length;
  const customerNowReplies=customerNow.filter(p=>(p.needs_response_count??0)>0).length;
  const pursuitMap=new Map(pursuits.map(p=>[p.pursuit_id,p]));
  const workContactNow=workLeads.filter(l=>l.inbox_bucket==="contact_now").length;
  const workResearch=workLeads.filter(l=>l.inbox_bucket==="research_contact").length;
  const workDraftsReady=new Set(workLeads.filter(l=>{
    if(!l.pursuit_id) return false;
    const p=pursuitMap.get(l.pursuit_id);
    return p?.latest_draft_state==="draft" || p?.latest_draft_state==="approved";
  }).map(l=>l.pursuit_id)).size;
  const workClosingSoon=workLeads.filter(l=>{
    if(!l.deadline_at) return false;
    const ms=new Date(l.deadline_at).getTime()-Date.now();
    return ms>=0 && ms<=7*24*60*60*1000;
  }).length;
  const workHealthySources=workSources.filter(source=>source.health_state==="healthy").length;
  const workProblemSources=workSources.filter(source=>["degraded","failing","stale"].includes(source.health_state)).length;
  const errors=[
    pursuitResult.error,replyResult.error,inboundResult.error,researchResult.error,timelineResult.error,
    analyticsResult.error,safetyResult.error,estimateResult.error,workLeadResult.error,workSourceResult.error,workRunResult.error,
  ].filter(Boolean);

  return <main className="list-shell">
    <header className="list-header">
      <Link className="back" href={"/dashboard" as Route}>← Command</Link>
      <span className="eyebrow">GROWTH EXECUTION</span>
      <h1>Outreach</h1>
      <p className="muted" style={{marginTop:8,maxWidth:920}}>
        One pursuit per account, reply-first execution, evidence-backed messaging, controlled follow-up, and revenue attribution from first touch through won work.
      </p>
    </header>

    <nav className="panel" aria-label="Outreach sections" style={{marginBottom:16,padding:10,display:"flex",gap:8,flexWrap:"wrap"}}>
      {views.map(([key,label])=>
        <Link key={key} className={view===key?"primary":"button"} href={("/outreach?view="+key) as Route}>
          {label}
          {key==="replies"&&(unhandledReplies.length+unresolvedInbound.length)?" ("+(unhandledReplies.length+unresolvedInbound.length)+")":""}
          {key==="work"&&workLeads.filter(l=>["contact_now","research_contact","review"].includes(l.inbox_bucket)).length
            ?" ("+workLeads.filter(l=>["contact_now","research_contact","review"].includes(l.inbox_bucket)).length+")":""}
        </Link>
      )}
    </nav>

    {errors.length?<section className="panel" style={{marginBottom:16}}>
      <strong>Data migration required</strong>
      <p className="muted" style={{marginTop:6}}>{errors[0]?.message}</p>
    </section>:null}

    <section className="metrics" style={{marginBottom:18}}>
      <div className="metric"><span>Active pursuits</span><strong>{activeAccounts.length}</strong><small>canonical accounts</small></div>
      <div className="metric"><span>Replies to handle</span><strong>{unhandledReplies.length+unresolvedInbound.length}</strong><small>{unhandledReplies.length} matched · {unresolvedInbound.length} need matching</small></div>
      <div className="metric"><span>Safe steps due</span><strong>{safeDue}</strong><small>{blockedDue} blocked by guardrails</small></div>
      <div className="metric"><span>Pipeline</span><strong>{money(pipeline)}</strong><small>outreach-linked</small></div>
      <div className="metric"><span>Won</span><strong>{money(won)}</strong><small>attributed revenue</small></div>
    </section>

    {view==="work"?<section className="panel">
      <div className="panel-head">
        <div>
          <span className="eyebrow">LIVE WORK DISCOVERY</span>
          <h3>Work Leads</h3>
        </div>
        <div style={{display:"flex",gap:8,alignItems:"center",flexWrap:"wrap",justifyContent:"flex-end"}}>
          <span className="muted">{workLeads.length} discovered</span>
          <form action={scanWorkLeads}>
            <button className="primary" type="submit">Scan now</button>
          </form>
        </div>
      </div>
      <p className="muted" style={{marginTop:8,maxWidth:920}}>
        Private tenders, subcontractor calls, vendor networks and service opportunities ranked for CB Contracting by trade fit and speed to revenue. High-confidence leads are promoted automatically; official response contacts create review-ready drafts, but nothing sends automatically.
      </p>
      <section className="metrics" style={{marginTop:16,marginBottom:16}}>
        <div className="metric"><span>Contact now</span><strong>{workContactNow}</strong><small>direct response path</small></div>
        <div className="metric"><span>Drafts ready</span><strong>{workDraftsReady}</strong><small>review before send</small></div>
        <div className="metric"><span>Needs research</span><strong>{workResearch}</strong><small>contact gap</small></div>
        <div className="metric"><span>Closing ≤7d</span><strong>{workClosingSoon}</strong><small>deadline pressure</small></div>
        <div className="metric"><span>Source health</span><strong>{workHealthySources}/{workSources.filter(s=>s.enabled).length}</strong><small>{workProblemSources} need attention</small></div>
      </section>

      <details style={{marginBottom:16}}>
        <summary className="button" style={{cursor:"pointer",display:"inline-flex"}}>
          Source health{workProblemSources?" · "+workProblemSources+" issue"+(workProblemSources===1?"":"s"):""}
        </summary>
        <div style={{display:"grid",gap:8,marginTop:10}}>
          {latestWorkRun?<div className="muted" style={{fontSize:11}}>
            Latest scan {moment(latestWorkRun.started_at)} · {human(latestWorkRun.status)} · {latestWorkRun.discovered_count} discovered · {latestWorkRun.promoted_count} promoted · {latestWorkRun.draft_count} drafts · {latestWorkRun.error_count} errors
          </div>:<div className="muted" style={{fontSize:11}}>No persisted Work Lead scan has completed yet.</div>}
          {workSources.map(source=><div key={source.id} style={{display:"grid",gridTemplateColumns:"minmax(220px,1fr) auto",gap:12,alignItems:"center",padding:"10px 0",borderBottom:"1px solid var(--line)"}}>
            <div>
              <div style={{display:"flex",gap:7,alignItems:"center",flexWrap:"wrap"}}>
                <strong style={{fontSize:12}}>{source.display_name}</strong>
                <span className="pill">{human(source.health_state)}</span>
              </div>
              <div className="muted" style={{fontSize:11,marginTop:3}}>
                {source.health_reason} · last results {source.last_result_count} · last success {moment(source.last_success_at)}
              </div>
            </div>
            <div style={{display:"flex",gap:7,alignItems:"center"}}>
              <a className="button" href={source.source_url} target="_blank" rel="noreferrer">Source</a>
              <form action={toggleWorkLeadSource}>
                <input type="hidden" name="source_id" value={source.id}/>
                <input type="hidden" name="enabled" value={source.enabled?"false":"true"}/>
                <button className="button" type="submit">{source.enabled?"Disable":"Enable"}</button>
              </form>
            </div>
          </div>)}
        </div>
      </details>

      <div style={{display:"grid",gap:12,marginTop:16}}>
        {workLeads.length?workLeads.map(lead=>{
          const score=Math.round(Number(lead.conversion_score??0));
          const promoted=lead.status==="promoted";
          return <article key={lead.id} className="panel" style={{margin:0}}>
            <div className="panel-head">
              <div>
                <span className="eyebrow">{human(lead.inbox_bucket)} · {lead.source_label}</span>
                <h3>{lead.buyer_name}</h3>
                <p style={{marginTop:5}}><strong>{lead.opportunity_title}</strong></p>
              </div>
              <div style={{textAlign:"right"}}>
                <strong style={{fontSize:24}}>{score}</strong><span className="muted">/100</span>
                <div className="muted" style={{fontSize:12}}>conversion score</div>
              </div>
            </div>
            {lead.description?<p className="muted" style={{marginTop:10}}>
              {lead.description.length>420?lead.description.slice(0,420)+"…":lead.description}
            </p>:null}
            <div style={{display:"flex",gap:8,flexWrap:"wrap",marginTop:10}}>
              <span className="chip">{human(lead.opportunity_type)}</span>
              <span className="chip">{human(lead.response_mode)}</span>
              {lead.region?<span className="chip">{lead.region}</span>:null}
              {lead.deadline_at?<span className="chip">Due {due(lead.deadline_at)}</span>:null}
              {(lead.service_fit??[]).slice(0,5).map(service=><span className="chip" key={service}>{service}</span>)}
            </div>
            <p style={{marginTop:12}}><strong>Next:</strong> {lead.recommended_next_action}</p>
            {(lead.contact_name||lead.contact_email||lead.contact_phone)?<p className="muted" style={{marginTop:6}}>
              Contact: {[lead.contact_name,lead.contact_email,lead.contact_phone].filter(Boolean).join(" · ")}
            </p>:null}
            <div style={{display:"flex",gap:8,flexWrap:"wrap",marginTop:12}}>
              <a className="button" href={lead.source_url} target="_blank" rel="noreferrer">Open source</a>
              {promoted
                ?<>
                  <Link className="primary" href={"/outreach?view=command" as Route}>In command queue</Link>
                  {lead.pursuit_id&&["draft","approved"].includes(pursuitMap.get(lead.pursuit_id)?.latest_draft_state??"")
                    ?<Link className="button" href={"/outreach?view=drafts" as Route}>Draft ready</Link>
                    :null}
                </>
                :<form action={promoteWorkLead}>
                  <input type="hidden" name="lead_id" value={lead.id}/>
                  <button className="primary" type="submit">Promote to outreach</button>
                </form>}
              {!promoted?<form action={dismissWorkLead}>
                <input type="hidden" name="lead_id" value={lead.id}/>
                <button className="button" type="submit">Dismiss</button>
              </form>:null}
            </div>
          </article>;
        }):<p className="muted" style={{marginTop:14}}>No work leads have been discovered yet.</p>}
      </div>
    </section>:null}

    {view==="command"?<>
      <section className="panel" style={{marginBottom:18}}>
        <div className="panel-head">
          <div>
            <span className="eyebrow">GET CUSTOMER NOW</span>
            <h3>Immediate-customer sprint</h3>
          </div>
          <form action={activateCustomerNowSprint}>
            <input type="hidden" name="limit" value="10"/>
            <button className="primary" type="submit">Prepare top 10 now</button>
          </form>
        </div>
        <p className="muted" style={{marginTop:8,maxWidth:900}}>
          Ranks direct-contact, service-fit accounts ahead of slow tender/procurement work. Preparing the sprint assigns the top pursuits to you, makes them due now, generates missing one-site email or call drafts, and queues contact research where required. It does not send anything automatically.
        </p>
      </section>

      <section className="metrics" style={{marginBottom:18}}>
        <div className="metric"><span>Ready now</span><strong>{customerNowReady}</strong><small>of top {customerNow.length}</small></div>
        <div className="metric"><span>Callable</span><strong>{customerNowCallable}</strong><small>direct phone available</small></div>
        <div className="metric"><span>Email-ready</span><strong>{customerNowEmailReady}</strong><small>direct email available</small></div>
        <div className="metric"><span>Replies</span><strong>{customerNowReplies}</strong><small>always first priority</small></div>
      </section>

      <section style={{display:"grid",gap:12}}>
        {customerNow.map((p,index)=>{
          const lane=customerNowLane(p);
          const nowScore=customerNowScore(p);
          const emailLink=mailto(p.contact_email,p.latest_draft_subject,p.latest_draft_body);
          const positiveReply=["interested","request_quote","request_call","site_visit_request","referral","send_information"].includes(p.latest_reply_classification??"");
          return <article key={p.pursuit_id} className="outreach-queue-card">
            <div style={{display:"grid",gridTemplateColumns:"repeat(auto-fit,minmax(220px,1fr))",gap:18,alignItems:"start"}}>
              <div>
                <span className="eyebrow">#{index+1}</span>
                <strong style={{display:"block",fontSize:30}}>{nowScore}</strong>
                <span className="muted" style={{fontSize:10}}>close-now score</span>
              </div>
              <div>
                <Link href={("/targets/"+p.primary_target_id) as Route}><strong>{p.organization_display_name}</strong></Link>
                <div className="muted" style={{fontSize:12,marginTop:4}}>{p.contact_display_name??"Direct contact needed"}</div>
                <div className="muted" style={{fontSize:11}}>{p.contact_job_title??""}</div>
                <div style={{display:"flex",gap:6,flexWrap:"wrap",marginTop:7}}>
                  <span className="pill">{human(lane)}</span>
                  <span className="pill">{human(p.stage)}</span>
                  {p.service_fit?.slice(0,2).map(service=><span className="pill" key={service}>{service}</span>)}
                </div>
              </div>
              <div>
                <span className="eyebrow">WHY THIS ACCOUNT</span>
                <div style={{fontSize:12,lineHeight:1.45,marginTop:5}}>{p.why_now??"Direct contact and service fit"}</div>
                <div className="muted" style={{fontSize:11,marginTop:6}}>
                  {p.contact_phone?"phone ready · ":""}{p.contact_email?"email ready · ":""}committee {p.contact_coverage_score}%
                </div>
              </div>
              <div>
                <span className="eyebrow">DO THIS NOW</span>
                <strong style={{display:"block",fontSize:12,lineHeight:1.45,marginTop:5}}>{customerNowAction(p)}</strong>
                <div style={{display:"flex",gap:8,flexWrap:"wrap",marginTop:10}}>
                  {p.contact_phone?<a className="primary" href={"tel:"+p.contact_phone}>Call now</a>:null}

                  {lane==="reply_now"&&p.latest_reply_id?
                    <form action={handleReply}>
                      <input type="hidden" name="reply_id" value={p.latest_reply_id}/>
                      <button className="button">Mark handled</button>
                    </form>:null}

                  {lane==="reply_now"&&positiveReply&&!p.opportunity_id?
                    <form action={createOpportunityFromPursuit}>
                      <input type="hidden" name="pursuit_id" value={p.pursuit_id}/>
                      <input type="hidden" name="reply_id" value={p.latest_reply_id??""}/>
                      <button className="primary">Create opportunity</button>
                    </form>:null}

                  {lane==="send_now"&&p.latest_draft_channel==="email"&&emailLink?
                    <a className="primary" href={emailLink}>Open email</a>:null}

                  {lane==="send_now"&&p.latest_draft_id?
                    <form action={markSent}>
                      <input type="hidden" name="target_id" value={p.primary_target_id}/>
                      <input type="hidden" name="draft_id" value={p.latest_draft_id}/>
                      <input type="hidden" name="provider" value="manual"/>
                      <button className="button">Mark sent</button>
                    </form>:null}

                  {lane==="approve_now"&&p.latest_draft_id?
                    <form action={approveDraft}>
                      <input type="hidden" name="target_id" value={p.primary_target_id}/>
                      <input type="hidden" name="draft_id" value={p.latest_draft_id}/>
                      <button className="primary">Approve draft</button>
                    </form>:null}

                  {lane==="draft_now"?
                    <form action={generateDraft}>
                      <input type="hidden" name="target_id" value={p.primary_target_id}/>
                      <input type="hidden" name="channel" value="email"/>
                      <input type="hidden" name="objective" value="quote"/>
                      <button className="primary">Build one-site email</button>
                    </form>:null}

                  {lane==="call_now"?
                    <form action={generateDraft}>
                      <input type="hidden" name="target_id" value={p.primary_target_id}/>
                      <input type="hidden" name="channel" value="call"/>
                      <input type="hidden" name="objective" value="site_walk"/>
                      <button className="button">Prepare call opener</button>
                    </form>:null}

                  {lane==="research"?
                    <Link className="primary" href={"/outreach?view=research" as Route}>Find direct contact</Link>:null}

                  <Link className="button" href={("/targets/"+p.primary_target_id) as Route}>Open account</Link>
                </div>
              </div>
            </div>
            <div className="muted" style={{fontSize:11,marginTop:12,paddingTop:10,borderTop:"1px solid var(--line)"}}>
              Existing next action: {p.next_action??"none"} · Due {due(p.next_action_due_at)}
            </div>
          </article>;
        })}
        {!customerNow.length?<section className="panel"><p className="muted">No active pursuits are available for the immediate-customer sprint.</p></section>:null}
      </section>
    </>:null}

    {view==="command"?<>
      <section className="panel" style={{marginBottom:18}}>
        <div className="panel-head">
          <div><span className="eyebrow">TODAY</span><h3>Command Queue</h3></div>
          <div style={{display:"flex",gap:8,alignItems:"center",flexWrap:"wrap"}}>
            <span className="muted">{pursuits.length} canonical pursuits</span>
            <form action={runDueSequences}><button className="primary" type="submit">Run {safeDue} safe sequence steps</button></form>
          </div>
        </div>
        {blockedDue>0?<p className="muted" style={{marginTop:8}}>
          {blockedDue} due sequence step{blockedDue===1?" is":"s are"} paused by reply, suppression, duplicate-pursuit, recent-touch, closed-target, or reachability guards.
        </p>:null}
      </section>

      <section style={{display:"grid",gap:12}}>
        {pursuits.slice(0,40).map(p=>{
          const emailLink=mailto(p.contact_email,p.latest_draft_subject,p.latest_draft_body);
          const events=(timelineByPursuit.get(p.pursuit_id)??[]).slice(0,6);
          return <article key={p.pursuit_id} className="outreach-queue-card">
            <div style={{display:"grid",gridTemplateColumns:"repeat(auto-fit,minmax(190px,1fr))",gap:18,alignItems:"start"}}>
              <div>
                <span className="eyebrow">SCORE</span>
                <strong style={{display:"block",fontSize:28}}>{p.total_score}</strong>
                <span className="muted" style={{fontSize:11}}>command {p.command_score}</span>
              </div>
              <div>
                <Link href={("/targets/"+p.primary_target_id) as Route}><strong>{p.organization_display_name}</strong></Link>
                <div className="muted" style={{fontSize:12,marginTop:4}}>{p.contact_display_name??"No verified primary contact"}</div>
                <div className="muted" style={{fontSize:11}}>{p.contact_job_title??""}</div>
                <div style={{display:"flex",gap:6,flexWrap:"wrap",marginTop:7}}>
                  <span className="pill">{human(p.stage)}</span>
                  {p.needs_response_count>0?<span className="pill">{p.needs_response_count} reply{p.needs_response_count===1?"":"ies"} waiting</span>:null}
                  <span className="pill">committee {p.contact_coverage_score}%</span>
                </div>
              </div>
              <div>
                <span className="eyebrow">WHY NOW</span>
                <div style={{fontSize:12,lineHeight:1.45,marginTop:5}}>{p.why_now??"Account fit and readiness"}</div>
                <div className="muted" style={{fontSize:11,marginTop:6}}>
                  {p.property_count} properties · {p.high_signal_property_count} strong-fit · {p.open_signal_count} signals
                  {p.service_fit?.length?" · "+p.service_fit.join(" / "):""}
                </div>
                <details style={{marginTop:8}}>
                  <summary style={{cursor:"pointer",fontSize:11}}>Score breakdown</summary>
                  <div className="muted" style={{fontSize:11,lineHeight:1.65,marginTop:6}}>
                    Fit {p.fit_score}/25 · Timing {p.timing_score}/25 · Evidence {p.evidence_score}/20 · Contact {p.contact_score}/15 · Committee {p.committee_score}/10 · Relationship {p.relationship_score}/5
                  </div>
                  {p.improvement_recommendations?.length?<div className="muted" style={{fontSize:11,marginTop:5}}>
                    Next score gain: {p.improvement_recommendations[0]}
                  </div>:null}
                </details>
              </div>
              <div>
                <span className="eyebrow">NEXT</span>
                <strong style={{display:"block",fontSize:12,marginTop:5,textTransform:"capitalize"}}>{human(p.recommended_action)}</strong>
                <div className="muted" style={{fontSize:11,marginTop:4}}>{p.next_action??"Set next action"}</div>
                <div className="muted" style={{fontSize:11,marginTop:3}}>
                  Owner: {p.next_action_owner_user_id===ctx.user.id?"You":p.next_action_owner_user_id?"Assigned teammate":"Unassigned"} · Due {due(p.next_action_due_at)}
                </div>
              </div>
            </div>

            {p.latest_reply_needs_response?<section style={{marginTop:12,padding:12,border:"1px solid var(--line)",borderRadius:10}}>
              <span className="eyebrow">REPLY NEEDS RESPONSE · {human(p.latest_reply_classification)}</span>
              <p style={{fontSize:12,lineHeight:1.5,margin:"6px 0 0"}}>{p.latest_reply_summary??p.latest_reply_body}</p>
              <div className="muted" style={{fontSize:11,marginTop:5}}>Classifier confidence {confidence(p.latest_reply_confidence)}</div>
              <div style={{display:"flex",gap:8,flexWrap:"wrap",marginTop:10}}>
                <form action={handleReply}><input type="hidden" name="reply_id" value={p.latest_reply_id??""}/><button className="primary">Mark handled</button></form>
                <form action={handleReply}><input type="hidden" name="reply_id" value={p.latest_reply_id??""}/><input type="hidden" name="resume_sequence" value="true"/><button className="button">Handle + resume sequence</button></form>
                {!p.opportunity_id&&["interested","request_quote","request_call","site_visit_request"].includes(p.latest_reply_classification??"")?
                  <form action={createOpportunityFromPursuit}>
                    <input type="hidden" name="pursuit_id" value={p.pursuit_id}/>
                    <input type="hidden" name="reply_id" value={p.latest_reply_id??""}/>
                    <button className="button">Create opportunity</button>
                  </form>:null}
              </div>
            </section>:null}

            {p.latest_draft_id?<details className="outreach-draft-review" style={{marginTop:12}}>
              <summary>
                {human(p.latest_draft_state)} draft · quality {p.latest_draft_quality_score}/100
                {p.latest_draft_strategy?" · "+human(p.latest_draft_strategy):""}
              </summary>
              <div style={{marginTop:10,padding:12,border:"1px solid var(--line)",borderRadius:10}}>
                {p.latest_draft_subject?<strong style={{display:"block",marginBottom:8}}>{p.latest_draft_subject}</strong>:null}
                <div style={{whiteSpace:"pre-wrap",fontSize:12,lineHeight:1.5}}>{p.latest_draft_body}</div>
                <div className="muted" style={{fontSize:11,marginTop:10}}>
                  Evidence: {String(p.latest_draft_evidence?.property_name??"no property")} · {String(p.latest_draft_evidence?.signal??"no live signal")} · contact {String(p.latest_draft_evidence?.contact_confidence??"unverified")}
                </div>
              </div>
            </details>:null}

            <div className="outreach-queue-actions" style={{marginTop:12}}>
              {p.recommended_action==="handle_reply"?null:
                (!p.latest_draft_id||p.latest_draft_state==="draft"||p.recommended_action==="generate_draft")?
                <form action={generateDraft} className="outreach-rewrite-form">
                  <input type="hidden" name="target_id" value={p.primary_target_id}/>
                  <select name="objective" defaultValue="referral">
                    <option value="referral">Referral / right person</option>
                    <option value="introduction">Introduction</option>
                    <option value="meeting">Meeting</option>
                    <option value="site_walk">Site walkthrough</option>
                    <option value="vendor_registration">Vendor registration</option>
                    <option value="quote">Quote opportunity</option>
                  </select>
                  <select name="channel" defaultValue={p.latest_draft_channel??"email"} aria-label="Draft channel">
                    <option value="email">Email</option><option value="linkedin">LinkedIn</option>
                    <option value="call">Call opener</option><option value="voicemail">Voicemail</option><option value="sms">SMS</option>
                  </select>
                  <button className={p.latest_draft_id?"button":"primary"}>{p.latest_draft_id?"Rewrite draft":"Generate draft"}</button>
                </form>:null}
              {p.latest_draft_id&&p.latest_draft_state==="draft"?
                <form action={approveDraft}>
                  <input type="hidden" name="target_id" value={p.primary_target_id}/>
                  <input type="hidden" name="draft_id" value={p.latest_draft_id}/>
                  <button className="primary" disabled={!p.latest_draft_quality_passed}>Approve {p.latest_draft_quality_score}/100</button>
                </form>:null}
              {p.latest_draft_id&&p.latest_draft_state==="approved"&&p.latest_draft_channel==="email"&&emailLink?
                <a className="primary" href={emailLink}>Open email</a>:null}
              {p.latest_draft_id&&p.latest_draft_state==="approved"?
                <form action={markSent}>
                  <input type="hidden" name="target_id" value={p.primary_target_id}/>
                  <input type="hidden" name="draft_id" value={p.latest_draft_id}/>
                  <input type="hidden" name="provider" value="manual"/>
                  <button className="button">Mark sent</button>
                </form>:null}
              <form action={enrollDefaultSequence}>
                <input type="hidden" name="target_id" value={p.primary_target_id}/>
                <button className="button">Enroll 7-touch</button>
              </form>
              <details>
                <summary className="button" style={{cursor:"pointer"}}>Log reply</summary>
                <form action={classifyReply} style={{display:"grid",gap:8,minWidth:340,marginTop:8}}>
                  <input type="hidden" name="target_id" value={p.primary_target_id}/>
                  <textarea name="reply_body" required rows={5} placeholder="Paste the reply. CBData will classify it and pause the sequence."/>
                  <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:8}}>
                    <select name="channel" defaultValue="email"><option value="email">Email</option><option value="linkedin">LinkedIn</option><option value="sms">SMS</option><option value="call">Call</option><option value="other">Other</option></select>
                    <select name="classification_override" defaultValue="">
                      <option value="">Auto classify</option><option value="interested">Interested</option>
                      <option value="request_quote">Quote request</option><option value="request_call">Call request</option>
                      <option value="site_visit_request">Site visit</option><option value="referral">Referral</option>
                      <option value="wrong_person">Wrong person</option><option value="under_contract">Under contract</option>
                      <option value="future_renewal">Future renewal</option><option value="not_interested">Not interested</option>
                      <option value="unsubscribe">Unsubscribe</option><option value="bounce">Bounce</option><option value="other">Other</option>
                    </select>
                  </div>
                  <input name="referred_contact" placeholder="Referred contact, if provided"/>
                  <input name="renewal_date" type="date"/>
                  <button className="primary">Classify + pause sequence</button>
                </form>
              </details>
              <details>
                <summary className="button" style={{cursor:"pointer"}}>Set next action</summary>
                <form action={updatePursuitNextAction} style={{display:"grid",gap:8,minWidth:330,marginTop:8}}>
                  <input type="hidden" name="pursuit_id" value={p.pursuit_id}/>
                  <input name="next_action" defaultValue={p.next_action??""} maxLength={240} required placeholder="Next action"/>
                  <input name="next_action_due_at" type="datetime-local" defaultValue={localInput(p.next_action_due_at)}/>
                  <label style={{display:"flex",gap:7,alignItems:"center",fontSize:12}}>
                    <input type="checkbox" name="assign_to_me" value="true" defaultChecked/> Assign to me
                  </label>
                  <button className="button">Save next action</button>
                </form>
              </details>
            </div>

            {events.length?<details style={{marginTop:12}}>
              <summary style={{cursor:"pointer",fontSize:12}}>Timeline · latest {events.length}</summary>
              <div style={{display:"grid",gap:8,marginTop:8}}>
                {events.map(e=><div key={e.event_type+"-"+e.event_id} style={{borderLeft:"2px solid var(--line)",paddingLeft:10}}>
                  <strong style={{fontSize:11}}>{e.title}</strong>
                  <span className="muted" style={{fontSize:10,marginLeft:8}}>{moment(e.occurred_at)}</span>
                  {e.detail?<div className="muted" style={{fontSize:11,marginTop:2}}>{e.detail.slice(0,360)}</div>:null}
                </div>)}
              </div>
            </details>:null}
          </article>;
        })}
        {!pursuits.length?<section className="panel"><p className="muted">No outreach pursuits yet.</p></section>:null}
      </section>
    </>:null}

    {view==="replies"?<section className="table-panel">
      <div className="panel-head">
        <div><span className="eyebrow">REPLY INBOX</span><h3>Replies requiring decisions</h3></div>
        <span className="muted">{unhandledReplies.length} matched · {unresolvedInbound.length} need matching</span>
      </div>

      {unresolvedInbound.length?<section style={{marginTop:12,padding:14,border:"1px solid var(--line)",borderRadius:12}}>
        <div className="panel-head">
          <div><span className="eyebrow">AUTOMATIC INBOUND</span><h3>Needs matching</h3></div>
          <span className="muted">{unresolvedInbound.length} unresolved</span>
        </div>
        <div style={{display:"grid",gap:10,marginTop:12}}>
          {unresolvedInbound.map(e=>{
            const candidateTargetIds=Array.isArray(e.raw_metadata?.candidate_target_ids)
              ? e.raw_metadata!.candidate_target_ids.filter((id):id is string=>typeof id==="string")
              : [];
            const candidates=candidateTargetIds.map(id=>inboundCandidateMap.get(id)).filter((x):x is InboundCandidateRow=>Boolean(x));
            return <article key={e.id} style={{border:"1px solid var(--line)",borderRadius:10,padding:12}}>
              <div style={{display:"grid",gridTemplateColumns:"repeat(auto-fit,minmax(220px,1fr))",gap:14}}>
                <div>
                  <span className="pill">{human(e.status)}</span>
                  <strong style={{display:"block",marginTop:7}}>{e.sender_email??"Unknown sender"}</strong>
                  <div className="muted" style={{fontSize:11}}>{moment(e.received_at)} · {e.provider}</div>
                  {e.subject?<div style={{fontSize:12,marginTop:7}}>{e.subject}</div>:null}
                </div>
                <div>
                  <p style={{fontSize:12,lineHeight:1.5,whiteSpace:"pre-wrap",margin:0}}>{e.body.slice(0,1200)}</p>
                  <div className="muted" style={{fontSize:11,marginTop:7}}>Match: {human(e.match_reason)}</div>
                </div>
                <div>
                  <span className="eyebrow">ATTACH TO PURSUIT</span>
                  <div style={{display:"flex",gap:7,flexWrap:"wrap",marginTop:8}}>
                    {candidates.map(candidate=><form key={candidate.id} action={resolveInboundEvent}>
                      <input type="hidden" name="event_id" value={e.id}/>
                      <input type="hidden" name="target_id" value={candidate.id}/>
                      <button className="button">
                        {candidate.organization_name??candidate.contact_name??candidate.email??"Candidate"}
                      </button>
                    </form>)}
                    {!candidates.length?<>
                      <span className="muted" style={{fontSize:11}}>No exact CBData target candidate. Verify the sender/contact record before attaching.</span>
                      <Link className="button" href={"/outreach?view=research" as Route}>Open Research</Link>
                    </>:null}
                  </div>
                </div>
              </div>
            </article>;
          })}
        </div>
      </section>:null}

      <div style={{display:"grid",gap:10,marginTop:12}}>
        {replies.map(r=><article key={r.reply_id} style={{border:"1px solid var(--line)",borderRadius:12,padding:14}}>
          <div style={{display:"grid",gridTemplateColumns:"repeat(auto-fit,minmax(220px,1fr))",gap:16}}>
            <div>
              <strong>{r.organization_display_name??"Account"}</strong>
              <div className="muted" style={{fontSize:12,marginTop:3}}>{r.contact_display_name??r.sender_email??r.contact_email??"Unknown contact"}</div>
              <div className="muted" style={{fontSize:11}}>{r.sender_email??r.contact_email??"No sender email"} · {moment(r.received_at)} · {human(r.channel)}</div>
              {r.subject?<div style={{fontSize:12,marginTop:7}}><strong>{r.subject}</strong></div>:null}
            </div>
            <div>
              <div style={{display:"flex",gap:7,alignItems:"center",flexWrap:"wrap"}}>
                <span className="pill">{human(r.classification)}</span>
                <span className="muted" style={{fontSize:11}}>confidence {confidence(r.classification_confidence)}</span>
                {r.sequence_paused?<span className="pill">sequence paused</span>:null}
              </div>
              <p style={{fontSize:12,lineHeight:1.5,whiteSpace:"pre-wrap",margin:"8px 0 0"}}>{r.body??r.summary??"No reply body captured"}</p>
              {r.classification_reason?<div className="muted" style={{fontSize:11,marginTop:6}}>Why: {r.classification_reason}</div>:null}
            </div>
            <div>
              <span className="eyebrow">NEXT</span>
              <div style={{fontSize:12,marginTop:4}}>{r.next_action??"Review reply"}</div>
              <div className="muted" style={{fontSize:11,marginTop:3}}>Due {due(r.next_action_due_at)}</div>
              <div style={{display:"flex",gap:8,flexWrap:"wrap",marginTop:10}}>
                {r.needs_response?<form action={handleReply}><input type="hidden" name="reply_id" value={r.reply_id}/><button className="primary">Handled</button></form>:<span className="muted" style={{fontSize:11}}>Handled</span>}
                {r.needs_response&&r.sequence_paused&&!["unsubscribe","bounce","not_interested"].includes(r.classification)?
                  <form action={handleReply}><input type="hidden" name="reply_id" value={r.reply_id}/><input type="hidden" name="resume_sequence" value="true"/><button className="button">Handle + resume</button></form>:null}
                {!r.opportunity_id&&r.pursuit_id&&["interested","request_quote","request_call","site_visit_request"].includes(r.classification)?
                  <form action={createOpportunityFromPursuit}><input type="hidden" name="pursuit_id" value={r.pursuit_id}/><input type="hidden" name="reply_id" value={r.reply_id}/><button className="button">Create opportunity</button></form>:null}
              </div>
            </div>
          </div>
        </article>)}
        {!replies.length?<p className="muted">No replies captured yet.</p>:null}
      </div>
    </section>:null}

    {view==="drafts"?<section className="table-panel">
      <div className="panel-head"><div><span className="eyebrow">MESSAGE QUALITY</span><h3>Draft review</h3></div><span className="muted">{draftRows.length} pursuits with drafts</span></div>
      <div style={{display:"grid",gap:10,marginTop:12}}>
        {draftRows.map(p=><article key={p.pursuit_id} style={{border:"1px solid var(--line)",borderRadius:12,padding:14}}>
          <div style={{display:"flex",justifyContent:"space-between",gap:16,alignItems:"start",flexWrap:"wrap"}}>
            <div><strong>{p.organization_display_name}</strong><div className="muted" style={{fontSize:11}}>{p.contact_display_name??"No named contact"} · {human(p.latest_draft_strategy)}</div></div>
            <div style={{textAlign:"right"}}><strong>{p.latest_draft_quality_score}/100</strong><div className="muted" style={{fontSize:11}}>{p.latest_draft_quality_passed?"passes quality gate":"blocked from approval"}</div></div>
          </div>
          <div style={{marginTop:10,padding:12,border:"1px solid var(--line)",borderRadius:10}}>
            {p.latest_draft_subject?<strong style={{display:"block",marginBottom:7}}>{p.latest_draft_subject}</strong>:null}
            <div style={{fontSize:12,whiteSpace:"pre-wrap",lineHeight:1.5}}>{p.latest_draft_body}</div>
          </div>
          <div className="muted" style={{fontSize:11,marginTop:8}}>
            Evidence: {String(p.latest_draft_evidence?.property_name??"no property")} · signal {String(p.latest_draft_evidence?.signal??"none")} · contact {String(p.latest_draft_evidence?.contact_confidence??"unverified")}
          </div>
          <div style={{display:"flex",gap:8,marginTop:10,flexWrap:"wrap"}}>
            {p.latest_draft_state==="draft"?<form action={approveDraft}><input type="hidden" name="target_id" value={p.primary_target_id}/><input type="hidden" name="draft_id" value={p.latest_draft_id??""}/><button className="primary" disabled={!p.latest_draft_quality_passed}>Approve</button></form>:null}
            <form action={generateDraft}><input type="hidden" name="target_id" value={p.primary_target_id}/><input type="hidden" name="channel" value={p.latest_draft_channel??"email"}/><input type="hidden" name="objective" value="referral"/><button className="button">Rewrite from evidence</button></form>
          </div>
        </article>)}
        {!draftRows.length?<p className="muted">No drafts yet.</p>:null}
      </div>
    </section>:null}

    {view==="research"?<section className="table-panel">
      <div className="panel-head"><div><span className="eyebrow">BUYING COMMITTEE</span><h3>Executable contact research</h3></div><span className="muted">{research.length} prioritized tasks</span></div>
      <div style={{display:"grid",gap:8,marginTop:12}}>
        {research.map(g=><div key={g.id} style={{display:"grid",gridTemplateColumns:"repeat(auto-fit,minmax(150px,1fr))",gap:12,alignItems:"center",padding:"10px 0",borderBottom:"1px solid var(--line)"}}>
          <div><strong>{g.organization_name}</strong><div className="muted" style={{fontSize:10}}>{g.research_priority_reason??"Buying-committee gap"}</div></div>
          <span className="pill">{human(g.missing_role)}</span>
          <strong>{g.research_priority_score??g.priority_score}</strong>
          <div className="muted" style={{fontSize:11}}>{g.research_query}</div>
          <div style={{fontSize:11}}>
            {g.candidate_name?<><strong>{g.candidate_name}</strong><div className="muted">{g.candidate_title??""}</div><div className="muted">{g.candidate_email??g.candidate_phone??""}</div></>:<span className="muted">{human(g.status)} · attempt {g.attempt_count??0}</span>}
          </div>
          {g.status==="found"&&g.confidence==="high"?
            <form action={acceptResearchCandidate}><input type="hidden" name="task_id" value={g.id}/><button className="primary">Verify + attach</button></form>:
            <form action={queueContactResearch}><input type="hidden" name="task_id" value={g.id}/><button className="button">{g.status==="not_found"?"Retry research":"Queue research"}</button></form>}
        </div>)}
        {!research.length?<p className="muted">No buying-committee research gaps are currently queued.</p>:null}
      </div>
    </section>:null}

    {view==="accounts"?<section style={{display:"grid",gap:12}}>
      {pursuits.map(p=>{
        const events=(timelineByPursuit.get(p.pursuit_id)??[]).slice(0,12);
        const availableEstimates=estimates.filter(e=>e.organization_id===p.organization_id&&!e.opportunity_id);
        return <article key={p.pursuit_id} className="outreach-queue-card">
          <div style={{display:"grid",gridTemplateColumns:"repeat(auto-fit,minmax(220px,1fr))",gap:18}}>
            <div>
              <span className="eyebrow">ACCOUNT PURSUIT</span>
              <h3 style={{marginTop:5}}>{p.organization_display_name}</h3>
              <div style={{display:"flex",gap:6,flexWrap:"wrap",marginTop:7}}>
                <span className="pill">{human(p.stage)}</span><span className="pill">{p.total_score}/100</span>
                <span className="pill">committee {p.contact_coverage_score}%</span>
              </div>
              <div className="muted" style={{fontSize:11,marginTop:8}}>{p.property_count} linked properties · {p.open_signal_count} open signals · {p.reply_count} replies</div>
            </div>
            <div>
              <span className="eyebrow">BUYING COMMITTEE</span>
              <div className="muted" style={{fontSize:11,lineHeight:1.7,marginTop:5}}>
                Decision maker {p.has_decision_maker?"✓":"missing"} · Operations {p.has_operations?"✓":"missing"} · Procurement {p.has_procurement?"✓":"missing"} · Property/site {p.has_property_contact?"✓":"missing"}
              </div>
              <div style={{marginTop:8}}><strong>{p.contact_display_name??"No primary contact"}</strong><div className="muted" style={{fontSize:11}}>{p.contact_job_title??""}</div></div>
            </div>
            <div>
              <span className="eyebrow">REVENUE PATH</span>
              <div style={{fontSize:12,marginTop:5}}>Opportunity: {p.opportunity_id?"linked":"not created"} · Pipeline {money(p.estimated_value)}</div>
              {!p.opportunity_id&&p.organization_id?<form action={createOpportunityFromPursuit} style={{display:"flex",gap:8,marginTop:8}}>
                <input type="hidden" name="pursuit_id" value={p.pursuit_id}/>
                <input name="estimated_value" type="number" min="0" step="1" placeholder="Estimated value" style={{maxWidth:140}}/>
                <button className="button">Create opportunity</button>
              </form>:null}
              {p.organization_id&&availableEstimates.length?<form action={linkEstimateToPursuit} style={{display:"flex",gap:8,marginTop:8,flexWrap:"wrap"}}>
                <input type="hidden" name="pursuit_id" value={p.pursuit_id}/>
                <select name="estimate_id" required defaultValue="">
                  <option value="" disabled>Link existing estimate</option>
                  {availableEstimates.map(e=><option key={e.id} value={e.id}>{e.estimate_number} · {human(e.status)} · {money(e.total)}</option>)}
                </select>
                <button className="button">Link estimate</button>
              </form>:null}
              {p.opportunity_id?<Link className="button" style={{display:"inline-block",marginTop:8}} href={"/sales" as Route}>Open sales pipeline</Link>:null}
            </div>
          </div>
          <div style={{marginTop:12,paddingTop:12,borderTop:"1px solid var(--line)"}}>
            <strong style={{fontSize:12}}>Next action</strong>
            <div className="muted" style={{fontSize:11,marginTop:3}}>{p.next_action??"Not set"} · {due(p.next_action_due_at)} · {p.next_action_owner_user_id===ctx.user.id?"You":p.next_action_owner_user_id?"Assigned teammate":"Unassigned"}</div>
          </div>
          <details style={{marginTop:10}}>
            <summary style={{cursor:"pointer",fontSize:12}}>Full timeline</summary>
            <div style={{display:"grid",gap:8,marginTop:8}}>
              {events.map(e=><div key={e.event_type+"-"+e.event_id} style={{borderLeft:"2px solid var(--line)",paddingLeft:10}}>
                <strong style={{fontSize:11}}>{e.title}</strong><span className="muted" style={{fontSize:10,marginLeft:8}}>{moment(e.occurred_at)}</span>
                {e.detail?<div className="muted" style={{fontSize:11,marginTop:2}}>{e.detail.slice(0,500)}</div>:null}
              </div>)}
              {!events.length?<span className="muted" style={{fontSize:11}}>No timeline events yet.</span>:null}
            </div>
          </details>
        </article>;
      })}
      {!pursuits.length?<section className="panel"><p className="muted">No canonical account pursuits yet.</p></section>:null}
    </section>:null}

    {view==="analytics"?<>
      <section className="panel" style={{marginBottom:14,padding:10,display:"flex",gap:8,flexWrap:"wrap"}}>
        {["target","property","service","contact_role","message"].map(d=>
          <Link key={d} className={analyticsDimension===d?"primary":"button"} href={("/outreach?view=analytics&dimension="+d) as Route}>{human(d)}</Link>
        )}
      </section>
      <section className="table-panel">
        <div className="panel-head"><div><span className="eyebrow">CONVERSION</span><h3>{human(analyticsDimension)} performance</h3></div><span className="muted">first touch → reply → opportunity → estimate → won</span></div>
        <div className="table-wrap" style={{marginTop:12}}>
          <table>
            <thead><tr><th>{human(analyticsDimension)}</th><th>Pursuits</th><th>Sent</th><th>Replies</th><th>Reply rate</th><th>Positive</th><th>Opportunities</th><th>Estimates</th><th>Pipeline</th><th>Won</th></tr></thead>
            <tbody>
              {analyticsRows.map((a,i)=><tr key={a.dimension_key+"-"+i}>
                <td><strong>{a.dimension_key}</strong></td><td>{a.pursuits}</td><td>{a.sent}</td><td>{a.replies}</td><td>{pct(a.reply_rate)}</td><td>{a.positive_replies}</td><td>{a.opportunities}</td><td>{a.estimates}</td><td>{money(a.pipeline_value)}</td><td>{money(a.won_value)}</td>
              </tr>)}
              {!analyticsRows.length?<tr><td colSpan={10} className="muted">No conversion data yet.</td></tr>:null}
            </tbody>
          </table>
        </div>
      </section>
    </>:null}
  </main>;
}

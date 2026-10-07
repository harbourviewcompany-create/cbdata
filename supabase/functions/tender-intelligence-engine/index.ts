import { createClient } from "https://esm.sh/@supabase/supabase-js@2.117.1";
import { authorizeMembership, PROCUREMENT_LEAD_ROLES } from "../_shared/authz.ts";

type Tender = {
  id:string; workspace_id:string; external_id:string; title:string; buyer_name:string|null; category:string|null;
  region:string|null; closing_date:string|null; source:string; source_url:string|null; response_mode:string|null;
  registration_required:boolean; fit_score:number|null; fit_note:string|null; raw_payload:any; matched_organization_id:string|null;
  estimated_value:number|null; currency:string|null; incumbent_name:string|null; previous_award_value:number|null;
  contract_start_date:string|null; contract_end_date:string|null; expected_rebid_date:string|null; watch_query:string|null;
};

const norm=(v:string|null|undefined)=>(v||"").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"").replace(/[^a-z0-9]+/g," ").trim();
const has=(text:string,terms:string[])=>terms.some(t=>norm(text).includes(norm(t)));
const clamp=(n:number)=>Math.max(0,Math.min(100,Math.round(n)));
const daysUntil=(d:string|null)=>!d?null:Math.ceil((new Date(d+"T23:59:59-04:00").getTime()-Date.now())/86400000);
const addDays=(date:string,days:number)=>{const d=new Date(date+"T12:00:00Z");d.setUTCDate(d.getUTCDate()+days);return d.toISOString().slice(0,10);};

function tenderText(t:Tender){
  const raw=t.raw_payload&&typeof t.raw_payload==="object"?JSON.stringify(t.raw_payload):"";
  return [t.title,t.category||"",t.fit_note||"",t.watch_query||"",raw].join(" ");
}

function scoreTender(t:Tender,registrationReady:boolean){
  const text=tenderText(t);
  const excluded=has(text,[
    "software","logiciel","gestion documentaire","information technology","informatique",
    "network maintenance","fleet maintenance","vehicle maintenance","office supplies","food services"
  ]);
  const direct=has(text,[
    "sheet metal","ductwork","duct work","snow","janitorial","cleaning","landscaping","grounds",
    "roofing","building envelope","facility maintenance","property maintenance","hvac","ventilation"
  ]);
  const upstream=has(text,[
    "prime mechanical","mechanical contractor","general contractor","general contracting",
    "construction","new school","school construction","prime electrical","electrical contractor"
  ]);
  const standing=has(text,["standing offer","supply arrangement"]);
  const vendorList=has(text,["vendor of record","vendor roster","contractor roster","source list"]);
  const invite=has(text,["invite only","invitation only","prequalified bidders","prequalification"]);
  const d=daysUntil(t.closing_date);

  const scope=clamp(Number(t.fit_score||0)|| (direct?88:upstream?65:50));
  const eligibility=clamp(t.registration_required?(registrationReady?92:58):86);
  const commercial=clamp(t.estimated_value?Math.min(95,55+Math.log10(Math.max(1,t.estimated_value))*7):65);
  const region=norm(t.region);
  const geography=clamp(has(region,["ottawa","national capital","gatineau","outaouais"])?95:
    has(region,["eastern ontario","prescott russell","lanark","renfrew","leeds","grenville"])?82:65);
  const timing=clamp(d===null?55:d<0?0:d<=2?35:d<=5?55:d<=10?75:d<=21?90:85);
  const competition=clamp(t.incumbent_name?48:65);
  const strategic=clamp(t.matched_organization_id?78:62);
  const subtrade=clamp(upstream?(has(text,["mechanical","hvac","ventilation"])?96:has(text,["general contractor","construction"])?84:70):direct?35:55);

  let pursuitMode="review";
  if(excluded&&!direct)pursuitMode="no_fit";
  else if(standing)pursuitMode="standing_offer";
  else if(vendorList)pursuitMode="vendor_list";
  else if(invite)pursuitMode="invite_only";
  else if(upstream&&!direct)pursuitMode="subtrade";
  else if(scope>=72&&eligibility>=55)pursuitMode="prime_bid";
  else if(scope<40)pursuitMode="no_fit";

  const weighted=scope*.24+eligibility*.14+commercial*.12+geography*.10+timing*.10+competition*.08+strategic*.10+subtrade*.12;
  const overall=pursuitMode==="no_fit"?Math.min(25,clamp(weighted)):clamp(weighted);

  const nextBestAction=
    pursuitMode==="subtrade" ? "Identify bidding prime contractors and contact estimators before their internal subtrade cutoff" :
    pursuitMode==="standing_offer" ? "Verify standing-offer eligibility and supplier registration, then prepare capability submission" :
    pursuitMode==="vendor_list" ? "Confirm roster eligibility and complete vendor onboarding before the next call-up" :
    pursuitMode==="invite_only" ? "Confirm prequalification path and get onto the eligible bidder list" :
    pursuitMode==="prime_bid" ? "Complete bid/no-bid qualification, mandatory requirements and estimating plan" :
    pursuitMode==="no_fit" ? "Record no-bid rationale and keep only as source-quality evidence" :
    "Review scope, eligibility and pursuit mode";

  const rationale=
    pursuitMode==="subtrade" ? "Upstream prime package contains downstream CB trade opportunity." :
    pursuitMode==="no_fit" ? "Notice is outside CB delivery scope despite generic procurement or construction language." :
    direct ? "Direct service/trade signals align with CB delivery capabilities." :
    "Related procurement opportunity requires manual scope confirmation.";

  return {pursuitMode,scope,eligibility,commercial,geography,timing,competition,strategic,subtrade,overall,nextBestAction,rationale};
}

function subtradesFor(t:Tender){
  const text=tenderText(t);
  const out:Array<{trade:string;title:string;summary:string;score:number}>=[];
  if(has(text,["prime mechanical","mechanical contractor","hvac","ventilation","air handling","new school","school construction"])){
    out.push({trade:"sheet_metal_ductwork",title:"Sheet Metal / Ductwork Package",summary:"Review ductwork, louvers, exhaust, rooftop transitions, fabrication and installation scope.",score:has(text,["prime mechanical","mechanical contractor"])?96:88});
  }
  if(has(text,["general contractor","general contracting","construction","renovation","school construction"])){
    out.push({trade:"sheet_metal_ductwork",title:"Sheet Metal / Ductwork Package",summary:"Identify mechanical divisions carrying ductwork, flashings, louvers and related sheet-metal scope.",score:82});
    out.push({trade:"roofing_envelope",title:"Roofing / Envelope Package",summary:"Review roof, flashing, cladding, waterproofing and envelope interfaces for self-perform or partner scope.",score:68});
  }
  if(has(text,["roofing","building envelope","cladding","flashing"])){
    out.push({trade:"roofing_envelope",title:"Roofing / Envelope Package",summary:"Direct roofing/envelope package with possible sheet-metal flashing and cladding scope.",score:92});
  }
  if(has(text,["site work","paving","asphalt","concrete","parking lot","fencing"])){
    out.push({trade:"site_services",title:"Site / Exterior Services Package",summary:"Review site, paving, concrete, fencing, drainage and exterior-maintenance scope.",score:72});
  }
  const best=new Map<string,{trade:string;title:string;summary:string;score:number}>();
  for(const x of out){const current=best.get(x.trade);if(!current||x.score>current.score)best.set(x.trade,x);}
  return Array.from(best.values()).slice(0,4);
}

Deno.serve(async(req)=>{
  if(req.method!=="POST")return new Response("method_not_allowed",{status:405});
  const supabaseUrl=Deno.env.get("SUPABASE_URL"),serviceKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if(!supabaseUrl||!serviceKey)return Response.json({error:"not_configured"},{status:500});

  const token=(req.headers.get("authorization")||"").replace(/^Bearer\s+/,"");
  const admin=createClient(supabaseUrl,serviceKey);
  const {data:userData,error:userError}=await admin.auth.getUser(token);
  if(userError||!userData.user)return Response.json({error:"unauthorized"},{status:401});

  const body=await req.json().catch(()=>({}));
  const requestedWorkspace=typeof body.workspace_id==="string"?body.workspace_id:null;
  const requestedTender=typeof body.tender_id==="string"?body.tender_id:null;
  const {data:memberships}=await admin.from("workspace_memberships").select("workspace_id,role").eq("user_id",userData.user.id).eq("status","active");
  const authz=authorizeMembership(memberships,requestedWorkspace,PROCUREMENT_LEAD_ROLES);
  if(!authz.ok)return Response.json({error:authz.error},{status:authz.status});
  const workspaceId=authz.workspaceId;

  const {data:registrationRows}=await admin.from("supplier_registrations").select("source_key,status").eq("workspace_id",workspaceId);
  const readyKeys=new Set((registrationRows||[]).filter((r:any)=>["active","not_required","complete","registered","ready"].includes(r.status)).map((r:any)=>r.source_key));

  let query=admin.from("tender_records")
    .select("id,workspace_id,external_id,title,buyer_name,category,region,closing_date,source,source_url,response_mode,registration_required,fit_score,fit_note,raw_payload,matched_organization_id,estimated_value,currency,incumbent_name,previous_award_value,contract_start_date,contract_end_date,expected_rebid_date,watch_query")
    .eq("workspace_id",workspaceId).order("closing_date",{ascending:false}).limit(500);
  if(requestedTender)query=query.eq("id",requestedTender);
  const {data:tenderRows,error:tenderError}=await query;
  if(tenderError)return Response.json({error:tenderError.message},{status:500});

  let intelligence=0,subtrades=0,cycles=0,future=0;
  for(const t of (tenderRows||[]) as Tender[]){
    const sourceKey=String(t.raw_payload?.source_key||"");
    const scored=scoreTender(t,readyKeys.has(sourceKey));
    const {error:piError}=await admin.from("tender_pursuit_intelligence").upsert({
      tender_record_id:t.id,workspace_id:workspaceId,pursuit_mode:scored.pursuitMode,
      scope_fit:scored.scope,eligibility:scored.eligibility,commercial_attractiveness:scored.commercial,
      geographic_fit:scored.geography,timing:scored.timing,competition:scored.competition,
      strategic_value:scored.strategic,subtrade_potential:scored.subtrade,overall_score:scored.overall,
      rationale:scored.rationale,next_best_action:scored.nextBestAction,
      evidence:{source:t.source,external_id:t.external_id,discovery_fit:t.fit_score,source_key:sourceKey,engine_version:"3.3"},
      calculated_at:new Date().toISOString(),updated_at:new Date().toISOString()
    },{onConflict:"tender_record_id"});
    if(!piError)intelligence++;

    for(const x of subtradesFor(t)){
      const due=t.closing_date?new Date(t.closing_date+"T12:00:00-04:00").toISOString():null;
      const {error}=await admin.from("tender_subtrade_opportunities").upsert({
        workspace_id:workspaceId,tender_record_id:t.id,trade:x.trade,package_title:x.title,scope_summary:x.summary,
        fit_score:x.score,suggested_action:"Identify likely bidding primes, find estimator contacts, confirm internal pricing cutoff and offer CB scope/pricing.",
        due_at:due,evidence:{source:t.source,external_id:t.external_id,title:t.title,engine_version:"3.2"},updated_at:new Date().toISOString()
      },{onConflict:"workspace_id,tender_record_id,trade"});
      if(!error)subtrades++;
    }

    if(t.incumbent_name||t.previous_award_value||t.contract_start_date||t.contract_end_date||t.expected_rebid_date){
      const serviceCategory=String(t.watch_query||t.raw_payload?.services?.[0]||t.category||"procurement services").slice(0,160);
      const rebid=t.expected_rebid_date||(t.contract_end_date?addDays(t.contract_end_date,-180):null);
      const cyclePayload={
        workspace_id:workspaceId,organization_id:t.matched_organization_id,source_tender_id:t.id,
        buyer_name:t.buyer_name||"Unknown buyer",contract_title:t.title,service_category:serviceCategory,
        incumbent_name:t.incumbent_name,award_value:t.previous_award_value,currency:t.currency||"CAD",
        contract_start_date:t.contract_start_date,contract_end_date:t.contract_end_date,expected_rebid_date:rebid,
        confidence:rebid?"high":"medium",evidence_url:t.source_url,source:t.source,
        notes:"Tender-derived contract cycle.",status:rebid&&rebid<=addDays(new Date().toISOString().slice(0,10),180)?"recompete_expected":"active",
        last_verified_at:new Date().toISOString(),updated_at:new Date().toISOString()
      };
      const {data:existingCycle,error:cycleLookupError}=await admin.from("procurement_contract_cycles")
        .select("id").eq("workspace_id",workspaceId).eq("source_tender_id",t.id).eq("service_category",serviceCategory).maybeSingle();
      let cycle:any=null,cycleError:any=cycleLookupError;
      if(!cycleLookupError){
        const write=existingCycle
          ? await admin.from("procurement_contract_cycles").update(cyclePayload).eq("id",existingCycle.id).select("id").single()
          : await admin.from("procurement_contract_cycles").insert(cyclePayload).select("id").single();
        cycle=write.data;cycleError=write.error;
      }
      if(!cycleError&&cycle){
        cycles++;
        if(rebid){
          const fit=clamp(Math.max(Number(t.fit_score||0),scored.scope));
          const nextActionAt=addDays(rebid,-120);
          const futurePayload={
            workspace_id:workspaceId,contract_cycle_id:cycle.id,organization_id:t.matched_organization_id,
            buyer_name:t.buyer_name||"Unknown buyer",title:"Prepare for rebid — "+t.title,service_category:serviceCategory,
            signal_type:"award_rebid",expected_publish_start:addDays(rebid,-60),expected_publish_end:addDays(rebid,60),
            fit_score:fit,confidence:t.expected_rebid_date?"high":"medium",
            status:nextActionAt<=new Date().toISOString().slice(0,10)?"pre_position":"watch",source_url:t.source_url,
            evidence:{source_tender_id:t.id,external_id:t.external_id,incumbent_name:t.incumbent_name,engine_version:"3.3"},
            next_action:"Verify incumbent and option years; contact procurement/facilities before the expected rebid window.",
            next_action_at:new Date(nextActionAt+"T13:00:00Z").toISOString(),linked_tender_id:t.id,updated_at:new Date().toISOString()
          };
          const {data:existingFuture,error:futureLookupError}=await admin.from("procurement_future_opportunities")
            .select("id").eq("workspace_id",workspaceId).eq("contract_cycle_id",cycle.id).maybeSingle();
          if(!futureLookupError){
            const futureWrite=existingFuture
              ? await admin.from("procurement_future_opportunities").update(futurePayload).eq("id",existingFuture.id)
              : await admin.from("procurement_future_opportunities").insert(futurePayload);
            if(!futureWrite.error)future++;
          }
        }
      }
    }
  }

  return Response.json({ok:true,workspace_id:workspaceId,tenders:(tenderRows||[]).length,intelligence,subtrades,cycles,future});
});

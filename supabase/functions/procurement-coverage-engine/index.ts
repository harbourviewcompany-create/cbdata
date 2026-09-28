import { createClient } from "https://esm.sh/@supabase/supabase-js@2.117.1";

const SERVICE_TERMS:Array<[string,string]>=[
  ["snow","snow"],["ice control","snow"],["salt","snow"],["sanding","snow"],["déneig","snow"],
  ["landscap","landscaping"],["grounds","grounds"],["mowing","grounds"],["turf","grounds"],["horticultur","grounds"],["tree care","grounds"],
  ["janitorial","janitorial"],["custodial","janitorial"],["cleaning","cleaning"],["nettoyage","cleaning"],["concierger","janitorial"],
  ["facility maintenance","facility maintenance"],["building maintenance","facility maintenance"],["property maintenance","property maintenance"],["preventive maintenance","facility maintenance"],
  ["hvac","hvac"],["ventilation","hvac"],["duct","sheet metal"],["sheet metal","sheet metal"],["flashing","sheet metal"],["cladding","sheet metal"],["louver","sheet metal"],["damper","sheet metal"],
  ["mechanical","mechanical"],["plumbing","plumbing"],["boiler","mechanical"],["controls","mechanical"],["refrigeration","mechanical"],
  ["roof","roofing"],["building envelope","building envelope"],["paving","paving"],["asphalt","paving"],["concrete","concrete"],["sidewalk","site work"],["curb","site work"],["drainage","site work"],["fencing","site work"],
  ["renovation","construction"],["rehabilitation","construction"],["retrofit","construction"],["fit-up","construction"],["fit up","construction"],["construction","construction"],
  ["standing offer","standing offer"],["vendor of record","vendor roster"],["prequalification","prequalification"]
];

function norm(v:string|null|undefined){return (v||"").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"").replace(/[^a-z0-9]+/g," ").trim();}
function services(v:string){const n=norm(v);return Array.from(new Set(SERVICE_TERMS.filter(([x])=>n.includes(norm(x))).map(([,x])=>x)));}
function opportunityType(v:string){
  const n=norm(v);
  if(n.includes("request for quotation")||n.includes(" rfq "))return "rfq";
  if(n.includes("standing offer")||n.includes("supply arrangement"))return "standing_offer";
  if(n.includes("prequalification")||n.includes("pre qualification")||n.includes("request for supplier qualification"))return "prequalification";
  if(n.includes("vendor of record")||n.includes("vendor roster")||n.includes("contractor roster"))return "vendor_roster";
  if(n.includes("planned procurement")||n.includes("procurement plan")||n.includes("future procurement"))return "planned_procurement";
  if(n.includes("award notice")||n.includes("contract award"))return "award";
  return "tender";
}
function localGeo(v:string){const n=norm(v);return ["ottawa","gatineau","hull","outaouais","national capital","ncr","kanata","nepean","orleans","gloucester","stittsville"].some(x=>n.includes(norm(x)));}
function scoreOpportunity(o:any,buyer:any){
  const text=[o.title,o.description,o.category,o.buyer_name,o.region].filter(Boolean).join(" ");
  const fit=services(text);
  const geography=localGeo(text)||buyer?.region ? 20 : 0;
  const service=Math.min(30,fit.length*8);
  const buyerScore=Math.round((Number(buyer?.watch_priority||40)/100)*20);
  const recurring=fit.some(x=>["snow","grounds","landscaping","janitorial","cleaning","facility maintenance","standing offer"].includes(x))?10:0;
  const form=["standing_offer","prequalification","vendor_roster","rfq","tender"].includes(opportunityType(text))?10:0;
  const close=o.closing_at?new Date(o.closing_at).getTime():null;
  const deadline=close===null?5:(close>=Date.now()?10:0);
  const total=Math.min(100,geography+service+buyerScore+recurring+form+deadline);
  return {fit,total,breakdown:{geography,service,buyer:buyerScore,recurring,form,deadline},type:opportunityType(text)};
}

Deno.serve(async(req)=>{
  if(req.method!=="POST") return new Response("method_not_allowed",{status:405});
  const supabaseUrl=Deno.env.get("SUPABASE_URL"), serviceRoleKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if(!supabaseUrl||!serviceRoleKey) return Response.json({error:"not_configured"},{status:500});
  const auth=req.headers.get("authorization")||"", token=auth.replace(/^Bearer\s+/,"");
  const admin=createClient(supabaseUrl,serviceRoleKey);
  const {data:userData,error:userError}=await admin.auth.getUser(token);
  if(userError||!userData.user) return Response.json({error:"unauthorized"},{status:401});
  const body=await req.json().catch(()=>({}));
  const requestedWorkspace=typeof body.workspace_id==="string"?body.workspace_id:null;
  const {data:memberships}=await admin.from("workspace_memberships").select("workspace_id").eq("user_id",userData.user.id).eq("status","active");
  const membership=(memberships||[]).find((m:any)=>!requestedWorkspace||m.workspace_id===requestedWorkspace);
  if(!membership) return Response.json({error:"workspace_access_denied"},{status:403});
  const workspaceId=membership.workspace_id;

  const {data:run,error:runError}=await admin.from("procurement_coverage_runs").insert({workspace_id:workspaceId}).select("id,started_at").single();
  if(runError||!run) return Response.json({error:runError?.message||"run_create_failed"},{status:500});

  const sourceErrors:any[]=[];
  const scouts=["canadabuys-scout","regional-tender-scout","canadabuys-award-scout"];
  await Promise.all(scouts.map(async slug=>{
    try{
      const r=await fetch(supabaseUrl+"/functions/v1/"+slug,{method:"POST",headers:{Authorization:auth,"Content-Type":"application/json"},body:JSON.stringify({workspace_id:workspaceId})});
      if(!r.ok){const p=await r.json().catch(()=>({}));sourceErrors.push({source:slug,error:p.error||("http_"+r.status)});}
    }catch(e){sourceErrors.push({source:slug,error:e instanceof Error?e.message:"request_failed"});}
  }));

  try{
    const [{data:buyers},{data:sources},{data:tenders},{data:listRows},{data:organizationRows}]=await Promise.all([
      admin.from("procurement_buyers").select("*").eq("workspace_id",workspaceId),
      admin.from("tender_sources").select("source_key,display_name").eq("workspace_id",workspaceId),
      admin.from("tender_records").select("id,source,external_id,title,buyer_name,category,region,published_date,closing_date,estimated_value,source_url,raw_payload,matched_organization_id,fit_score").eq("workspace_id",workspaceId),
      admin.from("outreach_lists").select("id").eq("workspace_id",workspaceId).eq("name","Regional Procurement Buyers").limit(1),
      admin.from("organizations").select("id,legal_name,operating_name").eq("workspace_id",workspaceId)
    ]);
    const sourceKeyByName=new Map((sources||[]).map((s:any)=>[norm(s.display_name),s.source_key]));
    const buyerRows:any[]=buyers||[];
    const organizations:any[]=organizationRows||[];

    // Backfill every already-known tender into the raw regional opportunity universe.
    for(const t of tenders||[]){
      const sourceKey=sourceKeyByName.get(norm(t.source))||norm(t.source).replace(/ /g,"_")||"unknown";
      const buyer=buyerRows.find((b:any)=>norm(b.display_name)===norm(t.buyer_name));
      await admin.from("procurement_opportunities").upsert({
        workspace_id:workspaceId,source_key:sourceKey,external_id:t.external_id,
        buyer_key:buyer?.buyer_key||null,buyer_name:t.buyer_name,title:t.title,
        opportunity_type:opportunityType([t.title,t.category].filter(Boolean).join(" ")),
        category:t.category,region:t.region,
        published_at:t.published_date?new Date(t.published_date+"T12:00:00Z").toISOString():null,
        closing_at:t.closing_date?new Date(t.closing_date+"T23:59:59-04:00").toISOString():null,
        estimated_value:t.estimated_value,source_url:t.source_url||"https://cbdata.local/procurement/"+t.id,
        matched_organization_id:t.matched_organization_id,promoted_tender_record_id:t.id,
        raw_payload:{legacy_tender_record:t.raw_payload||null},last_seen_at:new Date().toISOString(),updated_at:new Date().toISOString()
      },{onConflict:"workspace_id,source_key,external_id"});
    }

    const {data:opportunities}=await admin.from("procurement_opportunities").select("*").eq("workspace_id",workspaceId)
      .or("closing_at.is.null,closing_at.gte."+new Date().toISOString()).order("last_seen_at",{ascending:false}).limit(1000);

    let listId=listRows?.[0]?.id as string|undefined;
    if(!listId){
      const {data:list}=await admin.from("outreach_lists").insert({workspace_id:workspaceId,name:"Regional Procurement Buyers",criteria:{engine:"regional_procurement_coverage",region:"Ottawa / NCR / Outaouais"}}).select("id").single();
      listId=list?.id;
    }

    let classified=0,actionable=0,watch=0,targetsCreated=0,signalsCreated=0,tendersPromoted=0;
    for(const o of opportunities||[]){
      let buyer=buyerRows.find((b:any)=>b.buyer_key===o.buyer_key||norm(b.display_name)===norm(o.buyer_name));
      if(!buyer&&o.buyer_name){
        const key=norm(o.buyer_name).replace(/ /g,"-").slice(0,80);
        const {data:newBuyer}=await admin.from("procurement_buyers").upsert({
          workspace_id:workspaceId,buyer_key:key,display_name:o.buyer_name,sector:"other",region:o.region,
          primary_source_key:o.source_key,coverage_status:"partial",watch_priority:55,source_confidence:"medium",last_scanned_at:new Date().toISOString()
        },{onConflict:"workspace_id,buyer_key"}).select("*").single();
        if(newBuyer){buyer=newBuyer;buyerRows.push(newBuyer);}
      }
      const scored=scoreOpportunity(o,buyer);
      const status=scored.total>=60?"actionable":scored.total>=35?"watch":"suppressed";
      classified++; if(status==="actionable")actionable++; if(status==="watch")watch++;

      let organizationId=o.matched_organization_id||buyer?.organization_id||null;
      if(!organizationId&&o.buyer_name){
        const buyerName=norm(o.buyer_name);
        const org=organizations.find((x:any)=>norm(x.legal_name)===buyerName||norm(x.operating_name)===buyerName);
        organizationId=org?.id||null;
      }

      let targetId=o.matched_target_id||null;
      if(status==="actionable"&&organizationId&&listId){
        const {data:existingTarget}=await admin.from("outreach_targets").select("id").eq("workspace_id",workspaceId).eq("outreach_list_id",listId).eq("organization_id",organizationId).maybeSingle();
        if(existingTarget?.id) targetId=existingTarget.id;
        else {
          const {data:newTarget}=await admin.from("outreach_targets").insert({
            workspace_id:workspaceId,outreach_list_id:listId,organization_id:organizationId,organization_name:o.buyer_name,
            region:o.region,status:"queued",score:scored.total,priority:scored.total>=80?"urgent":"high",
            next_action:"Review procurement opportunity and identify procurement/facilities decision-maker",
            next_action_due_at:new Date(Date.now()+2*86400000).toISOString(),
            notes:"Auto-created by Regional Procurement Coverage Engine from "+o.source_key+" / "+o.external_id
          }).select("id").single();
          if(newTarget?.id){targetId=newTarget.id;targetsCreated++;}
        }
      }

      let tenderId=o.promoted_tender_record_id||null;
      if(status==="actionable"&&!tenderId){
        const sourceName=(sources||[]).find((s:any)=>s.source_key===o.source_key)?.display_name||o.source_key;
        const {data:existingTender}=await admin.from("tender_records").select("id").eq("workspace_id",workspaceId).eq("source",sourceName).eq("external_id",o.external_id).maybeSingle();
        if(existingTender?.id)tenderId=existingTender.id;
        else{
          const close=o.closing_at?new Date(o.closing_at).toISOString().slice(0,10):null;
          const pub=o.published_at?new Date(o.published_at).toISOString().slice(0,10):null;
          const {data:newTender}=await admin.from("tender_records").insert({
            workspace_id:workspaceId,source:sourceName,external_id:o.external_id,title:o.title,buyer_name:o.buyer_name,
            category:o.category||scored.fit.join(", "),region:o.region,estimated_value:o.estimated_value,published_date:pub,closing_date:close,
            source_url:o.source_url,raw_payload:o.raw_payload,status:"new",matched_organization_id:organizationId,
            response_mode:o.opportunity_type,fit_score:scored.total,fit_note:"Coverage engine score. Service fit: "+(scored.fit.join(", ")||"indirect/strategic buyer fit"),
            last_verified_at:new Date().toISOString(),watch_query:scored.fit.join(", "),action_state:"new",
            next_action:"Review solicitation, buyer fit and mandatory requirements"
          }).select("id").single();
          if(newTender?.id){tenderId=newTender.id;tendersPromoted++;}
        }
      }

      if(status==="actionable"&&o.source_url){
        const {data:existingSignal}=await admin.from("target_opportunity_signals").select("id").eq("workspace_id",workspaceId).eq("source_url",o.source_url).eq("reference_number",o.external_id).maybeSingle();
        if(!existingSignal){
          const {error:sigErr}=await admin.from("target_opportunity_signals").insert({
            workspace_id:workspaceId,organization_id:organizationId,target_id:targetId,signal_type:"procurement",
            title:o.title,service_fit:scored.fit,source_url:o.source_url,source_label:o.source_key,source_confidence:"high",
            published_at:o.published_at,deadline_at:o.closing_at,status:"open",reference_number:o.external_id,
            notes:"Auto-classified by Regional Procurement Coverage Engine; relevance score "+scored.total+"."
          });
          if(!sigErr)signalsCreated++;
        }
      }

      await admin.from("procurement_opportunities").update({
        buyer_key:buyer?.buyer_key||o.buyer_key,service_fit:scored.fit,relevance_score:scored.total,
        classification_status:tenderId?"promoted":status,score_breakdown:scored.breakdown,
        opportunity_type:scored.type,matched_organization_id:organizationId,matched_target_id:targetId,
        promoted_tender_record_id:tenderId,updated_at:new Date().toISOString()
      }).eq("id",o.id);

      if(buyer?.id) await admin.from("procurement_buyers").update({
        organization_id:organizationId||buyer.organization_id,last_opportunity_at:o.published_at||o.first_seen_at,
        last_scanned_at:new Date().toISOString(),coverage_status:buyer.coverage_status==="gap"?"partial":buyer.coverage_status,updated_at:new Date().toISOString()
      }).eq("id",buyer.id);
    }

    const {count:gapCount}=await admin.from("procurement_buyers").select("id",{count:"exact",head:true}).eq("workspace_id",workspaceId).in("coverage_status",["gap","partial"]);
    await admin.from("procurement_coverage_runs").update({
      finished_at:new Date().toISOString(),status:sourceErrors.length?"partial":"completed",
      buyers_checked:buyerRows.length,opportunities_classified:classified,actionable_count:actionable,watch_count:watch,
      targets_created:targetsCreated,signals_created:signalsCreated,tenders_promoted:tendersPromoted,coverage_gaps:gapCount||0,source_errors:sourceErrors
    }).eq("id",run.id);

    return Response.json({ok:true,run_id:run.id,buyers:buyerRows.length,classified,actionable,watch,targets_created:targetsCreated,signals_created:signalsCreated,tenders_promoted:tendersPromoted,coverage_gaps:gapCount||0,source_errors:sourceErrors});
  }catch(error){
    const message=error instanceof Error?error.message:"coverage_engine_failed";
    await admin.from("procurement_coverage_runs").update({finished_at:new Date().toISOString(),status:"error",source_errors:sourceErrors,error_message:message}).eq("id",run.id);
    return Response.json({error:message,run_id:run.id},{status:500});
  }
});

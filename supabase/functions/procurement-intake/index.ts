import { createClient } from "https://esm.sh/@supabase/supabase-js@2.117.1";
import { authorizeMembership, PROCUREMENT_ROLES } from "../_shared/authz.ts";

const norm=(v:string|null|undefined)=>(v||"").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"").replace(/[^a-z0-9]+/g," ").trim();
const slug=(v:string)=>norm(v).replace(/\s+/g,"-").slice(0,120);
const allowedTypes=new Set(["tender","rfq","standing_offer","prequalification","vendor_roster","planned_procurement","award","rebid_signal","other"]);

Deno.serve(async(req)=>{
  if(req.method!=="POST")return new Response("method_not_allowed",{status:405});
  const supabaseUrl=Deno.env.get("SUPABASE_URL"),serviceKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if(!supabaseUrl||!serviceKey)return Response.json({error:"not_configured"},{status:500});
  const token=(req.headers.get("authorization")||"").replace(/^Bearer\s+/,"");
  const admin=createClient(supabaseUrl,serviceKey);
  const {data:userData,error:userError}=await admin.auth.getUser(token);
  if(userError||!userData.user)return Response.json({error:"unauthorized"},{status:401});

  const body=await req.json().catch(()=>({}));
  const workspaceId=typeof body.workspace_id==="string"?body.workspace_id:"";
  const sourceKey=typeof body.source_key==="string"?body.source_key:"";
  const records=Array.isArray(body.records)?body.records.slice(0,100):[];
  if(!workspaceId||!sourceKey||!records.length)return Response.json({error:"workspace_id_source_key_and_records_required"},{status:400});

  const {data:memberships}=await admin.from("workspace_memberships").select("workspace_id,role").eq("workspace_id",workspaceId).eq("user_id",userData.user.id).eq("status","active");
  const authz=authorizeMembership(memberships,workspaceId,PROCUREMENT_ROLES);
  if(!authz.ok)return Response.json({error:authz.error},{status:authz.status});
  const {data:source}=await admin.from("tender_sources").select("source_key,display_name,source_url,enabled").eq("workspace_id",workspaceId).eq("source_key",sourceKey).maybeSingle();
  if(!source||source.enabled===false)return Response.json({error:"source_not_enabled"},{status:400});

  const {data:orgRows}=await admin.from("organizations").select("id,legal_name,operating_name").eq("workspace_id",workspaceId);
  const orgs:any[]=orgRows||[];
  let universeInserted=0,universeUpdated=0,promoted=0,leads=0,errors=0;

  for(const row of records){
    try{
      const externalId=String(row.external_id||row.id||"").trim();
      const title=String(row.title||"").trim();
      if(!externalId||!title){errors++;continue;}

      const buyer=String(row.buyer_name||row.buyer||"").trim()||null;
      const buyerKey=buyer?slug(buyer):null;
      const region=String(row.region||"").trim()||null;
      const sourceUrl=String(row.source_url||source.source_url||"").trim();
      if(!sourceUrl){errors++;continue;}

      let org:any=null;
      if(buyer){
        org=orgs.find(o=>norm(o.legal_name)===norm(buyer)||norm(o.operating_name)===norm(buyer));
        if(!org){
          const {data:created}=await admin.from("organizations").insert({
            workspace_id:workspaceId,legal_name:buyer,operating_name:buyer,organization_type:"owner",status:"active",
            primary_region:region,source_notes:"Created by procurement opportunity intake: "+source.display_name
          }).select("id,legal_name,operating_name").single();
          if(created){org=created;orgs.push(created);}
        }

        await admin.from("procurement_buyers").upsert({
          workspace_id:workspaceId,buyer_key:buyerKey,display_name:buyer,organization_id:org?.id||null,
          region,primary_source_key:sourceKey,portal_url:source.source_url,coverage_status:"monitored",
          watch_priority:Number(row.watch_priority||70),service_fit:Array.isArray(row.services)?row.services:[],
          last_opportunity_at:new Date().toISOString(),last_scanned_at:new Date().toISOString(),
          source_confidence:String(row.source_confidence||"medium"),updated_at:new Date().toISOString()
        },{onConflict:"workspace_id,buyer_key"});
      }

      const relevance=Math.max(0,Math.min(100,Number(row.relevance_score??row.fit_score??(Array.isArray(row.services)&&row.services.length?60:40))));
      const opportunityType=allowedTypes.has(String(row.opportunity_type||""))?String(row.opportunity_type):"other";
      const services=Array.isArray(row.services)?row.services.map(String):[];
      const closingAt=row.closing_at||row.closing_date||null;
      const publishedAt=row.published_at||row.published_date||null;
      const promoteRequested=row.promote===true;
      const promotable=["tender","rfq","standing_offer","prequalification","vendor_roster"].includes(opportunityType);
      const shouldPromote=promoteRequested||(relevance>=45&&!!closingAt&&promotable);
      const classification=shouldPromote?"actionable":relevance>=45?"actionable":relevance>=25?"watch":"suppressed";

      const opportunityPayload={
        workspace_id:workspaceId,source_key:sourceKey,external_id:externalId,buyer_key:buyerKey,buyer_name:buyer,
        title,opportunity_type:opportunityType,description:String(row.description||"").trim()||null,
        category:String(row.category||"").trim()||null,region,published_at:publishedAt,closing_at:closingAt,
        estimated_value:row.estimated_value===null||row.estimated_value===undefined?null:Number(row.estimated_value),
        currency:String(row.currency||"CAD"),source_url:sourceUrl,service_fit:services,relevance_score:relevance,
        classification_status:classification,score_breakdown:row.score_breakdown&&typeof row.score_breakdown==="object"?row.score_breakdown:{},
        matched_organization_id:org?.id||null,
        raw_payload:{...(row.raw_payload&&typeof row.raw_payload==="object"?row.raw_payload:{}),source_key:sourceKey,intake_version:"2.0",observed_at:new Date().toISOString()},
        last_seen_at:new Date().toISOString(),updated_at:new Date().toISOString()
      };

      const {data:existingOpp}=await admin.from("procurement_opportunities").select("id,promoted_tender_record_id").eq("workspace_id",workspaceId).eq("source_key",sourceKey).eq("external_id",externalId).maybeSingle();
      const {data:opp,error:oppError}=existingOpp
        ? await admin.from("procurement_opportunities").update(opportunityPayload).eq("id",existingOpp.id).select("id,promoted_tender_record_id").single()
        : await admin.from("procurement_opportunities").insert(opportunityPayload).select("id,promoted_tender_record_id").single();
      if(oppError||!opp){errors++;continue;}
      existingOpp?universeUpdated++:universeInserted++;

      if(opportunityType==="award"){
        await admin.from("procurement_awards").upsert({
          workspace_id:workspaceId,source_key:sourceKey,external_id:externalId,buyer_key:buyerKey,buyer_name:buyer,
          title,awarded_to:String(row.awarded_to||row.incumbent_name||"").trim()||null,
          award_amount:row.award_amount===null||row.award_amount===undefined?null:Number(row.award_amount),
          currency:String(row.currency||"CAD"),award_date:row.award_date||null,
          contract_start_date:row.contract_start_date||null,contract_end_date:row.contract_end_date||null,
          option_end_date:row.option_end_date||null,expected_rebid_date:row.expected_rebid_date||null,
          source_url:sourceUrl,
          raw_payload:{...(row.raw_payload&&typeof row.raw_payload==="object"?row.raw_payload:{}),services,source_opportunity_id:opp.id,intake_version:"2.1"},
          updated_at:new Date().toISOString()
        },{onConflict:"workspace_id,source_key,external_id"});
      }

      if(!shouldPromote)continue;

      const tenderPayload={
        workspace_id:workspaceId,source:source.display_name,external_id:externalId,title,buyer_name:buyer,
        category:String(row.category||"").trim()||services.join(", ")||null,region,
        estimated_value:row.estimated_value===null||row.estimated_value===undefined?null:Number(row.estimated_value),
        currency:String(row.currency||"CAD"),
        published_date:publishedAt?String(publishedAt).slice(0,10):null,
        closing_date:closingAt?String(closingAt).slice(0,10):null,
        source_url:sourceUrl,
        raw_payload:{...(opportunityPayload.raw_payload||{}),procurement_opportunity_id:opp.id,services},
        matched_organization_id:org?.id||null,response_mode:String(row.response_mode||opportunityType),
        registration_required:Boolean(row.registration_required),fit_score:relevance,
        fit_note:String(row.fit_note||"").trim()||"Promoted from procurement opportunity universe.",
        last_verified_at:new Date().toISOString(),watch_query:services.join(", ")||null,
        notes:String(row.notes||"").trim()||null,updated_at:new Date().toISOString()
      };

      const {data:existingTender}=await admin.from("tender_records").select("id,lead_id").eq("workspace_id",workspaceId).eq("source",source.display_name).eq("external_id",externalId).maybeSingle();
      const {data:tender,error:tenderError}=existingTender
        ? await admin.from("tender_records").update(tenderPayload).eq("id",existingTender.id).select("id,lead_id").single()
        : await admin.from("tender_records").insert({...tenderPayload,status:"new"}).select("id,lead_id").single();
      if(tenderError||!tender){errors++;continue;}
      promoted++;

      await admin.from("procurement_opportunities").update({
        classification_status:"promoted",promoted_tender_record_id:tender.id,updated_at:new Date().toISOString()
      }).eq("id",opp.id);

      if(!tender.lead_id){
        const {data:lead}=await admin.from("leads").insert({
          workspace_id:workspaceId,organization_id:org?.id||null,source:source.display_name,lead_type:"tender",status:"new",
          region,score:relevance,source_detail_table:"tender_records",source_detail_id:tender.id
        }).select("id").single();
        if(lead?.id){leads++;await admin.from("tender_records").update({lead_id:lead.id}).eq("id",tender.id).eq("workspace_id",workspaceId);}
      }
    }catch{errors++;}
  }

  await admin.from("tender_sources").update({
    last_run_at:new Date().toISOString(),last_success_at:errors===records.length?null:new Date().toISOString(),
    last_error:errors?errors+" intake record(s) failed":null,last_verified_at:new Date().toISOString(),updated_at:new Date().toISOString()
  }).eq("workspace_id",workspaceId).eq("source_key",sourceKey);

  return Response.json({
    ok:errors<records.length,source_key:sourceKey,received:records.length,
    universe_inserted:universeInserted,universe_updated:universeUpdated,promoted,lead_created:leads,errors
  });
});

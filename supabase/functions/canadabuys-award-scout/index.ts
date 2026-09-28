import { createClient } from "https://esm.sh/@supabase/supabase-js@2.117.1";

const BASE="https://canadabuys.canada.ca";
const SEARCH_TERMS=[
  "janitorial","cleaning","grounds maintenance","landscaping","snow removal","ice control",
  "facility maintenance","building maintenance","sheet metal","ductwork","hvac","mechanical",
  "roofing","building envelope","paving","concrete","site work","renovation"
];
const REGION_TERMS=["ottawa","gatineau","national capital","ncr","outaouais","nepean","kanata","orleans","gloucester","stittsville","hull"];
const SERVICE_TERMS:Array<[string,string]>=[
 ["snow","snow"],["ice control","snow"],["landscap","landscaping"],["grounds","grounds"],
 ["janitorial","janitorial"],["cleaning","cleaning"],["custodial","janitorial"],
 ["facility maintenance","facility maintenance"],["building maintenance","facility maintenance"],
 ["sheet metal","sheet metal"],["duct","sheet metal"],["hvac","hvac"],["ventilation","hvac"],
 ["mechanical","mechanical"],["roof","roofing"],["building envelope","building envelope"],
 ["paving","paving"],["asphalt","paving"],["concrete","concrete"],["site work","site work"],
 ["renovation","construction"],["construction","construction"]
];

function cleanHtml(v:string){return v.replace(/<script[\s\S]*?<\/script>/gi," ").replace(/<style[\s\S]*?<\/style>/gi," ").replace(/<[^>]+>/g," ").replace(/&nbsp;/gi," ").replace(/&amp;/gi,"&").replace(/&quot;/gi,'"').replace(/&#39;/gi,"'").replace(/\s+/g," ").trim();}
function norm(v:string|null|undefined){return (v||"").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"").replace(/[^a-z0-9]+/g," ").trim();}
function regionMatch(v:string){const n=norm(v);return REGION_TERMS.some(x=>n.includes(norm(x)));}
function serviceFit(v:string){const n=norm(v);return Array.from(new Set(SERVICE_TERMS.filter(([x])=>n.includes(norm(x))).map(([,x])=>x)));}
function isoDate(v:string|null|undefined){if(!v)return null;const m=v.match(/(20\d{2})[\/-](\d{1,2})[\/-](\d{1,2})/);if(m)return m[1]+"-"+m[2].padStart(2,"0")+"-"+m[3].padStart(2,"0");const d=new Date(v);return Number.isNaN(d.getTime())?null:d.toISOString().slice(0,10);}
function money(v:string|null|undefined){if(!v)return null;const n=Number(v.replace(/[^0-9.-]/g,""));return Number.isFinite(n)&&n>0?n:null;}
function field(text:string,labels:string[]){for(const label of labels){const re=new RegExp(label+"\\s*:?\\s*(.*?)(?=\\s+[A-Z][A-Za-z /()-]{2,40}\\s*:|$)","i");const m=text.match(re);if(m?.[1])return m[1].trim();}return null;}

type Award={externalId:string;title:string;category:string|null;awardDate:string|null;contractEndDate:string|null;buyer:string|null;url:string;detail:string;awardedTo:string|null;amount:number|null};

async function parseAwards(term:string):Promise<Award[]>{
 const url=new URL("/en/tender-opportunities",BASE);
 url.searchParams.set("current_tab","t");
 url.searchParams.set("items_per_page","50");
 url.searchParams.set("order","award_ifnot_amended");
 url.searchParams.set("sort","desc");
 url.searchParams.set("words",term);
 const r=await fetch(url,{headers:{"User-Agent":"CBData-CanadaBuys-Award-Scout/1.0"}});
 if(!r.ok)throw new Error("award_search_"+r.status);
 const html=await r.text();
 const marker=html.search(/List of award notices/i);
 if(marker<0)return[];
 const tail=html.slice(marker);
 const stop=tail.search(/List of contract history/i);
 const section=stop>0?tail.slice(0,stop):tail;
 const rows=section.match(/<tr[\s\S]*?<\/tr>/gi)||[];
 const out:Award[]=[];
 for(const row of rows){
   const hrefMatch=row.match(/href=["']([^"']*(?:award|tender)[^"']*)["'][^>]*>([\s\S]*?)<\/a>/i);
   if(!hrefMatch)continue;
   const title=cleanHtml(hrefMatch[2]);
   if(!title||/title|category|organization/i.test(title)&&title.length<35)continue;
   const href=hrefMatch[1].startsWith("http")?hrefMatch[1]:BASE+hrefMatch[1];
   const cells=(row.match(/<t[dh][^>]*>[\s\S]*?<\/t[dh]>/gi)||[]).map(cleanHtml).filter(Boolean);
   if(cells.length<3)continue;
   const dates=cells.join(" ").match(/20\d{2}[\/-]\d{1,2}[\/-]\d{1,2}/g)||[];
   const buyer=cells[cells.length-1]||null;
   const category=cells.length>1?cells[1]:null;
   const detailResp=await fetch(href,{headers:{"User-Agent":"CBData-CanadaBuys-Award-Scout/1.0"}}).catch(()=>null);
   const detail=detailResp?.ok?cleanHtml(await detailResp.text()):cells.join(" ");
   if(!regionMatch([title,buyer||"",detail].join(" ")))continue;
   const awardedTo=field(detail,["Supplier Name","Supplier","Awarded To","Contractor Name","Vendor Name"]);
   const amount=money(field(detail,["Contract Value","Award Value","Contract Amount","Total Contract Value"]));
   const contractEnd=isoDate(field(detail,["Contract End Date","End Date","Contract Period End"]))||isoDate(dates[1]);
   const awardDate=isoDate(field(detail,["Award Date","Contract Award Date"]))||isoDate(dates[0]);
   const externalId=(href.split("/").filter(Boolean).pop()||norm(title).replace(/ /g,"-")).split("?")[0].slice(0,180);
   out.push({externalId,title,category,awardDate,contractEndDate:contractEnd,buyer,url:href,detail,awardedTo,amount});
 }
 return out;
}

Deno.serve(async(req)=>{
 if(req.method!=="POST")return new Response("method_not_allowed",{status:405});
 const supabaseUrl=Deno.env.get("SUPABASE_URL"),serviceRoleKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
 if(!supabaseUrl||!serviceRoleKey)return Response.json({error:"not_configured"},{status:500});
 const auth=req.headers.get("authorization")||"",token=auth.replace(/^Bearer\s+/,"");
 const admin=createClient(supabaseUrl,serviceRoleKey);
 const {data:userData,error:userError}=await admin.auth.getUser(token);
 if(userError||!userData.user)return Response.json({error:"unauthorized"},{status:401});
 const body=await req.json().catch(()=>({})),requested=typeof body.workspace_id==="string"?body.workspace_id:null;
 const {data:memberships}=await admin.from("workspace_memberships").select("workspace_id").eq("user_id",userData.user.id).eq("status","active");
 const membership=(memberships||[]).find((m:any)=>!requested||m.workspace_id===requested);
 if(!membership)return Response.json({error:"workspace_access_denied"},{status:403});
 const workspaceId=membership.workspace_id;
 const [{data:buyers},{data:orgs}]=await Promise.all([
  admin.from("procurement_buyers").select("buyer_key,display_name,organization_id,watch_priority").eq("workspace_id",workspaceId),
  admin.from("organizations").select("id,legal_name,operating_name").eq("workspace_id",workspaceId)
 ]);
 const found=new Map<string,Award>();const errors:any[]=[];
 for(const term of SEARCH_TERMS){
  try{for(const a of await parseAwards(term))found.set(a.externalId,a);}
  catch(e){errors.push({term,error:e instanceof Error?e.message:"search_failed"});}
 }
 let inserted=0,updated=0,cycles=0,future=0;
 for(const a of found.values()){
  const fit=serviceFit([a.title,a.category||"",a.detail].join(" "));
  if(!fit.length)continue;
  const buyer=(buyers||[]).find((b:any)=>norm(b.display_name)===norm(a.buyer));
  const org=(orgs||[]).find((o:any)=>norm(o.legal_name)===norm(a.buyer)||norm(o.operating_name)===norm(a.buyer));
  const buyerKey=buyer?.buyer_key||null;
  const expectedRebid=a.contractEndDate?new Date(new Date(a.contractEndDate+"T12:00:00Z").getTime()-180*86400000).toISOString().slice(0,10):null;
  const payload={
    workspace_id:workspaceId,source_key:"canadabuys",external_id:a.externalId,buyer_key:buyerKey,
    buyer_name:a.buyer||"Unknown buyer",title:a.title,awarded_to:a.awardedTo,award_amount:a.amount,currency:"CAD",
    award_date:a.awardDate,contract_end_date:a.contractEndDate,expected_rebid_date:expectedRebid,source_url:a.url,
    raw_payload:{category:a.category,services:fit,detail_excerpt:a.detail.slice(0,12000),observed_at:new Date().toISOString()},
    updated_at:new Date().toISOString()
  };
  const {data:existing}=await admin.from("procurement_awards").select("id").eq("workspace_id",workspaceId).eq("source_key","canadabuys").eq("external_id",a.externalId).maybeSingle();
  const {error:awardError}=existing
   ? await admin.from("procurement_awards").update(payload).eq("id",existing.id)
   : await admin.from("procurement_awards").insert(payload);
  if(awardError){errors.push({award:a.externalId,error:awardError.message});continue;}
  existing?updated++:inserted++;

  const serviceCategory=fit.join(", ");
  const {data:cycleExisting}=await admin.from("procurement_contract_cycles").select("id").eq("workspace_id",workspaceId)
    .ilike("buyer_name",a.buyer||"Unknown buyer").eq("contract_title",a.title)
    .eq("service_category",serviceCategory).eq("contract_end_date",a.contractEndDate||"9999-12-31").maybeSingle();
  let cycleId=cycleExisting?.id||null;
  if(!cycleId){
    const {data:cycle}=await admin.from("procurement_contract_cycles").insert({
      workspace_id:workspaceId,organization_id:buyer?.organization_id||org?.id||null,buyer_name:a.buyer||"Unknown buyer",
      contract_title:a.title,service_category:serviceCategory,incumbent_name:a.awardedTo,award_value:a.amount,currency:"CAD",
      contract_end_date:a.contractEndDate,expected_rebid_date:expectedRebid,confidence:a.contractEndDate?"high":"medium",
      evidence_url:a.url,source:"canadabuys",notes:"CanadaBuys award notice; rebid date is contract end minus 180 days when not explicitly published.",
      status:expectedRebid&&expectedRebid<=new Date(Date.now()+180*86400000).toISOString().slice(0,10)?"recompete_expected":"active",
      last_verified_at:new Date().toISOString()
    }).select("id").single();
    cycleId=cycle?.id||null;if(cycleId)cycles++;
  }
  if(cycleId&&expectedRebid){
    const start=new Date(new Date(expectedRebid+"T12:00:00Z").getTime()-60*86400000).toISOString().slice(0,10);
    const end=new Date(new Date(expectedRebid+"T12:00:00Z").getTime()+60*86400000).toISOString().slice(0,10);
    const {data:existingFuture}=await admin.from("procurement_future_opportunities").select("id").eq("workspace_id",workspaceId).eq("contract_cycle_id",cycleId).maybeSingle();
    if(!existingFuture){
      const {error:fErr}=await admin.from("procurement_future_opportunities").insert({
        workspace_id:workspaceId,contract_cycle_id:cycleId,organization_id:buyer?.organization_id||org?.id||null,
        buyer_name:a.buyer||"Unknown buyer",title:"Prepare for rebid — "+a.title,service_category:serviceCategory,
        signal_type:"award_rebid",expected_publish_start:start,expected_publish_end:end,
        fit_score:Math.min(100,Number(buyer?.watch_priority||60)+20),confidence:a.contractEndDate?"high":"medium",
        status:expectedRebid<=new Date(Date.now()+120*86400000).toISOString().slice(0,10)?"pre_position":"watch",
        source_url:a.url,evidence:{award_external_id:a.externalId,incumbent:a.awardedTo,award_value:a.amount,contract_end_date:a.contractEndDate,forecast_method:"contract_end_minus_180_days"},
        next_action:"Verify incumbent and option years; contact procurement/facilities before the expected rebid window.",
        next_action_at:new Date(new Date(expectedRebid+"T12:00:00Z").getTime()-120*86400000).toISOString()
      });
      if(!fErr)future++;
    }
  }
  if(buyerKey){
    await admin.from("procurement_buyers").update({
      last_award_at:a.awardDate?new Date(a.awardDate+"T12:00:00Z").toISOString():new Date().toISOString(),
      next_expected_procurement_at:expectedRebid?new Date(expectedRebid+"T12:00:00Z").toISOString():undefined,
      updated_at:new Date().toISOString()
    }).eq("workspace_id",workspaceId).eq("buyer_key",buyerKey);
  }
 }
 return Response.json({ok:true,fetched:found.size,inserted,updated,cycles_created:cycles,future_opportunities_created:future,error_count:errors.length,errors:errors.slice(0,20)});
});

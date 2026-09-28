import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SOURCE = "CanadaBuys";
const BASE = "https://canadabuys.canada.ca";
const SEARCH_TERMS = ["landscaping","snow","grounds maintenance","janitorial","cleaning","facility maintenance","property maintenance","caretaking","déneigement","entretien","nettoyage","conciergerie"];
const REGION_TERMS = ["ottawa","gatineau","hull","national capital","ncr","capitale nationale","outaouais"];
const BUYER_REGION_TERMS = ["national capital commission","commission de la capitale nationale","national research council","conseil national de recherches","ville de gatineau"];
const SERVICE_TERMS: Array<[string,string]> = [["snow","snow"],["déneigement","snow"],["landscap","landscaping"],["grounds","grounds"],["entretien paysager","landscaping"],["janitorial","janitorial"],["cleaning","cleaning"],["nettoyage","cleaning"],["concierger","janitorial"],["facility","facility"],["property maintenance","property maintenance"],["maintenance","maintenance"],["caretaking","caretaking"],["entretien","maintenance"]];

function cleanHtml(value:string):string { return value.replace(/<script[\s\S]*?<\/script>/gi," ").replace(/<style[\s\S]*?<\/style>/gi," ").replace(/<[^>]+>/g," ").replace(/&nbsp;/gi," ").replace(/&amp;/gi,"&").replace(/&quot;/gi,'"').replace(/&#39;/gi,"'").replace(/&apos;/gi,"'").replace(/\s+/g," ").trim(); }
function decode(value:string):string { return cleanHtml(value).replace(/&#(\d+);/g,(_,n)=>String.fromCharCode(Number(n))); }
function dateValue(value:string|null):string|null { if(!value) return null; const m=value.match(/(20\d{2})[\/\-](\d{2})[\/\-](\d{2})/); return m ? m[1]+"-"+m[2]+"-"+m[3] : null; }
function normalize(value:string|null):string { return (value||"").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"").replace(/[^a-z0-9]+/g," ").trim(); }
function regionMatch(text:string):boolean { const n=normalize(text); return REGION_TERMS.some(t=>n.includes(normalize(t))) || BUYER_REGION_TERMS.some(t=>n.includes(normalize(t))); }
function serviceMatches(text:string):string[] { const n=normalize(text); return Array.from(new Set(SERVICE_TERMS.filter(([needle])=>n.includes(normalize(needle))).map(([,value])=>value))); }
function isOpen(closingDate:string|null):boolean { return !!closingDate && new Date(closingDate+"T23:59:59Z").getTime() >= Date.now(); }
function parseRows(html:string) {
 const rows:Array<any>=[]; const rowMatches=html.match(/<tr[\s\S]*?<\/tr>/gi)||[];
 for(const row of rowMatches){
  const link=row.match(/href=["\']([^"\']*tender-opportunities\/tender-notice\/[^"\']+)["\'][^>]*>([\s\S]*?)<\/a>/i); if(!link) continue;
  const href=link[1].startsWith("http")?link[1]:BASE+link[1]; const externalId=decode(href.split("/").pop()||"").split("?")[0]; if(!externalId) continue;
  const cells=(row.match(/<t[dh][^>]*>[\s\S]*?<\/t[dh]>/gi)||[]).map(decode); const title=decode(link[2]); const text=cells.join(" | "); const dates=text.match(/20\d{2}[\/\-]\d{2}[\/\-]\d{2}/g)||[];
  rows.push({title,category:cells[1]||null,openDate:dates[0]||null,closingDate:dates[1]||null,buyer:cells.length?cells[cells.length-1]||null:null,url:href,externalId});
 } return rows;
}
function fitFor(title:string,category:string|null,detail:string){ const services=serviceMatches([title,category||"",detail].join(" ")); const score=Math.min(98,55+services.length*10+(regionMatch([title,category||"",detail].join(" "))?10:0)); const fitNote=services.length ? "Relevant service signals: "+services.join(", ")+". Review the source notice and attachments before bidding." : null; return {services,score,fitNote}; }
function responseInfo(detail:string){ const n=normalize(detail); const registrationRequired=/must be registered|registration is required|supplier registration|register as a supplier|must register/.test(n); let responseMode="formal_rfp"; if(/request for quotation|rfq|invitation to quote/.test(n)) responseMode="rfq"; if(/invitation to tender|itt|tender submission/.test(n)) responseMode="formal_tender"; if(/request for proposal|rfp|proposal submission/.test(n)) responseMode="formal_rfp"; if(registrationRequired) responseMode="registration_required"; return {responseMode,registrationRequired}; }
async function detailFor(url:string):Promise<string>{ try{const r=await fetch(url,{headers:{"User-Agent":"CBData-CanadaBuys-Scout/1.0"}}); return r.ok?cleanHtml(await r.text()):"";}catch{return "";}}

Deno.serve(async(req)=>{
 if(req.method!=="POST") return new Response("method_not_allowed",{status:405});
 const supabaseUrl=Deno.env.get("SUPABASE_URL"); const serviceRoleKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"); if(!supabaseUrl||!serviceRoleKey) return Response.json({error:"not_configured"},{status:500});
 const auth=req.headers.get("authorization")||""; const token=auth.startsWith("Bearer ")?auth.slice(7):""; const admin=createClient(supabaseUrl,serviceRoleKey);
 const {data:authUser,error:authError}=await admin.auth.getUser(token); if(authError||!authUser.user) return Response.json({error:"unauthorized"},{status:401});
 const body=await req.json().catch(()=>({})); const requestedWorkspace=typeof body.workspace_id==="string"?body.workspace_id:null;
 const {data:memberships}=await admin.from("workspace_memberships").select("workspace_id,role").eq("user_id",authUser.user.id).eq("status","active"); const workspace=(memberships||[]).find((m:any)=>!requestedWorkspace||m.workspace_id===requestedWorkspace); if(!workspace) return Response.json({error:"workspace_access_denied"},{status:403});
 const workspaceId=workspace.workspace_id; const {data:run, error:runError}=await admin.from("canadabuys_runs").insert({workspace_id:workspaceId,query:SEARCH_TERMS.join(", "),region:"Ottawa / National Capital Region"}).select("id").single(); if(runError||!run) return Response.json({error:runError?.message||"run_create_failed"},{status:500});
 let fetchedCount=0,errorCount=0; const candidates=new Map<string,any>();
 try{
  for(const term of SEARCH_TERMS){ const url=new URL("/en/tender-opportunities",BASE); url.searchParams.set("current_tab","c"); url.searchParams.set("items_per_page","50"); url.searchParams.set("words",term); url.searchParams.set("order","field_tender_closing_date"); url.searchParams.set("sort","asc"); try{const r=await fetch(url,{headers:{"User-Agent":"CBData-CanadaBuys-Scout/1.0"}}); if(!r.ok){errorCount++;continue;} for(const row of parseRows(await r.text())){fetchedCount++; if(isOpen(row.closingDate)) candidates.set(row.externalId,row);} }catch{errorCount++;} }
  let qualifyingCount=0,insertedCount=0,updatedCount=0,leadCreatedCount=0;
  const {data:orgRows}=await admin.from("organizations").select("id,legal_name,operating_name,organization_type").eq("workspace_id",workspaceId); const orgs:any[]=orgRows||[];
  for(const row of candidates.values()){
   const detail=await detailFor(row.url); const combined=[row.title,row.category||"",row.buyer||"",detail].join(" "); const services=serviceMatches(combined); if(!services.length||!regionMatch(combined)) continue; qualifyingCount++;
   const fit=fitFor(row.title,row.category,detail); const response=responseInfo(detail); const publishedDate=dateValue(row.openDate); const closingDate=dateValue(row.closingDate); const normalizedBuyer=normalize(row.buyer);
   let org=orgs.find(o=>normalize(o.legal_name)===normalizedBuyer||normalize(o.operating_name)===normalizedBuyer);
   if(!org&&row.buyer){ const {data:created}=await admin.from("organizations").insert({workspace_id:workspaceId,legal_name:row.buyer.replace(/[.]$/,"").trim(),operating_name:row.buyer.replace(/[.]$/,"").trim(),organization_type:"owner",status:"active",primary_region:"National Capital Region",source_notes:"Created by CanadaBuys prospecting; buyer identity sourced from CanadaBuys notice."}).select("id,legal_name,operating_name,organization_type").single(); if(created){org=created;orgs.push(created);} }
   const payload={workspace_id:workspaceId,source:SOURCE,external_id:row.externalId,title:row.title,buyer_name:row.buyer,category:row.category,region:"National Capital Region",published_date:publishedDate,closing_date:closingDate,source_url:row.url,raw_payload:{source:SOURCE,scout_version:"1.0",services,detail_excerpt:detail.slice(0,12000),observed_at:new Date().toISOString()},status:"new",matched_organization_id:org?.id||null,response_mode:response.responseMode,registration_required:response.registrationRequired,fit_score:fit.score,fit_note:fit.fitNote,last_verified_at:new Date().toISOString(),watch_query:services.join(", "),notes:[fit.fitNote,response.registrationRequired?"Registration prerequisite indicated by source notice.":null,"Formal response requirements must be verified against the live notice and attachments."].filter(Boolean).join(" "),updated_at:new Date().toISOString()};
   const {data:existing}=await admin.from("tender_records").select("id,lead_id").eq("workspace_id",workspaceId).eq("source",SOURCE).eq("external_id",row.externalId).maybeSingle();
   const {data:tender,error:tenderError}=await admin.from("tender_records").upsert(payload,{onConflict:"workspace_id,source,external_id"}).select("id,lead_id").single(); if(tenderError||!tender){errorCount++;continue;} if(existing) updatedCount++; else insertedCount++;
   if(!tender.lead_id){ const {data:lead}=await admin.from("leads").insert({workspace_id:workspaceId,organization_id:org?.id||null,source:SOURCE,lead_type:"tender",status:"new",region:"National Capital Region",score:fit.score,source_detail_table:"tender_records",source_detail_id:tender.id}).select("id").single(); if(lead?.id){leadCreatedCount++;await admin.from("tender_records").update({lead_id:lead.id}).eq("id",tender.id);} } else { await admin.from("leads").update({organization_id:org?.id||null,region:"National Capital Region",score:fit.score}).eq("id",tender.lead_id); }
  }
  await admin.from("canadabuys_runs").update({finished_at:new Date().toISOString(),status:"completed",fetched_count:fetchedCount,qualifying_count:qualifyingCount,inserted_count:insertedCount,updated_count:updatedCount,lead_created_count:leadCreatedCount,error_count:errorCount}).eq("id",run.id);
  return Response.json({ok:true,run_id:run.id,fetched_count:fetchedCount,qualifying_count:qualifyingCount,inserted_count:insertedCount,updated_count:updatedCount,lead_created_count:leadCreatedCount,error_count:errorCount});
 }catch(error){ await admin.from("canadabuys_runs").update({finished_at:new Date().toISOString(),status:"error",fetched_count:fetchedCount,error_count:errorCount+1,error_message:error instanceof Error?error.message:"unknown_error"}).eq("id",run.id); return Response.json({error:error instanceof Error?error.message:"scout_failed",run_id:run.id},{status:500}); }
});
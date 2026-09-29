import { createClient } from "https://esm.sh/@supabase/supabase-js@2.117.1";

const ROLE_TERMS:Record<string,string[]>={
 decision_maker:["president","owner","principal","chief","vice president","vp","executive director","director"],
 operations:["operations","facilities","facility","property manager","building manager","maintenance"],
 procurement:["procurement","purchasing","buyer","sourcing","contracts","supply chain"]
};
const PATHS=["","/team","/our-team","/about","/about-us","/leadership","/staff","/contact","/contact-us","/directory"];
const DIRECTORY_SOURCES=[
 {match:/city of ottawa/i,url:"https://ottawa.ca/en/business/procurement/contact-supply-services",label:"City of Ottawa Supply Services directory"},
 {match:/public services and procurement canada|pspc|spac/i,url:"https://geds-sage.gc.ca/en/GEDS/?dn=T1U9TkNSTy1PUkNOLE9VPVJQU0ItREdTSSxPVT1QU1BDLVNQQUMsTz1HQyxDPUNB&pgid=014",label:"Government Electronic Directory Services (GEDS)"},
 {match:/university of ottawa|uottawa/i,url:"https://www.uottawa.ca/about-us/administration-services",label:"University of Ottawa administration directory"},
 {match:/ottawa.carleton district school board|ocdsb/i,url:"https://www.ocdsb.ca/about-us/departments/supply-chain-management-department",label:"OCDSB Supply Chain Management"},
 {match:/ottawa.carleton district school board|ocdsb/i,url:"https://www.ocdsb.ca/about-us/departments",label:"OCDSB department directory"},
 {match:/ottawa catholic school board|ocsb/i,url:"https://www.ocsb.ca/our-board/departments/supply-chain-risk-management/",label:"OCSB Supply Chain and Risk Management"},
 {match:/ottawa catholic school board|ocsb/i,url:"https://www.ocsb.ca/our-board/executive-council/",label:"OCSB executive council"},
 {match:/ottawa catholic school board|ocsb/i,url:"https://www.ocsb.ca/our-board/departments/planning-and-facilities/",label:"OCSB Planning and Facilities"},
 {match:/national capital commission|\bncc\b|commission de la capitale nationale/i,url:"https://ncc-ccn.gc.ca/business/contracting-with-the-ncc",label:"NCC contracting and supplier information"}
];
function clean(s:string){return s.replace(/<script[\s\S]*?<\/script>/gi," ").replace(/<style[\s\S]*?<\/style>/gi," ").replace(/<[^>]+>/g," ").replace(/&nbsp;|&#160;/g," ").replace(/&amp;/g,"&").replace(/\s+/g," ").trim();}
function absolute(base:string,path:string){try{return new URL(path,base).toString()}catch{return null}}
function sameHost(a:string,b:string){try{return new URL(a).hostname.replace(/^www\./,"")===new URL(b).hostname.replace(/^www\./,"")}catch{return false}}
function hrefs(html:string,base:string){const out:string[]=[]; for(const m of html.matchAll(/href=["']([^"'#]+)["']/gi)){try{const u=new URL(m[1],base); if(sameHost(base,u.toString())&&!out.includes(u.toString()))out.push(u.toString())}catch{}} return out;}
const INVALID_NAME=/^(first name|last name|full name|your name|contact us|learn more|read more|property management|facility management|vice president|executive director|privacy policy|terms conditions|stay connected|canada administrative|administrative assistant)$/i;
function candidateFromPage(html:string,url:string,role:string){
 const text=clean(html); const terms=ROLE_TERMS[role]||[]; const lower=text.toLowerCase();
 for(const term of terms){
  let at=lower.indexOf(term);
  while(at>=0){
   const snippet=text.slice(Math.max(0,at-100),Math.min(text.length,at+220));
   const email=snippet.match(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i)?.[0]||null;
   const phone=snippet.match(/(?:\+?1[ .-]?)?\(?\d{3}\)?[ .-]\d{3}[ .-]\d{4}/)?.[0]||null;
   const names=[...snippet.matchAll(/\b([A-Z][a-zÀ-ÿ'’-]{1,30})\s+([A-Z][a-zÀ-ÿ'’-]{1,30})\b/g)]
      .map(m=>({name:m[0],index:m.index??0})).filter(x=>!INVALID_NAME.test(x.name.trim()) && !/^(First|Last|Full|Your|Contact|Learn|Read|Property|Facility|Privacy|Terms|Stay|Canada|Administrative)\b/i.test(x.name));
   const roleAt=Math.max(0,at-Math.max(0,at-100));
   names.sort((a,b)=>Math.abs(a.index-roleAt)-Math.abs(b.index-roleAt));
   const name=names.length?names[0].name:null;
   if(name && email) return {name,title:term,email,phone,url,snippet:snippet.slice(0,320)};
   at=lower.indexOf(term,at+term.length);
  }
 }
 return null;
}
Deno.serve(async(req)=>{
 if(req.method!=="POST") return new Response("method_not_allowed",{status:405});
 const url=Deno.env.get("SUPABASE_URL"),key=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
 if(!url||!key) return Response.json({error:"not_configured"},{status:500});
 const admin=createClient(url,key); const token=(req.headers.get("x-cbdata-cron-token")||"").trim();
 const {data:valid}=await admin.rpc("verify_procurement_scout_cron_token",{p_token:token});
 if(!valid) return Response.json({error:"unauthorized"},{status:401});
 const body=await req.json().catch(()=>({})); const workspaceId=String(body.workspace_id||"");
 if(!workspaceId) return Response.json({error:"workspace_required"},{status:400});
 await admin.rpc("refresh_contact_research_queue",{p_workspace:workspaceId});
 const {data:tasks,error}=await admin.from("contact_enrichment_tasks").select("*,organizations!contact_enrichment_tasks_organization_id_fkey(website,legal_name,operating_name)")
  .eq("workspace_id",workspaceId).in("status",["queued","researching","not_found"]).or("next_attempt_at.is.null,next_attempt_at.lte."+new Date().toISOString())
  .order("priority_score",{ascending:false}).limit(Math.min(20,Number(body.limit)||10));
 if(error) return Response.json({error:error.message},{status:500});
 const results:any[]=[];
 for(const task of tasks||[]){
  const org=(task as any).organizations||{}; const site=org.website; const orgName=String(org.operating_name||org.legal_name||"");
  let found:any=null; let pages=0; let evidenceLabel="Official organization website";
  for(const path of PATHS){
   const page=absolute(site,path); if(!page||!sameHost(site,page)) continue;
   try{const res=await fetch(page,{headers:{"User-Agent":"CBDataContactResearch/1.0 (+business-contact-enrichment)","Accept":"text/html"},redirect:"follow",signal:AbortSignal.timeout(8000)});
    if(!res.ok||!(res.headers.get("content-type")||"").includes("text/html"))continue; pages++; const html=(await res.text()).slice(0,600000); found=candidateFromPage(html,res.url,task.missing_role); if(found)break;
   }catch{/* retry other official paths */}
  }
  if(!found){
   const sources=DIRECTORY_SOURCES.filter(s=>s.match.test(orgName));
   for(const source of sources){
    try{
     const res=await fetch(source.url,{headers:{"User-Agent":"CBDataContactResearch/1.1 (+business-contact-enrichment)","Accept":"text/html"},redirect:"follow",signal:AbortSignal.timeout(8000)});
     if(!res.ok)continue; pages++; const html=(await res.text()).slice(0,800000); found=candidateFromPage(html,res.url,task.missing_role);
     if(!found && /geds-sage\.gc\.ca/i.test(res.url)){
      const people=hrefs(html,res.url).filter(u=>/pgid=015/i.test(u)).slice(0,12);
      for(const person of people){try{const pr=await fetch(person,{headers:{"User-Agent":"CBDataContactResearch/1.1 (+business-contact-enrichment)"},signal:AbortSignal.timeout(6000)}); if(!pr.ok)continue; pages++; found=candidateFromPage((await pr.text()).slice(0,300000),pr.url,task.missing_role); if(found)break}catch{}}
     }
     if(found){evidenceLabel=source.label;break}
    }catch{}
   }
  }
  if(found){
   await admin.from("contact_enrichment_tasks").update({status:"found",candidate_name:found.name,candidate_title:found.title,candidate_email:found.email,candidate_phone:found.phone,
    evidence_url:found.url,evidence_label:evidenceLabel,confidence:"high",last_attempt_at:new Date().toISOString(),attempt_count:task.attempt_count+1,last_error:null,
    researcher_metadata:{pages_checked:pages,evidence_snippet:found.snippet,method:evidenceLabel==="Official organization website"?"official_site_role_contact":"authoritative_public_directory",source_type:evidenceLabel}}).eq("id",task.id);
   const {data:contactId,error:promoteError}=await admin.rpc("promote_verified_contact_candidate",{p_task_id:task.id});
   results.push({task_id:task.id,status:promoteError?"found":"verified",contact_id:contactId||null,error:promoteError?.message||null});
  }else{
   const attempts=task.attempt_count+1; await admin.from("contact_enrichment_tasks").update({status:attempts>=3?"not_found":"queued",attempt_count:attempts,last_attempt_at:new Date().toISOString(),
    next_attempt_at:new Date(Date.now()+(attempts>=3?14:2)*86400000).toISOString(),last_error:"no high-confidence named contact on official or authoritative directory pages",researcher_metadata:{pages_checked:pages,method:"official_plus_authoritative_directory"}}).eq("id",task.id);
   results.push({task_id:task.id,status:"not_found"});
  }
 }
 return Response.json({ok:true,processed:results.length,results});
});
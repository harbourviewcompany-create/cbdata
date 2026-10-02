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

const USER_AGENT="CBDataContactResearch/1.2 (+business-contact-enrichment)";
const CONCURRENCY=4;
const FETCH_TIMEOUT_MS=6500;

function clean(s:string){
 return s.replace(/<script[\s\S]*?<\/script>/gi," ")
  .replace(/<style[\s\S]*?<\/style>/gi," ")
  .replace(/<[^>]+>/g," ")
  .replace(/&nbsp;|&#160;/g," ")
  .replace(/&amp;/g,"&")
  .replace(/\s+/g," ")
  .trim();
}
function absolute(base:string|undefined,path:string){
 try{return base?new URL(path,base).toString():null}catch{return null}
}
function sameHost(a:string|undefined,b:string){
 try{return Boolean(a)&&new URL(a!).hostname.replace(/^www\./,"")===new URL(b).hostname.replace(/^www\./,"")}catch{return false}
}
function hrefs(html:string,base:string){
 const out:string[]=[];
 for(const m of html.matchAll(/href=["']([^"'#]+)["']/gi)){
  try{
   const u=new URL(m[1],base);
   if(sameHost(base,u.toString())&&!out.includes(u.toString()))out.push(u.toString());
  }catch{}
 }
 return out;
}
const INVALID_NAME=/^(first name|last name|full name|your name|contact us|learn more|read more|property management|facility management|vice president|executive director|privacy policy|terms conditions|stay connected|canada administrative|administrative assistant)$/i;

function candidateFromPage(html:string,url:string,role:string){
 const text=clean(html);
 const terms=ROLE_TERMS[role]||[];
 const lower=text.toLowerCase();
 for(const term of terms){
  let at=lower.indexOf(term);
  while(at>=0){
   const snippet=text.slice(Math.max(0,at-100),Math.min(text.length,at+220));
   const email=snippet.match(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i)?.[0]||null;
   const phone=snippet.match(/(?:\+?1[ .-]?)?\(?\d{3}\)?[ .-]\d{3}[ .-]\d{4}/)?.[0]||null;
   const names=[...snippet.matchAll(/\b([A-Z][a-zÀ-ÿ'’-]{1,30})\s+([A-Z][a-zÀ-ÿ'’-]{1,30})\b/g)]
    .map(m=>({name:m[0],index:m.index??0}))
    .filter(x=>!INVALID_NAME.test(x.name.trim())&&!/^(First|Last|Full|Your|Contact|Learn|Read|Property|Facility|Privacy|Terms|Stay|Canada|Administrative)\b/i.test(x.name));
   const roleAt=Math.max(0,at-Math.max(0,at-100));
   names.sort((a,b)=>Math.abs(a.index-roleAt)-Math.abs(b.index-roleAt));
   const name=names.length?names[0].name:null;
   if(name&&email)return{name,title:term,email,phone,url,snippet:snippet.slice(0,320)};
   at=lower.indexOf(term,at+term.length);
  }
 }
 return null;
}

async function fetchHtml(url:string,maxBytes=600000){
 try{
  const res=await fetch(url,{
   headers:{"User-Agent":USER_AGENT,"Accept":"text/html"},
   redirect:"follow",
   signal:AbortSignal.timeout(FETCH_TIMEOUT_MS)
  });
  if(!res.ok||!(res.headers.get("content-type")||"").includes("text/html"))return null;
  return {html:(await res.text()).slice(0,maxBytes),url:res.url};
 }catch{return null}
}

async function researchTask(admin:any,task:any){
 const org=task.organizations||{};
 const site=org.website as string|undefined;
 const orgName=String(org.operating_name||org.legal_name||"");
 let found:any=null;
 let pages=0;
 let evidenceLabel="Official organization website";

 for(let i=0;i<PATHS.length&&!found;i+=3){
  const batch=PATHS.slice(i,i+3)
   .map(path=>absolute(site,path))
   .filter((page):page is string=>Boolean(page)&&sameHost(site,page!));
  const fetchedPages=await Promise.all(batch.map(page=>fetchHtml(page)));
  for(const fetched of fetchedPages){
   if(!fetched)continue;
   pages++;
   found=candidateFromPage(fetched.html,fetched.url,task.missing_role);
   if(found)break;
  }
 }

 if(!found){
  const sources=DIRECTORY_SOURCES.filter(s=>s.match.test(orgName));
  for(const source of sources){
   const fetched=await fetchHtml(source.url,800000);
   if(!fetched)continue;
   pages++;
   found=candidateFromPage(fetched.html,fetched.url,task.missing_role);

   if(!found&&/geds-sage\.gc\.ca/i.test(fetched.url)){
    const people=hrefs(fetched.html,fetched.url).filter(u=>/pgid=015/i.test(u)).slice(0,8);
    for(let i=0;i<people.length&&!found;i+=4){
     const personPages=await Promise.all(people.slice(i,i+4).map(person=>fetchHtml(person,300000)));
     for(const personPage of personPages){
      if(!personPage)continue;
      pages++;
      found=candidateFromPage(personPage.html,personPage.url,task.missing_role);
      if(found)break;
     }
    }
   }

   if(found){
    evidenceLabel=source.label;
    break;
   }
  }
 }

 const attemptedAt=new Date().toISOString();
 if(found){
  const {error:updateError}=await admin.from("contact_enrichment_tasks").update({
   status:"found",
   candidate_name:found.name,
   candidate_title:found.title,
   candidate_email:found.email,
   candidate_phone:found.phone,
   evidence_url:found.url,
   evidence_label:evidenceLabel,
   confidence:"high",
   last_attempt_at:attemptedAt,
   attempt_count:task.attempt_count+1,
   last_error:null,
   researcher_metadata:{
    pages_checked:pages,
    evidence_snippet:found.snippet,
    method:evidenceLabel==="Official organization website"?"official_site_role_contact":"authoritative_public_directory",
    source_type:evidenceLabel
   }
  }).eq("id",task.id);

  if(updateError)return{task_id:task.id,status:"error",error:updateError.message};

  const {data:contactId,error:promoteError}=await admin.rpc("promote_verified_contact_candidate",{p_task_id:task.id});
  return{
   task_id:task.id,
   status:promoteError?"found":"verified",
   contact_id:contactId||null,
   error:promoteError?.message||null,
   pages_checked:pages
  };
 }

 const attempts=task.attempt_count+1;
 const {error:updateError}=await admin.from("contact_enrichment_tasks").update({
  status:attempts>=3?"not_found":"queued",
  attempt_count:attempts,
  last_attempt_at:attemptedAt,
  next_attempt_at:new Date(Date.now()+(attempts>=3?14:2)*86400000).toISOString(),
  last_error:"no high-confidence named contact on official or authoritative directory pages",
  researcher_metadata:{pages_checked:pages,method:"official_plus_authoritative_directory"}
 }).eq("id",task.id);

 return{
  task_id:task.id,
  status:updateError?"error":"not_found",
  error:updateError?.message||null,
  pages_checked:pages
 };
}

Deno.serve(async(req)=>{
 if(req.method!=="POST")return new Response("method_not_allowed",{status:405});

 const url=Deno.env.get("SUPABASE_URL");
 const key=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
 if(!url||!key)return Response.json({error:"not_configured"},{status:500});

 const admin=createClient(url,key);
 const token=(req.headers.get("x-cbdata-cron-token")||"").trim();
 const {data:valid}=await admin.rpc("verify_procurement_scout_cron_token",{p_token:token});
 if(!valid)return Response.json({error:"unauthorized"},{status:401});

 const body=await req.json().catch(()=>({}));
 const workspaceId=String(body.workspace_id||"");
 if(!workspaceId)return Response.json({error:"workspace_required"},{status:400});

 await admin.rpc("refresh_contact_research_queue",{p_workspace:workspaceId});

 const requested=Math.max(1,Math.min(40,Number(body.limit)||20));
 const {data:tasks,error}=await admin
  .from("contact_enrichment_tasks")
  .select("*,organizations!contact_enrichment_tasks_organization_id_fkey(website,legal_name,operating_name)")
  .eq("workspace_id",workspaceId)
  .in("status",["queued","researching","not_found"])
  .or("next_attempt_at.is.null,next_attempt_at.lte."+new Date().toISOString())
  .order("research_priority_score",{ascending:false})
  .order("research_urgency_rank",{ascending:false})
  .order("priority_score",{ascending:false})
  .order("next_attempt_at",{ascending:true,nullsFirst:true})
  .limit(requested);

 if(error)return Response.json({error:error.message},{status:500});

 const selected=tasks||[];
 const results:any[]=[];
 for(let i=0;i<selected.length;i+=CONCURRENCY){
  const batch=selected.slice(i,i+CONCURRENCY);
  results.push(...await Promise.all(batch.map(task=>researchTask(admin,task))));
 }

 return Response.json({
  ok:true,
  requested,
  processed:results.length,
  verified:results.filter(r=>r.status==="verified").length,
  not_found:results.filter(r=>r.status==="not_found").length,
  errors:results.filter(r=>r.status==="error").length,
  results
 });
});

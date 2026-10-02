import { createClient } from "https://esm.sh/@supabase/supabase-js@2.117.1";

const ROLE_TERMS:Record<string,string[]>={
 decision_maker:[
  "president","owner","principal","chief","vice president","vp","executive director","director",
  "managing partner","managing director","general manager","broker of record","partner"
 ],
 operations:[
  "operations","director of operations","operations manager","facilities","facility","facilities manager",
  "facility manager","property manager","commercial property manager","building manager","building operator",
  "maintenance","construction manager","project manager","capital projects"
 ],
 procurement:[
  "procurement","purchasing","buyer","sourcing","strategic sourcing","contracts","contract manager",
  "supply chain","vendor management","estimating","estimator"
 ]
};

const PATHS=[
 "","/team","/our-team","/our-people","/people","/management","/leadership","/executive-team",
 "/about","/about-us","/who-we-are","/our-company","/staff","/staff-directory","/directory",
 "/contact","/contact-us","/property-management","/commercial-property-management","/facilities",
 "/operations","/procurement","/projects","/construction"
];

const LINK_KEYWORDS=[
 "team","people","staff","directory","leadership","management","manager","operations","facilities",
 "property","commercial","construction","project","procurement","purchasing","supply","contract",
 "estimating","contact","about","executive"
];
const DIRECTORY_SOURCES=[
 {match:/city of ottawa/i,url:"https://ottawa.ca/en/business/procurement/contact-supply-services",label:"City of Ottawa Supply Services directory"},
 {match:/public services and procurement canada|pspc|spac/i,url:"https://geds-sage.gc.ca/en/GEDS/?dn=T1U9TkNSTy1PUkNOLE9VPVJQU0ItREdTSSxPVT1QU1BDLVNQQUMsTz1HQyxDPUNB&pgid=014",label:"Government Electronic Directory Services (GEDS)"},
 {match:/university of ottawa|uottawa/i,url:"https://www.uottawa.ca/about-us/administration-services",label:"University of Ottawa administration directory"},
 {match:/ottawa.carleton district school board|ocdsb/i,url:"https://www.ocdsb.ca/about-us/departments/supply-chain-management-department",label:"OCDSB Supply Chain Management"},
 {match:/ottawa.carleton district school board|ocdsb/i,url:"https://www.ocdsb.ca/about-us/departments",label:"OCDSB department directory"},
 {match:/ottawa catholic school board|ocsb/i,url:"https://www.ocsb.ca/our-board/departments/supply-chain-risk-management/",label:"OCSB Supply Chain and Risk Management"},
 {match:/ottawa catholic school board|ocsb/i,url:"https://www.ocsb.ca/our-board/executive-council/",label:"OCSB executive council"},
 {match:/ottawa catholic school board|ocsb/i,url:"https://www.ocsb.ca/our-board/departments/planning-and-facilities/",label:"OCSB Planning and Facilities"},
 {match:/national capital commission|\bncc\b|commission de la capitale nationale/i,url:"https://ncc-ccn.gc.ca/business/contracting-with-the-ncc",label:"NCC contracting and supplier information"},
 {match:/certapro painters of ottawa/i,url:"https://certapro.com/ottawa/our-team/dipkumar-patel/",label:"CertaPro Ottawa operations leadership profile"}
];
const VERIFIED_PERSON_SOURCES=[
 {
  match:/fiore corp renovations/i,
  roles:["decision_maker","operations"],
  url:"https://fiorecorprenovations.ca/about",
  label:"Fiore Corp official owner profile",
  name:"Brian Fiore",
  title:"Owner & Operator / Founder & Lead Project Manager",
  verified_email:"brian@fiorecorprenovations.com",
  verified_phone:"613-327-4466",
  verified_at:"2026-10-02"
 },
 {
  match:/certapro painters of ottawa/i,
  roles:["decision_maker","operations"],
  url:"https://certapro.com/ottawa/our-team/dipkumar-patel/",
  label:"CertaPro Ottawa official operations leadership profile",
  name:"Dipkumar Patel",
  title:"Co-Owner & Operations Manager"
 }
] as const;

const USER_AGENT="CBDataContactResearch/1.3 (+business-contact-enrichment)";
const CONCURRENCY=4;
const FETCH_TIMEOUT_MS=4500;

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
function prioritizedLinks(html:string,base:string){
 return hrefs(html,base)
  .map(url=>{
   let score=0;
   const token=url.toLowerCase();
   for(const keyword of LINK_KEYWORDS) if(token.includes(keyword)) score+=1;
   return {url,score};
  })
  .filter(x=>x.score>0)
  .sort((a,b)=>b.score-a.score)
  .map(x=>x.url);
}
const INVALID_NAME=/^(first name|last name|full name|your name|contact us|learn more|read more|property management|facility management|vice president|executive director|privacy policy|terms conditions|stay connected|canada administrative|administrative assistant)$/i;

function normalizeToken(v:string){
 return v.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"").replace(/[^a-z0-9]+/g," ").trim();
}
function emailMatchesName(name:string,email:string){
 const local=normalizeToken(email.split("@")[0]||"").replaceAll(" ","");
 const parts=normalizeToken(name).split(" ").filter(p=>p.length>=3);
 return parts.some(part=>local.includes(part));
}
function isGenericMailbox(email:string){
 const local=normalizeToken(email.split("@")[0]||"").replaceAll(" ","");
 return /^(info|contact|hello|office|admin|administration|reception|leasing|rentals|sales|support|service|services|operations|facilities|maintenance|propertymanagement|projectmanagement|procurement|purchasing|estimating|careers|jobs|accounts|accounting|ap|ar|corporaterecords|records|communications|marketing|hr|humanresources)$/.test(local);
}
const NON_PERSON_NAME=/\b(corporate|records|department|services?|management|office|team|support|facilit(?:y|ies)|leasing|procurement|purchasing|maintenance|construction|property|properties|company|group|administration|administrative|communications?|marketing|sales|careers?|resources?|reception|information|president|director|manager|chief|owner|partner|vice)\b/i;
function looksLikePersonName(name:string){
 const parts=name.trim().split(/\s+/).filter(Boolean);
 return parts.length>=2 && parts.length<=4 && !NON_PERSON_NAME.test(name);
}
function structuredText(html:string){
 return html
  .replace(/\\u0040/gi,"@")
  .replace(/\\u002e/gi,".")
  .replace(/&#64;|&commat;/gi,"@")
  .replace(/&period;/gi,".")
  .replace(/<[^>]+>/g," ")
  .replace(/\\n|\\r|\\t/g," ")
  .replace(/\\["']/g," ")
  .replace(/\s+/g," ")
  .trim();
}
function verifiedNamedProfile(html:string,url:string,name:string,title:string){
 const visible=clean(html);
 const structured=structuredText(html);
 const lower=normalizeToken(visible+" "+structured);
 const nameToken=normalizeToken(name);
 const titleWords=normalizeToken(title).split(" ").filter(w=>w.length>=4);
 if(!looksLikePersonName(name) || !lower.includes(nameToken) || !titleWords.some(word=>lower.includes(word))) return null;
 return {name,title,url,snippet:(name+" — "+title).slice(0,320)};
}
function matchingNamedEmail(html:string,url:string,name:string){
 const visible=clean(html);
 const structured=structuredText(html);
 const corpus=visible+" "+structured;
 const emails=Array.from(new Set(
  [...corpus.matchAll(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi)].map(m=>m[0])
 ));
 const email=emails.find(e=>!isGenericMailbox(e)&&emailMatchesName(name,e))||null;
 if(!email)return null;
 const phone=corpus.match(/(?:\+?1[ .-]?)?\(?\d{3}\)?[ .-]\d{3}[ .-]\d{4}/)?.[0]||null;
 return {email,phone,url};
}

function candidateFromMailtoPage(html:string,url:string,role:string){
 const terms=ROLE_TERMS[role]||[];
 for(const m of html.matchAll(/href=["']mailto:([^"'?]+)(?:\?[^"']*)?["']/gi)){
  const email=decodeURIComponent(m[1]||"").trim();
  if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))continue;
  const at=m.index??0;
  const snippet=clean(html.slice(Math.max(0,at-900),Math.min(html.length,at+900)));
  const lower=snippet.toLowerCase();
  const title=terms.find(term=>lower.includes(term))||null;
  if(!title)continue;
  const names=[...snippet.matchAll(/\b([A-Z][a-zÀ-ÿ'’-]{1,30})\s+([A-Z][a-zÀ-ÿ'’-]{1,30})\b/g)]
   .map(match=>match[0])
   .filter(name=>!INVALID_NAME.test(name.trim())&&!/^(First|Last|Full|Your|Contact|Learn|Read|Property|Facility|Privacy|Terms|Stay|Canada|Administrative)\b/i.test(name));
  if(isGenericMailbox(email))continue;
  const name=names.find(n=>looksLikePersonName(n)&&emailMatchesName(n,email))||null;
  const phone=snippet.match(/(?:\+?1[ .-]?)?\(?\d{3}\)?[ .-]\d{3}[ .-]\d{4}/)?.[0]||null;
  if(name)return{name,title,email,phone,url,snippet:snippet.slice(0,320)};
 }
 return null;
}

type ContactCandidate={
 name:string;
 title:string;
 email:string;
 phone:string|null;
 url:string;
 snippet:string;
};

function contactCandidatesFromPage(html:string,url:string,role:string){
 const terms=ROLE_TERMS[role]||[];
 const text=clean(html);
 const out=new Map<string,ContactCandidate>();

 const consider=(email:string,snippet:string)=>{
  const normalized=email.trim().toLowerCase();
  if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalized)||isGenericMailbox(normalized))return;
  const lower=snippet.toLowerCase();
  const title=terms.find(term=>lower.includes(term));
  if(!title)return;
  const names=[...snippet.matchAll(/\b([A-Z][a-zÀ-ÿ'’-]{1,30})\s+([A-Z][a-zÀ-ÿ'’-]{1,30})\b/g)]
   .map(match=>match[0])
   .filter(name=>looksLikePersonName(name)&&!INVALID_NAME.test(name.trim()));
  const name=names.find(candidate=>emailMatchesName(candidate,normalized));
  if(!name)return;
  const phone=snippet.match(/(?:\+?1[ .-]?)?\(?\d{3}\)?[ .-]\d{3}[ .-]\d{4}/)?.[0]||null;
  out.set(normalized,{name,title,email:normalized,phone,url,snippet:snippet.slice(0,320)});
 };

 for(const m of text.matchAll(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi)){
  const at=m.index??0;
  consider(m[0],text.slice(Math.max(0,at-450),Math.min(text.length,at+450)));
 }

 for(const m of html.matchAll(/href=["']mailto:([^"'?]+)(?:\?[^"']*)?["']/gi)){
  const at=m.index??0;
  consider(decodeURIComponent(m[1]||""),clean(html.slice(Math.max(0,at-900),Math.min(html.length,at+900))));
 }

 return [...out.values()];
}

async function persistAdditionalCandidates(admin:any,task:any,candidates:ContactCandidate[],sourceLabel:string,primaryEmail:string){
 const extras=candidates
  .filter(candidate=>candidate.email.toLowerCase()!==primaryEmail.toLowerCase())
  .slice(0,6);
 const contactIds:string[]=[];

 for(const candidate of extras){
  const parts=candidate.name.trim().split(/\s+/);
  const first=parts.shift()||"";
  const last=parts.join(" ");
  if(!first||!last)continue;

  const {data:existing,error:lookupError}=await admin
   .from("contacts")
   .select("id,job_title,email,phone,source_url,source_label,source_confidence,source_verified_at")
   .eq("workspace_id",task.workspace_id)
   .ilike("email",candidate.email)
   .limit(1)
   .maybeSingle();
  if(lookupError)continue;

  let contactId=existing?.id as string|undefined;
  if(!contactId){
   const {data:inserted,error:insertError}=await admin
    .from("contacts")
    .insert({
     workspace_id:task.workspace_id,
     first_name:first,
     last_name:last,
     job_title:candidate.title,
     email:candidate.email,
     phone:candidate.phone,
     status:"active",
     source_url:candidate.url,
     source_label:sourceLabel,
     source_confidence:"high",
     source_verified_at:new Date().toISOString()
    })
    .select("id")
    .single();
   if(insertError)continue;
   contactId=inserted.id;
  }else{
   await admin.from("contacts").update({
    job_title:existing.job_title||candidate.title,
    phone:existing.phone||candidate.phone,
    source_url:existing.source_url||candidate.url,
    source_label:existing.source_label||sourceLabel,
    source_confidence:"high",
    source_verified_at:existing.source_verified_at||new Date().toISOString(),
    updated_at:new Date().toISOString()
   }).eq("id",contactId);
  }

  const {data:existingLink}=await admin
   .from("organization_contacts")
   .select("id")
   .eq("workspace_id",task.workspace_id)
   .eq("organization_id",task.organization_id)
   .eq("contact_id",contactId)
   .limit(1)
   .maybeSingle();

  let linkError:any=null;
  if(!existingLink){
   const link=await admin.from("organization_contacts").insert({
    workspace_id:task.workspace_id,
    organization_id:task.organization_id,
    contact_id:contactId,
    relationship_type:task.missing_role,
    is_primary:false
   });
   linkError=link.error;
  }
  if(!linkError)contactIds.push(contactId);
 }

 return contactIds;
}

function candidateFromPage(html:string,url:string,role:string){
 const text=clean(html);
 const terms=ROLE_TERMS[role]||[];
 const lower=text.toLowerCase();
 for(const term of terms){
  let at=lower.indexOf(term);
  while(at>=0){
   const snippet=text.slice(Math.max(0,at-100),Math.min(text.length,at+220));
   const nearbyEmail=snippet.match(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i)?.[0]||null;
   const phone=snippet.match(/(?:\+?1[ .-]?)?\(?\d{3}\)?[ .-]\d{3}[ .-]\d{4}/)?.[0]||null;
   const names=[...snippet.matchAll(/\b([A-Z][a-zÀ-ÿ'’-]{1,30})\s+([A-Z][a-zÀ-ÿ'’-]{1,30})\b/g)]
    .map(m=>({name:m[0],index:m.index??0}))
    .filter(x=>!INVALID_NAME.test(x.name.trim())&&!/^(First|Last|Full|Your|Contact|Learn|Read|Property|Facility|Privacy|Terms|Stay|Canada|Administrative)\b/i.test(x.name));
   const roleAt=Math.max(0,at-Math.max(0,at-100));
   names.sort((a,b)=>Math.abs(a.index-roleAt)-Math.abs(b.index-roleAt));
   const name=names.find(x=>looksLikePersonName(x.name))?.name||null;
   const pageEmails=Array.from(new Set(
    [...text.matchAll(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi)].map(m=>m[0])
   ));
   const matchedEmail=name?pageEmails.find(e=>!isGenericMailbox(e)&&emailMatchesName(name,e))||null:null;
   const nearbyNamedEmail=name&&nearbyEmail&&!isGenericMailbox(nearbyEmail)&&emailMatchesName(name,nearbyEmail)
    ?nearbyEmail:null;
   const email=nearbyNamedEmail||matchedEmail;
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
 let verifiedProfileMatched=false;
 let verifiedEmailMatched=false;
 let verifiedCuratedSourceUsed=false;
 let verifiedSourcePages=0;
 const harvested=new Map<string,ContactCandidate>();
 const capture=(html:string,url:string)=>{
  for(const candidate of contactCandidatesFromPage(html,url,task.missing_role)){
   harvested.set(candidate.email.toLowerCase(),candidate);
  }
 };

 const verifiedSources=VERIFIED_PERSON_SOURCES.filter(source=>
  source.match.test(orgName) && source.roles.includes(task.missing_role)
 );
 for(const source of verifiedSources){
  const fetched=await fetchHtml(source.url,500000);
  if(!fetched)continue;
  pages++;
  verifiedSourcePages++;
  capture(fetched.html,fetched.url);
  const profile=verifiedNamedProfile(fetched.html,fetched.url,source.name,source.title);
  if(!profile){
   if("verified_email" in source
      && typeof source.verified_email==="string"
      && emailMatchesName(source.name,source.verified_email)){
    verifiedCuratedSourceUsed=true;
    found={
     name:source.name,
     title:source.title,
     email:source.verified_email,
     phone:"verified_phone" in source?source.verified_phone:null,
     url:source.url,
     snippet:(
      source.name+" — "+source.title+" — curated from reachable official profile"+
      ("verified_at" in source?" — verified "+source.verified_at:"")
     ).slice(0,320)
    };
    evidenceLabel=source.label+" — curated verified official contact";
    break;
   }
   continue;
  }
  verifiedProfileMatched=true;

  let matched=matchingNamedEmail(fetched.html,fetched.url,source.name);
  if(!matched){
   const base=site||fetched.url;
   const emailPages=new Set<string>();
   for(const path of PATHS.slice(0,14)){
    const page=absolute(base,path);
    if(page&&sameHost(base,page))emailPages.add(page);
   }
   for(const page of prioritizedLinks(fetched.html,fetched.url).slice(0,12)){
    if(sameHost(base,page))emailPages.add(page);
   }
   for(const page of [...emailPages].slice(0,16)){
    if(page===fetched.url)continue;
    const candidatePage=await fetchHtml(page,400000);
    if(!candidatePage)continue;
    pages++;
    capture(candidatePage.html,candidatePage.url);
    matched=matchingNamedEmail(candidatePage.html,candidatePage.url,source.name);
    if(matched)break;
   }
  }

  if(matched){
   verifiedEmailMatched=true;
   found={
    name:source.name,
    title:source.title,
    email:matched.email,
    phone:matched.phone,
    url:profile.url,
    snippet:(profile.snippet+" — email verified at "+matched.url).slice(0,320)
   };
   evidenceLabel=source.label+" + matching official email";
   break;
  }
 }

 const discoveredLinks=new Set<string>();
 for(const path of PATHS){
  if(found)break;
  const page=absolute(site,path);
  if(!page||!sameHost(site,page))continue;
  const fetched=await fetchHtml(page);
  if(!fetched)continue;
  pages++;
  capture(fetched.html,fetched.url);
  for(const link of prioritizedLinks(fetched.html,fetched.url).slice(0,16)) discoveredLinks.add(link);
  found=candidateFromMailtoPage(fetched.html,fetched.url,task.missing_role)
    ||candidateFromPage(fetched.html,fetched.url,task.missing_role);
  if(found)break;
 }

 if(!found&&discoveredLinks.size){
  for(const page of [...discoveredLinks].slice(0,12)){
   const fetched=await fetchHtml(page,500000);
   if(!fetched)continue;
   pages++;
   capture(fetched.html,fetched.url);
   found=candidateFromMailtoPage(fetched.html,fetched.url,task.missing_role)
    ||candidateFromPage(fetched.html,fetched.url,task.missing_role);
   if(found)break;
  }
 }

 if(!found){
  const sources=DIRECTORY_SOURCES.filter(s=>s.match.test(orgName));
  for(const source of sources){
   const fetched=await fetchHtml(source.url,800000);
   if(!fetched)continue;
   pages++;
   capture(fetched.html,fetched.url);
   found=candidateFromMailtoPage(fetched.html,fetched.url,task.missing_role)
    ||candidateFromPage(fetched.html,fetched.url,task.missing_role);

   if(!found&&/geds-sage\.gc\.ca/i.test(fetched.url)){
    const people=hrefs(fetched.html,fetched.url).filter(u=>/pgid=015/i.test(u)).slice(0,8);
    for(const person of people){
     const personPage=await fetchHtml(person,300000);
     if(!personPage)continue;
     pages++;
     capture(personPage.html,personPage.url);
     found=candidateFromMailtoPage(personPage.html,personPage.url,task.missing_role)
      ||candidateFromPage(personPage.html,personPage.url,task.missing_role);
     if(found)break;
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
  let additionalContactIds:string[]=[];
  if(!promoteError&&contactId){
   additionalContactIds=await persistAdditionalCandidates(
    admin,
    task,
    [...harvested.values()],
    evidenceLabel,
    found.email
   );
  }
  let draftId:string|null=null;
  let draftError:string|null=null;
  if(!promoteError&&contactId){
   const {data,error}=await admin.rpc("prepare_work_lead_draft",{
    p_task_id:task.id,
    p_contact_id:contactId
   });
   draftId=data||null;
   draftError=error?.message||null;
  }
  return{
   task_id:task.id,
   status:promoteError?"found":"verified",
   contact_id:contactId||null,
   draft_id:draftId,
   draft_error:draftError,
   additional_contacts:additionalContactIds.length,
   additional_contact_ids:additionalContactIds,
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
  researcher_metadata:{
   pages_checked:pages,
   method:"official_plus_authoritative_directory",
   verified_profile_matched:verifiedProfileMatched,
   verified_email_matched:verifiedEmailMatched,
   verified_curated_source_used:verifiedCuratedSourceUsed,
   verified_source_pages:verifiedSourcePages
  }
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

 const requested=Math.max(1,Math.min(8,Number(body.limit)||8));
 const taskIds=Array.isArray(body.task_ids)
  ?Array.from(new Set(body.task_ids.filter((id:unknown)=>typeof id==="string"&&id.length>0))).slice(0,8)
  :[];

 let taskQuery=admin
  .from("contact_enrichment_tasks")
  .select("*,organizations!contact_enrichment_tasks_organization_id_fkey(website,legal_name,operating_name)")
  .eq("workspace_id",workspaceId)
  .in("status",["queued","researching","not_found"]);

 if(taskIds.length){
  taskQuery=taskQuery.in("id",taskIds);
 }else{
  taskQuery=taskQuery
   .or("next_attempt_at.is.null,next_attempt_at.lte."+new Date().toISOString())
   .order("attempt_count",{ascending:true})
   .order("research_priority_score",{ascending:false})
   .order("research_urgency_rank",{ascending:false})
   .order("priority_score",{ascending:false})
   .order("next_attempt_at",{ascending:true,nullsFirst:true});
 }

 const {data:tasks,error}=await taskQuery.limit(taskIds.length||requested);
 if(error)return Response.json({error:error.message},{status:500});

 const selected=tasks||[];
 const results:any[]=[];
 for(let i=0;i<selected.length;i+=CONCURRENCY){
  const batch=selected.slice(i,i+CONCURRENCY);
  results.push(...await Promise.all(batch.map(task=>researchTask(admin,task))));
 }

 return Response.json({
  ok:true,
  requested:taskIds.length||requested,
  targeted:taskIds.length>0,
  processed:results.length,
  verified:results.filter(r=>r.status==="verified").length,
  additional_contacts:results.reduce((sum,r)=>sum+Number(r.additional_contacts||0),0),
  not_found:results.filter(r=>r.status==="not_found").length,
  errors:results.filter(r=>r.status==="error").length,
  results
 });
});

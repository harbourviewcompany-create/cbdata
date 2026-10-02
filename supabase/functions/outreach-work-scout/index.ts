import { createClient } from "https://esm.sh/@supabase/supabase-js@2.117.1";

type LeadInput={
  source_key:string; external_id:string; source_label:string; buyer_name:string;
  opportunity_title:string; opportunity_type:string; response_mode:string;
  description?:string|null; region?:string|null; source_url:string;
  contact_name?:string|null; contact_email?:string|null; contact_phone?:string|null;
  published_at?:string|null; deadline_at?:string|null; service_fit:string[];
  fit_score:number; speed_score:number; conversion_score:number; raw_payload?:Record<string,unknown>;
};

const MBC_CURRENT="https://mbc.ca/current-tenders/";
const NETWORKS=[
  {
    source_key:"dynamic_building_subcontractors",
    source_label:"Dynamic Building Improvements — Trusted Subcontractors",
    buyer_name:"Dynamic Building Improvements Inc.",
    opportunity_title:"Become a trusted subcontractor for Ottawa/Gatineau restoration and rebuild work",
    opportunity_type:"subcontractor_network",
    response_mode:"subcontractor_application",
    source_url:"https://www.dynamicbuilding.ca/careers",
    region:"Ottawa / Gatineau",
    contact_email:"info@dynamicbuilding.ca",
    contact_phone:"613-746-9888",
    service_fit:["renovation & general contracting","painting & finishes","roofing & envelope","sheet metal & ductwork"],
    fit_score:91,speed_score:92,conversion_score:92,
    required:["subcontractor","steady work","ottawa"]
  },
  {
    source_key:"fiore_subcontractors",
    source_label:"Fiore Corp Renovations — Subcontractor Work",
    buyer_name:"Fiore Corp Renovations",
    opportunity_title:"Apply for recurring subcontractor renovation work in Ottawa",
    opportunity_type:"subcontractor_network",
    response_mode:"subcontractor_application",
    source_url:"https://fiorecorprenovations.ca/join-the-team",
    region:"Ottawa, Ontario",
    contact_email:"brian@fiorecorprenovations.com",
    contact_phone:"613-327-4466",
    service_fit:["renovation & general contracting","painting & finishes"],
    fit_score:84,speed_score:88,conversion_score:86,
    required:["subcontractor","ottawa"]
  },
  {
    source_key:"omsg_service_network",
    source_label:"Ottawa Multiservices Group — Service Network",
    buyer_name:"Ottawa Multiservices Group",
    opportunity_title:"Join Ottawa service network for repairs, renovations, landscaping, snow and recurring work",
    opportunity_type:"vendor_network",
    response_mode:"vendor_registration",
    source_url:"https://www.ottawamultiservicesgroup.com/partners",
    region:"Ottawa / Gatineau",
    contact_email:null,
    contact_phone:null,
    service_fit:["facility maintenance","renovation & general contracting","landscaping & grounds","snow & ice","janitorial & cleaning"],
    fit_score:80,speed_score:82,conversion_score:78,
    required:["service network","small repairs","snow removal"]
  },
  {
    source_key:"machaalani_subcontractors",
    source_label:"Machaalani Landscaping & Contracting — Subcontractors",
    buyer_name:"Machaalani Landscaping and Contracting",
    opportunity_title:"Become a subcontractor for Ottawa landscaping, concrete, excavation and site work",
    opportunity_type:"subcontractor_network",
    response_mode:"subcontractor_application",
    source_url:"https://www.machaalani.ca/",
    region:"Ottawa, Ontario",
    contact_email:"ali.machaalani@gmail.com",
    contact_phone:"613-252-4190",
    service_fit:["landscaping & grounds","site & civil","renovation & general contracting"],
    fit_score:86,speed_score:88,conversion_score:87,
    required:["become a subcontractor","ottawa"]
  },
  {
    source_key:"certapro_ottawa_subcontractors",
    source_label:"CertaPro Painters Ottawa — Independent Contractor",
    buyer_name:"CertaPro Painters of Ottawa",
    opportunity_title:"Exterior painting subcontractor / independent contractor work across Ottawa",
    opportunity_type:"subcontractor_network",
    response_mode:"subcontractor_application",
    source_url:"https://certapro-painters-ottawa-on.careerplug.com/jobs/1951264/apps/new",
    region:"Ottawa, Ontario",
    contact_email:null,
    contact_phone:"613-255-8068",
    service_fit:["painting & finishes","facility maintenance"],
    fit_score:82,speed_score:92,conversion_score:84,
    required:["independent contractor","ottawa","partners"]
  },
  {
    source_key:"613painting_subcontractors",
    source_label:"613PAINTING — Subcontractor Application",
    buyer_name:"613PAINTING",
    opportunity_title:"Apply for painting and repair subcontract work in Ottawa",
    opportunity_type:"subcontractor_network",
    response_mode:"subcontractor_application",
    source_url:"https://613painting.com/join-our-team/",
    region:"Ottawa, Ontario",
    contact_email:"info@613painting.com",
    contact_phone:"613-618-3217",
    service_fit:["painting & finishes","renovation & general contracting"],
    fit_score:80,speed_score:88,conversion_score:82,
    required:["subcontractor","wsib","hst"]
  },
  {
    source_key:"mbc_trade_registration",
    source_label:"McDonald Brothers Construction — Trade Contractor List",
    buyer_name:"McDonald Brothers Construction Inc.",
    opportunity_title:"Register CB Contracting on MBC's trade contractor list for ongoing tender invitations",
    opportunity_type:"subcontractor_network",
    response_mode:"vendor_registration",
    source_url:"https://mbc.ca/trade-registration-form/",
    region:"Ottawa / Eastern Ontario",
    contact_email:"tenders@mbc.ca",
    contact_phone:"613-831-6223",
    service_fit:["sheet metal & ductwork","metals & fabrication","roofing & envelope","painting & finishes","site & civil","landscaping & grounds"],
    fit_score:95,speed_score:88,conversion_score:94,
    required:["trade contractor","sub-contractors"]
  }
] as const;

const FIT_RULES=[
  {label:"sheet metal & ductwork",weight:32,terms:["sheet metal","ductwork","duct work","metal flashing","metal cladding","metal siding","siding","louvers","soffit","fascia","eavestrough","gutter"]},
  {label:"metals & fabrication",weight:30,terms:["structural steel","steel fabrication","metal fabrication","welding","misc. metals","miscellaneous metals","metal stairs","metal railing"]},
  {label:"roofing & envelope",weight:25,terms:["roofing","roof replacement","roof repair","waterproofing","building envelope","cladding","sealants","expansion joints"]},
  {label:"hvac & mechanical",weight:24,terms:["hvac","ventilation","air handling","exhaust","mechanical"]},
  {label:"renovation & general contracting",weight:18,terms:["renovation","fit-up","fit up","general contractor","demolition","carpentry","millwork"]},
  {label:"painting & finishes",weight:16,terms:["painting","drywall","ceilings","flooring","ceramic","resilient flooring"]},
  {label:"site & civil",weight:16,terms:["asphalt","sidewalk","concrete","fencing","site services","excavation"]},
  {label:"landscaping & grounds",weight:24,terms:["landscaping","grounds","grass","lawn"]},
  {label:"snow & ice",weight:26,terms:["snow","ice control","salting"]},
  {label:"janitorial & cleaning",weight:22,terms:["cleaning","janitorial","custodial"]},
  {label:"facility maintenance",weight:22,terms:["maintenance","repair","restoration","rebuild"]}
] as const;

function cleanHtml(v:string){
  return v.replace(/<script[\s\S]*?<\/script>/gi," ")
    .replace(/<style[\s\S]*?<\/style>/gi," ")
    .replace(/<[^>]+>/g," ")
    .replace(/&nbsp;/gi," ").replace(/&amp;/gi,"&").replace(/&quot;/gi,'"')
    .replace(/&#39;/gi,"'").replace(/&#8211;/gi,"–").replace(/&#8212;/gi,"—").replace(/\s+/g," ").trim();
}
function normalize(v:string){return v.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"").replace(/[^a-z0-9]+/g," ").trim();}
function classify(text:string){
  const n=normalize(text),services:string[]=[];let score=28;
  for(const rule of FIT_RULES){
    if(rule.terms.some(t=>n.includes(normalize(t)))){
      services.push(rule.label);score+=rule.weight;
    }
  }
  return {service_fit:Array.from(new Set(services)),fit_score:Math.max(0,Math.min(98,score))};
}
function deadlineScore(deadline:string|null){
  if(!deadline)return 72;
  const days=(new Date(deadline).getTime()-Date.now())/86400000;
  if(days<0)return 0;if(days<=3)return 68;if(days<=14)return 92;if(days<=35)return 82;return 68;
}
function conversionScore(fit:number,speed:number,direct:boolean){
  return Math.max(0,Math.min(100,Math.round(fit*.68+speed*.22+(direct?10:0))));
}
function monthDate(text:string):string|null{
  const m=text.match(/\b(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(20\d{2})\b/i);
  if(!m)return null;
  const d=new Date(`${m[1]} ${m[2]}, ${m[3]} 15:00:00 GMT-0400`);
  return Number.isNaN(d.getTime())?null:d.toISOString();
}
async function fetchText(url:string){
  const c=new AbortController(),timer=setTimeout(()=>c.abort(),20000);
  try{
    const r=await fetch(url,{headers:{"User-Agent":"CBData-Outreach-Work-Scout/1.0"},signal:c.signal});
    if(!r.ok)throw new Error(`http_${r.status}`);
    return await r.text();
  }finally{clearTimeout(timer);}
}

Deno.serve(async(req)=>{
  if(req.method!=="POST")return new Response("method_not_allowed",{status:405});
  const supabaseUrl=Deno.env.get("SUPABASE_URL");
  const serviceRoleKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if(!supabaseUrl||!serviceRoleKey)return Response.json({error:"not_configured"},{status:500});

  const admin=createClient(supabaseUrl,serviceRoleKey);
  const token=(req.headers.get("authorization")||"").replace(/^Bearer\s+/,"");
  const cronToken=req.headers.get("x-cbdata-cron-token")||"";
  const body=await req.json().catch(()=>({}));
  const requestedWorkspace=typeof body.workspace_id==="string"?body.workspace_id:null;
  let workspaceId:string|null=null;

  if(cronToken){
    const {data:allowed,error}=await admin.rpc("verify_procurement_scout_cron_token",{p_token:cronToken});
    if(error||allowed!==true)return Response.json({error:"unauthorized_cron"},{status:401});
    if(!requestedWorkspace)return Response.json({error:"workspace_required"},{status:400});
    const {data:workspace}=await admin.from("workspaces").select("id").eq("id",requestedWorkspace).eq("status","active").maybeSingle();
    if(!workspace)return Response.json({error:"workspace_not_active"},{status:404});
    workspaceId=workspace.id;
  }else{
    const {data:userData,error:userError}=await admin.auth.getUser(token);
    if(userError||!userData.user)return Response.json({error:"unauthorized"},{status:401});
    const {data:memberships}=await admin.from("workspace_memberships").select("workspace_id").eq("user_id",userData.user.id).eq("status","active");
    const membership=(memberships||[]).find((m:any)=>!requestedWorkspace||m.workspace_id===requestedWorkspace);
    if(!membership)return Response.json({error:"workspace_access_denied"},{status:403});
    workspaceId=membership.workspace_id;
  }
  if(!workspaceId)return Response.json({error:"workspace_unresolved"},{status:400});

  const observedAt=new Date().toISOString();
  const leads:LeadInput[]=[];
  const sourceResults:any[]=[];

  for(const source of NETWORKS){
    try{
      const html=await fetchText(source.source_url);
      const text=normalize(cleanHtml(html));
      const missing=source.required.filter(term=>!text.includes(normalize(term)));
      if(missing.length===source.required.length)throw new Error("expected_source_markers_missing");
      leads.push({
        source_key:source.source_key,external_id:"standing-network",source_label:source.source_label,
        buyer_name:source.buyer_name,opportunity_title:source.opportunity_title,
        opportunity_type:source.opportunity_type,response_mode:source.response_mode,
        description:"Verified standing contractor/service network page observed by CBData.",
        region:source.region,source_url:source.source_url,contact_email:source.contact_email,
        contact_phone:source.contact_phone,service_fit:[...source.service_fit],
        fit_score:source.fit_score,speed_score:source.speed_score,conversion_score:source.conversion_score,
        raw_payload:{observed_at:observedAt,source_kind:"standing_network"}
      });
      sourceResults.push({source:source.source_key,ok:true});
    }catch(e){
      sourceResults.push({source:source.source_key,ok:false,error:e instanceof Error?e.message:"unknown_error"});
    }
  }

  try{
    const indexHtml=await fetchText(MBC_CURRENT);
    const links=Array.from(indexHtml.matchAll(/href=["'](https?:\/\/mbc\.ca\/tender\/[^"'#?]+|\/tender\/[^"'#?]+)["']/gi))
      .map(m=>m[1].startsWith("http")?m[1]:`https://mbc.ca${m[1]}`);
    const unique=[...new Set(links)].slice(0,30);

    for(const url of unique){
      try{
        const html=await fetchText(url);
        const plain=cleanHtml(html);
        const h1=html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i);
        const title=cleanHtml(h1?.[1]||"");
        if(!title)continue;
        const fit=classify(plain);
        if(fit.service_fit.length===0||fit.fit_score<44)continue;
        const closingFragment=plain.match(/(?:Closing Date|Tender Closing date)\s*:?\s*.{0,100}/i)?.[0]||plain;
        const deadline=monthDate(closingFragment);
        if(deadline&&new Date(deadline).getTime()<Date.now())continue;
        const speed=deadlineScore(deadline);
        const slug=new URL(url).pathname.replace(/^\/tender\//,"").replace(/\/$/,"");
        leads.push({
          source_key:"mbc_current_tenders",external_id:slug,source_label:"McDonald Brothers Construction — Current Tenders",
          buyer_name:"McDonald Brothers Construction Inc.",opportunity_title:title,
          opportunity_type:"private_tender",response_mode:"formal_bid",
          description:plain.slice(0,5000),region:"Ottawa / Eastern Ontario",source_url:url,
          contact_email:"tenders@mbc.ca",contact_phone:"613-831-6223",
          deadline_at:deadline,service_fit:fit.service_fit,fit_score:fit.fit_score,speed_score:speed,
          conversion_score:conversionScore(fit.fit_score,speed,true),
          raw_payload:{observed_at:observedAt,index_url:MBC_CURRENT,source_kind:"private_tender"}
        });
      }catch(e){
        sourceResults.push({source:"mbc_tender_detail",url,ok:false,error:e instanceof Error?e.message:"unknown_error"});
      }
    }
    sourceResults.push({source:"mbc_current_tenders",ok:true,discovered:unique.length});
  }catch(e){
    sourceResults.push({source:"mbc_current_tenders",ok:false,error:e instanceof Error?e.message:"unknown_error"});
  }

  let upserted=0,writeErrors=0;
  for(const lead of leads){
    const {error}=await admin.from("outreach_work_leads").upsert({
      workspace_id:workspaceId,...lead,last_seen_at:observedAt,updated_at:observedAt
    },{onConflict:"workspace_id,source_key,external_id"});
    if(error){writeErrors++;sourceResults.push({source:lead.source_key,external_id:lead.external_id,write_error:error.message});}
    else upserted++;
  }

  const {data:routing,error:routingError}=await admin.rpc("route_outreach_work_leads",{p_workspace:workspaceId,p_limit:20});
  return Response.json({
    ok:writeErrors===0&&!routingError,
    discovered:leads.length,upserted,write_errors:writeErrors,
    routing:routing||null,routing_error:routingError?.message||null,
    sources:sourceResults
  });
});
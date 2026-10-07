import { createClient } from "https://esm.sh/@supabase/supabase-js@2.117.1";
import { authorizeMembership, PROCUREMENT_LEAD_ROLES } from "../_shared/authz.ts";

const cleanHtml=(v:string)=>v.replace(/<script[\s\S]*?<\/script>/gi," ").replace(/<style[\s\S]*?<\/style>/gi," ").replace(/<[^>]+>/g," ").replace(/&nbsp;/gi," ").replace(/&amp;/gi,"&").replace(/&quot;/gi,'"').replace(/&#39;/gi,"'").replace(/\s+/g," ").trim();
const norm=(v:string)=>(v||"").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"").replace(/[^a-z0-9]+/g," ").trim();

function publicHttpUrl(value:string){
  let u:URL;
  try{u=new URL(value);}catch{throw new Error("invalid_document_url");}
  if(!["http:","https:"].includes(u.protocol))throw new Error("unsupported_document_url_scheme");
  if(u.username||u.password)throw new Error("document_url_credentials_not_allowed");
  const h=u.hostname.toLowerCase().replace(/^\[|\]$/g,"");
  if(h.includes(":"))throw new Error("ipv6_document_hosts_not_supported");
  if(h==="localhost"||h.endsWith(".localhost")||h.endsWith(".local")||h==="0.0.0.0")throw new Error("blocked_document_host");
  const m=h.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if(m){
    const a=Number(m[1]),b=Number(m[2]);
    if(a===10||a===127||a===0||(a===169&&b===254)||(a===172&&b>=16&&b<=31)||(a===192&&b===168))throw new Error("blocked_document_host");
  }
  return u.toString();
}

async function fetchPublic(value:string){
  let current=publicHttpUrl(value);
  for(let i=0;i<4;i++){
    const r=await fetch(current,{headers:{"User-Agent":"CBData-Tender-Document-Intelligence/1.0"},redirect:"manual"});
    if(r.status>=300&&r.status<400){
      const location=r.headers.get("location");
      if(!location)throw new Error("document_redirect_without_location");
      current=publicHttpUrl(new URL(location,current).toString());
      continue;
    }
    return r;
  }
  throw new Error("too_many_document_redirects");
}

async function readTextLimited(r:Response,maxBytes=1_000_000){
  const length=Number(r.headers.get("content-length")||0);
  if(length>maxBytes)throw new Error("document_too_large");
  if(!r.body)return "";
  const reader=r.body.getReader(),decoder=new TextDecoder();
  let bytes=0,out="";
  while(true){
    const {done,value}=await reader.read();
    if(done)break;
    bytes+=value.byteLength;
    if(bytes>maxBytes){await reader.cancel();throw new Error("document_too_large");}
    out+=decoder.decode(value,{stream:true});
  }
  out+=decoder.decode();
  return out;
}

function intelligenceFor(text:string){
  const n=norm(text);
  const scopes:string[]=[];
  const rules:Array<[string,string[]]>= [
    ["sheet metal / ductwork",["sheet metal","ductwork","duct work","louvers","air handling","exhaust fan"]],
    ["roofing / envelope",["roofing","roof replacement","building envelope","cladding","flashing","waterproofing"]],
    ["snow / ice",["snow removal","snow clearing","deicing","salting","winter maintenance","deneigement"]],
    ["landscaping / grounds",["landscaping","grounds maintenance","grass cutting","lawn mowing","tree pruning"]],
    ["janitorial / cleaning",["janitorial","custodial","cleaning services","window cleaning","housekeeping"]],
    ["mechanical / HVAC",["hvac","mechanical contractor","ventilation","boiler","chiller","cooling tower"]],
    ["site / civil",["site work","paving","asphalt","concrete","fencing","drainage","excavation"]],
    ["renovation / GC",["general contractor","renovation","demolition","tenant improvement","accessibility upgrade"]]
  ];
  for(const [label,terms] of rules)if(terms.some(x=>n.includes(norm(x))))scopes.push(label);
  const requirements:string[]=[];
  if(/mandatory site visit|required site visit|compulsory site visit/.test(n))requirements.push("mandatory site visit");
  if(/bid bond|tender bond|bonding/.test(n))requirements.push("bonding");
  if(/certificate of insurance|insurance requirement|commercial general liability/.test(n))requirements.push("insurance");
  if(/wsib|workplace safety/.test(n))requirements.push("WSIB / safety");
  if(/security clearance|reliability status|secret clearance/.test(n))requirements.push("security clearance");
  if(/subcontractor|sub contractor|sub-trade|subtrade/.test(n))requirements.push("subtrade / subcontractor provisions");
  return {scopes:Array.from(new Set(scopes)),requirements:Array.from(new Set(requirements)),text_length:text.length};
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
  const tenderId=typeof body.tender_id==="string"?body.tender_id:null;
  if(!tenderId)return Response.json({error:"tender_id_required"},{status:400});
  const {data:memberships}=await admin.from("workspace_memberships").select("workspace_id,role").eq("user_id",userData.user.id).eq("status","active");
  const authz=authorizeMembership(memberships,requestedWorkspace,PROCUREMENT_LEAD_ROLES);
  if(!authz.ok)return Response.json({error:authz.error},{status:authz.status});
  const workspaceId=authz.workspaceId;

  const {data:docs,error}=await admin.from("tender_documents").select("id,title,document_type,source_url,extracted_text").eq("workspace_id",workspaceId).eq("tender_record_id",tenderId).eq("is_current",true);
  if(error)return Response.json({error:error.message},{status:500});
  let parsed=0,needsTextExtraction=0,errors=0;
  const aggregate={scopes:new Set<string>(),requirements:new Set<string>()};

  for(const d of docs||[]){
    try{
      let text=String(d.extracted_text||"");
      if(!text&&d.source_url){
        const r=await fetchPublic(d.source_url);
        if(!r.ok)throw new Error("document_fetch_"+r.status);
        const ct=(r.headers.get("content-type")||"").toLowerCase();
        if(ct.includes("text/")||ct.includes("html")||ct.includes("json")){
          text=cleanHtml(await readTextLimited(r)).slice(0,100000);
        }else{
          const intel=intelligenceFor([d.title,d.document_type,d.source_url].join(" "));
          await admin.from("tender_documents").update({
            extraction_status:"needs_text_extraction",intelligence:{...intel,content_type:ct,reason:"binary_document_requires_text_extraction"},parsed_at:new Date().toISOString()
          }).eq("id",d.id).eq("workspace_id",workspaceId);
          needsTextExtraction++;
          continue;
        }
      }
      const intel=intelligenceFor([d.title,d.document_type,text].join(" "));
      for(const x of intel.scopes)aggregate.scopes.add(x);
      for(const x of intel.requirements)aggregate.requirements.add(x);
      await admin.from("tender_documents").update({
        extraction_status:"parsed",extracted_text:text||null,intelligence:intel,parsed_at:new Date().toISOString()
      }).eq("id",d.id).eq("workspace_id",workspaceId);
      parsed++;
    }catch(e){
      errors++;
      await admin.from("tender_documents").update({
        extraction_status:"error",intelligence:{error:e instanceof Error?e.message:"unknown_error"},parsed_at:new Date().toISOString()
      }).eq("id",d.id).eq("workspace_id",workspaceId);
    }
  }

  const {data:tender}=await admin.from("tender_records").select("raw_payload").eq("workspace_id",workspaceId).eq("id",tenderId).maybeSingle();
  if(tender){
    const raw=(tender.raw_payload&&typeof tender.raw_payload==="object")?tender.raw_payload:{};
    await admin.from("tender_records").update({
      raw_payload:{...raw,document_intelligence:{scopes:Array.from(aggregate.scopes),requirements:Array.from(aggregate.requirements),parsed_documents:parsed,needs_text_extraction:needsTextExtraction,updated_at:new Date().toISOString()}}
    }).eq("workspace_id",workspaceId).eq("id",tenderId);
  }

  return Response.json({ok:true,tender_id:tenderId,documents:(docs||[]).length,parsed,needs_text_extraction:needsTextExtraction,errors,scopes:Array.from(aggregate.scopes),requirements:Array.from(aggregate.requirements)});
});


import { createClient } from "https://esm.sh/@supabase/supabase-js@2.117.1";

type FitRule={label:string;weight:number;core?:boolean;terms:string[]};
const FIT_RULES:FitRule[]=[
{label:"snow & ice",weight:28,core:true,terms:["snow removal","snow clearing","snow plow","snowplow","winter maintenance","ice control","salting","deicing","déneigement","deneigement"]},
{label:"landscaping & grounds",weight:26,core:true,terms:["landscaping","grounds maintenance","groundskeeping","grass cutting","lawn mowing","turf maintenance","tree pruning","arborist","entretien paysager"]},
{label:"janitorial & cleaning",weight:28,core:true,terms:["janitorial","custodial","cleaning services","building cleaning","window cleaning","pressure washing","housekeeping","nettoyage","conciergerie"]},
{label:"sheet metal & ductwork",weight:32,core:true,terms:["sheet metal","ductwork","duct work","metal flashing","metal cladding","siding","louvers","eavestrough","gutter"]},
{label:"roofing & envelope",weight:26,core:true,terms:["roof replacement","roof repair","roofing","epdm","tpo roofing","modified bitumen","building envelope","waterproofing","cladding"]},
{label:"facility maintenance",weight:24,core:true,terms:["facility maintenance","facilities maintenance","building maintenance","property maintenance","caretaking","preventive maintenance"]},
{label:"hvac & mechanical",weight:24,core:true,terms:["hvac","mechanical contractor","mechanical systems","ventilation","air handling","exhaust fan","boiler","chiller","cooling tower"]},
{label:"renovation & general contracting",weight:18,terms:["general contractor","general contracting","renovation","building renovation","tenant improvement","washroom renovation","accessibility upgrade","ceiling replacement","door replacement","window replacement","demolition"]},
{label:"site & civil",weight:16,terms:["site work","sitework","asphalt paving","paving","concrete sidewalk","concrete repair","retaining wall","fencing","drainage","excavation","parking lot"]},
{label:"painting & finishes",weight:16,terms:["painting","flooring","carpet","tile replacement","millwork","carpentry","drywall"]},
{label:"plumbing",weight:10,terms:["plumbing","plumber","domestic water","sanitary piping"]},
{label:"electrical",weight:8,terms:["electrical contractor","electrical upgrade","lighting replacement","fire alarm replacement"]},
{label:"metals & fabrication",weight:30,core:true,terms:["structural steel","steel fabrication","metal fabrication","welding","miscellaneous metals","architectural metals","pre-engineered metal","metal stairs","metal railing"]},
{label:"roof sheet metal",weight:30,core:true,terms:["metal roofing","roof flashing","sheet metal flashing","soffit","fascia","coping","roof curb"]},
{label:"mechanical accessories",weight:26,core:true,terms:["fire damper","smoke damper","volume damper","roof curb","exhaust hood","mechanical insulation","duct insulation","air balancing"]},
{label:"standing offers & prequalification",weight:18,terms:["standing offer","request for standing offer","rfso","source list","prequalification","pre-qualification","contractor prequalification","vendor of record"]},
{label:"construction",weight:10,terms:["construction","building addition","capital renewal","school renewal"]}
];
const EXCLUSION_TERMS=["software maintenance","software management","document management software","logiciel","gestion documentaire","informatique","it maintenance","network maintenance","vehicle maintenance","fleet maintenance","aircraft maintenance","marine maintenance","medical equipment","laboratory equipment","training services","consulting services","engineering services only","architectural services only","survey services","office supplies","food services"];
const FACILITY_CONTEXT=["building","facility","facilities","property","school","housing","campus","hospital","roof","site","grounds","parking","washroom","mechanical","construction","renovation","maintenance"];

const SOURCES=[
{key:"city_ottawa_merx",name:"City of Ottawa / MERX",kind:"merx",url:"https://www.merx.com/cityofottawa/solicitations/open-bids",buyer:"City of Ottawa",region:"Ottawa, Ontario"},
{key:"och_merx",name:"Ottawa Community Housing / MERX",kind:"merx",url:"https://www.merx.com/ottawacommunityhousing/solicitations/open-bids",buyer:"Ottawa Community Housing",region:"Ottawa, Ontario"},
{key:"uottawa_merx",name:"University of Ottawa / MERX",kind:"merx",url:"https://www.merx.com/oupma/uottawa/solicitations/open-bids",buyer:"University of Ottawa",region:"Ottawa, Ontario"},
{key:"carleton_merx",name:"Carleton University / MERX",kind:"merx",url:"https://www.merx.com/oupma/carleton/solicitations/open-bids",buyer:"Carleton University",region:"Ottawa, Ontario"},
{key:"algonquin_merx",name:"Algonquin College / MERX",kind:"merx",url:"https://www.merx.com/algonquincollege/solicitations/open-bids",buyer:"Algonquin College",region:"Ottawa, Ontario"},
{key:"montfort_merx",name:"Hôpital Montfort / MERX",kind:"merx",url:"https://www.merx.com/hopitalmontfort/solicitations/open-bids",buyer:"Hôpital Montfort",region:"Ottawa, Ontario"},
{key:"lacite_merx",name:"La Cité / MERX",kind:"merx",url:"https://www.merx.com/lacitecollegiale/solicitations/open-bids",buyer:"La Cité",region:"Ottawa, Ontario"},
{key:"bruyere_merx",name:"Bruyère / MERX",kind:"merx",url:"https://www.merx.com/bruyerecontinuingcare/solicitations/open-bids",buyer:"Bruyère Health",region:"Ottawa, Ontario"},
{key:"ocdsb_bids_tenders",name:"OCDSB Bids & Tenders",kind:"bids_tenders",url:"https://ocdsb.bidsandtenders.ca/",buyer:"Ottawa-Carleton District School Board",region:"Ottawa, Ontario"},
{key:"ocsb_bids_tenders",name:"OCSB Bids & Tenders",kind:"bids_tenders",url:"https://ocsb.bidsandtenders.ca/",buyer:"Ottawa Catholic School Board",region:"Ottawa, Ontario"},
{key:"clarence_rockland_bids_tenders",name:"Clarence-Rockland Bids & Tenders",kind:"bids_tenders",url:"https://clarence-rockland.bidsandtenders.ca/",buyer:"City of Clarence-Rockland",region:"Prescott-Russell, Ontario"},
{key:"prescott_russell_bids_tenders",name:"Prescott-Russell Bids & Tenders",kind:"bids_tenders",url:"https://prescott-russell.bidsandtenders.ca/",buyer:"United Counties of Prescott and Russell",region:"Prescott-Russell, Ontario"},
{key:"lanark_county_bids_tenders",name:"Lanark County Bids & Tenders",kind:"bids_tenders",url:"https://lanarkcounty.bidsandtenders.ca/",buyer:"County of Lanark",region:"Lanark County, Ontario"},
{key:"county_renfrew_bids_tenders",name:"County of Renfrew Bids & Tenders",kind:"bids_tenders",url:"https://countyofrenfrew.bidsandtenders.ca/",buyer:"County of Renfrew",region:"Renfrew County, Ontario"},
{key:"rcdsb_bids_tenders",name:"RCDSB Bids & Tenders",kind:"bids_tenders",url:"https://rcdsb.bidsandtenders.ca/",buyer:"Renfrew County District School Board",region:"Renfrew County, Ontario"},
{key:"ucdsb_bids_tenders",name:"UCDSB Bids & Tenders",kind:"bids_tenders",url:"https://ucdsb.bidsandtenders.ca/",buyer:"Upper Canada District School Board",region:"Eastern Ontario"},
{key:"leeds_grenville_bids_tenders",name:"Leeds Grenville Bids & Tenders",kind:"bids_tenders",url:"https://leedsgrenville.bidsandtenders.ca/",buyer:"United Counties of Leeds and Grenville",region:"Eastern Ontario"},
{key:"gatineau_open_data",name:"Ville de Gatineau open tenders",kind:"gatineau_csv",url:"https://www.gatineau.ca/upload/donneesouvertes/appels_offres_utf8.csv",buyer:"Ville de Gatineau",region:"Gatineau, Québec"}
] as const;

type Source=(typeof SOURCES)[number];
type Candidate={externalId:string;title:string;buyer:string;category?:string|null;publishedDate?:string|null;closingDate?:string|null;url:string;region:string;detail?:string;raw?:unknown};

function cleanHtml(v:string){return v.replace(/<script[\s\S]*?<\/script>/gi," ").replace(/<style[\s\S]*?<\/style>/gi," ").replace(/<[^>]+>/g," ").replace(/&nbsp;/gi," ").replace(/&amp;/gi,"&").replace(/&quot;/gi,'"').replace(/&#39;/gi,"'").replace(/\s+/g," ").trim();}
function norm(v:string){return v.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"").replace(/[^a-z0-9]+/g," ").trim();}
function classifyFit(v:string){
 const n=norm(v);
 const matched=FIT_RULES.filter(r=>r.terms.some(t=>n.includes(norm(t))));
 const services=Array.from(new Set(matched.map(r=>r.label)));
 const hasCore=matched.some(r=>r.core);
 const hasContext=FACILITY_CONTEXT.some(t=>n.includes(norm(t)));
 const excluded=EXCLUSION_TERMS.some(t=>n.includes(norm(t)));
 let score=30+matched.reduce((sum,r)=>sum+r.weight,0)+(hasCore?12:0)+(hasContext?8:0);
 if(excluded&&!hasCore)score-=28;
 score=Math.max(0,Math.min(98,score));
 const tier=score>=82?"core":score>=62?"strong_adjacent":score>=45?"adjacent":"skip";
 return {services,score,tier,excluded,hasCore};
}
function isoDate(v:string|null|undefined):string|null{if(!v)return null;const m=v.match(/(20\d{2})[\/-](\d{1,2})[\/-](\d{1,2})/);if(m)return m[1]+"-"+m[2].padStart(2,"0")+"-"+m[3].padStart(2,"0");const d=new Date(v);return Number.isNaN(d.getTime())?null:d.toISOString().slice(0,10);}
function isOpen(v:string|null){return !!v&&new Date(v+"T23:59:59-04:00").getTime()>=Date.now();}
function esc(v:string){return v.replace(/[.*+?^$()|[\]\\{}]/g,"\\$&");}
function field(text:string,label:string,labels:string[]){const re=new RegExp(esc(label)+"\\s*:?\\s*(.*?)(?=\\s+(?:"+labels.map(esc).join("|")+")\\s*:|$)","i");return(text.match(re)?.[1]||"").trim();}

function csvRows(text:string):Record<string,string>[]{
 const rows:string[][]=[];let row:string[]=[];let cell="";let q=false;
 for(let i=0;i<text.length;i++){const c=text[i];if(c==='"'){if(q&&text[i+1]==='"'){cell+='"';i++;}else q=!q;}else if(c===','&&!q){row.push(cell);cell="";}else if((c==="\n"||c==="\r")&&!q){if(c==="\r"&&text[i+1]==="\n")i++;row.push(cell);if(row.some(x=>x.trim()))rows.push(row);row=[];cell="";}else cell+=c;}
 if(cell||row.length){row.push(cell);rows.push(row);}if(rows.length<2)return[];
 const heads=rows[0].map(h=>norm(h));return rows.slice(1).map(r=>Object.fromEntries(heads.map((h,i)=>[h,(r[i]||"").trim()])));
}
function pick(row:Record<string,string>,aliases:string[]){for(const a of aliases){const na=norm(a);for(const [k,v] of Object.entries(row))if((k===na||k.includes(na))&&v)return v;}return"";}

function parseMerx(html:string,source:Source):Candidate[]{
 const plain=cleanHtml(html),out:Candidate[]=[];
 const re=/([A-Z0-9][A-Z0-9._\/-]{3,})\s+(.{4,220}?)\s+([A-Za-zÀ-ÿ0-9 .,'’\-]{2,80}),\s*(ON|QC),\s*CAN\s+Calendar\s+Published\s+(20\d{2}[\/-]\d{2}[\/-]\d{2})\s+Clock\s+Closing\s+(20\d{2}[\/-]\d{2}[\/-]\d{2})/gi;
 for(const m of plain.matchAll(re))out.push({externalId:m[1],title:m[2].trim(),buyer:source.buyer,publishedDate:isoDate(m[5]),closingDate:isoDate(m[6]),url:source.url,region:source.region,raw:{parser:"merx_text",listed_city:m[3].trim(),listed_province:m[4]}});
 return out;
}

async function parseBidsTenders(source:Source):Promise<Candidate[]>{
 const home=await fetch(source.url,{headers:{"User-Agent":"CBData-Regional-Tender-Scout/1.0"}});if(!home.ok)throw new Error("homepage_"+home.status);
 const html=await home.text();const ids=Array.from(new Set(Array.from(html.matchAll(/Tender\/Detail\/([0-9a-f-]{20,})/gi)).map(m=>m[1]))).slice(0,100);const out:Candidate[]=[];
 const labels=["Bid Classification","Bid Type","Bid Number","Bid Name","Bid Status","Published Date","Bid Closing Date","Question Deadline","Duration in months","Negotiation Type","Condition for Participation","Electronic Auctions","Language for Bid Submissions","Submission Type","Submission Address","Public Opening","Description","Bid Document Access"];
 for(const id of ids){const detailUrl=new URL("/Module/Tenders/en/Tender/Detail/"+id,source.url).toString();const r=await fetch(detailUrl,{headers:{"User-Agent":"CBData-Regional-Tender-Scout/1.0"}});if(!r.ok)continue;const text=cleanHtml(await r.text());const status=field(text,"Bid Status",labels);if(!/open/i.test(status))continue;const externalId=field(text,"Bid Number",labels)||id;const title=field(text,"Bid Name",labels);if(!title)continue;const closingDate=isoDate(field(text,"Bid Closing Date",labels));if(closingDate&&!isOpen(closingDate))continue;out.push({externalId,title,buyer:source.buyer,category:field(text,"Bid Classification",labels)||null,publishedDate:isoDate(field(text,"Published Date",labels)),closingDate,url:detailUrl,region:source.region,detail:field(text,"Description",labels),raw:{status,bid_type:field(text,"Bid Type",labels),submission_type:field(text,"Submission Type",labels)}});}
 return out;
}

async function parseGatineau(source:Source):Promise<Candidate[]>{
 const r=await fetch(source.url,{headers:{"User-Agent":"CBData-Regional-Tender-Scout/1.0"}});if(!r.ok)throw new Error("csv_"+r.status);
 const rows=csvRows(await r.text()),out:Candidate[]=[];
 for(const row of rows){const externalId=pick(row,["numero","numéro","no appel","reference","référence","id"]);const title=pick(row,["titre","description","objet","appel offres","appel d offres"]);const publishedDate=isoDate(pick(row,["date publication","date ouverture","publication"]));const closingDate=isoDate(pick(row,["date fermeture","date cloture","date clôture","fermeture","cloture","clôture"]));const status=pick(row,["statut","etat","état"]);if(!externalId||!title||(!isOpen(closingDate)&&!/ouvert|en cours|active/i.test(status)))continue;const detailUrl=pick(row,["url","lien","hyperlien"])||"https://www.gatineau.ca/portail/default.aspx?p=guichet_municipal/affaires_developpement_economique/faire_affaires_ville/appels_offres";out.push({externalId,title,buyer:source.buyer,category:pick(row,["categorie","catégorie","type"])||null,publishedDate,closingDate,url:detailUrl,region:source.region,detail:Object.values(row).join(" "),raw:row});}
 return out;
}

Deno.serve(async(req)=>{
 if(req.method!=="POST")return new Response("method_not_allowed",{status:405});
 const supabaseUrl=Deno.env.get("SUPABASE_URL"),serviceRoleKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");if(!supabaseUrl||!serviceRoleKey)return Response.json({error:"not_configured"},{status:500});
 const token=(req.headers.get("authorization")||"").replace(/^Bearer\s+/,""),cronToken=req.headers.get("x-cbdata-cron-token")||"",admin=createClient(supabaseUrl,serviceRoleKey);
 const body=await req.json().catch(()=>({})),requestedWorkspace=typeof body.workspace_id==="string"?body.workspace_id:null;
 let workspaceId:string|null=null;
 if(cronToken){
  const {data:cronAllowed,error:cronError}=await admin.rpc("verify_procurement_scout_cron_token",{p_token:cronToken});if(cronError||cronAllowed!==true)return Response.json({error:"unauthorized_cron"},{status:401});
  if(!requestedWorkspace)return Response.json({error:"workspace_required"},{status:400});
  const {data:workspace}=await admin.from("workspaces").select("id").eq("id",requestedWorkspace).eq("status","active").maybeSingle();if(!workspace)return Response.json({error:"workspace_not_active"},{status:404});workspaceId=workspace.id;
 }else{
  const {data:userData,error:userError}=await admin.auth.getUser(token);if(userError||!userData.user)return Response.json({error:"unauthorized"},{status:401});
  const {data:memberships}=await admin.from("workspace_memberships").select("workspace_id").eq("user_id",userData.user.id).eq("status","active");const membership=(memberships||[]).find((m:any)=>!requestedWorkspace||m.workspace_id===requestedWorkspace);if(!membership)return Response.json({error:"workspace_access_denied"},{status:403});workspaceId=membership.workspace_id;
 }
 if(!workspaceId)return Response.json({error:"workspace_unresolved"},{status:400});
 await admin.from("tender_sources").upsert(
   SOURCES.map(source=>({workspace_id:workspaceId,source_key:source.key,display_name:source.name,source_url:source.url,ingestion_mode:"live",enabled:true,updated_at:new Date().toISOString()})),
   {onConflict:"workspace_id,source_key",ignoreDuplicates:true}
 );
 const {data:sourceRows}=await admin.from("tender_sources").select("source_key,enabled").eq("workspace_id",workspaceId),enabled=new Map((sourceRows||[]).map((x:any)=>[x.source_key,x.enabled]));const {data:orgRows}=await admin.from("organizations").select("id,legal_name,operating_name").eq("workspace_id",workspaceId),orgs:any[]=orgRows||[],summary:any[]=[];
 for(const source of SOURCES){if(enabled.get(source.key)===false)continue;const {data:run}=await admin.from("tender_scout_runs").insert({workspace_id:workspaceId,source_key:source.key,source_name:source.name}).select("id").single();let fetched=0,qualifying=0,inserted=0,updated=0,leads=0,errors=0;
  try{let candidates:Candidate[]=[];if(source.kind==="merx"){const r=await fetch(source.url,{headers:{"User-Agent":"CBData-Regional-Tender-Scout/1.0"}});if(!r.ok)throw new Error("merx_"+r.status);candidates=parseMerx(await r.text(),source);}else if(source.kind==="bids_tenders")candidates=await parseBidsTenders(source);else candidates=await parseGatineau(source);fetched=candidates.length;
   for(const c of candidates){const {error:opportunityError}=await admin.from("procurement_opportunities").upsert({workspace_id:workspaceId,source_key:source.key,external_id:c.externalId,buyer_key:source.key,buyer_name:c.buyer,title:c.title,opportunity_type:"tender",description:c.detail||null,category:c.category||null,region:c.region,published_at:c.publishedDate?new Date(c.publishedDate+"T12:00:00Z").toISOString():null,closing_at:c.closingDate?new Date(c.closingDate+"T23:59:59-04:00").toISOString():null,source_url:c.url,raw_payload:{source_payload:c.raw||null,observed_at:new Date().toISOString()},last_seen_at:new Date().toISOString(),updated_at:new Date().toISOString()},{onConflict:"workspace_id,source_key,external_id"});if(opportunityError){errors++;continue;}const fit=classifyFit([c.title,c.category||"",c.detail||""].join(" "));if(fit.tier==="skip")continue;const matches=fit.services;qualifying++;let org=orgs.find(o=>norm(o.legal_name)===norm(c.buyer)||norm(o.operating_name||"")===norm(c.buyer));if(!org){const {data:created}=await admin.from("organizations").insert({workspace_id:workspaceId,legal_name:c.buyer,operating_name:c.buyer,organization_type:"owner",status:"active",primary_region:c.region,source_notes:"Created by regional tender discovery."}).select("id,legal_name,operating_name").single();if(created){org=created;orgs.push(created);}}
    const score=fit.score;const payload={workspace_id:workspaceId,source:source.name,external_id:c.externalId,title:c.title,buyer_name:c.buyer,category:c.category||matches.join(", "),region:c.region,published_date:c.publishedDate||null,closing_date:c.closingDate||null,source_url:c.url,raw_payload:{source_key:source.key,scout_version:"2.0",services:matches,fit_tier:fit.tier,excluded_signal:fit.excluded,source_payload:c.raw||null,observed_at:new Date().toISOString()},matched_organization_id:org?.id||null,response_mode:"formal_tender",registration_required:source.kind==="bids_tenders",fit_score:score,fit_note:(fit.tier==="core"?"Core fit":fit.tier==="strong_adjacent"?"Strong adjacent fit":"Adjacent fit")+": "+matches.join(", ")+". Verify scope, prequalification, mandatory requirements and submission instructions before bidding.",last_verified_at:new Date().toISOString(),watch_query:matches.join(", "),updated_at:new Date().toISOString()};const {data:existing}=await admin.from("tender_records").select("id,lead_id").eq("workspace_id",workspaceId).eq("source",source.name).eq("external_id",c.externalId).maybeSingle();const {data:tender,error:tenderError}=existing?await admin.from("tender_records").update(payload).eq("id",existing.id).select("id,lead_id").single():await admin.from("tender_records").insert({...payload,status:"new"}).select("id,lead_id").single();if(tenderError||!tender){errors++;continue;}existing?updated++:inserted++;if(!tender.lead_id){const {data:lead}=await admin.from("leads").insert({workspace_id:workspaceId,organization_id:org?.id||null,source:source.name,lead_type:"tender",status:"new",region:c.region,score,source_detail_table:"tender_records",source_detail_id:tender.id}).select("id").single();if(lead?.id){leads++;await admin.from("tender_records").update({lead_id:lead.id}).eq("id",tender.id);}}}
   await admin.from("tender_scout_runs").update({finished_at:new Date().toISOString(),status:errors?"partial":"completed",fetched_count:fetched,qualifying_count:qualifying,inserted_count:inserted,updated_count:updated,lead_created_count:leads,error_count:errors}).eq("id",run?.id);await admin.from("tender_sources").update({last_run_at:new Date().toISOString(),...(errors?{last_error:`${errors} procurement writes failed`}:{last_success_at:new Date().toISOString(),last_error:null}),updated_at:new Date().toISOString()}).eq("workspace_id",workspaceId).eq("source_key",source.key);summary.push({source:source.key,fetched,qualifying,inserted,updated,leads,errors});
  }catch(e){const message=e instanceof Error?e.message:"unknown_error";errors++;await admin.from("tender_scout_runs").update({finished_at:new Date().toISOString(),status:"error",fetched_count:fetched,qualifying_count:qualifying,inserted_count:inserted,updated_count:updated,lead_created_count:leads,error_count:errors,error_message:message}).eq("id",run?.id);await admin.from("tender_sources").update({last_run_at:new Date().toISOString(),last_error:message,updated_at:new Date().toISOString()}).eq("workspace_id",workspaceId).eq("source_key",source.key);summary.push({source:source.key,error:message});}
 }
 const {data:routing,error:routingError}=await admin.rpc("route_procurement_pursuits",{p_workspace:workspaceId});
 return Response.json({ok:summary.every(source=>!source.error&&!source.errors)&&!routingError,sources:summary,routing:routing||null,routing_error:routingError?.message||null});
});

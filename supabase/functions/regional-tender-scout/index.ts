
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.117.1";

const SERVICES:Array<[string,string]>=[
["snow","snow"],["déneig","snow"],["winter maintenance","snow"],["landscap","landscaping"],
["grounds","grounds"],["grass","grounds"],["janitorial","janitorial"],["cleaning","cleaning"],
["nettoyage","cleaning"],["concierger","janitorial"],["custodial","janitorial"],
["facility maintenance","facility maintenance"],["building maintenance","facility maintenance"],
["property maintenance","property maintenance"],["paving","paving"],["asphalt","paving"],
["concrete","concrete"],["roof","roofing"],["hvac","hvac"],["mechanical","mechanical"],
["plumbing","plumbing"],["sheet metal","sheet metal"],["building envelope","building envelope"],
["site work","site work"],["sitework","site work"],["renovation","renovation"],["construction","construction"]
];

const SOURCES=[
{key:"city_ottawa_merx",name:"City of Ottawa / MERX",kind:"merx",url:"https://www.merx.com/cityofottawa/solicitations/open-bids",buyer:"City of Ottawa",region:"Ottawa, Ontario"},
{key:"och_merx",name:"Ottawa Community Housing / MERX",kind:"merx",url:"https://www.merx.com/ottawacommunityhousing/solicitations/open-bids",buyer:"Ottawa Community Housing",region:"Ottawa, Ontario"},
{key:"ocdsb_bids_tenders",name:"OCDSB Bids & Tenders",kind:"bids_tenders",url:"https://ocdsb.bidsandtenders.ca/",buyer:"Ottawa-Carleton District School Board",region:"Ottawa, Ontario"},
{key:"ocsb_bids_tenders",name:"OCSB Bids & Tenders",kind:"bids_tenders",url:"https://ocsb.bidsandtenders.ca/Module/Tenders/en/Home/BidsHomepage",buyer:"Ottawa Catholic School Board",region:"Ottawa, Ontario"},
{key:"gatineau_open_data",name:"Ville de Gatineau open tenders",kind:"gatineau_csv",url:"https://www.gatineau.ca/upload/donneesouvertes/appels_offres_utf8.csv",buyer:"Ville de Gatineau",region:"Gatineau, Québec"}
] as const;

type Source=(typeof SOURCES)[number];
type Candidate={externalId:string;title:string;buyer:string;category?:string|null;publishedDate?:string|null;closingDate?:string|null;url:string;region:string;detail?:string;raw?:unknown};

function cleanHtml(v:string){return v.replace(/<script[\s\S]*?<\/script>/gi," ").replace(/<style[\s\S]*?<\/style>/gi," ").replace(/<[^>]+>/g," ").replace(/&nbsp;/gi," ").replace(/&amp;/gi,"&").replace(/&quot;/gi,'"').replace(/&#39;/gi,"'").replace(/\s+/g," ").trim();}
function norm(v:string){return v.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"").replace(/[^a-z0-9]+/g," ").trim();}
function serviceMatches(v:string){const n=norm(v);return Array.from(new Set(SERVICES.filter(([x])=>n.includes(norm(x))).map(([,x])=>x)));}
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
 const re=/([A-Z0-9][A-Z0-9._\/-]{3,})\s+(.{4,220}?)\s+Ottawa,\s*ON,\s*CAN\s+Calendar\s+Published\s+(20\d{2}[\/-]\d{2}[\/-]\d{2})\s+Clock\s+Closing\s+(20\d{2}[\/-]\d{2}[\/-]\d{2})/gi;
 for(const m of plain.matchAll(re))out.push({externalId:m[1],title:m[2].trim(),buyer:source.buyer,publishedDate:isoDate(m[3]),closingDate:isoDate(m[4]),url:source.url,region:source.region,raw:{parser:"merx_text"}});
 return out;
}

async function parseBidsTenders(source:Source):Promise<Candidate[]>{
 const home=await fetch(source.url,{headers:{"User-Agent":"CBData-Regional-Tender-Scout/1.0"}});if(!home.ok)throw new Error("homepage_"+home.status);
 const html=await home.text();const ids=Array.from(new Set(Array.from(html.matchAll(/Tender\/Detail\/([0-9a-f-]{20,})/gi)).map(m=>m[1]))).slice(0,100);const out:Candidate[]=[];
 const labels=["Bid Classification","Bid Type","Bid Number","Bid Name","Bid Status","Bid Closing Date","Question Deadline","Duration in months","Negotiation Type","Condition for Participation","Electronic Auctions","Language for Bid Submissions","Submission Type","Submission Address","Public Opening","Description","Bid Document Access"];
 for(const id of ids){const detailUrl=new URL("/Module/Tenders/en/Tender/Detail/"+id,source.url).toString();const r=await fetch(detailUrl,{headers:{"User-Agent":"CBData-Regional-Tender-Scout/1.0"}});if(!r.ok)continue;const text=cleanHtml(await r.text());const status=field(text,"Bid Status",labels);if(!/open/i.test(status))continue;const externalId=field(text,"Bid Number",labels)||id;const title=field(text,"Bid Name",labels);if(!title)continue;const closingDate=isoDate(field(text,"Bid Closing Date",labels));if(closingDate&&!isOpen(closingDate))continue;out.push({externalId,title,buyer:source.buyer,category:field(text,"Bid Classification",labels)||null,closingDate,url:detailUrl,region:source.region,detail:field(text,"Description",labels),raw:{status,bid_type:field(text,"Bid Type",labels),submission_type:field(text,"Submission Type",labels)}});}
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
 const token=(req.headers.get("authorization")||"").replace(/^Bearer\s+/,""),admin=createClient(supabaseUrl,serviceRoleKey);const {data:userData,error:userError}=await admin.auth.getUser(token);if(userError||!userData.user)return Response.json({error:"unauthorized"},{status:401});
 const body=await req.json().catch(()=>({})),requestedWorkspace=typeof body.workspace_id==="string"?body.workspace_id:null;const {data:memberships}=await admin.from("workspace_memberships").select("workspace_id").eq("user_id",userData.user.id).eq("status","active");const membership=(memberships||[]).find((m:any)=>!requestedWorkspace||m.workspace_id===requestedWorkspace);if(!membership)return Response.json({error:"workspace_access_denied"},{status:403});
 const workspaceId=membership.workspace_id,{data:sourceRows}=await admin.from("tender_sources").select("source_key,enabled").eq("workspace_id",workspaceId),enabled=new Map((sourceRows||[]).map((x:any)=>[x.source_key,x.enabled]));const {data:orgRows}=await admin.from("organizations").select("id,legal_name,operating_name").eq("workspace_id",workspaceId),orgs:any[]=orgRows||[],summary:any[]=[];
 for(const source of SOURCES){if(enabled.get(source.key)===false)continue;const {data:run}=await admin.from("tender_scout_runs").insert({workspace_id:workspaceId,source_key:source.key,source_name:source.name}).select("id").single();let fetched=0,qualifying=0,inserted=0,updated=0,leads=0,errors=0;
  try{let candidates:Candidate[]=[];if(source.kind==="merx"){const r=await fetch(source.url,{headers:{"User-Agent":"CBData-Regional-Tender-Scout/1.0"}});if(!r.ok)throw new Error("merx_"+r.status);candidates=parseMerx(await r.text(),source);}else if(source.kind==="bids_tenders")candidates=await parseBidsTenders(source);else candidates=await parseGatineau(source);fetched=candidates.length;
   for(const c of candidates){const matches=serviceMatches([c.title,c.category||"",c.detail||""].join(" "));if(!matches.length)continue;qualifying++;let org=orgs.find(o=>norm(o.legal_name)===norm(c.buyer)||norm(o.operating_name||"")===norm(c.buyer));if(!org){const {data:created}=await admin.from("organizations").insert({workspace_id:workspaceId,legal_name:c.buyer,operating_name:c.buyer,organization_type:"owner",status:"active",primary_region:c.region,source_notes:"Created by regional tender discovery."}).select("id,legal_name,operating_name").single();if(created){org=created;orgs.push(created);}}
    const highValue=matches.some(x=>["snow","grounds","landscaping","janitorial","cleaning","facility maintenance","property maintenance","sheet metal"].includes(x)),score=Math.min(98,55+matches.length*8+(highValue?12:0));const payload={workspace_id:workspaceId,source:source.name,external_id:c.externalId,title:c.title,buyer_name:c.buyer,category:c.category||matches.join(", "),region:c.region,published_date:c.publishedDate||null,closing_date:c.closingDate||null,source_url:c.url,raw_payload:{source_key:source.key,scout_version:"1.0",services:matches,source_payload:c.raw||null,observed_at:new Date().toISOString()},matched_organization_id:org?.id||null,response_mode:"formal_tender",registration_required:source.kind==="bids_tenders",fit_score:score,fit_note:"Regional procurement match: "+matches.join(", ")+". Verify scope, mandatory requirements and submission instructions before bidding.",last_verified_at:new Date().toISOString(),watch_query:matches.join(", "),updated_at:new Date().toISOString()};const {data:existing}=await admin.from("tender_records").select("id,lead_id").eq("workspace_id",workspaceId).eq("source",source.name).eq("external_id",c.externalId).maybeSingle();const {data:tender,error:tenderError}=existing?await admin.from("tender_records").update(payload).eq("id",existing.id).select("id,lead_id").single():await admin.from("tender_records").insert({...payload,status:"new"}).select("id,lead_id").single();if(tenderError||!tender){errors++;continue;}existing?updated++:inserted++;if(!tender.lead_id){const {data:lead}=await admin.from("leads").insert({workspace_id:workspaceId,organization_id:org?.id||null,source:source.name,lead_type:"tender",status:"new",region:c.region,score,source_detail_table:"tender_records",source_detail_id:tender.id}).select("id").single();if(lead?.id){leads++;await admin.from("tender_records").update({lead_id:lead.id}).eq("id",tender.id);}}}
   await admin.from("tender_scout_runs").update({finished_at:new Date().toISOString(),status:errors?"partial":"completed",fetched_count:fetched,qualifying_count:qualifying,inserted_count:inserted,updated_count:updated,lead_created_count:leads,error_count:errors}).eq("id",run?.id);await admin.from("tender_sources").update({last_run_at:new Date().toISOString(),last_success_at:new Date().toISOString(),last_error:null,updated_at:new Date().toISOString()}).eq("workspace_id",workspaceId).eq("source_key",source.key);summary.push({source:source.key,fetched,qualifying,inserted,updated,leads,errors});
  }catch(e){const message=e instanceof Error?e.message:"unknown_error";errors++;await admin.from("tender_scout_runs").update({finished_at:new Date().toISOString(),status:"error",fetched_count:fetched,qualifying_count:qualifying,inserted_count:inserted,updated_count:updated,lead_created_count:leads,error_count:errors,error_message:message}).eq("id",run?.id);await admin.from("tender_sources").update({last_run_at:new Date().toISOString(),last_error:message,updated_at:new Date().toISOString()}).eq("workspace_id",workspaceId).eq("source_key",source.key);summary.push({source:source.key,error:message});}
 }
 return Response.json({ok:true,sources:summary});
});

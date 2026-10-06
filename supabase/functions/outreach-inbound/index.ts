import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { Resend } from "npm:resend@6.9.2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cbdata-integration-key",
};

const json = (status:number, body:unknown) => new Response(JSON.stringify(body), {
  status,
  headers: {...corsHeaders, "Content-Type":"application/json"},
});

function clean(value:unknown,max=10000):string|null {
  if(typeof value!=="string") return null;
  const t=value.trim();
  return t ? t.slice(0,max) : null;
}
function normalizeEmail(value:unknown):string|null {
  const raw=clean(value,500);
  if(!raw) return null;
  const bracket=raw.match(/<([^>]+@[^>]+)>/);
  const email=(bracket?.[1]??raw).trim().toLowerCase();
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)?email:null;
}
function valueAt(obj:Record<string,unknown>,keys:string[]):unknown {
  for(const key of keys) if(obj[key]!==undefined&&obj[key]!==null) return obj[key];
  return null;
}
function parseTimestamp(value:unknown):string {
  const raw=clean(value,100);
  if(!raw) return new Date().toISOString();
  const d=new Date(raw);
  return Number.isNaN(d.getTime())?new Date().toISOString():d.toISOString();
}
function arrayOfStrings(value:unknown):string[] {
  if(Array.isArray(value)) return [...new Set(value.filter((x):x is string=>typeof x==="string").map(x=>x.trim()).filter(Boolean))].slice(0,50);
  if(typeof value==="string") return [...new Set(value.split(/[\s,]+/).map(x=>x.trim()).filter(Boolean))].slice(0,50);
  return [];
}
function htmlToText(value:unknown):string|null {
  const html=clean(value,100000);
  if(!html) return null;
  const text=html
    .replace(/<script[\s\S]*?<\/script>/gi," ")
    .replace(/<style[\s\S]*?<\/style>/gi," ")
    .replace(/<br\s*\/?>/gi,"\n")
    .replace(/<\/p>/gi,"\n")
    .replace(/<[^>]+>/g," ")
    .replace(/&nbsp;/gi," ")
    .replace(/&amp;/gi,"&")
    .replace(/&lt;/gi,"<")
    .replace(/&gt;/gi,">")
    .replace(/[ \t]+/g," ")
    .replace(/\n{3,}/g,"\n\n")
    .trim();
  return text?text.slice(0,50000):null;
}
async function sha256(value:string):Promise<string> {
  const digest=await crypto.subtle.digest("SHA-256",new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map(b=>b.toString(16).padStart(2,"0")).join("");
}
function bytesToBase64(bytes:Uint8Array):string {
  let value="";
  for(const byte of bytes) value+=String.fromCharCode(byte);
  return btoa(value);
}
function base64ToBytes(value:string):Uint8Array {
  return Uint8Array.from(atob(value),c=>c.charCodeAt(0));
}
function constantTimeEqual(a:string,b:string):boolean {
  if(a.length!==b.length) return false;
  let diff=0;
  for(let i=0;i<a.length;i++) diff|=a.charCodeAt(i)^b.charCodeAt(i);
  return diff===0;
}
async function verifyResendSignature(req: Request, rawBody: string, secret: string): Promise<boolean> {
  const id = req.headers.get("svix-id");
  const timestamp = req.headers.get("svix-timestamp");
  const signature = req.headers.get("svix-signature");
  if (!id || !timestamp || !signature || !secret) return false;

  try {
    const verifier = new Resend(Deno.env.get("RESEND_API_KEY") ?? "re_webhook_verify_only");
    await verifier.webhooks.verify({
      payload: rawBody,
      headers: {
        "svix-id": id,
        "svix-timestamp": timestamp,
        "svix-signature": signature,
      },
      secret,
    });
    return true;
  } catch {
    return false;
  }
}

Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS") return new Response("ok",{headers:corsHeaders});
  if(req.method!=="POST") return json(405,{error:"method_not_allowed"});

  const supabaseUrl=Deno.env.get("SUPABASE_URL");
  const serviceRoleKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if(!supabaseUrl||!serviceRoleKey) return json(500,{error:"integration_not_configured"});
  const authHeaders={apikey:serviceRoleKey,Authorization:`Bearer ${serviceRoleKey}`,"Content-Type":"application/json"};

  const rawBody=await req.text();
  let payload:Record<string,unknown>;
  try {
    const parsed=JSON.parse(rawBody);
    if(!parsed||typeof parsed!=="object"||Array.isArray(parsed)) throw new Error("invalid");
    payload=parsed as Record<string,unknown>;
  } catch { return json(400,{error:"invalid_json"}); }

  const eventType=clean(valueAt(payload,["type","event_type","eventType"]),120);
  const signedResend=eventType==="email.received"&&Boolean(req.headers.get("svix-id")&&req.headers.get("svix-timestamp")&&req.headers.get("svix-signature"));
  const integrationKey=req.headers.get("x-cbdata-integration-key")??new URL(req.url).searchParams.get("integration_key");
  let workspaceId:string|null=null;

  if(integrationKey){
    const lookup=await rpc(supabaseUrl,authHeaders,"lookup_integration_workspace",{
      p_provider:"outreach_inbound",p_key_hash:await sha256(integrationKey)
    });
    if(!lookup.ok) return json(500,{error:"credential_lookup_failed"});
    if(typeof lookup.data!=="string"||!lookup.data) return json(401,{error:"invalid_integration_key"});
    workspaceId=lookup.data;
  } else if(signedResend){
    const secret=await rpc(supabaseUrl,authHeaders,"get_service_integration_secret",{p_name:"resend_outreach_webhook_signing_secret"});
    if(!secret.ok) return json(500,{error:"webhook_secret_lookup_failed"});
    if(typeof secret.data!=="string"||!secret.data) return json(500,{error:"webhook_secret_not_configured"});
    if(!await verifyResendSignature(req,rawBody,secret.data)) return json(401,{error:"invalid_webhook_signature"});
    const ws=await rpc(supabaseUrl,authHeaders,"lookup_signed_integration_workspace",{p_provider:"resend_webhook"});
    if(!ws.ok||typeof ws.data!=="string"||!ws.data) return json(500,{error:"signed_workspace_unavailable"});
    workspaceId=ws.data;
  } else {
    return json(401,{error:"missing_integration_auth"});
  }

  const nested=(payload.data&&typeof payload.data==="object"&&!Array.isArray(payload.data))
    ? payload.data as Record<string,unknown>
    : (payload.message&&typeof payload.message==="object"&&!Array.isArray(payload.message))
      ? payload.message as Record<string,unknown>
      : payload;

  let provider=clean(valueAt(nested,["provider"]),80)??clean(valueAt(payload,["provider"]),80)??(eventType==="email.received"?"resend":"webhook");
  provider=provider.toLowerCase();
  let senderEmail=normalizeEmail(valueAt(nested,["sender_email","from_email","from","sender","email"]));
  let subject=clean(valueAt(nested,["subject","Subject"]),1000);
  let body=clean(valueAt(nested,["text","body","text_body","plain","content","message"]),50000)
    ??clean(valueAt(payload,["text","body","text_body","plain","content"]),50000);
  const resendEmailId=clean(valueAt(nested,["email_id","emailId"]),500);
  let providerThreadId=clean(valueAt(nested,["thread_id","threadId","conversation_id","conversationId"]),500)
    ??clean(valueAt(payload,["thread_id","threadId","conversation_id","conversationId"]),500);
  let providerMessageId=clean(valueAt(nested,["message_id","messageId","id","event_id","eventId"]),500)
    ??clean(valueAt(payload,["message_id","messageId","id","event_id","eventId"]),500);
  const receivedAt=parseTimestamp(valueAt(nested,["received_at","receivedAt","created_at","createdAt","timestamp","date"])
    ??valueAt(payload,["received_at","receivedAt","created_at","createdAt","timestamp","date"]));
  let inReplyTo=clean(valueAt(nested,["in_reply_to","inReplyTo"]),500)??clean(valueAt(payload,["in_reply_to","inReplyTo"]),500);
  let references=arrayOfStrings(valueAt(nested,["reference_message_ids","references"])??valueAt(payload,["reference_message_ids","references"]));
  let verifiedSentTargetEmail=normalizeEmail(valueAt(nested,["verified_sent_target_email"])??valueAt(payload,["verified_sent_target_email"]));
  const sentThreadVerified=valueAt(nested,["sent_thread_verified"])===true||valueAt(payload,["sent_thread_verified"])===true;
  const isTest=valueAt(nested,["is_test"])===true||valueAt(payload,["is_test"])===true;
  const cursor=clean(valueAt(nested,["history_id","historyId","cursor"])??valueAt(payload,["history_id","historyId","cursor"]),1000);

  if(provider==="gmail"&&!sentThreadVerified){
    await rpc(supabaseUrl,authHeaders,"record_outreach_sync_state_system",{
      p_workspace_id:workspaceId,p_provider:"gmail",p_cursor:cursor,p_status:"error",
      p_error:"gmail_sent_thread_verification_required",
      p_details:{provider_message_id:providerMessageId}
    });
    return json(422,{error:"gmail_sent_thread_verification_required"});
  }

  // Resend webhooks initially carry metadata only. Retrieve the full body immediately when
  // RESEND_API_KEY is configured; otherwise persist pending_content for a later secure fetch.
  if(provider==="resend"&&resendEmailId&&!body){
    const resendKey=Deno.env.get("RESEND_API_KEY");
    if(resendKey){
      try {
        const resend=new Resend(resendKey);
        const result=await resend.emails.receiving.get(resendEmailId);
        const message=result.data as any;
        if(!result.error&&message){
          body=clean(message.text,50000)??htmlToText(message.html);
          senderEmail=normalizeEmail(message.from)??senderEmail;
          subject=clean(message.subject,1000)??subject;
          providerMessageId=clean(message.message_id,500)??providerMessageId;
          providerThreadId=clean(message.thread_id,500)??providerThreadId;
          inReplyTo=clean(message.in_reply_to,500)??inReplyTo;
          references=arrayOfStrings(message.references).length?arrayOfStrings(message.references):references;
        }
      } catch {
        // Persist metadata-only event below. The retry/dead-letter path will surface failures.
      }
    }
  }

  if(!providerMessageId) providerMessageId=`auto-${(await sha256(JSON.stringify(payload))).slice(0,48)}`;

  const result=await rpc(supabaseUrl,authHeaders,"register_outreach_inbound_event_system",{
    p_workspace_id:workspaceId,
    p_provider:provider,
    p_provider_message_id:providerMessageId,
    p_provider_thread_id:providerThreadId,
    p_sender_email:senderEmail,
    p_subject:subject,
    p_body:body,
    p_received_at:receivedAt,
    p_in_reply_to:inReplyTo,
    p_reference_message_ids:references,
    p_verified_sent_target_email:verifiedSentTargetEmail,
    p_is_test:isTest,
    p_raw_metadata:{
      source:"outreach_inbound_edge",
      event_type:eventType,
      resend_email_id:resendEmailId,
      sent_thread_verified:sentThreadVerified,
      payload
    }
  });

  if(!result.ok){
    await rpc(supabaseUrl,authHeaders,"record_outreach_sync_state_system",{
      p_workspace_id:workspaceId,p_provider:provider,p_cursor:cursor,p_status:"error",
      p_error:"register_inbound_event_failed",p_details:{http_status:result.status}
    });
    return json(500,{error:"register_inbound_event_failed",detail:result.data});
  }

  const data=(result.data??{}) as Record<string,unknown>;
  const eventStatus=typeof data.status==="string"?data.status:"unknown";
  const failed=eventStatus==="error"||eventStatus==="dead_letter";
  await rpc(supabaseUrl,authHeaders,"record_outreach_sync_state_system",{
    p_workspace_id:workspaceId,p_provider:provider,p_cursor:cursor,p_status:failed?"error":"healthy",
    p_error:failed?(typeof data.error==="string"?data.error:eventStatus):null,
    p_details:{last_event_status:eventStatus,last_event_id:data.event_id??null}
  });

  if(failed) return json(500,{accepted:false,...data});
  if(eventStatus==="pending_content") return json(202,{accepted:true,...data,resend_email_id:resendEmailId});
  return json(201,{accepted:true,...data});
});

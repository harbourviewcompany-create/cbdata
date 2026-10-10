/**
 * Safely prepares local property-manager records for CBData review.
 * NO network calls, database writes, email sends, or inferred marketing consent.
 * Keep customer inputs and generated output out of this public repository.
 * Usage: node scripts/property-manager-reconcile.mjs --input private.json --output private-directory
 */
import { readFileSync, mkdirSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

export const emailKey = (v) => {
  const s = String(v ?? "").trim().toLowerCase();
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s) ? s : null;
};
export const nameKey = (v) => String(v ?? "").normalize("NFKC")
  .toLocaleLowerCase("en-CA").replace(/&/g, " and ")
  .replace(/[^\p{L}\p{N}]+/gu, " ").replace(/\s+/g, " ").trim();
const trim = (v, n = 1000) => String(v ?? "").trim().slice(0, n);
const csv = (rows, fields) => {
  const cell = (v) => {
    let s = String(v ?? "");
    if (/^\s*[=+@\-\t\r]/.test(s)) s = "'" + s; // CSV spreadsheet formula injection guard
    return '"' + s.replace(/"/g, '""') + '"';
  };
  return fields.join(",") + "\n" + rows.map(r => fields.map(f => cell(r[f])).join(",")).join("\n") + "\n";
};

export function reconcile(input) {
  if (!Array.isArray(input?.companies) || !Array.isArray(input?.drafts))
    throw new Error("Expected private JSON with companies[] and drafts[].");
  const accounts = [], drafts = [], properties = [], review_flags = [];
  const byName = new Map(), byEmail = new Map(), seenIDs = new Set(), seenRecipients = new Set();
  for (const raw of input.companies) {
    const lead_id = trim(raw.id, 100), company = trim(raw.company, 240);
    const name_key = nameKey(company), email = emailKey(raw.email) || "";
    if (!lead_id || !name_key || seenIDs.has(lead_id)) {
      review_flags.push({type:"invalid_or_duplicate_company_id",company,email,detail:lead_id});
      continue;
    }
    seenIDs.add(lead_id);
    const account = {lead_id,company,name_key,email,phone:trim(raw.phone,100),
      priority:trim(raw.priority,10)||"P3",verification:trim(raw.verification,300),
      source_url:trim(raw.source_url,1200),research_action:trim(raw.research_action,500),
      pipeline_stage:"research",consent_status:"unassessed",send_eligible:"NO",draft_count:0};
    if (byName.has(name_key)) review_flags.push({
      type:"name_collision_manual_review",company,email,detail:"Check " + byName.get(name_key).lead_id
    });
    else byName.set(name_key, account);
    if (email) {
      const owners = byEmail.get(email) || new Set(); owners.add(name_key); byEmail.set(email,owners);
    }
    accounts.push(account);
  }
  for (const [email,owners] of byEmail) if (owners.size > 1)
    review_flags.push({type:"email_used_by_multiple_companies",company:[...owners].join(" | "),email,detail:"Do not merge automatically"});
  for (const raw of input.drafts) {
    const company = trim(raw.company,240), recipient_email = emailKey(raw.email);
    const gmail_draft_url = trim(raw.gmail_draft_url,1500), stage = trim(raw.stage,50)||"Drafted";
    if (!company || !recipient_email || !/^https:\/\/mail\.google\.com\//i.test(gmail_draft_url)) {
      review_flags.push({type:"invalid_draft",company,email:recipient_email||"",detail:"Missing recipient or valid Gmail link"});
      continue;
    }
    if (seenRecipients.has(recipient_email))
      review_flags.push({type:"duplicate_recipient",company,email:recipient_email,detail:"Review existing draft"});
    seenRecipients.add(recipient_email);
    const key = nameKey(company), owners = byEmail.get(recipient_email);
    const match = byName.get(key) || (owners?.size===1 ? byName.get([...owners][0]) : null);
    if (!match) review_flags.push({type:"unmatched_draft_account",company,email:recipient_email,detail:"Manual account mapping required"});
    else {
      match.draft_count += 1;
      if (match.name_key !== key) review_flags.push({type:"company_name_mismatch",company,email:recipient_email,detail:"Matched via email to "+match.company});
    }
    drafts.push({company,recipient_email,lead_id:match?.lead_id||"",subject:trim(raw.subject,500),
      gmail_draft_url,draft_stage:stage,priority:trim(raw.priority,10)||"P2",
      owner:trim(raw.owner,100)||"Tyler",consent_status:"unassessed",
      send_eligible:"NO",suppression_review:"required",
      next_action:stage.toLowerCase()==="on hold"
        ? "Coordinate prior account contact; no duplicate send"
        : "Verify consent evidence, suppression list and sent-mail history",
      contact_source_url:trim(raw.contact_source,1200)});
  }
  for (const raw of (Array.isArray(input.properties) ? input.properties : [])) {
    const property = trim(raw.property,250), manager = trim(raw.manager,250);
    if (!property || !manager) {
      review_flags.push({type:"property_missing_manager",company:manager,email:"",detail:property});
      continue;
    }
    properties.push({property,manager,location:trim(raw.location,500),
      matched_lead_id:byName.get(nameKey(manager))?.lead_id||"",
      property_type:trim(raw.property_type,100),source_url:trim(raw.source_url,1200),
      evidence_caveat:trim(raw.evidence_caveat,1000),stage:"research",
      open_job_confirmed:"NO",next_action:"Confirm manager and request a defined work order"});
  }
  return {schema_version:1,summary:{company_records:accounts.length,
    staged_drafts:drafts.length,staged_properties:properties.length,
    matched_drafts:drafts.filter(d=>d.lead_id).length,
    no_public_email:accounts.filter(a=>!a.email).length,review_flags:review_flags.length,
    all_sends_blocked:true,db_mutation_performed:false,provider_sync_performed:false},
    accounts,drafts,properties,review_flags};
}

export function writePackage(plan, out) {
  mkdirSync(out, {recursive:true});
  const write = (name, value) => writeFileSync(resolve(out,name),value);
  write("accounts.csv",csv(plan.accounts,["lead_id","company","email","phone","priority","verification","source_url","consent_status","send_eligible","draft_count"]));
  write("gmail_draft_ledger.csv",csv(plan.drafts,["company","recipient_email","lead_id","subject","gmail_draft_url","draft_stage","priority","consent_status","suppression_review","send_eligible","next_action"]));
  write("properties.csv",csv(plan.properties,["property","location","manager","matched_lead_id","property_type","source_url","evidence_caveat","open_job_confirmed"]));
  write("manual_review.csv",csv(plan.review_flags,["type","company","email","detail"]));
  write("summary.json",JSON.stringify(plan.summary,null,2)+"\n");
  write("staging.json",JSON.stringify(plan,null,2)+"\n");
}
if (process.argv[1] && resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  const arg = (flag) => {const i=process.argv.indexOf(flag);return i<0?null:process.argv[i+1];};
  const input=arg("--input"),output=arg("--output");
  if (!input||!output) {console.error("Usage: --input PRIVATE.json --output PRIVATE_DIR");process.exitCode=2;}
  else {
    const plan=reconcile(JSON.parse(readFileSync(resolve(input),"utf8")));
    writePackage(plan,resolve(output));
    console.log(JSON.stringify(plan.summary));
  }
}

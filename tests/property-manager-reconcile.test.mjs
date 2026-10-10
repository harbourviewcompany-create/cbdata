import test from "node:test";
import assert from "node:assert/strict";
import {reconcile,emailKey,nameKey} from "../scripts/property-manager-reconcile.mjs";
const d={company:"Acme Management",email:"Office@Acme.CA",subject:"repairs",stage:"Drafted",
  gmail_draft_url:"https://mail.google.com/mail/u/0/#drafts/abc"};
test("matches exact accounts and never infers marketing consent",()=>{
  const r=reconcile({companies:[{id:"PC-1",company:"Acme Management",email:"office@acme.ca"}],drafts:[d]});
  assert.equal(r.summary.matched_drafts,1);
  assert.equal(r.accounts[0].consent_status,"unassessed");
  assert.equal(r.drafts[0].send_eligible,"NO");
  assert.equal(r.summary.db_mutation_performed,false);
});
test("similar companies stay separate",()=>{
  const r=reconcile({companies:[{id:"a",company:"613 Property Management"},
    {id:"b",company:"613 Property Management Filmer Chu"}],drafts:[]});
  assert.equal(r.accounts.length,2);
  assert.notEqual(nameKey(r.accounts[0].company),nameKey(r.accounts[1].company));
});
test("shared recipient email is flagged for manual review",()=>{
  const r=reconcile({companies:[{id:"a",company:"A Inc",email:"info@same.ca"},
    {id:"b",company:"B Inc",email:"info@same.ca"}],drafts:[]});
  assert.ok(r.review_flags.some(i=>i.type==="email_used_by_multiple_companies"));
});
test("invalid recipient or unsafe Gmail link never stages a draft",()=>{
  const r=reconcile({companies:[],drafts:[{...d,gmail_draft_url:"https://example.net/phish"},
    {...d,email:"not-an-email"}]});
  assert.equal(r.drafts.length,0);
  assert.equal(r.review_flags.length,2);
  assert.equal(emailKey("not-an-email"),null);
});
test("hold status never becomes send-ready",()=>{
  const r=reconcile({companies:[],drafts:[{...d,stage:"On hold"}]});
  assert.match(r.drafts[0].next_action,/no duplicate send/);
  assert.equal(r.drafts[0].send_eligible,"NO");
});
test("unconfirmed properties are not advertised as open work",()=>{
  const r=reconcile({companies:[{id:"c",company:"Acme Management"}],drafts:[],
    properties:[{property:"1 Main",manager:"Acme Management"}]});
  assert.equal(r.properties[0].matched_lead_id,"c");
  assert.equal(r.properties[0].open_job_confirmed,"NO");
});

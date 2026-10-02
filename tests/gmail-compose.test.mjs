import test from "node:test";
import assert from "node:assert/strict";

import { gmailComposeUrl, replySubject } from "../src/lib/gmail-compose.ts";

test("gmailComposeUrl opens Gmail compose with encoded recipient subject and body",()=>{
  const url=gmailComposeUrl(
    "brian@example.com",
    "CB Contracting — subcontractor coverage",
    "Hi Brian,\n\nCan you send the scope?"
  );
  assert.ok(url);
  const parsed=new URL(url);
  assert.equal(parsed.origin,"https://mail.google.com");
  assert.equal(parsed.searchParams.get("view"),"cm");
  assert.equal(parsed.searchParams.get("fs"),"1");
  assert.equal(parsed.searchParams.get("to"),"brian@example.com");
  assert.equal(parsed.searchParams.get("su"),"CB Contracting — subcontractor coverage");
  assert.equal(parsed.searchParams.get("body"),"Hi Brian,\n\nCan you send the scope?");
});

test("gmailComposeUrl returns null without an address",()=>{
  assert.equal(gmailComposeUrl(null,"Subject","Body"),null);
  assert.equal(gmailComposeUrl("   ","Subject","Body"),null);
});

test("replySubject adds Re only once",()=>{
  assert.equal(replySubject("Scope request"),"Re: Scope request");
  assert.equal(replySubject("Re: Scope request"),"Re: Scope request");
  assert.equal(replySubject(null),"");
});

import test from "node:test";
import assert from "node:assert/strict";
import {
  customerNowAction,
  customerNowLane,
  customerNowScore,
  isSlowCycleCandidate,
  rankCustomerNow,
} from "../src/lib/customer-now.ts";

test("positive inbound replies are first priority", () => {
  const hot = {
    organization_display_name: "Hot account",
    total_score: 40,
    command_score: 40,
    needs_response_count: 1,
    latest_reply_classification: "request_quote",
    contact_email: "buyer@example.com",
  };
  const cold = {
    organization_display_name: "Cold account",
    total_score: 95,
    command_score: 95,
    contact_email: "buyer@example.com",
    contact_phone: "613-555-0100",
    service_fit: ["snow"],
  };
  assert.equal(customerNowLane(hot), "reply_now");
  assert.ok(customerNowScore(hot) > customerNowScore(cold));
});

test("approved and quality-passed drafts become immediate send work", () => {
  assert.equal(
    customerNowLane({
      latest_draft_state: "approved",
      contact_email: "ops@example.com",
    }),
    "send_now",
  );
  assert.equal(
    customerNowLane({
      latest_draft_state: "draft",
      latest_draft_quality_passed: true,
      contact_email: "ops@example.com",
    }),
    "approve_now",
  );
});

test("phone beats new draft when a direct number exists", () => {
  const candidate = {
    contact_email: "ops@example.com",
    contact_phone: "613-555-0100",
  };
  assert.equal(customerNowLane(candidate), "call_now");
  assert.match(customerNowAction(candidate), /Call now/);
});

test("email-only direct contacts get a draft-now lane", () => {
  assert.equal(
    customerNowLane({ contact_email: "ops@example.com" }),
    "draft_now",
  );
});

test("long-cycle procurement work is penalized for immediate-customer ranking", () => {
  const fast = {
    organization_display_name: "Commercial property manager",
    total_score: 55,
    command_score: 55,
    contact_email: "ops@example.com",
    contact_phone: "613-555-0100",
    service_fit: ["grounds"],
    next_action: "Ask for one current repair overflow item",
  };
  const slow = {
    ...fast,
    organization_display_name: "Public procurement",
    next_action: "Monitor formal procurement and supplier registration",
    service_fit: [],
  };
  assert.equal(isSlowCycleCandidate(slow), true);
  assert.ok(customerNowScore(fast) > customerNowScore(slow));
});

test("ranking favors direct, service-fit private work over research-only work", () => {
  const ranked = rankCustomerNow([
    {
      organization_display_name: "Research account",
      total_score: 80,
      command_score: 80,
      stage: "research",
      next_action: "Monitor tender portal",
    },
    {
      organization_display_name: "Direct account",
      total_score: 55,
      command_score: 55,
      stage: "contact_ready",
      contact_email: "pm@example.com",
      contact_phone: "613-555-0100",
      service_fit: ["snow", "grounds"],
      high_signal_property_count: 2,
    },
  ]);
  assert.equal(ranked[0].organization_display_name, "Direct account");
});

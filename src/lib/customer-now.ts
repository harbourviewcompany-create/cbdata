export type CustomerNowCandidate = {
  organization_display_name?: string | null;
  stage?: string | null;
  pursuit_status?: string | null;
  next_action?: string | null;
  why_now?: string | null;
  contact_email?: string | null;
  contact_phone?: string | null;
  contact_coverage_score?: number | null;
  high_signal_property_count?: number | null;
  open_signal_count?: number | null;
  service_fit?: string[] | null;
  total_score?: number | string | null;
  command_score?: number | string | null;
  needs_response_count?: number | null;
  latest_reply_classification?: string | null;
  latest_draft_state?: string | null;
  latest_draft_quality_passed?: boolean | null;
  latest_draft_channel?: string | null;
  opportunity_id?: string | null;
};

export type CustomerNowLane =
  | "reply_now"
  | "send_now"
  | "approve_now"
  | "call_now"
  | "draft_now"
  | "research";

const POSITIVE_REPLIES = new Set([
  "interested",
  "request_quote",
  "request_call",
  "site_visit_request",
  "referral",
  "send_information",
]);

const SLOW_CYCLE_TERMS = [
  "procurement",
  "tender",
  "registration",
  "register",
  "rfp",
  "rfsq",
  "standing offer",
  "supplier portal",
  "monitor formal",
  "vendor package",
  "bonfire",
  "merx",
];

function n(value: number | string | null | undefined) {
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

function text(candidate: CustomerNowCandidate) {
  return [
    candidate.next_action,
    candidate.why_now,
    candidate.organization_display_name,
  ]
    .filter(Boolean)
    .join(" ")
    .toLowerCase();
}

export function isSlowCycleCandidate(candidate: CustomerNowCandidate) {
  const haystack = text(candidate);
  return SLOW_CYCLE_TERMS.some((term) => haystack.includes(term));
}

export function customerNowLane(candidate: CustomerNowCandidate): CustomerNowLane {
  const reply = candidate.latest_reply_classification ?? "";
  if ((candidate.needs_response_count ?? 0) > 0 && POSITIVE_REPLIES.has(reply)) return "reply_now";
  if ((candidate.needs_response_count ?? 0) > 0) return "reply_now";
  if (candidate.latest_draft_state === "approved") return "send_now";
  if (candidate.latest_draft_state === "draft" && candidate.latest_draft_quality_passed) return "approve_now";
  if (candidate.contact_phone) return "call_now";
  if (candidate.contact_email) return "draft_now";
  return "research";
}

export function customerNowAction(candidate: CustomerNowCandidate) {
  switch (customerNowLane(candidate)) {
    case "reply_now":
      return "Respond now and book a call, site walk, or quote before doing more outbound.";
    case "send_now":
      return "Send the approved message now, then call the contact while the account is fresh.";
    case "approve_now":
      return "Approve the evidence-backed draft, send it now, then make the matching call.";
    case "call_now":
      return "Call now. Ask for one current small job, service gap, or same-week site walk.";
    case "draft_now":
      return "Generate a one-site quote/site-walk message and send it today.";
    default:
      return "Find a direct operations, property, facilities, or board contact before outreach.";
  }
}

export function customerNowScore(candidate: CustomerNowCandidate) {
  const reply = candidate.latest_reply_classification ?? "";
  const hasPositiveReply =
    (candidate.needs_response_count ?? 0) > 0 && POSITIVE_REPLIES.has(reply);

  let score = Math.round(n(candidate.total_score) * 0.35 + n(candidate.command_score) * 0.15);

  if (hasPositiveReply) score += 45;
  else if ((candidate.needs_response_count ?? 0) > 0) score += 20;

  if (candidate.contact_email) score += 18;
  if (candidate.contact_phone) score += 16;
  if (candidate.contact_email && candidate.contact_phone) score += 6;

  if (n(candidate.contact_coverage_score) >= 75) score += 10;
  else if (n(candidate.contact_coverage_score) >= 50) score += 7;
  else if (n(candidate.contact_coverage_score) >= 25) score += 3;

  if (n(candidate.high_signal_property_count) > 0) score += 8;
  if (n(candidate.open_signal_count) > 0) score += 5;
  if ((candidate.service_fit?.length ?? 0) > 0) score += 7;

  if (candidate.latest_draft_state === "approved") score += 14;
  else if (candidate.latest_draft_state === "draft" && candidate.latest_draft_quality_passed) score += 10;

  if (candidate.stage === "contact_ready" || candidate.stage === "outreach") score += 6;
  if (candidate.opportunity_id) score += 8;

  if (!candidate.contact_email && !candidate.contact_phone) score -= 24;
  if ((candidate.service_fit?.length ?? 0) === 0 && !hasPositiveReply) score -= 8;
  if (candidate.stage === "research") score -= 8;
  if (isSlowCycleCandidate(candidate) && !hasPositiveReply) score -= 25;

  return Math.max(0, Math.min(100, score));
}

export function rankCustomerNow<T extends CustomerNowCandidate>(candidates: T[]) {
  return [...candidates].sort((a, b) => {
    const scoreDelta = customerNowScore(b) - customerNowScore(a);
    if (scoreDelta !== 0) return scoreDelta;

    const laneOrder: Record<CustomerNowLane, number> = {
      reply_now: 0,
      send_now: 1,
      approve_now: 2,
      call_now: 3,
      draft_now: 4,
      research: 5,
    };
    return laneOrder[customerNowLane(a)] - laneOrder[customerNowLane(b)];
  });
}

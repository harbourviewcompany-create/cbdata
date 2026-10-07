// Role checks for edge functions that act with the service role.
// Service-role writes bypass RLS, so membership alone is not enough: the caller's
// role must be one the matching server action / RLS policy would also allow.
// Keep these lists in sync with ROLES in src/lib/authz.ts and with the write
// policies in 20260930120000_role_based_write_policies_procurement_outreach.sql.

export const PROCUREMENT_ROLES = [
  "owner", "administrator", "operations_manager", "sales_manager", "sales_rep",
] as const;

export const PROCUREMENT_LEAD_ROLES = [
  "owner", "administrator", "operations_manager", "sales_manager",
] as const;

export type Membership = { workspace_id: string; role: string };

export type MembershipDecision =
  | { ok: true; workspaceId: string; role: string }
  | { ok: false; status: 403; error: "workspace_access_denied" | "insufficient_role" };

/**
 * Pick the workspace a request may act in.
 * - requestedWorkspace given: only that workspace is considered.
 * - not given: the first workspace where the caller has an allowed role
 *   (never a workspace where they lack the role).
 * Fails closed: no membership -> workspace_access_denied; membership present but
 * role not allowed -> insufficient_role.
 */
export function authorizeMembership(
  memberships: readonly Membership[] | null | undefined,
  requestedWorkspace: string | null,
  allowedRoles: readonly string[],
): MembershipDecision {
  const candidates = (memberships ?? []).filter(
    (m) => !!m?.workspace_id && (!requestedWorkspace || m.workspace_id === requestedWorkspace),
  );
  if (candidates.length === 0) {
    return { ok: false, status: 403, error: "workspace_access_denied" };
  }
  const allowed = candidates.find((m) => allowedRoles.includes(m.role));
  if (!allowed) return { ok: false, status: 403, error: "insufficient_role" };
  return { ok: true, workspaceId: allowed.workspace_id, role: allowed.role };
}

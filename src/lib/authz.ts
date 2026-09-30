import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/lib/database.types";

export type WorkspaceRole = Database["public"]["Enums"]["membership_role"];

export async function requireWorkspaceRole(
  supabase: SupabaseClient<Database>,
  workspaceId: string,
  allowedRoles: readonly WorkspaceRole[],
) {
  if (!workspaceId) throw new Error("Workspace is required");

  // Verify the caller with the auth server; never trust an unverified session.
  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();
  if (userError || !user) throw new Error("Unauthorized");

  // RLS lets every member read every membership row in the workspace,
  // so the query MUST be scoped to the caller. Without user_id this returns
  // one row per member and maybeSingle() errors (or picks the wrong role).
  const { data, error } = await supabase
    .from("workspace_memberships")
    .select("role")
    .eq("workspace_id", workspaceId)
    .eq("user_id", user.id)
    .eq("status", "active")
    .limit(2);

  if (error) throw new Error(error.message);
  // Fail closed: zero rows = not a member; more than one = corrupt data.
  if (!data || data.length !== 1) {
    throw new Error("You do not have permission to perform this action");
  }
  const role = data[0].role;
  if (!allowedRoles.includes(role)) {
    throw new Error("You do not have permission to perform this action");
  }
  return role;
}

export const ROLES = {
  admin: ["owner", "administrator"] as const,
  operations: ["owner", "administrator", "operations_manager", "operations_supervisor"] as const,
  dispatch: ["owner", "administrator", "operations_manager", "operations_supervisor", "field_supervisor"] as const,
  field: ["owner", "administrator", "operations_manager", "operations_supervisor", "field_supervisor", "field_worker"] as const,
  sales: ["owner", "administrator", "sales_manager", "sales_rep"] as const,
  contracts: ["owner", "administrator", "operations_manager", "sales_manager"] as const,
  finance: ["owner", "administrator", "finance", "operations_manager"] as const,
  people: ["owner", "administrator", "operations_manager"] as const,
} satisfies Record<string, readonly WorkspaceRole[]>;

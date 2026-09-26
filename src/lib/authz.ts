import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/lib/database.types";

export type WorkspaceRole = Database["public"]["Enums"]["membership_role"];

export async function requireWorkspaceRole(
  supabase: SupabaseClient<Database>,
  workspaceId: string,
  allowedRoles: readonly WorkspaceRole[],
) {
  if (!workspaceId) throw new Error("Workspace is required");
  const { data, error } = await supabase
    .from("workspace_memberships")
    .select("role")
    .eq("workspace_id", workspaceId)
    .eq("status", "active")
    .maybeSingle();

  if (error) throw new Error(error.message);
  if (!data || !allowedRoles.includes(data.role)) {
    throw new Error("You do not have permission to perform this action");
  }
  return data.role;
}

export const ROLES = {
  admin: ["owner", "administrator"] as const,
  operations: ["owner", "administrator", "operations_manager", "operations_supervisor"] as const,
  dispatch: ["owner", "administrator", "operations_manager", "operations_supervisor", "field_supervisor"] as const,
  field: ["owner", "administrator", "operations_manager", "operations_supervisor", "field_supervisor", "field_worker"] as const,
  sales: ["owner", "administrator", "sales_manager", "sales_rep"] as const,
  contracts: ["owner", "administrator", "operations_manager", "sales_manager"] as const,
} satisfies Record<string, readonly WorkspaceRole[]>;

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export type WorkspaceContext = {
  user: { id: string; email?: string | null };
  workspaceId: string;
  workspaceName: string;
  role: string | null;
};

export async function requireUser() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");
  return { supabase, user };
}

export async function getWorkspaceContext(): Promise<WorkspaceContext | null> {
  const { supabase, user } = await requireUser();

  const { data: memberships } = await supabase
    .from("workspace_memberships")
    .select("workspace_id, role, workspaces(id,name,status)")
    .eq("user_id", user.id);

  const row = memberships?.[0];
  const workspace = row?.workspaces as
    | { id?: string; name?: string }
    | { id?: string; name?: string }[]
    | null
    | undefined;
  const workspaceId = Array.isArray(workspace)
    ? workspace[0]?.id
    : workspace?.id;
  const workspaceName = Array.isArray(workspace)
    ? workspace[0]?.name
    : workspace?.name;

  if (!workspaceId) return null;

  return {
    user: { id: user.id, email: user.email },
    workspaceId: String(workspaceId),
    workspaceName: String(workspaceName ?? "Workspace"),
    role: row?.role ? String(row.role) : null,
  };
}

/** Auth + workspace membership required; redirects to login if signed out. */
export async function requireWorkspace(): Promise<WorkspaceContext> {
  const ctx = await getWorkspaceContext();
  if (!ctx) {
    // Signed in but no membership — still return a typed failure via redirect to dashboard empty state
    redirect("/dashboard");
  }
  return ctx;
}

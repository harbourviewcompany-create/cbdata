import { cache } from "react";
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

type MembershipRow = {
  workspace_id: string;
  role: string | null;
  workspaces:
    | { id?: string; name?: string; status?: string }
    | { id?: string; name?: string; status?: string }[]
    | null;
};

function unwrapWorkspace(
  workspace: MembershipRow["workspaces"],
): { id?: string; name?: string } | null {
  if (!workspace) return null;
  return Array.isArray(workspace) ? workspace[0] ?? null : workspace;
}

export const getWorkspaceContext = cache(async (): Promise<WorkspaceContext | null> => {
  const { supabase, user } = await requireUser();

  const { data: memberships } = await supabase
    .from("workspace_memberships")
    .select("workspace_id, role, workspaces(id,name,status)")
    .eq("user_id", user.id)
    .eq("status", "active");

  const rows = (memberships ?? []) as MembershipRow[];
  if (!rows.length) return null;

  const { data: profile } = await supabase
    .from("user_profiles")
    .select("active_workspace_id")
    .eq("id", user.id)
    .maybeSingle();

  const preferredId = (profile as { active_workspace_id?: string | null } | null)
    ?.active_workspace_id ?? null;
  const preferred = preferredId
    ? rows.find((r) => r.workspace_id === preferredId)
    : undefined;
  const row = preferred ?? rows[0];
  const workspace = unwrapWorkspace(row.workspaces);
  const workspaceId = String(workspace?.id ?? row.workspace_id);
  if (!workspaceId) return null;

  if (preferredId !== workspaceId) {
    await supabase.from("user_profiles").upsert(
      {
        id: user.id,
        active_workspace_id: workspaceId,
      } as never,
      { onConflict: "id" },
    );
  }

  return {
    user: { id: user.id, email: user.email },
    workspaceId,
    workspaceName: String(workspace?.name ?? "Workspace"),
    role: row.role ? String(row.role) : null,
  };
});

/** Auth + workspace membership required; redirects to login if signed out. */
export async function requireWorkspace(): Promise<WorkspaceContext> {
  const ctx = await getWorkspaceContext();
  if (!ctx) {
    redirect("/dashboard");
  }
  return ctx;
}

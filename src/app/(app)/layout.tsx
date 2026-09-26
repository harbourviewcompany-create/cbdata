import { redirect } from "next/navigation";
import { AppShell } from "@/components/AppShell";
import { createClient } from "@/lib/supabase/server";

export default async function AppLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

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
  const workspaceName = Array.isArray(workspace)
    ? workspace[0]?.name
    : workspace?.name;

  return (
    <AppShell
      workspaceName={workspaceName ?? "CB Contracting"}
      userEmail={user.email}
      role={row?.role ? String(row.role) : null}
    >
      {children}
    </AppShell>
  );
}

import { AppShell } from "@/components/AppShell";
import { getWorkspaceContext } from "@/lib/workspace";

export default async function AppLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const ctx = await getWorkspaceContext();

  return (
    <AppShell
      workspaceName={ctx?.workspaceName ?? "CB Contracting"}
      userEmail={ctx?.user.email}
      role={ctx?.role ?? null}
    >
      {children}
    </AppShell>
  );
}

"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireWorkspaceRole, ROLES } from "@/lib/authz";

const v = (f: FormData, k: string) => String(f.get(k) ?? "").trim();

export async function issueInvoice(f: FormData) {
  const s = await createClient();
  const id = v(f, "id");
  const { data: inv } = await s.from("invoices").select("workspace_id").eq("id", id).single();
  if (!inv) throw new Error("Invoice not found");
  await requireWorkspaceRole(s, inv.workspace_id, ROLES.finance);
  const { error } = await s.rpc("issue_invoice" as never, { p_invoice_id: id } as never);
  if (error) throw new Error(error.message);
  revalidatePath("/invoices");
  revalidatePath("/dashboard");
}

export async function recordPayment(f: FormData) {
  const s = await createClient();
  const id = v(f, "id");
  const amount = Number(v(f, "amount"));
  const { data: inv } = await s.from("invoices").select("workspace_id").eq("id", id).single();
  if (!inv) throw new Error("Invoice not found");
  await requireWorkspaceRole(s, inv.workspace_id, ROLES.finance);
  const { error } = await s.rpc("record_invoice_payment" as never, {
    p_invoice_id: id,
    p_amount: amount,
    p_method: v(f, "method") || "e_transfer",
  } as never);
  if (error) throw new Error(error.message);
  revalidatePath("/invoices");
  revalidatePath("/dashboard");
}

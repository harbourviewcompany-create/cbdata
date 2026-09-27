"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireWorkspace } from "@/lib/workspace";
import { requireWorkspaceRole, ROLES } from "@/lib/authz";

const v = (f: FormData, k: string) => String(f.get(k) ?? "").trim();

export async function createEmployee(f: FormData) {
  const ctx = await requireWorkspace();
  const s = await createClient();
  await requireWorkspaceRole(s, ctx.workspaceId, ROLES.people);
  const { error } = await s.from("employees").insert({
    workspace_id: ctx.workspaceId,
    first_name: v(f, "first_name") || "Unknown",
    last_name: v(f, "last_name") || "—",
    email: v(f, "email") || null,
    phone: v(f, "phone") || null,
    employment_type: (v(f, "employment_type") || "employee") as "employee" | "contractor",
    employment_status: "active",
    hire_date: v(f, "hire_date") || null,
  });
  if (error) throw new Error(error.message);
  revalidatePath("/crew");
}

export async function createCrew(f: FormData) {
  const ctx = await requireWorkspace();
  const s = await createClient();
  await requireWorkspaceRole(s, ctx.workspaceId, ROLES.people);
  const { error } = await s.from("crews").insert({
    workspace_id: ctx.workspaceId,
    name: v(f, "name") || "Crew",
    crew_type: v(f, "crew_type") || null,
    status: "active",
    supervisor_employee_id: v(f, "supervisor_employee_id") || null,
  });
  if (error) throw new Error(error.message);
  revalidatePath("/crew");
  revalidatePath("/dispatch");
}

export async function addCrewMember(f: FormData) {
  const ctx = await requireWorkspace();
  const s = await createClient();
  await requireWorkspaceRole(s, ctx.workspaceId, ROLES.people);
  const crewId = v(f, "crew_id");
  const employeeId = v(f, "employee_id");
  if (!crewId || !employeeId) throw new Error("Crew and employee required");
  const { error } = await s.from("crew_members").insert({
    workspace_id: ctx.workspaceId,
    crew_id: crewId,
    employee_id: employeeId,
    start_date: v(f, "start_date") || new Date().toISOString().slice(0, 10),
  });
  if (error) throw new Error(error.message);
  revalidatePath("/crew");
  revalidatePath("/dispatch");
}

"use server";
import { randomUUID } from "crypto"; import { revalidatePath } from "next/cache"; import { createClient } from "@/lib/supabase/server"; import { requireWorkspaceRole, ROLES } from "@/lib/authz";
const v=(f:FormData,k:string)=>String(f.get(k)??"").trim(); async function auth(){const s=await createClient();const {data:{user}}=await s.auth.getUser();if(!user)throw new Error("Unauthorized");return s;}
export async function createContract(f:FormData){const s=await auth();const property_id=v(f,"property_id"),organization_id=v(f,"organization_id"),start=v(f,"start_date"),end=v(f,"end_date");const {data:p}=await s.from("properties").select("workspace_id").eq("id",property_id).single();if(!p)throw new Error("Property not found");await requireWorkspaceRole(s,p.workspace_id,ROLES.contracts);const {data:o}=await s.from("organizations").select("id").eq("id",organization_id).eq("workspace_id",p.workspace_id).single();if(!o)throw new Error("Customer not found in workspace");const value=Number(v(f,"contract_value"));if(!start||!v(f,"name")||!Number.isFinite(value)||value<0)throw new Error("Contract name, start date and valid value required");if(end&&new Date(end)<new Date(start))throw new Error("Invalid contract dates");const {error}=await s.from("contracts").insert({workspace_id:p.workspace_id,contract_number:`CTR-${new Date().toISOString().slice(0,10).replaceAll("-","")}-${randomUUID().slice(0,8).toUpperCase()}`,organization_id,property_id,name:v(f,"name"),status:"draft",start_date:start,end_date:end||null,contract_value:value,billing_frequency:v(f,"billing_frequency")||null,renewal_type:v(f,"renewal_type")||null});if(error)throw new Error(error.message);revalidatePath("/contracts");}
export async function renewContract(f:FormData){const s=await auth();const id=v(f,"id"),start=v(f,"start_date"),end=v(f,"end_date");const {data:c}=await s.from("contracts").select("workspace_id,status,contract_value,billing_frequency,renewal_type").eq("id",id).single();if(!c)throw new Error("Contract not found");await requireWorkspaceRole(s,c.workspace_id,ROLES.contracts);if(!["active","expired","renewal_pending"].includes(c.status))throw new Error("Contract is not eligible for renewal");if(!start||(end&&new Date(end)<new Date(start)))throw new Error("Invalid renewal dates");const value=Number(v(f,"contract_value"));const {error}=await s.from("contracts").update({status:"renewal_pending",start_date:start,end_date:end||null,contract_value:Number.isFinite(value)&&value>=0?value:c.contract_value,billing_frequency:v(f,"billing_frequency")||c.billing_frequency,renewal_type:v(f,"renewal_type")||c.renewal_type}).eq("id",id);if(error)throw new Error(error.message);revalidatePath("/contracts");}
export async function transitionContract(f:FormData){const s=await auth();const id=v(f,"id"),status=v(f,"status");const {data:c}=await s.from("contracts").select("workspace_id,status").eq("id",id).single();if(!c)throw new Error("Contract not found");await requireWorkspaceRole(s,c.workspace_id,ROLES.contracts);const a:Record<string,string[]>={draft:["pending_signature","terminated"],pending_signature:["active","draft","terminated"],active:["suspended","expired","terminated","renewal_pending"],suspended:["active","terminated"],expired:["renewal_pending","terminated"],renewal_pending:["active","terminated"],terminated:[]};if(!a[c.status]?.includes(status))throw new Error("Invalid contract transition");const patch:any={status};if(status==="terminated")patch.terminated_at=new Date().toISOString();const {error}=await s.from("contracts").update(patch).eq("id",id);if(error)throw new Error(error.message);revalidatePath("/contracts");}
export async function generateWorkOrdersFromContract(f: FormData) {
  const s = await auth();
  const id = v(f, "id");
  const days = Number(v(f, "days_ahead") || "14");
  if (!id) throw new Error("Contract required");
  const { data: c } = await s.from("contracts").select("workspace_id,status").eq("id", id).single();
  if (!c) throw new Error("Contract not found");
  await requireWorkspaceRole(s, c.workspace_id, ROLES.operations);
  const { data, error } = await s.rpc("generate_work_orders_from_contract" as never, {
    p_contract_id: id,
    p_days_ahead: Number.isFinite(days) ? days : 14,
  } as never);
  if (error) throw new Error(error.message);
  revalidatePath("/contracts");
  revalidatePath("/work-orders");
  revalidatePath("/dispatch");
  revalidatePath("/dashboard");
  return data as number;
}

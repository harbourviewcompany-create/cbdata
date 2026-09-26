"use server";
import { randomUUID } from "crypto";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireWorkspaceRole, ROLES } from "@/lib/authz";

const v=(f:FormData,k:string)=>String(f.get(k)??"").trim();
async function auth(){const s=await createClient();const {data:{user}}=await s.auth.getUser();if(!user)throw new Error("Unauthorized");return{s,user};}

export async function createWorkOrder(f:FormData){
 const {s,user}=await auth(); const property_id=v(f,"property_id");
 const {data:p}=await s.from("properties").select("workspace_id").eq("id",property_id).single();
 if(!p)throw new Error("Property not found");
 await requireWorkspaceRole(s,p.workspace_id,ROLES.operations);
 const start=v(f,"scheduled_start"),end=v(f,"scheduled_end");
 if(end&&(!start||new Date(end)<=new Date(start)))throw new Error("Invalid schedule");
 const duration=Number(v(f,"estimated_duration_minutes"));
 if(v(f,"estimated_duration_minutes")&&(!Number.isFinite(duration)||duration<=0))throw new Error("Invalid duration");
 const {error}=await s.from("work_orders").insert({workspace_id:p.workspace_id,work_order_number:`WO-${new Date().toISOString().slice(0,10).replaceAll("-","")}-${randomUUID().slice(0,8).toUpperCase()}`,property_id,source_type:(v(f,"source_type")||"manual") as any,priority:(v(f,"priority")||"normal") as any,status:start?"scheduled":"draft",scheduled_start:start||null,scheduled_end:end||null,estimated_duration_minutes:duration||null,description:v(f,"description"),site_instructions:v(f,"site_instructions")||null,created_by:user.id});
 if(error)throw new Error(error.message); revalidatePath("/work-orders");revalidatePath("/dispatch");
}

export async function scheduleWorkOrder(f:FormData){
 const {s}=await auth();const id=v(f,"id"),start=v(f,"scheduled_start"),end=v(f,"scheduled_end");
 if(!id||!start)throw new Error("Work order and start required");if(end&&new Date(end)<=new Date(start))throw new Error("Invalid schedule");
 const {data:w}=await s.from("work_orders").select("workspace_id,status").eq("id",id).single();if(!w)throw new Error("Work order not found");
 await requireWorkspaceRole(s,w.workspace_id,ROLES.dispatch);
 if(!["draft","scheduled","assigned","paused"].includes(w.status))throw new Error("Work order cannot be scheduled from its current state");
 const {error}=await s.from("work_orders").update({scheduled_start:start,scheduled_end:end||null,status:"scheduled"}).eq("id",id);if(error)throw new Error(error.message);
 revalidatePath("/work-orders");revalidatePath("/dispatch");
}

export async function assignWorkOrder(f:FormData){
 const {s}=await auth();const id=v(f,"id"),type=v(f,"assignment_type"),resource=v(f,"resource_id");
 if(!["crew","employee","contractor","equipment"].includes(type)||!resource)throw new Error("Valid resource required");
 const {data:w}=await s.from("work_orders").select("workspace_id,scheduled_start,scheduled_end,status").eq("id",id).single();if(!w)throw new Error("Work order not found");
 await requireWorkspaceRole(s,w.workspace_id,ROLES.dispatch);
 if(!w.scheduled_start)throw new Error("Schedule the work order before assigning resources");
 const table=type==="crew"?"crews":type==="employee"?"employees":type==="contractor"?"contractors":"equipment";
 const {data:r}=await s.from(table).select("id").eq("id",resource).eq("workspace_id",w.workspace_id).single();if(!r)throw new Error("Resource not found in workspace");
 const {error:cancelError}=await s.from("work_order_assignments").update({status:"cancelled",unassigned_at:new Date().toISOString()}).eq("work_order_id",id).is("unassigned_at",null);if(cancelError)throw new Error(cancelError.message);
 const payload:any={workspace_id:w.workspace_id,work_order_id:id,assignment_type:type,status:"assigned"};payload[type+"_id"]=resource;
 const {error}=await s.from("work_order_assignments").insert(payload);if(error)throw new Error(error.message);
 const {error:up}=await s.from("work_orders").update({status:"assigned"}).eq("id",id);if(up)throw new Error(up.message);
 revalidatePath("/work-orders");revalidatePath("/dispatch");
}

export async function startWorkOrder(f:FormData){
 const {s,user}=await auth();const id=v(f,"id");const {data:w}=await s.from("work_orders").select("workspace_id,status").eq("id",id).single();if(!w)throw new Error("Work order not found");
 await requireWorkspaceRole(s,w.workspace_id,ROLES.field);
 if(!["scheduled","assigned","en_route"].includes(w.status))throw new Error("Work order cannot start from its current state");
 const {data:a}=await s.from("work_visits").select("id").eq("work_order_id",id).is("ended_at",null).limit(1);
 if(!a?.length){const {error}=await s.from("work_visits").insert({workspace_id:w.workspace_id,work_order_id:id,started_at:new Date().toISOString(),created_by:user.id,completion_status:"in_progress"});if(error)throw new Error(error.message);}
 const {error}=await s.from("work_orders").update({status:"in_progress"}).eq("id",id);if(error)throw new Error(error.message);
 revalidatePath("/work-orders");revalidatePath("/dispatch");
}

export async function completeWorkOrder(f:FormData){
 const {s}=await auth();const id=v(f,"id");const {data:w}=await s.from("work_orders").select("workspace_id,status").eq("id",id).single();if(!w)throw new Error("Work order not found");
 await requireWorkspaceRole(s,w.workspace_id,ROLES.field);
 if(w.status!=="in_progress")throw new Error("Work order is not in progress");
 const {error}=await s.from("work_visits").update({ended_at:new Date().toISOString(),completion_status:"completed",notes:v(f,"notes")||null}).eq("work_order_id",id).is("ended_at",null);if(error)throw new Error(error.message);
 const {error:e}=await s.from("work_orders").update({status:"completed",completed_at:new Date().toISOString()}).eq("id",id);if(e)throw new Error(e.message);
 revalidatePath("/work-orders");revalidatePath("/dispatch");
}
export async function completeWorkOrderWithInvoice(f: FormData) {
  const { s } = await auth();
  const id = v(f, "id");
  if (!id) throw new Error("Work order required");
  const { data: w } = await s.from("work_orders").select("workspace_id,status").eq("id", id).single();
  if (!w) throw new Error("Work order not found");
  await requireWorkspaceRole(s, w.workspace_id, ROLES.field);
  const { data, error } = await s.rpc("complete_work_order_with_invoice" as never, {
    p_work_order_id: id,
  } as never);
  if (error) throw new Error(error.message);
  revalidatePath("/work-orders");
  revalidatePath("/dispatch");
  revalidatePath("/dashboard");
  void data;
}

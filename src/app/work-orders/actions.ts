"use server";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
export async function transitionWorkOrder(formData: FormData) {
 const s=await createClient(); const {data:{user}}=await s.auth.getUser(); if(!user) throw new Error("Unauthorized");
 const id=String(formData.get("id")); const status=String(formData.get("status"));
 const allowed=["draft","scheduled","assigned","en_route","in_progress","paused","completed","needs_review","approved","cancelled"]; if(!allowed.includes(status)) throw new Error("Invalid status");
 const patch:any={status}; if(status==="completed") patch.completed_at=new Date().toISOString(); if(status==="cancelled") patch.cancelled_at=new Date().toISOString();
 const {error}=await s.from("work_orders").update(patch).eq("id",id); if(error) throw new Error(error.message); revalidatePath("/work-orders"); revalidatePath("/dashboard");
}
export async function assignWorkOrder(formData: FormData) {
 const s=await createClient(); const {data:{user}}=await s.auth.getUser(); if(!user) throw new Error("Unauthorized");
 const id=String(formData.get("id")); const crew_id=String(formData.get("crew_id")); if(!crew_id) throw new Error("Crew required");
 const {data:wo}=await s.from("work_orders").select("workspace_id").eq("id",id).single(); if(!wo) throw new Error("Work order not found");
 const {error}=await s.from("work_order_assignments").insert({workspace_id:wo.workspace_id,work_order_id:id,assignment_type:"crew",crew_id,status:"assigned"});
 if(error) throw new Error(error.message); await s.from("work_orders").update({status:"assigned"}).eq("id",id); revalidatePath("/work-orders");
}
export async function startWorkOrder(formData: FormData) {
 const s=await createClient(); const {data:{user}}=await s.auth.getUser(); if(!user) throw new Error("Unauthorized");
 const id=String(formData.get("id")); const {data:wo}=await s.from("work_orders").select("workspace_id").eq("id",id).single(); if(!wo) throw new Error("Work order not found");
 const {error}=await s.from("work_visits").insert({workspace_id:wo.workspace_id,work_order_id:id,started_at:new Date().toISOString(),created_by:user.id,completion_status:"in_progress"});
 if(error) throw new Error(error.message); await s.from("work_orders").update({status:"in_progress"}).eq("id",id); revalidatePath("/work-orders");
}
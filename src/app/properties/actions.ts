"use server";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireWorkspaceRole, ROLES } from "@/lib/authz";
export async function updateProperty(formData: FormData) {
 const s=await createClient(); const {data:{user}}=await s.auth.getUser(); if(!user) throw new Error("Unauthorized");
 const id=String(formData.get("id")); const {data:p}=await s.from("properties").select("workspace_id").eq("id",id).single(); if(!p) throw new Error("Property not found");
 await requireWorkspaceRole(s,p.workspace_id,ROLES.operations);
 const {error}=await s.from("properties").update({name:String(formData.get("name")||"").trim(),site_notes:String(formData.get("site_notes")||"").trim()}).eq("id",id);
 if(error) throw new Error(error.message); revalidatePath("/properties");
}
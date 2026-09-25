"use server";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
export async function updateIssue(formData: FormData) {
 const s=await createClient(); const {data:{user}}=await s.auth.getUser(); if(!user) throw new Error("Unauthorized");
 const id=String(formData.get("id")); const status=String(formData.get("status"));
 if(!["open","in_progress","blocked","resolved","closed"].includes(status)) throw new Error("Invalid status");
 const patch:any={status}; if(status==="resolved"){patch.resolved_at=new Date().toISOString(); patch.resolution_notes=String(formData.get("resolution_notes")||"");}
 const {error}=await s.from("issues").update(patch).eq("id",id); if(error) throw new Error(error.message); revalidatePath("/issues"); revalidatePath("/dashboard");
}
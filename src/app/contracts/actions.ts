"use server";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
export async function transitionContract(formData: FormData) {
 const s=await createClient(); const {data:{user}}=await s.auth.getUser(); if(!user) throw new Error("Unauthorized");
 const id=String(formData.get("id")); const status=String(formData.get("status"));
 if(!["draft","pending_signature","active","suspended","expired","terminated","renewal_pending"].includes(status)) throw new Error("Invalid status");
 const {error}=await s.from("contracts").update({status:status as any}).eq("id",id); if(error) throw new Error(error.message); revalidatePath("/contracts"); revalidatePath("/dashboard");
}
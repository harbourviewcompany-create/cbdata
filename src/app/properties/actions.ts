"use server";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
export async function updateProperty(formData: FormData) {
 const s=await createClient(); const {data:{user}}=await s.auth.getUser(); if(!user) throw new Error("Unauthorized");
 const id=String(formData.get("id")); const {error}=await s.from("properties").update({name:String(formData.get("name")),site_notes:String(formData.get("site_notes")||"")}).eq("id",id);
 if(error) throw new Error(error.message); revalidatePath("/properties");
}
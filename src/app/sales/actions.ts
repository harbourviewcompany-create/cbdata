"use server";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
export async function transitionOpportunity(formData: FormData) {
 const s=await createClient(); const {data:{user}}=await s.auth.getUser(); if(!user) throw new Error("Unauthorized");
 const id=String(formData.get("id")); const stage=String(formData.get("stage"));
 if(!["new","qualified","site_visit","estimating","proposal","negotiation","won","lost"].includes(stage)) throw new Error("Invalid stage");
 const status=stage==="won"?"won":stage==="lost"?"lost":"open";
 const {error}=await s.from("opportunities").update({stage:stage as any,status:status as any,closed_at:stage==="won"||stage==="lost"?new Date().toISOString():null}).eq("id",id);
 if(error) throw new Error(error.message); revalidatePath("/sales"); revalidatePath("/dashboard");
}
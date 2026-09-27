"use client";

import { createBrowserClient } from "@supabase/ssr";
import type { Database } from "@/lib/database.types";

export function createBrowserSupabase() {
  return createBrowserClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
  );
}

export const SITE_PHOTOS_BUCKET = "site-photos";
export const SITE_DOCS_BUCKET = "site-docs";

export function siteObjectPath(
  workspaceId: string,
  entityType: string,
  entityId: string,
  filename: string,
) {
  const safe = filename.replace(/[^a-zA-Z0-9._-]/g, "_").slice(-80);
  const id = crypto.randomUUID();
  return `${workspaceId}/${entityType}/${entityId}/${id}-${safe}`;
}

import { createClient } from "@/lib/supabase/server";

export async function PhotoStrip({
  workspaceId,
  entityType,
  entityId,
}: {
  workspaceId: string;
  entityType: string;
  entityId: string;
}) {
  const s = await createClient();
  const { data: photos } = await s
    .from("photos")
    .select("id,storage_path,photo_type,captured_at")
    .eq("workspace_id", workspaceId)
    .eq("entity_type", entityType)
    .eq("entity_id", entityId)
    .order("captured_at", { ascending: false })
    .limit(8);

  if (!photos?.length) return null;

  const signed = await Promise.all(
    photos.map(async (p) => {
      const { data } = await s.storage.from("site-photos").createSignedUrl(p.storage_path, 60 * 30);
      return { ...p, url: data?.signedUrl ?? null };
    }),
  );

  return (
    <div className="photo-strip" style={{ display: "flex", gap: 8, flexWrap: "wrap", marginTop: 8 }}>
      {signed.map((p) =>
        p.url ? (
          <a key={p.id} href={p.url} target="_blank" rel="noreferrer">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={p.url}
              alt={p.photo_type}
              width={96}
              height={96}
              style={{ width: 96, height: 96, objectFit: "cover", borderRadius: 8 }}
            />
          </a>
        ) : null,
      )}
    </div>
  );
}

import { createClient } from "@/lib/supabase/server";

type PhotoRow = {
  id: string;
  storage_path: string;
  photo_type: string;
  captured_at: string | null;
  entity_id: string;
};

export type SignedPhoto = {
  id: string;
  url: string;
  photo_type: string;
};

export async function loadPhotoStrips({
  workspaceId,
  entityType,
  entityIds,
  perEntity = 4,
}: {
  workspaceId: string;
  entityType: string;
  entityIds: string[];
  perEntity?: number;
}): Promise<Map<string, SignedPhoto[]>> {
  const out = new Map<string, SignedPhoto[]>();
  if (!entityIds.length) return out;

  const s = await createClient();
  const { data: photos } = await s
    .from("photos")
    .select("id,storage_path,photo_type,captured_at,entity_id")
    .eq("workspace_id", workspaceId)
    .eq("entity_type", entityType)
    .in("entity_id", entityIds)
    .order("captured_at", { ascending: false })
    .limit(Math.min(entityIds.length * perEntity, 80));

  const grouped = new Map<string, PhotoRow[]>();
  for (const p of (photos ?? []) as PhotoRow[]) {
    const list = grouped.get(p.entity_id) ?? [];
    if (list.length < perEntity) {
      list.push(p);
      grouped.set(p.entity_id, list);
    }
  }

  const uniquePaths = Array.from(
    new Set(Array.from(grouped.values()).flat().map((p) => p.storage_path)),
  );
  const signedByPath = new Map<string, string>();
  await Promise.all(
    uniquePaths.map(async (path) => {
      const { data } = await s.storage.from("site-photos").createSignedUrl(path, 60 * 30);
      if (data?.signedUrl) signedByPath.set(path, data.signedUrl);
    }),
  );

  for (const [entityId, list] of grouped) {
    out.set(
      entityId,
      list
        .map((p) => {
          const url = signedByPath.get(p.storage_path);
          return url ? { id: p.id, url, photo_type: p.photo_type } : null;
        })
        .filter((p): p is SignedPhoto => Boolean(p)),
    );
  }
  return out;
}

export function PhotoStripView({ photos }: { photos: SignedPhoto[] | undefined }) {
  if (!photos?.length) return null;
  return (
    <div className="photo-strip" style={{ display: "flex", gap: 8, flexWrap: "wrap", marginTop: 8 }}>
      {photos.map((p) => (
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
      ))}
    </div>
  );
}

export async function PhotoStrip({
  workspaceId,
  entityType,
  entityId,
}: {
  workspaceId: string;
  entityType: string;
  entityId: string;
}) {
  const map = await loadPhotoStrips({
    workspaceId,
    entityType,
    entityIds: [entityId],
    perEntity: 8,
  });
  return <PhotoStripView photos={map.get(entityId)} />;
}

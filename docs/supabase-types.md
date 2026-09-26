# Regenerating Supabase TypeScript types

`src/lib/database.types.ts` is the typed contract for the Next.js app.
Vercel `next build` runs `tsc`. If this file lags behind applied migrations,
queries against new tables/columns fail typecheck (example: `outreach_touches`,
`organizations.doors_managed` on Targets detail).

Regenerate **after every migration that adds/renames tables, columns, views, RPCs, or enums**.

## Project

| Field | Value |
|-------|--------|
| Project | Cbdata |
| Ref | `nzjwhmqrsxztnpdppbub` |
| URL | https://nzjwhmqrsxztnpdppbub.supabase.co |
| Output | `src/lib/database.types.ts` |

Confirm the Vercel env `NEXT_PUBLIC_SUPABASE_URL` matches this ref before generating.

## Prerequisites

```bash
npm i -g supabase
# or
npx supabase --version

supabase login
supabase link --project-ref nzjwhmqrsxztnpdppbub
```

You need access to the project (dashboard login or access token).

## Regenerate from the linked remote (preferred)

From the repo root:

```bash
npm run types:supabase
```

Which runs:

```bash
npx supabase gen types typescript --linked --schema public > src/lib/database.types.ts
```

If the project is not linked:

```bash
npx supabase gen types typescript --project-id nzjwhmqrsxztnpdppbub --schema public > src/lib/database.types.ts
```

## Regenerate from a local Postgres (optional)

```bash
supabase start
supabase db reset   # applies supabase/migrations
npx supabase gen types typescript --local --schema public > src/lib/database.types.ts
```

Use local only when the local migration chain matches production. If production
is ahead, prefer `--linked` / `--project-id`.

## After generation

```bash
npx tsc --noEmit
git diff --stat src/lib/database.types.ts
```

Commit the updated types with the migration (or immediately after `db push`):

```bash
git add src/lib/database.types.ts
git commit -m "chore: regenerate database types after <migration name>"
```

## CI / Vercel

Do **not** generate types during `vercel build`. Generate locally (or in a
GitHub Action with a Supabase access token), commit the file, then deploy.

If `tsc` fails on a new table name that exists in SQL but not in
`database.types.ts`, regenerate first — do not paper over with `as any`
except as a temporary unblock.

## Access token (CI)

```bash
export SUPABASE_ACCESS_TOKEN=sbp_...
npx supabase gen types typescript --project-id nzjwhmqrsxztnpdppbub --schema public > src/lib/database.types.ts
```

Never commit the token. Store it as a GitHub Actions secret if you automate this.

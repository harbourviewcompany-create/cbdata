# Apply migrations (db-push)

GitHub Action: `.github/workflows/db-push.yml`  
Project ref: `nzjwhmqrsxztnpdppbub`  
Runs on: **manual only** — Actions → Supabase db push → Run workflow. It does not run on push or pull request, so merging a migration to `main` does **not** apply it to production.

Until the two secrets below exist, every run fails at "Require secrets" and **production Postgres stays behind git**.

## 1. Create a Supabase access token

1. Sign in at [supabase.com/dashboard/account/tokens](https://supabase.com/dashboard/account/tokens)
2. Generate a token (name it `cbdata-github-db-push`)
3. Copy it once. It is not shown again.

## 2. Copy the database password

1. Open project **nzjwhmqrsxztnpdppbub** → **Project Settings → Database**
2. Copy the database password (reset it if you do not have it)
3. This is `SUPABASE_DB_PASSWORD`, not the anon or service-role key

## 3. Add GitHub Actions secrets

Repo: [harbourviewcompany-create/cbdata](https://github.com/harbourviewcompany-create/cbdata) → **Settings → Secrets and variables → Actions**

| Secret | Value |
| --- | --- |
| `SUPABASE_ACCESS_TOKEN` | token from step 1 |
| `SUPABASE_DB_PASSWORD` | database password from step 2 |
| `SUPABASE_PROJECT_ID` | `nzjwhmqrsxztnpdppbub` (optional; workflow already defaults to this) |

Do not put these in the repo, Vercel env, or chat.

## 4. Dry-run, then apply

1. **Actions → Supabase db push → Run workflow**
2. Set **dry_run** = true
3. Confirm the pending files look right (`supabase migration list` + dry-run output)
4. Run again from `main` with **dry_run** = false (applying from any other ref is refused by the workflow)

The job will:

1. `supabase link --project-ref nzjwhmqrsxztnpdppbub`
2. `supabase migration list`
3. `supabase db push --yes` (skipped on dry-run)
4. `supabase migration list` again

## 5. After a successful push

```bash
supabase login
supabase link --project-ref nzjwhmqrsxztnpdppbub
npm run types:supabase
npx tsc --noEmit
```

Commit `src/lib/database.types.ts` if it changed. See `docs/supabase-types.md`.

## Local apply (same effect, no GitHub)

```bash
supabase login
supabase link --project-ref nzjwhmqrsxztnpdppbub --password "$SUPABASE_DB_PASSWORD"
supabase migration list
supabase db push --dry-run
supabase db push
```

Use this if Actions secrets are not ready yet. Only apply from a clean `main`.

## What is waiting on prod

Anything in `supabase/migrations/` with a timestamp after the last version shown by `supabase migration list` on the linked project. That currently includes snapshot RPC hardening, property-intelligence, and later data migrations.

## Guardrails

- Applying is **main only**: a non-dry-run from any other ref fails before linking the project. A dry run may be run from any branch.
- Manual trigger only: merges, pushes and pull requests never apply migrations.
- Supabase CLI is pinned (same version as `verify.yml`); bump both together.
- One apply at a time (`concurrency` group is not per-ref) and `cancel-in-progress: false`, so a second run queues instead of aborting an apply mid-migration.
- Never `--include-all` against prod.
- Never commit `.env` or the database password.

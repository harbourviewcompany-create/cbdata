# Regenerating Supabase TypeScript types

`src/lib/database.types.ts` is the typed contract for the Next.js app.

```bash
supabase login
supabase link --project-ref nzjwhmqrsxztnpdppbub
npm run types:supabase
npx tsc --noEmit
```

`npm run types:supabase` runs:

```bash
npx supabase gen types typescript --linked --schema public > src/lib/database.types.ts
```

Or:

```bash
npx supabase gen types typescript --project-id nzjwhmqrsxztnpdppbub --schema public > src/lib/database.types.ts
```

Regenerate after every schema migration. Do not generate types in the Vercel build.

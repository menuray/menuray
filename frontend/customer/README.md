# MenuRay Customer View

SvelteKit 2 SSR app serving published menus at `/<slug>`.

## Dev

```bash
pnpm install
pnpm dev           # http://localhost:5173
```

Requires a local Supabase running on `http://127.0.0.1:54321` (see `../../backend/supabase/`).

## Scripts

- `pnpm check` — type check (must be clean before commit)
- `pnpm test` — Vitest unit tests
- `pnpm test:e2e` — Playwright e2e (requires `pnpm dev` running or `pnpm build && pnpm preview`)
- `pnpm build` — production build via adapter-node

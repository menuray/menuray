# MenuRay — Backend

Supabase-powered backend: Postgres + Auth + Storage + Edge Functions. This directory holds schema migrations, RLS policies, seed data, and the `parse-menu` Edge Function scaffold (with mock OCR / LLM adapters).

Design spec: [`docs/superpowers/specs/2026-04-19-supabase-backend-mvp-design.md`](../docs/superpowers/specs/2026-04-19-supabase-backend-mvp-design.md).

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) running.
- [Supabase CLI](https://supabase.com/docs/guides/cli) ≥ 1.150: `brew install supabase/tap/supabase` or `curl -fsSL https://supabase.com/install.sh | sh`.
- [Deno](https://deno.land/) (optional; only needed for direct `deno check` / function development outside the Supabase CLI).

## First-run setup

```bash
cd backend
supabase start        # pulls Docker images on first run
supabase db reset     # applies migrations + seed.sql
```

The `supabase start` output prints local URLs:

```
API URL:   http://localhost:54321
DB URL:    postgresql://postgres:postgres@localhost:54322/postgres
Studio:    http://localhost:54323
```

Studio (http://localhost:54323) is a local web UI for inspecting tables, running SQL, and browsing Storage.

## Seeded demo

`supabase db reset` runs `seed.sql` after migrations, producing:

- Demo user: `seed@menuray.com` / `demo1234` (email login).
- Store: 云间小厨 · 静安店 (auto-created via signup trigger, then updated).
- One published menu `午市套餐 2025 春`, slug `yun-jian-xiao-chu-lunch-2025`, CNY, `zh-CN`, containing 凉菜 (3 dishes) + 热菜 (2 dishes) — mirrors `frontend/merchant/lib/shared/mock/mock_data.dart`.
- English translations for named dishes, categories, and the store.
- One completed `parse_runs` row (for testing idempotency / Realtime subscription).

## Running `parse-menu`

See [`supabase/functions/parse-menu/README.md`](supabase/functions/parse-menu/README.md) for the full curl-based demo.

Quick version:
```bash
supabase functions serve parse-menu --import-map supabase/functions/import_map.json
# In another terminal, follow the README's curl block.
```

## Schema overview

9 tables in the `public` schema — `stores`, `menus`, `categories`, `dishes`, `dish_translations`, `category_translations`, `store_translations`, `parse_runs`, `view_logs` — all with RLS enabled. Owner access is keyed off a redundant `store_id` column; anonymous diner reads are limited to children of `menus.status='published'`.

3 Storage buckets: `menu-photos` (private — OCR input), `dish-images` (public read), `store-logos` (public read). All paths follow `{store_id}/<uuid>.<ext>`.

## Adding a new OCR / LLM provider

1. Add one file under `supabase/functions/_shared/providers/` implementing `OcrProvider` or `LlmProvider` from `types.ts`.
2. Add one `case` to `factory.ts`.
3. Set `MENURAY_OCR_PROVIDER` or `MENURAY_LLM_PROVIDER` in the Supabase dashboard (or `supabase/.env` locally).

No orchestrator change required. See ADR-010 in [`docs/decisions.md`](../docs/decisions.md).

## Common commands

| Purpose | Command |
|---|---|
| Start local stack | `supabase start` |
| Stop local stack | `supabase stop` |
| Reset local DB + re-run migrations + seed | `supabase db reset` |
| Tail logs | `supabase functions logs parse-menu` |
| Serve a function locally | `supabase functions serve parse-menu --import-map supabase/functions/import_map.json` |
| Push migrations to hosted project | `supabase db push --db-url "$SUPABASE_DB_URL"` |
| Deploy function to hosted project | `supabase functions deploy parse-menu --project-ref idwhukvigkoevaakhsqv` |

> **Do not run `db push` or `functions deploy` as part of the initial scaffold work.** Those happen in a separate, reviewed session after the hosted project's env is confirmed.

## Deploying to hosted Supabase

Credentials live in the repo-root `.env.local` (gitignored). The committed `.env.local.example` lists the expected variables (`SUPABASE_URL`, `SUPABASE_PROJECT_REF`, `SUPABASE_DB_URL`, `SUPABASE_SERVICE_ROLE_KEY`, etc.).

Before deploying:
1. Confirm the hosted project's ref matches `SUPABASE_PROJECT_REF`.
2. Set `MENURAY_OCR_PROVIDER` and `MENURAY_LLM_PROVIDER` (default `mock`; override per session).
3. Set the SMS provider credentials in the dashboard (Auth → Providers → Phone).

`supabase db push` is one-way — review migrations carefully first.

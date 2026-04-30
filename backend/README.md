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

## Getting the local anon key for the Flutter app

The Flutter merchant app embeds the local Supabase anon key as a constant in
`frontend/merchant/lib/config/supabase_config.dart`. To retrieve the current
value:

```bash
cd backend && supabase status --output env | grep ANON_KEY
```

The value is stable across `supabase start` invocations because the JWT
secret in `backend/supabase/config.toml` is fixed. Running `supabase init`
from scratch regenerates it — update the constant if that happens.

### Android emulator note

`http://localhost:54321` points at the emulator itself, not the host. The
Flutter app automatically substitutes `http://10.0.2.2:54321` in Android
debug builds. On a physical device connected by USB, override at build time:

```bash
flutter run --dart-define=SUPABASE_URL=http://<host-lan-ip>:54321 \
            --dart-define=SUPABASE_ANON_KEY=<key>
```

### Physical Android device against cloud Supabase

Local Supabase is loopback-bound and `10.0.2.2` is emulator-only, so a
physical device cannot reach it. Build a release APK that points at the
hosted project (credentials in repo-root `.env.local`):

```bash
set -a && source .env.local && set +a
cd frontend/merchant
flutter build apk --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --dart-define=SHOW_SEED_LOGIN=true
flutter install -d <device-id>      # e.g. 192.168.x.x:port for adb-over-wifi
```

Notes:
- `SHOW_SEED_LOGIN=true` reveals the dev-only "种子账户登录" button
  (`seed@menuray.com` / `demo1234`). Without it, release builds hide the
  button and only phone+OTP is available.
- Phone+OTP requires SMS provider (Twilio / MessageBird) configured in the
  hosted project's Auth settings — not yet set up. Seed login is the only
  working path until then.

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

## Deploying to hosted Supabase

Credentials live in the repo-root `.env.local` (gitignored). The committed `.env.local.example` lists the expected variables (`SUPABASE_URL`, `SUPABASE_PROJECT_REF`, `SUPABASE_DB_URL`, `SUPABASE_SERVICE_ROLE_KEY`, etc.).

### Current hosted-project state (verify before assuming)

The reference project (`SUPABASE_PROJECT_REF` in `.env.local`) is set up
with:

- All 12 migrations pushed (`stores`, `templates`, etc. queryable).
- All 10 Edge Functions deployed (`parse-menu`, `accept-invite`,
  `create-checkout-session`, `create-portal-session`,
  `handle-stripe-webhook`, `create-store`, `log-dish-view`,
  `export-statistics-csv`, `translate-menu`, `ai-optimize`).
- Seed user `seed@menuray.com` / `demo1234` (verify via Auth admin API).
- Anon key is the new `sb_publishable_*` format —
  `supabase_flutter ^2.5.0` accepts it.

Verify any of these before relying on them:

```bash
set -a && source .env.local && set +a
# Schema
curl -s "$SUPABASE_URL/rest/v1/stores?select=id&limit=1" -H "apikey: $SUPABASE_ANON_KEY"
# Edge Functions (200/401 = deployed; 404 = missing)
curl -s -o /dev/null -w "%{http_code}\n" \
  -X POST "$SUPABASE_URL/functions/v1/parse-menu" \
  -H "apikey: $SUPABASE_ANON_KEY" -H "Content-Type: application/json" -d '{}'
# Seed user
curl -s "$SUPABASE_URL/auth/v1/admin/users?per_page=10" \
  -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY"
```

### Outstanding hosted-project config

Not yet confirmed in the dashboard:

- `MENURAY_OCR_PROVIDER` / `MENURAY_LLM_PROVIDER` Edge Function secrets
  (default `mock`; flip to `openai` + supply `OPENAI_API_KEY` to enable
  real parsing).
- Stripe live/test keys + price IDs + `STRIPE_WEBHOOK_SECRET` for
  billing functions.
- SMS provider (Auth → Providers → Phone) for `signInWithOtp` — without
  this, the phone-login flow in the merchant app cannot complete.

### Pushing changes

Avoid running `db push` / `functions deploy` casually — both have
production blast radius. Confirm migration content first, and run from a
known-good local state.

```bash
supabase db push --db-url "$SUPABASE_DB_URL"
supabase functions deploy <fn-name> --project-ref "$SUPABASE_PROJECT_REF"
```

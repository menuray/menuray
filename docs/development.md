# Development

> Local environment setup, common commands, and troubleshooting for working on MenuRay.

## Prerequisites

| Tool | Version | Required for |
|---|---|---|
| **Flutter SDK** | stable channel (3.41+) | Merchant app |
| **Node.js** | 22+ | Customer SvelteKit app, Supabase CLI |
| **pnpm** | 9+ | Customer app package manager |
| **Deno** | 2.x | Edge Functions + their tests |
| **Supabase CLI** | latest | Local Postgres + Edge Function dev ([install](https://supabase.com/docs/guides/cli)) |
| **Docker** | recent | Underlying engine for Supabase CLI's local stack |
| **Git** | 2.30+ | Source control |

Optional but useful:
- **Stripe CLI** — when working on billing webhooks ([install](https://docs.stripe.com/stripe-cli))
- **Android Studio** — Android emulator + better Flutter inspection
- **VS Code** with Flutter extension — recommended editor
- **Python 3** — only if you use the static-server fallback for headless web preview

## First-time setup

```bash
# Clone
git clone git@github.com:menuray/menuray.git
cd menuray

# Install Flutter SDK if you haven't
# https://flutter.dev/docs/get-started/install

# Verify Flutter
flutter doctor
```

`flutter doctor` should show ✓ for the platforms you intend to build for. Install missing dependencies it flags.

## Running the merchant app

```bash
cd frontend/merchant
flutter pub get
```

Then pick a target:

| Target | Command | Notes |
|---|---|---|
| iOS simulator | `flutter run -d ios` | macOS only |
| Android emulator | `flutter run -d android` | Need Android Studio + emulator running |
| Linux desktop | `flutter run -d linux` | Quick preview (not mobile UX) |
| Chrome (dev) | `flutter run -d chrome` | Best for headless servers via tunneling — but see below |
| Web (release static) | `flutter build web --release` + serve | Required for HTTPS-tunneled access (no WS) |

### Headless Linux + tunnel access

If you're developing on a Linux server with no browser and accessing via an HTTPS tunnel (e.g. `https://your-tunnel-host/`), the dev server's hot-reload uses `ws://` which is blocked by browsers as Mixed Content. Use the **release static build** instead:

```bash
cd frontend/merchant
flutter build web --release
cd build/web
python3 -m http.server 8123 --bind 0.0.0.0
```

Then access via your tunnel. No hot reload — rerun `flutter build web --release` after code changes.

## Running the customer view

```bash
cd frontend/customer
pnpm install
pnpm dev      # http://localhost:5173/<slug>
```

The customer view requires a local Supabase instance (see "Running the backend" below) and at least one published menu (the seed script provides one at `/yun-jian-xiao-chu-lunch-2025`).

## Running the backend (Supabase local)

```bash
cd backend/supabase
supabase start              # boots Postgres + Auth + Storage + Edge runtime
supabase db reset           # applies all migrations + seed
```

Default ports: REST `54321`, DB `54322`, Studio `54323`, Inbucket (test SMTP) `54324`.

Stop with `supabase stop`. Reset the DB any time with `supabase db reset` (drops + re-applies migrations).

### Running individual Edge Functions locally

```bash
cd backend/supabase
supabase functions serve parse-menu --env-file ./.env.local --no-verify-jwt
```

For Stripe webhooks, in a second terminal:

```bash
stripe listen --forward-to http://127.0.0.1:54321/functions/v1/handle-stripe-webhook
```

Copy the printed signing secret into `.env.local` as `STRIPE_WEBHOOK_SECRET`. See `backend/supabase/functions/STRIPE_DEPLOY.md` for the full runbook.

## Tests

### Flutter (merchant)

```bash
cd frontend/merchant
flutter test                                    # all tests
flutter test test/widgets/                      # only widget tests
flutter test test/smoke/                        # only smoke tests
flutter test test/widgets/menu_card_test.dart   # one file
```

### Vitest (customer)

```bash
cd frontend/customer
pnpm test                  # one-shot run
pnpm test:watch            # watch mode (if defined)
pnpm exec playwright test  # e2e
```

### Deno (Edge Functions)

Each function has its own test file. Run all:

```bash
cd backend/supabase
for fn in functions/*/; do
  [ -f "${fn}test.ts" ] && (cd "$fn" && deno test --allow-env --allow-net)
done
```

### PgTAP (Postgres regressions)

Three regression scripts at `backend/supabase/tests/`. They run inside a `BEGIN; … ROLLBACK;` so they don't pollute the local DB:

```bash
docker exec -i supabase_db_menuray psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  < backend/supabase/tests/rls_auth_expansion.sql
docker exec -i supabase_db_menuray psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  < backend/supabase/tests/billing_quotas.sql
docker exec -i supabase_db_menuray psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  < backend/supabase/tests/analytics_aggregations.sql
```

Each ends with `<name>: all assertions passed`.

## Linting & type check

```bash
cd frontend/merchant && flutter analyze     # Flutter — must be clean before commit
cd frontend/customer && pnpm check          # svelte-check — must be 0 errors / 0 warnings
```

Lint config: [`frontend/merchant/analysis_options.yaml`](../frontend/merchant/analysis_options.yaml) (Flutter defaults).

## Pre-commit checklist

Before opening a PR, run all of:

```bash
# Merchant
cd frontend/merchant && flutter analyze && flutter test

# Customer
cd frontend/customer && pnpm check && pnpm test

# Backend (after a fresh `supabase db reset`)
cd backend/supabase
docker exec -i supabase_db_menuray psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  < tests/rls_auth_expansion.sql
docker exec -i supabase_db_menuray psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  < tests/billing_quotas.sql
docker exec -i supabase_db_menuray psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  < tests/analytics_aggregations.sql
for fn in functions/*/; do
  [ -f "${fn}test.ts" ] && (cd "$fn" && deno test --allow-env --allow-net)
done
```

All must pass clean.

## Common commands cheatsheet

| Task | Command |
|---|---|
| Install deps | `flutter pub get` |
| Update deps | `flutter pub upgrade` |
| Show outdated | `flutter pub outdated` |
| Clean build artifacts | `flutter clean` |
| Hot reload (dev) | `r` in terminal where `flutter run` is running |
| Hot restart | `R` in terminal where `flutter run` is running |
| Inspect widget tree | `flutter run` then `w` (or use Flutter DevTools) |
| Generate release APK | `flutter build apk --release` |
| Generate release iOS | `flutter build ios --release` (macOS only) |
| Generate web | `flutter build web --release` |

## IDE setup

### VS Code (recommended)

Install:
- **Dart** extension
- **Flutter** extension

`.vscode/settings.json` (optional, project-local):
```json
{
  "editor.formatOnSave": true,
  "[dart]": {
    "editor.defaultFormatter": "Dart-Code.dart-code",
    "editor.formatOnSave": true,
    "editor.rulers": [80]
  }
}
```

### Android Studio / IntelliJ

Install Flutter + Dart plugins. Open the `frontend/merchant/` folder as a project.

## Project structure cheat sheet

```
frontend/merchant/
├── lib/
│   ├── main.dart              # ProviderScope + HappyMenuApp
│   ├── app.dart               # MaterialApp.router
│   ├── theme/                 # AppColors, AppTheme
│   ├── router/                # go_router config + AppRoutes
│   ├── shared/
│   │   ├── models/            # Menu, Dish, Category, Store
│   │   ├── mock/              # MockData (the only place for sample data)
│   │   └── widgets/           # StatusChip, PrimaryButton, ...
│   └── features/
│       ├── auth/              # A1 Login
│       ├── home/              # A2 Home
│       ├── capture/           # A3 Camera, A4 Upload, A5 Crop, A6 OCR
│       ├── edit/              # A7 Organize, A8 Edit Dish
│       ├── ai/                # A9 AI Optimize
│       ├── publish/           # A10–A13 Template / Theme / Preview / Published
│       ├── manage/            # A14 Manage, A15 Statistics
│       └── store/             # A16 Stores, A17 Settings
├── assets/sample/             # Placeholder images (menu covers, etc.)
└── test/
    ├── widgets/               # Shared widget tests
    └── smoke/                 # Per-screen smoke tests
```

## Adding a new screen

1. Add the route constant to `lib/router/app_router.dart` (if new) and a `GoRoute` entry pointing to the new screen.
2. Create `lib/features/<feature>/presentation/<screen>_screen.dart` as a `StatelessWidget` (or `StatefulWidget` if it owns controllers).
3. Use shared widgets where applicable (`PrimaryButton`, `MenuCard`, etc.).
4. Use `AppColors.*` tokens from `lib/theme/app_colors.dart` — no hardcoded hex.
5. Add a smoke test at `test/smoke/<screen>_smoke_test.dart` verifying it renders + key text present.
6. `flutter analyze && flutter test` must pass.
7. Visual-check it against any existing design in `frontend/design/`.

## Adding a shared widget

1. Create `lib/shared/widgets/<name>.dart`.
2. **Const constructor** required.
3. Use `AppColors` tokens.
4. Add a widget test at `test/widgets/<name>_test.dart` verifying behavior (not just render).

## Adding a new dependency

Justify it in the PR description. Current shipped Flutter deps include `flutter_riverpod`, `go_router`, `google_fonts`, `supabase_flutter`, `image_picker`, `camera`, `shared_preferences`, `url_launcher`, `share_plus`, `path_provider`, `intl`, `flutter_localizations`. Don't introduce a second state management library (no `bloc`/`provider`/`getx` — we standardized on Riverpod). For backend work, prefer `npm:` imports in Deno edge functions over adding to the import map.

## Troubleshooting

### `flutter doctor` complains about Android licenses
```bash
flutter doctor --android-licenses
```

### Tests hang / never complete
Likely a `pumpAndSettle` waiting on a never-completing animation or timer. Use `pump()` (single frame) instead. See `processing_screen_smoke_test.dart` for the pattern.

### Web build error after Riverpod / go_router upgrade
Try:
```bash
flutter clean && flutter pub get && flutter analyze
```

### Android build fails after package rename
You may need to delete `frontend/merchant/build/` and `frontend/merchant/android/.gradle/`:
```bash
flutter clean
rm -rf frontend/merchant/android/.gradle
flutter pub get
flutter build apk --debug
```

### "package:happy_menu_merchant/..." import errors
We renamed to `menuray_merchant`. If you see old imports, your branch is behind `main`. Rebase.

## Where to ask for help

- **Question about how to do X**: open a GitHub Discussion or comment on a related issue
- **Bug**: file an issue with the bug template
- **Process/design question**: see [decisions.md](decisions.md) — if not answered, open a Discussion

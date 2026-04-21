# Architecture

> High-level view of how MenuRay is built. For *why* we picked these specific technologies, see [decisions.md](decisions.md). For brand / visual specs, see [DESIGN.md](DESIGN.md).

## System overview

MenuRay has three deployable units, glued by a single backend:

```
┌─────────────────────────────────────────────────────────────┐
│                       MenuRay system                        │
│                                                             │
│  ┌────────────────┐   ┌────────────────┐   ┌─────────────┐  │
│  │  Merchant app  │   │  Customer view │   │  Admin       │  │
│  │   (Flutter)    │   │   (SvelteKit)  │   │  console     │  │
│  │  iOS / Android │   │   responsive   │   │  (later)     │  │
│  │  + Web for dev │   │      H5        │   │              │  │
│  └────────┬───────┘   └────────┬───────┘   └──────┬──────┘  │
│           │                    │                  │          │
│           └─────────┬──────────┴──────────────────┘          │
│                     │ HTTPS                                  │
│           ┌─────────▼──────────┐                             │
│           │     Supabase       │                             │
│           │ ┌────────────────┐ │                             │
│           │ │  Postgres      │ │                             │
│           │ │  + RLS         │ │                             │
│           │ ├────────────────┤ │                             │
│           │ │  Auth (OTP)    │ │                             │
│           │ ├────────────────┤ │                             │
│           │ │  Storage       │ │                             │
│           │ ├────────────────┤ │                             │
│           │ │  Edge Functions│ │  ──┐                        │
│           │ │  (Deno / TS)   │ │    │ outbound API calls     │
│           │ └────────────────┘ │    │                        │
│           └────────────────────┘    │                        │
│                                     │                        │
│           ┌─────────────────────────▼─────────────────────┐  │
│           │  External AI services (provider-agnostic)     │  │
│           │  - Google Vision / others (OCR)               │  │
│           │  - Anthropic / OpenAI (LLM parsing)           │  │
│           │  - Image generation (when AI photos enabled)  │  │
│           └────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Components

### 1. Merchant app — `frontend/merchant/`

Flutter app for restaurant owners/staff. Mobile-first (iOS + Android); also builds for Web (used in development & for browsers without app install).

**Responsibilities:**
- Capture / upload paper menu photos
- Show OCR results & let user edit
- Manage menus, dishes, categories, time slots, sold-out state
- Customize template & theme
- Generate share links + QR codes
- View access analytics
- Multi-store management (for chains)

**Internal structure:**
- `lib/theme/` — Material 3 theme + AppColors
- `lib/router/` — go_router config; all routes
- `lib/shared/` — models, mock data, reusable widgets, Supabase client helper, JSON→model mappers
- `lib/features/<feature>/presentation/` — one screen file per route
- `lib/features/<feature>/<name>_repository.dart` — thin wrapper over `SupabaseClient` (e.g. `auth_repository.dart`, `menu_repository.dart`)
- `lib/features/<feature>/<name>_providers.dart` — Riverpod providers composing the repository (e.g. `auth_providers.dart`, `home_providers.dart`)

State management: **Riverpod**. Thirteen of seventeen screens are wired to Supabase using the pattern in ADR-017 (repository + hand-written mappers + `FutureProvider`/`FutureProvider.family`): login, home, menu-manage, edit_dish, organize_menu, preview_menu, published, settings, store_management (Batch 1), plus camera, select_photos, correct_image, processing (Batch 2 — capture flow). Four remaining screens (ai_optimize, select_template, custom_theme, statistics) are deferred past P0. See [`docs/superpowers/plans/2026-04-20-menu-manage-supabase-wire-up.md`](superpowers/plans/2026-04-20-menu-manage-supabase-wire-up.md) for the canonical single-screen example, [`docs/superpowers/plans/2026-04-20-p0-batch1-wire-up.md`](superpowers/plans/2026-04-20-p0-batch1-wire-up.md) for the six-screen Batch 1 fan-out, and [`docs/superpowers/plans/2026-04-20-p0-batch2-parse-menu.md`](superpowers/plans/2026-04-20-p0-batch2-parse-menu.md) for the capture flow + realtime pipeline.

**Platform-split camera capture:** `lib/features/capture/platform/camera_launcher.dart` uses Dart's conditional export (`if (dart.library.io) 'camera_launcher_io.dart' if (dart.library.html) 'camera_launcher_web.dart'`) to keep the `camera` package out of the web bundle entirely. Mobile targets get a real `CameraPreview` + shutter; web targets fall back to `image_picker`'s `ImageSource.camera` (browser file picker with capture hint). Both expose the same `buildCameraPreview({onCaptured, onPermissionDenied})` function so the calling screen is platform-agnostic. This pattern can be promoted to an ADR if we add a second similar shim; for now it's documented here.

**Localization (Batch 3, 2026-04-20):** Every UI-chrome string in all 17 screens (plus shared widgets like `menu_card`, `status_chip`, `merchant_bottom_nav`) routes through `AppLocalizations` generated by `flutter gen-l10n`. ARB templates live at `lib/l10n/app_en.arb` (template / source of truth) and `lib/l10n/app_zh.arb` (Chinese copy preserved verbatim). `pubspec.yaml` sets `flutter.generate: true`; `l10n.yaml` at the Flutter app root wires gen-l10n. Default locale is `en` — users on a non-Chinese OS see English, zh-CN OS users see Chinese. Generated files (`lib/l10n/app_localizations*.dart`) are checked in because Flutter 3.41 deprecated the synthetic-package flag. Smoke tests wrap their widget-under-test in `zhMaterialApp(home: ...)` (from `test/support/test_harness.dart`) so their existing Chinese assertions still pass; one additional smoke test asserts that the login screen resolves English under `Locale('en')`. See [`docs/i18n.md`](i18n.md) and [`docs/superpowers/specs/2026-04-20-p0-batch3-i18n-design.md`](superpowers/specs/2026-04-20-p0-batch3-i18n-design.md) for the full rationale and key-naming convention.

### 2. Customer view — `frontend/customer/`

Lightweight SvelteKit web app served at `menu.menuray.com/<slug>`. Diners scan a QR code on a printed table tent and the menu opens in their browser. **No app install required.**

**Why a separate stack from Flutter?** First paint speed is everything for "open and view" — Flutter Web has a large initial bundle. SvelteKit + SSR delivers usable HTML in <500ms over slow networks.

**Responsibilities:**
- Render menu by slug, in user's preferred language
- Search & filter dishes
- Show allergens, spice level, recommended/signature tags
- Track view count (sent back to backend for analytics)

**Runtime & data loading:**

Location: `frontend/customer/` (standalone pnpm package, Node 22, adapter-node).

SSR: One Supabase anon client per request (attached to `event.locals.supabase` in `hooks.server.ts`). Each `[slug]` page loads a single denormalized join query: menus + stores + categories + dishes + all translations (dish + category) for the target slug and store. After the initial page load, search/filter/language switching are fully client-side.

RLS: The anon role reads `stores` via the `stores_anon_read_of_published` policy (migration `20260420000005_anon_stores_read.sql`), gated on the existence of a published menu owned by the store. All other tables anon touches remain governed by the original RLS policies in `20260420000002_rls_policies.sql`.

SEO: Each `[slug]` page emits schema.org `Restaurant` + `Menu` + `MenuSection` + `MenuItem` JSON-LD, plus og:* meta tags. This ensures correct sharing & indexing on social platforms and search engines.

Language negotiation: URL parameter `?lang=` → localStorage → `Accept-Language` header → menu `source_locale` (fallback).

View logging: Analytics — each page view fires a background insert into `view_logs` (fire-and-forget, no await). Dedup & bot filtering will land with the analytics pipeline (Session 5).

**Templates**

Location: `frontend/customer/src/lib/templates/{minimal,grid}/`.

Each template exports a `MenuPage.svelte` that receives `{data}` and renders the full layout. `[slug]/+page.svelte` is a thin dispatcher — `{#if templateId === 'grid'} <GridLayout/> {:else} <MinimalLayout/> {/if}`. Shared components (MenuHeader, SearchBar, FilterDrawer, CategoryNav, LangDropdown) are reused across templates; per-template dish cards live under the template folder.

The `templates` table (migration `20260420000006`) seeds 5 rows with `is_launch` flags. Merchant shows only `is_launch=true` as selectable. Customer dispatcher's `{:else}` branch catches any unknown `templateId` and renders MinimalLayout — prevents broken state from direct SQL tampering.

Primary-color override injects a runtime `<style>:root{--color-primary:X}</style>` into `<svelte:head>`. Tailwind v4's `@theme` declares `--color-primary` at `:root`; the runtime override comes later in the cascade and wins. Values are hex-regex-validated in the SSR mapper; malformed data silently falls back to the brand default.

### 3. Backend — Supabase

[Supabase](https://supabase.com/) provides Postgres + Auth + Storage + Edge Functions. We use the hosted version for development; OSS users can self-host.

**Database:** Postgres with Row Level Security (RLS) policies enforcing multi-tenancy (each store sees only its own data).

**Auth:** Phone OTP (via Twilio) + email/password (fallback). Sessions managed via JWT.

**Storage:** Buckets for menu photos (private), dish images (public read), store logos (public read).

**Edge Functions (Deno):** Server-side logic that needs secrets — primarily orchestrating OCR + LLM calls for menu parsing.

**Data schema:** 9 tables in `public` schema: `stores`, `menus`, `categories`, `dishes`, `dish_translations`, `category_translations`, `store_translations`, `parse_runs`, `view_logs`. All owned tables carry a redundant `store_id` for a uniform RLS template (ADR-014). Three Storage buckets (`menu-photos`, `dish-images`, `store-logos`) share a `{store_id}/<uuid>.<ext>` path convention (ADR-016). See `backend/supabase/migrations/` for the concrete DDL and `docs/superpowers/specs/2026-04-19-supabase-backend-mvp-design.md` for the design rationale.

**Parse pipeline status tracking:** The `parse-menu` Edge Function writes progress onto a `parse_runs` row (`pending → ocr → structuring → succeeded | failed`). Clients subscribe via Supabase Realtime (or poll the row) and pick up the final `menu_id` from it. See ADR-015.

### 4. AI services (provider-agnostic)

External APIs called from Edge Functions:

| Use | Provider (default) | Swappable? |
|---|---|---|
| OCR | Google Cloud Vision | Yes — abstracted via interface |
| LLM (parse OCR → menu structure) | Anthropic Claude | Yes — same interface for OpenAI/etc |
| LLM (description expansion / translation) | Same as above | Yes |
| Image generation (dish photos, optional) | TBD (Replicate / Stability / fal) | Yes |

**No vendor lock-in:** Edge Functions hide provider details behind a thin interface. Swap by changing one env var + deploying.

## Data flow: photo to digital menu

```
┌──────────┐ 1. Photo
│ Merchant │─────────────────┐
│ app      │                 │
└──────────┘                 ▼
                    ┌────────────────┐
                    │ Supabase       │
                    │ Storage        │ 2. PUT photo
                    │ (private)      │
                    └────────┬───────┘
                             │ 3. trigger edge function
                             ▼
                    ┌────────────────┐
                    │ Edge Function  │
                    │ "parse-menu"   │
                    └────────┬───────┘
                             │
                ┌────────────┴────────────┐
                │ 4. OCR API call         │
                ▼                         │
        ┌──────────────┐                  │
        │ Vision API   │                  │
        │ → text+layout│                  │
        └──────┬───────┘                  │
               │                          │
               └────────┬─────────────────┘
                        │ 5. LLM call
                        ▼
               ┌──────────────┐
               │ Claude/GPT   │
               │ → JSON menu  │
               │   structure  │
               └──────┬───────┘
                      │ 6. INSERT into Postgres
                      ▼
              ┌────────────────┐
              │ Postgres       │
              │ (menus, dishes,│
              │  categories)   │
              └────────────────┘
                      │
                      │ 7. Read via PostgREST
                      ▼
              ┌────────────────┐    ┌──────────┐
              │ Merchant app   │───▶│  Diner   │
              │ shows for      │ 8. │  scans   │
              │ review/edit    │ QR │  QR      │
              └────────────────┘    └──────────┘
```

## Trust boundaries

- **Merchant app ↔ Supabase:** authenticated user JWT; RLS enforces "user can only access their own store's data".
- **Customer view ↔ Supabase:** anonymous read of public menu by slug (no auth); writes (view counter) go through a rate-limited Edge Function with a captcha if needed.
- **Edge Functions ↔ External APIs:** Edge Function holds the API keys; the client never sees them.

## Self-hosting

The whole stack is open source:
- **Merchant app:** any Flutter dev machine + `flutter build`
- **Customer view:** Vercel / Netlify / your own Node host
- **Backend:** Supabase has a [self-hosted option](https://supabase.com/docs/guides/self-hosting) (Docker Compose). The schema, RLS policies, and Edge Functions are all in this repo and replayable on a fresh instance via Supabase CLI.

See [development.md](development.md) for setup instructions once backend lands.

## What this architecture deliberately does *not* include

- A custom backend framework — we lean hard on Supabase to avoid building plumbing.
- Microservices — single Postgres + a handful of Edge Functions is plenty for years of growth.
- Server-side rendering for the merchant app — desktop/mobile Flutter only; SSR handled by SvelteKit on the customer side.
- A "real-time collaboration" layer — restaurants editing menus together isn't a target use case.
- An admin/back-office app for now — a SQL UI on Supabase suffices until we have customers paying us.

## Future evolution

| When | Likely change |
|---|---|
| Real users + real OCR cost matters | Cache OCR results by photo hash |
| Multiple staff editing one menu | Real-time subscriptions via Supabase channels |
| White-label / enterprise customers | Tenant-aware DNS + custom theming |
| Heavy traffic | Read replicas / Postgres connection pooling (Supavisor) |
| Self-host adoption | First-class CLI installer / Docker Compose template |

We'll update this doc when those changes land.

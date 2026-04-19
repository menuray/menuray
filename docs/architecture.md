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
- `lib/shared/` — models, mock data, reusable widgets
- `lib/features/<feature>/presentation/` — one screen file per route

State management: **Riverpod**. Currently mostly stateless screens with mock data; will grow as backend lands.

### 2. Customer view — `frontend/customer/` *(planned)*

Lightweight SvelteKit web app served at `menu.menuray.app/<slug>`. Diners scan a QR code on a printed table tent and the menu opens in their browser. **No app install required.**

**Why a separate stack from Flutter?** First paint speed is everything for "open and view" — Flutter Web has a large initial bundle. SvelteKit + SSR delivers usable HTML in <500ms over slow networks.

**Responsibilities:**
- Render menu by slug, in user's preferred language
- Search & filter dishes
- Show allergens, spice level, recommended/signature tags
- Track view count (sent back to backend for analytics)

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

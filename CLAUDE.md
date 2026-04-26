# CLAUDE.md — Guidance for AI coding agents

> This file is read automatically by Claude Code, Cursor, GitHub Copilot, and similar AI coding tools. Keep it short, opinionated, and current.

## What this project is

**MenuRay** — open-source app that turns paper restaurant menus into shareable digital menus via a single photo. Targets global SMB restaurants. MIT-licensed. Multi-platform (mobile native + web).

Read [`README.md`](README.md) and [`docs/architecture.md`](docs/architecture.md) for the full picture before making non-trivial changes.

## Where to look first

| Question | Doc |
|---|---|
| What does the system do? | [README.md](README.md) |
| How is it laid out? | [docs/architecture.md](docs/architecture.md) |
| Why these technology choices? | [docs/decisions.md](docs/decisions.md) |
| How do I run it? | [docs/development.md](docs/development.md) |
| What's the brand spec? | [docs/DESIGN.md](docs/DESIGN.md) |
| What's left to build? | [docs/roadmap.md](docs/roadmap.md) |
| How to add a language? | [docs/i18n.md](docs/i18n.md) |
| Detailed plan for a feature? | [docs/superpowers/plans/](docs/superpowers/plans/) |

## Tech stack (current)

| Layer | Tech |
|---|---|
| Merchant app | Flutter (stable), Material 3, Riverpod, go_router, google_fonts, `shared_preferences`, `url_launcher`, `share_plus`, `image_picker`/`camera`, `supabase_flutter` |
| Customer view | SvelteKit 2 + Svelte 5 runes (SSR + Node adapter, anon RLS + JSON-LD), Tailwind v4 |
| Backend | Supabase (Postgres + Auth + Storage + Edge Functions, `pg_cron`); Stripe Checkout + Customer Portal; Deno `npm:stripe@^17` for billing edge fns |
| AI | OpenAI `gpt-4o-mini` (OCR + LLM) behind a provider-agnostic factory; `mock` provider stays default in CI |
| Tier gating | `Tier { free, pro, growth }` enum + `currentTierProvider` + `TierGate` widget + tier-aware Edge Function gates |
| RBAC | `store_members` + 3 roles (Owner/Manager/Staff) + `RoleGate` widget |

## Conventions (follow these without asking)

### Code
- **Const constructors on every private stateless widget** — even if it has `context.go(...)` callbacks. Pattern established in `frontend/merchant/lib/features/auth/presentation/login_screen.dart`.
- **`StatefulWidget` for any widget owning a `TextEditingController`, `AnimationController`, or `Timer`** — initialize in `initState`, dispose in `dispose`. Never create controllers inline in build.
- **Use `AppColors` tokens** from `frontend/merchant/lib/theme/app_colors.dart`, not hardcoded hex literals. Two documented exceptions: Stitch's `surface-container-highest` (`#E6E2DB`) and `surface-container-low` (`#F7F3EC`) for input field backgrounds — these may be inline.
- **Use `withValues(alpha: …)`, never `withOpacity(…)`** (latter is deprecated in Flutter 3.41+).
- **Avoid `Spacer()` in `SingleChildScrollView` or `Column(mainAxisSize: min)`** — causes unbounded-height crashes. Use `SizedBox(height: N)` instead.
- **Riverpod for any new state** — `flutter_riverpod` is set up; create `Provider`/`StateProvider` etc. when you need state beyond a screen.
- **`go_router` for navigation** — never `Navigator.push` directly. Add new route constants to `frontend/merchant/lib/router/app_router.dart`.

### Files & folders
- Feature-first under `frontend/merchant/lib/features/<feature>/presentation/<screen>_screen.dart`.
- Shared widgets at `frontend/merchant/lib/shared/widgets/`.
- Shared models at `frontend/merchant/lib/shared/models/`.
- Mock data at `frontend/merchant/lib/shared/mock/mock_data.dart` — only place for sample data.
- Tests at `frontend/merchant/test/widgets/` (shared widget tests) and `frontend/merchant/test/smoke/` (per-screen smoke).

### Brand
- Brand name is **`MenuRay`** (CamelCase, one word). Never write "Menu Ray" with space, never lowercase except in package/URL contexts.
- Slogan: "Snap a photo of any paper menu, get a shareable digital menu in minutes." (English) / "拍一张照，5 分钟生成电子菜单" (Chinese).
- Brand color hex codes are in [`docs/DESIGN.md`](docs/DESIGN.md). Don't invent new ones.

### Tests
- **Skip strict TDD for UI screens** — see [docs/decisions.md](docs/decisions.md) ADR-007. Smoke test (renders without throwing + key text present) is the bar for screens.
- **Widget tests for shared widgets** — must verify props/behavior, not just render.
- **`flutter analyze` must be clean before commit** — non-negotiable.
- **`flutter test` must pass before commit** — non-negotiable.

### Commits
- **Conventional commits**: `<type>(<scope>): <subject>`.
  - Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`.
  - Scopes used so far: `auth`, `home`, `capture`, `edit`, `ai`, `publish`, `manage`, `store`, `shared`, `theme`, `router`, `nav`, `mock`, `models`, `assets`, `i18n`, `backend`, `customer`, `billing`, `rbac`, `settings`, `menu`, `deps`, `smoke`, `test`.
- One logical change per commit.
- Co-authored-by trailer for AI agent contributions:
  ```
  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  ```

### Branches
- **`main` is the only branch** for now. Once we have remote + multiple contributors, switch to feature branches + PR.
- Don't push to `main` if a remote exists without a PR.

## Don'ts

- ❌ Don't add new dependencies without justification in the PR description.
- ❌ Don't introduce a different state management library (no `bloc`, no `provider`, no `getx`) — we standardized on Riverpod.
- ❌ Don't hardcode user-visible strings — when i18n is set up (see roadmap), every visible string lives in `.arb` files. For now, write strings in a way that's easy to extract (no string concatenation; full sentences in source).
- ❌ Don't bake in vendor-specific OCR / LLM API calls — abstract behind an interface so providers are swappable.
- ❌ Don't commit secrets / API keys. Use `.env` (already gitignored if present) or Supabase secrets.
- ❌ Don't ship code that's only China-specific (短信宝, 微信支付, 阿里云 OCR) — this project is global. Use international defaults; offer Chinese-specific alternatives via plugin/config later.
- ❌ Don't refactor unrelated code while making a focused change. Stay in scope.

## When in doubt

- Read [`docs/decisions.md`](docs/decisions.md) for "why we did it this way".
- If a decision isn't documented and would matter for future contributors, **add an ADR** to `docs/decisions.md` after making it.
- Before any non-trivial implementation, propose the design and get user approval (see superpowers `brainstorming` skill if available).
- Before claiming "done", run `flutter analyze && flutter test` and paste the output.

## Active work

### ✅ Shipped

**Pre-session baseline** — brand system, 17 merchant screens with Supabase wire-up (ADR-017 repository pattern), `parse-menu` realtime + capture flow, full en/zh i18n, iOS/Android camera permissions, product decisions ratified 2026-04-20, ADR-018 supersedes ADR-013 (auth model not yet applied).

**Session 1 — customer view + templates + merchant polish** (37 commits, all on `main`):

- Sub-batch 1: SvelteKit customer view `frontend/customer/` (B1–B4). SSR-by-slug, search/filter, language switcher, JSON-LD schema.org, fixed-bottom MenuRay badge. New migration `20260420000005` adds `stores_anon_read_of_published` RLS. 18 Vitest + 8 Playwright e2e tests. Spec/plan under `docs/superpowers/{specs,plans}/2026-04-20-customer-view-sveltekit*.md`.
- Sub-batch 2: Launch templates Minimal + Grid. Migration `20260420000006` adds `templates` table (5 rows seeded, 2 `is_launch=true`) + `menus.template_id` + `menus.theme_overrides jsonb`. Customer dispatcher + primary-color CSS override. Merchant `SelectTemplateScreen` + tappable logo upload to `store-logos` bucket. ADR-019. Specs/plans at `2026-04-20-launch-templates*.md`.
- Sub-batch 3: Merchant polish. Real logout (signOut + redirect), register link wired, explicit `shouldCreateUser: true`, 4 validator helpers (`lib/shared/validation.dart`) + 3 form-wired screens (login / edit_dish / store_management), `LoadingView` + `ErrorView` shared widgets replacing per-screen duplication in 4 async screens, 2 new empty states. 72 merchant tests. Specs/plans at `2026-04-20-merchant-polish*.md`.

**Session 2 — OpenAI adapter** (10 commits):

OpenAI `gpt-4o-mini` plugged into the existing `parse-menu` pipeline behind the provider factory. Two adapter classes (`OpenAIOcrProvider`, `OpenAIStructureProvider`) + shared HTTP helper. Strict JSON Schema `response_format` guarantees valid output. Mock remains the default — env-var switch (`MENURAY_*_PROVIDER=openai` + `OPENAI_API_KEY`) opts in. Migration `20260420000007` adds `parse_runs.{ocr,llm}_raw_response jsonb` for diagnostic capture. Factory threads `FactoryContext` so real providers persist raw responses via callback. 14 Deno tests with mocked `fetch` — no real API calls in CI. ADR-020. Specs/plans at `2026-04-20-openai-adapter*.md`. Local-dev + prod secret setup documented in `backend/supabase/functions/parse-menu/README.md`.

**Session 3 — auth migration ADR-018** (20 commits):

Single atomic migration `20260424000001_auth_expansion.sql` replaces
`stores.owner_id UNIQUE` with `store_members + organizations +
store_invites` + 3-role RBAC. All 9-table owner RLS policies + 12
storage policies rewritten via `public.user_store_ids()` SETOF-uuid
helper (+ `public.user_store_role(store_id)` for writes). `guard_last_owner`
trigger prevents orphaning a store; `mark_dish_soldout` (SECURITY DEFINER,
staff-safe single-column write), `accept_invite`, and `transfer_ownership`
RPCs ship. Flutter: `activeStoreProvider` (SharedPreferences-persisted
StoreContext), `MembershipRepository`, `StorePickerScreen` + `TeamManagementScreen`,
`RoleGate` widget applied to publish/save/add-category. Backend:
`accept-invite` Edge Function (5 Deno tests). Customer SvelteKit adds a
minimal `/accept-invite` landing page. 22 new en+zh i18n keys. PgTAP
regression script (`backend/supabase/tests/rls_auth_expansion.sql`)
covers cross-store isolation, guard_last_owner, invite round-trip, and
staff write-path. Spec/plan at
`docs/superpowers/{specs,plans}/2026-04-24-auth-migration-adr-018*.md`.

**Session 4 — Stripe billing** (15 commits):

Single atomic migration `20260424000002_billing.sql` adds the
`subscriptions` table (keyed by `owner_user_id`), denormalises `tier`
onto `stores`, adds a `view_logs` INSERT trigger + `pg_cron` reset for
QR-view counts, and three `assert_*_under_cap` SECURITY DEFINER RPCs
for menu/dish/language caps. Four new Edge Functions:
`create-checkout-session` + `create-portal-session` wrap Stripe
Checkout / Customer Portal; `handle-stripe-webhook` verifies HMAC via
`constructEventAsync`, dedupes via `stripe_events_seen`, flips tier on
`checkout.session.completed` (auto-creates `organizations` on Growth),
`customer.subscription.updated` (re-derives via price ID), and
`customer.subscription.deleted`; `create-store` gates multi-store
creation to `tier='growth'`. `parse-menu` now hard-gates re-parses
per-menu per-month. Customer SvelteKit throws 402 on free-tier QR-view
overage and hides the MenuRay badge for Pro+. Flutter: `Tier` enum +
`currentTierProvider` + `TierGate` widget; `/upgrade` route with tier
comparison cards + USD/CNY + monthly/annual toggles + Stripe Checkout
redirect via `url_launcher`; gates applied to home (+ new menu RPC
pre-check), custom-theme picker, settings tile. 28 new en+zh i18n
keys. PgTAP regression covers tier reads, counter trigger, cron reset,
all three `assert` RPCs, and `stripe_events_seen` idempotency.
Spec/plan at
`docs/superpowers/{specs,plans}/2026-04-24-stripe-billing*.md`.
Manual Stripe smoke (test card 4242 + WeChat Pay test method) documented in
`backend/supabase/functions/STRIPE_DEPLOY.md`.

**Session 5 — Analytics real data** (15 commits):

Single atomic migration `20260425000001_analytics.sql` adds `dish_view_logs`
(store_id, dish_id, session_id, qr_variant, viewed_at) with 12-month
`pg_cron` retention, and four SECURITY DEFINER aggregation RPCs gated on
`store_members` membership: `get_store_visit_overview`, `get_store_visits_by_day`,
`get_top_dishes`, `get_store_visits_by_locale`. Two new Edge Functions:
`log-dish-view` (anon, upsert via service-role bypass, session dedup) and
`export-statistics-csv` (Growth-tier only, returns `text/csv` with all four
aggregation results). Customer view gains a `sessionStorage` UUID helper
(`getSessionId`), `DishViewTracker.svelte` (IntersectionObserver + 2-second
debounce, opt-in via `Store.dishTrackingEnabled`), and `logDishView` client —
both Minimal + Grid dish card variants are wrapped. Flutter: `StatisticsRepository`
+ four providers (`visitOverviewProvider`, `visitsByDayProvider`,
`topDishesProvider`, `visitsByLocaleProvider`), Statistics screen rewired with
`Timer.periodic(30 s)` polling + real chart data + `TierGate` CSV-export button
that calls `share_plus` system share sheet; Settings screen gains a
`dish_tracking_enabled` toggle tile. 12 new en+zh i18n keys (analytics
section + dish-tracking opt-in). Spec/plan at
`docs/superpowers/{specs,plans}/2026-04-25-analytics-real-data*.md`.

**Session 6 — QR generation + customer dispatcher refactor** (12 commits):

Reframed from the original "three new templates" brief because the
designer hadn't delivered Bistro / Izakaya / Street assets — see
ADR-023 + spec for the decision rationale. Real `qr_flutter`
`QrImageView` on `published_screen.dart` encodes
`AppConfig.customerMenuUrl(menu.slug)` (compile-time host via
`String.fromEnvironment('MENURAY_CUSTOMER_HOST')`, default
`menu.menuray.com`), embeds the store logo at the centre with
`errorCorrectionLevel: H`. The previously decorative buttons
(`publishedExportQr` / `publishedExportSocial` / `publishedSocialCopy`
/ `publishedSocialMore` / `publishedSocialWeChat` / link-row copy)
all wire to one of three handlers: `_handleShareQrPng` captures an
`Offstage` `RepaintBoundary` containing a brand-styled `_QrShareCard`
(store name + 460px QR + "Scan to view menu" caption +
`menuray.com` wordmark) at `pixelRatio: 3.0`, writes via
`QrExportService` to `path_provider`'s temp dir, hands off to
`SharePlus`; `_handleCopyLink` populates `Clipboard` + snackbar;
`_handleShareUrl` invokes `SharePlus` with the text URL (system
sheet routes to WeChat / Mail / etc.). PDF export hidden — deferred
to P1. `team_management_screen.dart` invite link now reads the same
`AppConfig.customerInviteUrl(token)`. Customer view dispatcher
refactored from `if/else` to `Record<TemplateId, ComponentType>`
registry in `frontend/customer/src/lib/templates/registry.ts` with
defensive `resolveTemplate(id)` falling back to `MinimalLayout` for
designer-pending Bistro/Izakaya/Street + unknown / null ids;
`[slug]/+page.svelte` shrinks to `const Template = $derived(...)` +
`<Template {data} />`. 4 new en+zh i18n keys
(`publishedLinkCopied`, `publishedShareSubject` with `storeName`
placeholder, `publishedScanCaption`, `publishedShareFailed`).
Spec/plan at
`docs/superpowers/{specs,plans}/2026-04-25-qr-and-dispatcher*.md`.
ADR-023.

**Session 7 — AI batch + multi-store button** (~12 commits):

Closes the last three P0-coding items in one session.

`backend/supabase/migrations/20260425000002_ai_runs.sql` adds the
`ai_runs` table (one row per translate-menu / ai-optimize call) +
`(store_id, month)` index. `_shared/quotas.ts` centralises
`AI_BATCH_QUOTA = {free:1, pro:10, growth:100}` (cumulative per
store per month) and `LOCALE_CAP = {free:2, pro:5, growth:∞}`
(per-menu, counts source).

Two new Edge Functions reuse the S2 OpenAI provider pattern (mock
default in CI):
- `translate-menu` — `{menu_id, target_locale}` → tier-cap +
  monthly-quota gate → batched LLM translation via strict JSON Schema
  → upserts `category_translations` + `dish_translations` + bumps
  `menus.available_locales`. 5 Deno tests.
- `ai-optimize` — `{menu_id}` → monthly-quota gate → batched LLM
  description rewrite → PATCHes each `dishes.source_description`. 4
  Deno tests.

Merchant `ai_optimize_screen.dart` becomes a `ConsumerStatefulWidget`
taking a required `menuId` route param (`/ai/optimize/:menuId`).
Auto-image toggle is disabled with a `(coming soon)` subtitle suffix
(P1); locale picker expanded from 4 to 8 (en, zh-CN, ja, ko, fr, es,
de, vi). `_onStart` calls `optimizeDescriptions` then `translateMenu`
in sequence based on toggle state, shows a progress overlay, surfaces
the typed `AiQuotaError` (402/429) as an `Upgrade` snackbar.

Store Picker grows a `+ New store` tile that wraps S4's `create-store`
Edge Function via a new `StoreCreationRepository`. 403 →
`MultiStoreRequiresGrowthError` → snackbar + `/upgrade`. Modal sheet
with name + currency + source-locale fields; on success refreshes
memberships, sets active store, navigates home.

18 new en+zh i18n keys (4 locale labels + 7 AI runtime + 7 store
form). Spec/plan at
`docs/superpowers/{specs,plans}/2026-04-25-ai-batch-and-multi-store*.md`.
ADR-024.

**Session 8 — Merchant editorial polish** (~9 commits):

Three small surfaces in one M-budget batch.

`backend/supabase/migrations/20260426000001_menus_available_locales_and_duplicate.sql`
does two things:

1. Declares the `menus.available_locales text[]` column the S7
   `translate-menu` Edge Function had been reading + writing without a
   schema entry. Backfills via UNION over `source_locale +
   dish_translations.locale + category_translations.locale` so existing
   menus pass the locale-cap arithmetic immediately.
2. Adds the `public.duplicate_menu(p_source_menu_id uuid)` SECURITY
   DEFINER RPC. Validates caller is `owner`/`manager` via
   `user_store_role`; runs `assert_menu_count_under_cap` (S4 hard-gate);
   deep-clones categories + dishes + translations into a `status='draft'`,
   `slug=NULL` menu with name suffixed " (copy)". Image URL strings
   copied; bucket objects NOT cloned (documented in ADR-025).

Flutter:
- `_QrShareCard.showWordmark` reads `currentTierProvider`; Pro/Growth
  hide the `menuray.com` wordmark on the brand-styled share PNG.
  On-screen QR card unchanged.
- `MenuManagementScreen._setTimeSlot` invokes
  `MenuRepository.updateMenu(timeSlot:)`; optimistic local snap +
  network round-trip + `invalidate(menuByIdProvider)`.
- `HomeScreen` wires `MenuCard.onMore` → bottom sheet with one option
  ("Duplicate menu") → `MenuRepository.duplicateMenu` → on success
  invalidate menus + go to the new menu's manage screen; on
  `MenuCapExceededError` snackbar with "Upgrade" action linking to
  `/upgrade`.

5 new en+zh i18n keys; 4 new Flutter smoke tests (117 total); PgTAP
`billing_quotas.sql` extended with 2 `duplicate_menu` cases (happy +
free-tier-cap raise). Spec/plan at
`docs/superpowers/{specs,plans}/2026-04-26-merchant-polish*.md`.
ADR-025.

**Session 9 — PDF table-tent generator** (~5 commits):

Wires the hidden-since-S6 `publishedExportPdf` button to a new
`PdfExportService` (`lib/features/publish/data/pdf_export_service.dart`)
that builds an A4-portrait page with two stacked table-tent panels
(store name + 180pt vector QR + scan caption + URL + tier-aware
menuray.com wordmark) separated by a dashed cut guide. Pure-Dart `pdf`
package — no native plugins. Output written to path_provider's temp
dir as `menuray-<menuId>-tent.pdf`; handed to `share_plus`.

Tier gating mirrors S8: `_PublishedBodyState.build` reads
`currentTierProvider` once and passes the same `showWordmark` flag to
both the share PNG and the PDF call, so Pro+ gets a clean print
artifact in either format.

1 new i18n key (`publishedExportPdfFailed`); 2 new unit tests for the
service (PDF header byte check + Pro-tier no-wordmark variant); 1
extended smoke test for the button presence. Spec/plan at
`docs/superpowers/{specs,plans}/2026-04-26-pdf-table-tent*.md`. ADR-026.

**Current test totals:** 119 merchant Flutter tests · 25 customer Vitest + 8 Playwright e2e · 40 Deno tests (5 accept-invite + 4 create-checkout + 3 create-portal + 5 handle-stripe-webhook + 4 create-store + 5 log-dish-view + 5 export-statistics-csv + 5 translate-menu + 4 ai-optimize) · PgTAP analytics_aggregations + billing_quotas (extended in S8) + rls_auth_expansion. `flutter analyze` + `pnpm check` clean.

### 🔄 Next — launch-readiness + designer-delivered templates

All P0 *coding* tasks are now closed. What remains for "first real
restaurant on hosted instance":

| # | Scope | Size | Owner |
|---|---|---|---|
| — | Logo finalisation (Figma multi-size export from `docs/logo-prompts.md`) | S | human |
| — | Domain registration (`menuray.com` / `.app`) | S | human |
| — | Trademark search (USPTO + EUIPO + WIPO) | S | human |
| — | Privacy policy + ToS drafts | S | human |
| — | Public GitHub repo + branch protection + CI passing on `main` | S | human |
| — | Demo URL hosting merchant app + sample menu | S | human |
| — | Real-device pass on iOS + Android | S | human |
| — | Reference deployment via Supabase Cloud (free tier) | S | needs human Supabase account |
| — | Bistro / Izakaya / Street `MenuPage.svelte` (still pending designer). Drop-in is now: add `frontend/customer/src/lib/templates/<id>/MenuPage.svelte` + register in `$lib/templates/registry.ts` + flip `is_launch=true` on the templates row. | S per template, M for the group | needs designer |

See [`docs/roadmap.md`](docs/roadmap.md) for the full prioritized list and [`docs/superpowers/plans/`](docs/superpowers/plans/) for every shipped plan.

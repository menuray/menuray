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
| Merchant app | Flutter (stable), Material 3, Riverpod, go_router, google_fonts |
| Customer view | SvelteKit (SSR + Node adapter, anon RLS + JSON-LD) |
| Backend | Supabase (Postgres + Auth + Storage + Edge Functions) |
| AI | OCR + LLM (provider-agnostic) |

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
  - Scopes used so far: `auth`, `home`, `capture`, `edit`, `ai`, `publish`, `manage`, `store`, `shared`, `theme`, `router`, `nav`, `mock`, `models`, `assets`.
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

**Current test totals:** 88 merchant Flutter tests · 18 customer Vitest + 8 Playwright e2e · 14 Deno tests (9 parse-menu + 5 accept-invite) · PgTAP RLS regression. `flutter analyze` + `pnpm check` clean.

### 🔄 Next — Sessions 4–6

| # | Scope | Size estimate |
|---|---|---|
| 4 | Stripe billing — subscription plans, paywall gates on feature flags (multi-store, Pro custom theme, QR volume cap, language cap). Depends on Session 3 auth. | L |
| 5 | Analytics pipeline — `view_logs` dedup / bot-filter edge function, Statistics screen wired to real data (top dishes, category breakdown, traffic by locale) | M |
| 6 | Templates Bistro / Izakaya / Street — designer-delivered; flip `is_launch=true`, implement 3 new `$lib/templates/*/MenuPage.svelte`; consider dynamic-import dispatcher at this scale | M |

See [`docs/roadmap.md`](docs/roadmap.md) for the full prioritized list and [`docs/superpowers/plans/`](docs/superpowers/plans/) for every shipped plan.

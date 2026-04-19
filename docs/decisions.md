# Architecture Decision Records (ADRs)

> Each ADR is a short, dated record of *why* a non-obvious choice was made. When in the future you wonder "why did we pick X?", read here. When you make a new architectural choice, **add a new ADR**.

Format: status — context — decision — consequences.

---

## ADR-001 — Open source, MIT licensed, global from day one

**Date:** 2026-04-19
**Status:** Accepted

**Context:** The team needs a license stance and audience scope before publishing the repo.

**Decision:**
- License: **MIT** — maximum adoption, commercial-friendly, simple.
- Audience: **global SMB restaurants** — not China-first, not US-first. English-primary docs with Chinese supplement.
- Public from day one.

**Consequences:**
- ✅ No ICP 备案 burden (not deploying primarily inside China).
- ✅ Phone OTP can use Twilio defaults; no custom SMS provider needed for v1.
- ✅ Forks and self-hosting are first-class — architecture stays portable.
- ⚠️ China-mainland users may experience higher latency on hosted instance; we'll document self-hosting on Alibaba Cloud as a workaround if demand arises.
- ⚠️ Internationalization is a P0 concern, not P3 — see ADR-009.

---

## ADR-002 — Flutter for the merchant app

**Date:** 2026-04-19
**Status:** Accepted

**Context:** Need cross-platform native UX for the staff-facing app (camera capture, photo editing, frequent use). Single-codebase preferred to halve maintenance.

**Decision:** Flutter (stable channel) with Material 3.

**Alternatives considered:**
- React Native — JavaScript fatigue, fragmented native module ecosystem, slower for image-heavy UIs.
- Native Swift + Kotlin — 2× the work; team is small.
- PWA — camera & file system limitations on mobile browsers.

**Consequences:**
- ✅ Single codebase for iOS + Android + Web (dev preview).
- ✅ Material 3 gives us a coherent default look that's easy to brand.
- ⚠️ Flutter Web bundle is large — we're using it for development preview only, not for the customer-facing experience (see ADR-003).

---

## ADR-003 — SvelteKit for customer view (separate from merchant app)

**Date:** 2026-04-19
**Status:** Accepted

**Context:** Diners scan a QR code on a table tent and the menu must open near-instantly on a cold mobile browser. First paint matters more than anything else.

**Decision:** Implement the customer view as a separate SvelteKit project (`frontend/customer/`), not as part of the Flutter app.

**Alternatives considered:**
- Flutter Web — initial bundle too large for "open and view" UX (multi-MB cold load).
- Next.js / React — fine, but heavier than SvelteKit for this simple read-only case.
- Plain HTML + Tailwind generated server-side — workable, but we want SSR + i18n + state for filters/search; SvelteKit gives us that for similar bundle size.

**Consequences:**
- ✅ Customer first paint can be sub-500ms over 4G with SSR.
- ✅ SEO-friendly: search engines can index public menu pages.
- ⚠️ Two frontend stacks to maintain. We'll share the design system via [DESIGN.md](DESIGN.md) and a small CSS variable set rather than a shared component lib.

---

## ADR-004 — Supabase as the backend (hosted, with self-host docs)

**Date:** 2026-04-20
**Status:** Accepted

**Context:** Need Postgres + Auth + Storage + serverless functions. Want to avoid writing CRUD plumbing. Want OSS-friendly stack.

**Decision:** **Supabase** (Postgres + Auth + Storage + Edge Functions). Use the hosted service for our reference deployment; document self-hosting (open-source Supabase) for forks.

**Alternatives considered:**
- Firebase — proprietary, NoSQL (less fit for menu data), full vendor lock-in.
- Roll-your-own (Node + Fastify + Prisma + Postgres + S3) — 2–3 weeks of plumbing before we ship the first feature.
- Hasura — strong GraphQL story, but auth & storage need separate services.

**Consequences:**
- ✅ Postgres + auto-API + RLS + Auth + Storage in one product, all OSS.
- ✅ Phone OTP works globally via Twilio.
- ✅ Self-hostable — important for OSS users / privacy-conscious deployments.
- ⚠️ China access from hosted instance is best-effort; document the self-host path.

---

## ADR-005 — Riverpod for state management

**Date:** 2026-04-19
**Status:** Accepted

**Context:** Pick one state management library and stick with it.

**Decision:** **Riverpod** (`flutter_riverpod`).

**Alternatives considered:**
- Bloc — more ceremony for our app's complexity.
- Provider — Riverpod is the spiritual successor and fixes its issues.
- GetX — controversial community reputation; we want defensible choices.
- setState only — fine for now but ceiling is low once we add real data fetching.

**Consequences:**
- ✅ Modern API, compile-time safe, async-friendly.
- ⚠️ Don't introduce a second state library. Period.

---

## ADR-006 — go_router for navigation

**Date:** 2026-04-19
**Status:** Accepted

**Context:** Need a routing solution that supports deep-linking, web URLs, and declarative configuration.

**Decision:** **`go_router`** (official Flutter package).

**Consequences:**
- ✅ All routes declared in one place (`lib/router/app_router.dart`).
- ✅ Web URLs map cleanly to screens (helps debugging).
- ⚠️ Always navigate via `context.go()` / `context.push()`, never via `Navigator.push` directly.

---

## ADR-007 — Skip strict TDD for UI screens

**Date:** 2026-04-19
**Status:** Accepted

**Context:** UI screen translation from designs is mostly pixel work. Forcing TDD on every visual change is high-friction with low payoff.

**Decision:**
- **Strict TDD for shared widgets** that have logic (StatusChip variants, PrimaryButton states).
- **Smoke tests only** for screens — verify route loads + key text present + no exceptions.
- **`flutter analyze` clean + `flutter test` green** are non-negotiable gates before commit.
- **Visual review against Stitch designs** is the actual quality bar for screens.

**Consequences:**
- ✅ Velocity unblocked on UI work.
- ⚠️ Visual regressions easier to slip through. Mitigation: when a UI bug is found, the regression test goes in (e.g., golden test for that specific case).

---

## ADR-008 — Mock data first, real API later

**Date:** 2026-04-19
**Status:** Accepted

**Context:** Building UI before backend is risky if we tie tightly to API shape early.

**Decision:** Build the merchant app with `MockData` (in `lib/shared/mock/mock_data.dart`) seeded from realistic example data (云间小厨, 宫保鸡丁, etc). Replace with Riverpod providers calling real Supabase API in a focused future task.

**Consequences:**
- ✅ UI complete and demo-able without backend.
- ✅ Forces us to think about UI shape first (which the user actually sees), API second.
- ⚠️ Some screens may need refactoring once the real API shape is locked in. Cost is small because each screen is isolated.

---

## ADR-009 — i18n is P0 (not P3)

**Date:** 2026-04-20
**Status:** Accepted

**Context:** Originally i18n was treated as "later" because the team is Chinese. Switching to a global open-source posture (ADR-001) inverts that.

**Decision:**
- Default locale: **English**.
- Chinese as first supplemental language (so existing screens don't lose their copy).
- Use `flutter_localizations` + `.arb` files from the start.
- All hardcoded strings get extracted to `.arb` keys before public OSS launch.
- Customer-facing menu content is **dynamic translation** stored per dish (not part of the static i18n bundle).

**Consequences:**
- ✅ Late i18n retrofit is painful; doing it during initial build is much cheaper.
- ⚠️ Slightly more upfront ceremony per screen.

See [i18n.md](i18n.md) for implementation details.

---

## ADR-010 — Provider-agnostic OCR / LLM

**Date:** 2026-04-20
**Status:** Accepted

**Context:** AI services change fast. Pricing & quality vary. We don't want to be married to one vendor.

**Decision:** Each AI capability (OCR, LLM parsing, LLM translation, image generation) is wrapped in a small interface inside Edge Functions. Default implementation is one specific vendor (Vision for OCR, Claude for LLM), but swapping is one env var + one file change.

**Consequences:**
- ✅ Self-hosters can use whichever provider has best regional pricing/availability.
- ✅ A/B testing providers is straightforward.
- ⚠️ Slightly more code than calling vendor SDK directly. Acceptable trade.

---

## ADR-011 — Brand: "MenuRay" (CamelCase, one word)

**Date:** 2026-04-19
**Status:** Accepted

**Context:** Initial codename was "Happy Menu" but happymenu.com / .app were taken. Also, McDonald's owns "Happy Meal" trademark — risky for global open source.

**Decision:** Rename to **MenuRay**:
- CamelCase, one word ("MenuRay")
- All-lowercase in URL/package contexts (`menuray.com`, `menuray_merchant`, `github.com/menuray`)
- "Menu" + "Ray" — Ray = light beam (camera scan)
- Slogan: "Snap a photo of any paper menu, get a shareable digital menu in minutes."

**Consequences:**
- ✅ Self-explanatory product name (scan menu).
- ✅ Likely to clear trademark.
- ⚠️ Required project-wide rename — done in a single commit before public launch.

---

## ADR-012 — Subagent-driven development workflow

**Date:** 2026-04-19
**Status:** Accepted (for human + AI collaboration)

**Context:** When using Claude Code (or similar) for the bulk of implementation, we want quality gates without manual review on every line.

**Decision:** Use `superpowers:subagent-driven-development` workflow when implementing from a written plan:
1. Implementer subagent (cheap model, mechanical work)
2. Spec compliance reviewer (verifies what was built matches spec)
3. Code quality reviewer (verifies how it was built — clean, tested)

**Consequences:**
- ✅ High quality without intensive human review per task.
- ⚠️ More tokens per task. Acceptable trade for the time saved.
- ⚠️ Reviewer subagents can be over-zealous (we override when their "Critical" is actually a non-issue).

---

## ADR-013 — Tenancy: `stores.owner_id` 1:1 with `auth.users`

**Date:** 2026-04-19
**Status:** Accepted

**Context:** The P0 backend needs a multi-tenancy boundary for RLS. Roadmap defers multi-store / chain accounts and staff sub-accounts to P2.

**Decision:** `stores.owner_id uuid UNIQUE REFERENCES auth.users(id)` — one user owns exactly one store. A `handle_new_user()` trigger on `auth.users` INSERT auto-creates a default store row so `auth.uid()` always maps to exactly one store.

**Alternatives considered:**
- A `memberships(user_id, store_id, role)` junction from day 1. Cleaner future migration path, but unnecessary ceremony for P0/P1 where no shared-ownership scenario exists.

**Consequences:**
- ✅ RLS policies are one-line subqueries: `store_id IN (SELECT id FROM stores WHERE owner_id = auth.uid())`.
- ✅ Zero join overhead in hot paths.
- ⚠️ Adding P2 chain / staff will require a one-time migration: introduce `memberships`, seed it with `(owner_id, store_id, 'owner')` for every existing store, flip RLS policies to reference `memberships`. Cost is small and localized.

---

## ADR-014 — Postgres conventions: `TEXT + CHECK` over `ENUM`; redundant `store_id` on owned tables

**Date:** 2026-04-19
**Status:** Accepted

**Context:** Several columns are constrained to a small set of values (`menu.status`, `dish.spice_level`, `parse_runs.status`, etc.). The schema also repeatedly asks "does this row belong to the current user's store?" for RLS.

**Decision:**
- Use `TEXT` columns with `CHECK (col IN (...))` constraints rather than Postgres `ENUM` types.
- Every owned table carries a redundant `store_id` column (even when derivable from a parent FK).

**Alternatives considered:**
- Postgres `ENUM`: harder to migrate (cannot `DROP VALUE`; requires careful `ALTER TYPE … ADD VALUE` with transaction quirks); cast-unfriendly in policy subqueries.
- Normalized access-control: derive `store_id` via joins in every RLS policy — more joins at every read, higher CPU.

**Consequences:**
- ✅ Adding/removing a value is a one-line `ALTER TABLE … DROP CONSTRAINT … ADD CONSTRAINT` migration.
- ✅ One RLS policy template applies verbatim to every owned table.
- ⚠️ `store_id` must be kept correct on writes. The orchestrator carries `store_id` explicitly through the pipeline; application code does too. Application-level bugs that write the wrong `store_id` would create cross-tenant visibility — caught by integration tests.

---

## ADR-015 — Parse pipeline: single `parse-menu` Edge Function + `parse_runs` status table

**Date:** 2026-04-19
**Status:** Accepted

**Context:** The photo-to-digital-menu pipeline has two distinct stages (OCR, LLM structuring) plus a DB write. It runs 10–30s once real providers are wired in. We need both a clean provider-swap boundary (ADR-010) and a status-tracking mechanism for clients.

**Decision:** One Edge Function `parse-menu` that orchestrates both stages in a linear pipeline. Progress and final outcome are recorded on a `parse_runs` row, keyed by `id`. Clients subscribe to Realtime updates or poll the row.

**Alternatives considered:**
- Split into three functions (`extract-text`, `structure-menu`, `translate-menu`). More boundaries; more deployment surface for P0.
- A step-parameterized single function, driven by the client. Adds client-side orchestration complexity without a clear benefit.

**Consequences:**
- ✅ P0 is simple: one function, one HTTP contract, one RLS-scoped table.
- ✅ `parse_runs.error_stage` ∈ `{'ocr','structure'}` records the seam where a split could later happen.
- ⚠️ If OCR caching by photo hash becomes a need, it lives inside the function for now (or in a new helper table) rather than its own function.

---

## ADR-016 — Storage path convention: `{store_id}/<uuid>.<ext>`

**Date:** 2026-04-19
**Status:** Accepted

**Context:** Three Storage buckets (`menu-photos`, `dish-images`, `store-logos`) all scope by store. We need a way to enforce per-store isolation via RLS on `storage.objects`.

**Decision:** All object keys start with `{store_id}/`, and all three buckets share one RLS-policy template that tests `(storage.foldername(name))[1]::uuid` against `stores.owner_id = auth.uid()`. File names inside that prefix are random UUIDs plus extension, generated client-side.

**Alternatives considered:**
- A central `files(id, bucket, path, store_id, …)` index table + RLS on it — requires a new table + sync on every upload.
- Signed URLs for all reads — OK for private bucket, wasteful for public buckets where the CDN benefits from stable keys.

**Consequences:**
- ✅ Uniform policy across three buckets.
- ✅ Listing/filtering objects by store is fast (common prefix).
- ⚠️ Path traversal attempts (`../`) are blocked by Supabase Storage's name normalization — but we rely on it being correct. Any change there is a breach condition for this convention.

---

## How to add an ADR

When you make a non-obvious architectural choice:

1. Append a new section to this file using the format above.
2. Link to it from the PR description.
3. Don't edit historical ADRs — supersede them with a new one if a decision is reversed (status: "Superseded by ADR-NNN").

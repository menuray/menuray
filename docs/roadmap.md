# MenuRay — Roadmap

> Where we are, what's next, in priority order. Open-source, global SMB-restaurant focus, Supabase backend.
>
> Effort tags: **S** = 1–2 days · **M** = 3–7 days · **L** = 1–4 weeks (single-person estimates).
>
> Updated: 2026-04-25 (post Session 5)

---

## Session map (authoritative progress view)

This block tracks the 6 planned end-to-end sessions. For detail see `CLAUDE.md` "Active work" + `docs/superpowers/{specs,plans}/`.

- **✅ Session 1** (2026-04-20) — Customer view B1–B4 + 2 launch templates + merchant polish. Three sub-batches, 37 commits. Specs/plans `2026-04-20-customer-view-sveltekit*`, `2026-04-20-launch-templates*`, `2026-04-20-merchant-polish*`. ADR-019.
- **✅ Session 2** (2026-04-20) — OpenAI `gpt-4o-mini` OCR+LLM adapter behind strict JSON Schema. 10 commits. Specs/plans `2026-04-20-openai-adapter*`. ADR-020.
- **✅ Session 3** (2026-04-24) — ADR-018 auth expansion — `store_members`, `organizations`, `store_invites`, 3-role RBAC (Owner/Manager/Staff), `guard_last_owner` trigger, `mark_dish_soldout`/`accept_invite`/`transfer_ownership` RPCs, Flutter store picker + team management screens, copy-link invite flow, `accept-invite` Edge Function + SvelteKit landing page. 88 Flutter tests · 18 customer Vitest + 8 Playwright e2e · 14 Deno tests (9 parse-menu + 5 accept-invite) · PgTAP RLS regression. 20 commits. Specs/plans `2026-04-24-auth-migration-adr-018*`. ADR-018 fully applied.
- **✅ Session 4** (2026-04-24) — Stripe billing — subscriptions table, tier denormalisation on stores, hard-gate RPCs (menu/dish/translation count), monthly QR-view counter + pg_cron reset, four Edge Functions (create-checkout-session, create-portal-session, handle-stripe-webhook, create-store), parse-menu re-parse quota gate, customer-view 402 paywall + MenuRay badge gating, Flutter Upgrade screen + TierGate + currentTierProvider, 28 i18n keys. 101 Flutter tests · 18 customer Vitest + 8 Playwright e2e · 35 Deno tests (14 shared-providers + 5 accept-invite + 4 create-checkout + 3 create-portal + 5 handle-stripe-webhook + 4 create-store). Both PgTAP scripts (billing_quotas + rls_auth_expansion) green. 15 commits. Specs/plans `2026-04-24-stripe-billing*`. ADR-021.
- **✅ Session 5** (2026-04-25) — Analytics real data — `dish_view_logs` table + 4 SECURITY DEFINER aggregation RPCs (visits overview / by day / top dishes / by locale), 2 new Edge Functions (`log-dish-view` anon + `export-statistics-csv` Growth-only returning `text/csv`), customer-view `DishViewTracker` (IntersectionObserver, 2-sec debounce), Statistics screen rewired with 30-sec polling + TierGate + `share_plus` CSV export, Settings dish-tracking opt-in toggle, 12-month retention via `pg_cron`. 106 Flutter tests · 18 Vitest + 8 Playwright e2e · 31 Deno tests. Three PgTAP regressions green (analytics_aggregations + billing_quotas + rls_auth_expansion). 15 commits. Specs/plans `2026-04-25-analytics-real-data*`.
- **✅ Session 6** (2026-04-25) — Reframed from "three new templates" (designer assets still pending) to QR + dispatcher infra. Real `qr_flutter` `QrImageView` on PublishedScreen + brand-styled share PNG via `Offstage`+`RepaintBoundary`+`share_plus`; `Clipboard` copy-link with snackbar; customer host pulled into compile-time `AppConfig.customerHost` (default `menu.menuray.com`, override via `--dart-define=MENURAY_CUSTOMER_HOST=…`); customer template dispatcher refactored to `Record<TemplateId, ComponentType>` registry so designer-delivered Bistro / Izakaya / Street drop in as one file + one map entry. 4 new i18n keys; 5 new tests (3 AppConfig unit + 1 QrExportService unit + 1 PublishedScreen smoke split into 2 + 7 customer registry); ADR-023. Spec/plan `2026-04-25-qr-and-dispatcher*`.
- **✅ Session 7** (2026-04-25) — AI batch + multi-store button. New `ai_runs` table + `_shared/quotas.ts` (locale cap + monthly batch quota per tier). Two new Edge Functions: `translate-menu` (per-menu batched LLM translation, locale-cap-gated, upserts category_translations + dish_translations + bumps `menus.available_locales`) and `ai-optimize` (per-menu description rewrite). Both inherit the existing OpenAI gpt-4o-mini provider factory; mock stays default in CI. Merchant `ai_optimize_screen.dart` rewired to drive both Edge Functions; auto-image toggle disabled (P1); locale picker expanded 4→8. New `+ New store` tile on Store Picker wraps S4 `create-store` (Growth-gated server-side; 403 → snackbar + `/upgrade`). 18 new i18n keys (en + zh); 9 new Deno tests (5 translate-menu + 4 ai-optimize) + 2 Flutter smoke updates. ADR-024. Spec/plan `2026-04-25-ai-batch-and-multi-store*`.
- **🔄 Next: designer-delivered templates** — Bistro / Izakaya / Street still pending. Drop-in pattern is now: add `frontend/customer/src/lib/templates/<id>/MenuPage.svelte` + register in `$lib/templates/registry.ts` + flip `is_launch=true` on the matching row in the templates seed. Per-template effort **S**; group **M**.

Current test totals: 113 merchant Flutter · 25 customer Vitest + 8 Playwright e2e · 40 Deno tests (5 accept-invite + 4 create-checkout + 3 create-portal + 5 handle-stripe-webhook + 4 create-store + 5 log-dish-view + 5 export-statistics-csv + 5 translate-menu + 4 ai-optimize) · PgTAP analytics_aggregations + billing_quotas + rls_auth_expansion. Branch: `main` only (no remote).

---

## ✅ Done (pre-session baseline)

- Brand system (`docs/DESIGN.md`)
- 21 Stitch UI designs (`frontend/design/`)
- Logo generation prompts (`docs/logo-prompts.md`)
- Merchant Flutter app — 17 screens with mock data
- Open-source baseline: README, LICENSE (MIT), CLAUDE.md, CONTRIBUTING, CoC, SECURITY, ADRs, GitHub templates, Flutter CI

---

## P0 — Required for public OSS launch + first paying-or-using restaurant

> Goal: a stranger can clone the repo, follow the README, and have a working "snap → digital menu → QR" demo locally. A real restaurant can use the hosted reference instance.

### Backend (Supabase)
- [x] **M** Set up Supabase project + DB schema (stores / users / menus / categories / dishes / dish_translations / view_logs) — migrations `20260420000001`–`20260420000007`
- [x] **M** Row Level Security policies — multi-tenant isolation by store (plus `stores_anon_read_of_published` + `templates_public_read`)
- [x] **S** Phone OTP + email/password auth (Supabase Auth defaults) — explicit `shouldCreateUser: true` wired Session 1
- [x] **S** Storage buckets: `menu-photos` (private), `dish-images` (public read), `store-logos` (public read)
- [x] **M** Edge Function `parse-menu`: orchestrates OCR + LLM parser (mock + OpenAI provider paths shipped)
- [x] **S** Edge Function `translate-menu`: per-menu batched translation via LLM (Session 7, ADR-024)
- [x] **S** Database migration scripts versioned in `backend/supabase/migrations/` (Supabase CLI)
- [ ] **S** Reference deployment via Supabase Cloud (free tier) — launch readiness item

### AI services (provider-agnostic)
- [x] **M** OCR provider interface + OpenAI `gpt-4o-mini` vision adapter (Session 2, ADR-020). Google Vision adapter: factory has placeholder, not implemented
- [x] **M** LLM provider interface + OpenAI `gpt-4o-mini` structuring adapter (Session 2). Anthropic adapter: factory placeholder, not implemented
- [x] **S** Document how to swap providers (env vars + ADR-010 + ADR-020 + parse-menu README)

### Merchant app — connect to real backend
- [x] **S** Login + home screens wired to Supabase (seed user, 2/17 screens)
- [x] **M** Menu-manage screen wired to Supabase (read + sold-out mutation)
- [x] **M** `parse-menu` realtime subscription from the capture/processing flow
- [x] **M** Batch 1 (edit_dish / organize_menu / preview_menu / published / settings / store_management) wired to Supabase
- [x] **M** Batch 2 (camera / correct_image / processing / select_photos) wired to Supabase + parse-menu realtime
- [x] **S** select_template wired (Session 1 sub-batch 2; ADR-019 templates)
- [x] **S** custom_theme wired with TierGate (Session 4 — Pro+ unlocks color picker)
- [x] **S** statistics wired to real RPC aggregations (Session 5 — 30s polling, Growth-only CSV export)
- [x] **S** ai_optimize — wired to translate-menu + ai-optimize Edge Functions (Session 7, ADR-024). Auto-image stays disabled pending P1 image-gen provider choice.
- [x] **S** Real camera integration (`image_picker` / `camera`)
- [x] **S** iOS Info.plist + Android Manifest permission strings for camera + photo library
- [x] **M** correct_image rotate + axis-aligned crop (perspective correction deferred — see P1 follow-up)
- [x] **S** Home 相册 entry point → `/capture/select` (FAB now opens a bottom-sheet source picker)
- [x] **S** Form validation (phone E.164 / CN mobile, price non-negative + 2-decimal, required fields) — `lib/shared/validation.dart` + login / edit_dish / store_management (Session 1 sub-batch 3)
- [x] **S** Loading / error / empty states — `LoadingView` + `ErrorView` + `EmptyState` shared trio; 4 async screens refactored; 2 new empty states (Session 1 sub-batch 3)
- [ ] **S** Real-device pass on iOS + Android — launch readiness item

### Customer view (`frontend/customer/`)
- [x] **M** Set up SvelteKit 2 + Svelte 5 runes + Tailwind v4 project with shared design tokens (`@theme` CSS vars matching merchant `AppColors`)
- [x] **M** B1 menu home (sticky category nav + dish cards + sold-out badges)
- [x] **S** B2 dish detail (deep-linkable at `/<slug>/<dishId>`)
- [x] **S** B3 search + filter (client-side, diacritic-insensitive, empty-category hiding)
- [x] **S** B4 language switcher (URL `?lang=` + localStorage)
- [x] **S** QR generation — `qr_flutter` real QR + brand-styled share PNG + Clipboard copy-link on PublishedScreen (Session 6)
- [x] **S** SEO meta tags + schema.org JSON-LD (Restaurant + Menu + MenuSection + MenuItem)
- [x] **M** Launch templates — Minimal + Grid; 3 more (Bistro / Izakaya / Street) placeholders seeded awaiting designer (Session 6)

### i18n (P0, not P3 — see ADR-009)
- [x] **M** Set up `flutter_localizations` + `.arb` files for merchant app
- [x] **M** Extract all hardcoded strings → `app_en.arb` (default) + `app_zh.arb`
- [x] **S** In-app language picker
- [x] **S** Customer view: locale negotiation via URL param → localStorage → Accept-Language → menu `source_locale`
- [ ] Detail in [`docs/i18n.md`](i18n.md)

### Brand & launch readiness
- [ ] **S** Logo: generate from `docs/logo-prompts.md`, vectorize in Figma, export multi-size
- [ ] **S** Domain: confirm `menuray.com` / `.app` availability + register
- [ ] **S** Trademark search: USPTO + EUIPO + WIPO Madrid for "MenuRay"
- [ ] **S** Privacy policy + Terms of Service drafts (with legal review)
- [ ] **S** Public GitHub repo with branch protection + CI passing on `main`
- [ ] **S** Demo URL hosting the merchant app + a sample menu (linked from README)

---

## P1 — Core differentiators

> Make it good enough that someone would pay for the hosted version. Tackle after P0 ships and we have ≥10 real restaurants on it.

### AI enhancements
- [ ] **M** Auto-generate dish images for missing-photo dishes
- [ ] **S** One-click translate entire menu
- [ ] **S** One-click description rewrite/expansion
- [ ] **S** AI-call cost tracking + per-merchant quotas

### Capture polish
- [ ] **M** correct_image perspective / skew correction (axis-aligned crop + 90° rotate shipped in P1 polish batch; full perspective correction deferred until real OCR behaviour informs the ergonomics)

### Real analytics
- [x] **M** Customer view sends anonymous view events (Session 1; dish-view tracking added Session 5 with opt-in)
- [x] **S** Statistics screen (A15) reads real data (Session 5)
- [x] **S** Top dishes / category breakdown (Session 5 — top dishes via opt-in `dish_view_logs`; category breakdown deferred — store-level traffic by locale ships instead)
- [ ] **S** Optional weekly email digest — deferred

### Templates & theming
- [ ] **M** Real menu template system — 4–6 designs, data-driven render
- [ ] **S** Custom theme color/logo applies to live customer view

### Operational features
- [ ] **S** Multi-menu (lunch / dinner / seasonal) — connected to backend
- [ ] **S** Sold-out toggles persist
- [ ] **S** Menu duplication / templating

---

## P2 — Scale & monetize

> When >100 restaurants are active. Don't pre-optimize.

- [x] **M** Multi-store with real auth (chain accounts) — Session 3 (ADR-018) + Session 4 `create-store` Edge Fn (Growth-tier gated)
- [x] **M** Sub-accounts + permission tiers (Owner / Manager / Staff) — Session 3, 3-role RBAC + invite flow
- [x] **L** Billing (Stripe): Free / Pro / Growth tiers, monthly + USD-annual, WeChat Pay + Alipay day-1 — Session 4 (ADR-021)
- [x] **S** Subscription management — Stripe Customer Portal (Session 4); dunning is Stripe's automatic retries (no in-app banner yet — see deferred)
- [ ] **M** App Store + Google Play submissions (beta via TestFlight first)
- [ ] **L** Admin console for project owners (user mgmt, menu moderation, analytics)
- [x] **S** Multi-store "+ New store" Flutter UI button — tile on Store Picker, wraps S4 `create-store` Edge Function (Session 7)

---

## P3 — Long-tail polish

> Nice-to-have. Won't block adoption. Pick based on user feedback.

- [ ] **M** Dark mode
- [ ] **M** Accessibility audit + improvements (screen readers, font scaling)
- [ ] **S** Customer view PWA (add-to-home-screen)
- [ ] **S** Image lazy loading + skeleton refinements
- [ ] **L** Comprehensive automated testing (golden tests, E2E with Patrol or Maestro)
- [ ] **S** Crash reporting (Sentry)
- [ ] **S** Privacy-preserving analytics (Plausible / PostHog)
- [ ] **M** Offline cache for customer view
- [ ] **S** A/B testing infrastructure
- [ ] **L** RTL language support audit + fixes
- [ ] **S** Voice-driven menu reading (accessibility + multilingual diners)

---

## Strategic notes

### Critical path

```
Logo + Domain         →  Public OSS launch announcement
       +
Supabase setup        →  Merchant connects to real API  →  First real restaurant on hosted
       +                                                           ↑
i18n migration        →  English-first docs              →  Global adoption signal
```

These three tracks (brand, backend, i18n) all need to clear before P0 is done. They're parallelizable across contributors.

### Validation before scaling

Before pouring effort into P1 features, validate with real restaurants:
- Find 3–5 small restaurants willing to use the demo
- Have them snap a real menu, generate the QR, put it on their tables for one week
- Track: did diners use it? Did the merchant come back to update it?
- **Real usage data > more features**

### What we are deliberately *not* doing

- A custom-built backend framework (Supabase covers it)
- Microservices (one Postgres + a few Edge Functions is plenty)
- Native iPad layouts (responsive only)
- Web3 / blockchain anything
- Self-trained ML models (use APIs)
- China-specific features in core (provided as plugin/config later if community wants it)
- A built-in POS / ordering system (out of scope — we're display, not transaction)

---

## Contributing

Pick anything from P0 with no assignee, claim it on the issue tracker, and ship a PR. New language translations and bug reports are *especially* welcome.

See [CONTRIBUTING.md](../CONTRIBUTING.md) for the workflow.

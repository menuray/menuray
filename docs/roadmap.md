# MenuRay — Roadmap

> Where we are, what's next, in priority order. Open-source, global SMB-restaurant focus, Supabase backend.
>
> Effort tags: **S** = 1–2 days · **M** = 3–7 days · **L** = 1–4 weeks (single-person estimates).
>
> Updated: 2026-04-20

---

## ✅ Done

- Brand system (`docs/DESIGN.md`)
- 21 Stitch UI designs (`frontend/design/`)
- Logo generation prompts (`docs/logo-prompts.md`)
- Merchant Flutter app — 17 screens with mock data, 27 tests passing
- Open-source baseline: README, LICENSE (MIT), CLAUDE.md, CONTRIBUTING, CoC, SECURITY, ADRs, GitHub templates, Flutter CI

---

## P0 — Required for public OSS launch + first paying-or-using restaurant

> Goal: a stranger can clone the repo, follow the README, and have a working "snap → digital menu → QR" demo locally. A real restaurant can use the hosted reference instance.

### Backend (Supabase)
- [ ] **M** Set up Supabase project + DB schema (stores / users / menus / categories / dishes / dish_translations / view_logs)
- [ ] **M** Row Level Security policies — multi-tenant isolation by store
- [ ] **S** Phone OTP + email/password auth (Supabase Auth defaults work globally)
- [ ] **S** Storage buckets: `menu-photos` (private), `dish-images` (public read), `store-logos` (public read)
- [ ] **M** Edge Function `parse-menu`: orchestrates OCR + LLM parser
- [ ] **S** Edge Function `translate-menu`: per-dish translation via LLM
- [ ] **S** Database migration scripts versioned in `backend/migrations/` (Supabase CLI)
- [ ] **S** Reference deployment via Supabase Cloud (free tier)

### AI services (provider-agnostic)
- [ ] **M** OCR provider interface + Google Vision adapter
- [ ] **M** LLM provider interface + Anthropic Claude adapter (with OpenAI fallback)
- [ ] **S** Document how to swap providers (env vars + ADR-010)

### Merchant app — connect to real backend
- [x] **S** Login + home screens wired to Supabase (seed user, 2/17 screens)
- [x] **M** Menu-manage screen wired to Supabase (read + sold-out mutation)
- [x] **M** `parse-menu` realtime subscription from the capture/processing flow
- [x] **M** Batch 1 (edit_dish / organize_menu / preview_menu / published / settings / store_management) wired to Supabase
- [x] **M** Batch 2 (camera / correct_image / processing / select_photos) wired to Supabase + parse-menu realtime
- [ ] **S** Remaining 4 screens (ai_optimize / select_template / custom_theme / statistics) — deferred past P0
- [x] **S** Real camera integration (`image_picker` / `camera`)
- [ ] **S** iOS Info.plist + Android Manifest permission strings for camera + photo library (P1 follow-up carried from Batch 2)
- [ ] **M** correct_image crop / rotate / perspective UI (P1 follow-up carried from Batch 2)
- [ ] **S** Home 相册 entry point → `/capture/select` (minor UX gap; currently only reachable by direct URL)
- [ ] **S** Form validation (phone format, price, required fields)
- [ ] **S** Loading / error / empty states reviewed across all 17 screens
- [ ] **S** Real-device pass on iOS + Android

### Customer view (`frontend/customer/`)
- [ ] **M** Set up SvelteKit project with shared design tokens
- [ ] **M** B1 menu home (sticky category nav + dish cards + sold-out)
- [ ] **S** B2 dish detail
- [ ] **S** B3 search + filter
- [ ] **S** B4 language switcher
- [ ] **S** QR generation + slug-based URLs (`menu.menuray.com/<slug>`)
- [ ] **S** SEO meta tags + structured data (so menus are discoverable)

### i18n (P0, not P3 — see ADR-009)
- [x] **M** Set up `flutter_localizations` + `.arb` files for merchant app
- [x] **M** Extract all hardcoded strings → `app_en.arb` (default) + `app_zh.arb`
- [ ] **S** In-app language picker
- [ ] **S** Customer view: locale negotiation via Accept-Language + URL param
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

### Real analytics
- [ ] **M** Customer view sends anonymous view events
- [ ] **S** Statistics screen (A15) reads real data
- [ ] **S** Top dishes / category breakdown
- [ ] **S** Optional weekly email digest

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

- [ ] **M** Multi-store with real auth (chain accounts)
- [ ] **M** Sub-accounts + permission tiers (manager / staff)
- [ ] **L** Billing (Stripe): free tier + Pro subscription
- [ ] **S** Subscription management + dunning
- [ ] **M** App Store + Google Play submissions (beta via TestFlight first)
- [ ] **L** Admin console for project owners (user mgmt, menu moderation, analytics)

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

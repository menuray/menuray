# MenuRay

> **Snap a photo of any paper menu — get a shareable digital menu in minutes.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-stable-02569B.svg?logo=flutter)](https://flutter.dev)
[![中文](https://img.shields.io/badge/lang-中文-red.svg)](README.zh-CN.md)

MenuRay is an open-source, AI-assisted tool for restaurants to digitize their paper menus through a single photo capture. Diners scan a QR code to view, search, and translate the menu in their language — no app install required.

It is designed for the **global SMB restaurant market**, with first-class support for multilingual menus and self-hosting.

---

## Status

🚧 **Work in progress**. Open source from day one.

| Component | Status |
|---|---|
| Brand & visual design | ✅ Done — see [`docs/DESIGN.md`](docs/DESIGN.md) |
| Stitch UI designs (21 screens) | ✅ Done — see [`frontend/design/`](frontend/design/) |
| Merchant mobile app (Flutter) | ✅ Wired to Supabase across 18 screens (incl. Store Picker / Team Management / Upgrade) — Riverpod data layer, en/zh i18n, RBAC + tier gates |
| Customer scan-to-view web (SvelteKit) | ✅ B1–B4 views, search/filter, language switching, JSON-LD, 2-template dispatcher (Minimal + Grid), QR-view paywall, dish-view tracking. See [`frontend/customer/`](frontend/customer/) |
| Backend (Supabase) | ✅ Schema + RLS + Storage + 7 Edge Functions (`parse-menu`, `accept-invite`, `create-checkout-session`, `create-portal-session`, `handle-stripe-webhook`, `create-store`, `log-dish-view`, `export-statistics-csv`); 3 PgTAP regression scripts |
| OCR + LLM | ✅ OpenAI `gpt-4o-mini` (Session 2, ADR-020); mock fallback for CI |
| Auth + RBAC | ✅ `store_members` + 3 roles (Owner / Manager / Staff), email magic-link invites (ADR-018) |
| Billing | ✅ Stripe Checkout + Customer Portal (Free / Pro / Growth tiers), WeChat Pay + Alipay day-1, hard quota gates |
| Analytics | ✅ Real visit data, top dishes (opt-in), traffic by locale, 30-sec polling, Growth-tier CSV export |
| Logo (final asset) | 🔄 Prompts ready, generation pending |
| App Store / Play Store releases | 🔄 Future |

See [`docs/roadmap.md`](docs/roadmap.md) for the prioritized todo list.

---

## Quick start

### Run the merchant app

**Prereq:** [Flutter SDK](https://flutter.dev/docs/get-started/install) (stable channel).

```bash
git clone git@github.com:menuray/menuray.git
cd menuray/frontend/merchant
flutter pub get

# pick a target:
flutter run -d chrome      # web (easiest)
flutter run -d ios         # iOS simulator (requires macOS)
flutter run -d android     # Android emulator
flutter run -d linux       # Linux desktop window
```

For headless Linux + tunnel-based access (no browser on the server), use the **static-build** workflow:

```bash
flutter build web --release
cd build/web && python3 -m http.server 8080 --bind 0.0.0.0
```

Full setup, troubleshooting, and IDE notes: [`docs/development.md`](docs/development.md).

### Run the customer view

**Prereq:** Node 22, pnpm, and a local Supabase instance.

```bash
cd menuray/frontend/customer
pnpm install
pnpm dev   # opens http://localhost:5173/<slug>
```

The customer view reads published menus by slug from Supabase. See [`backend/supabase/`](backend/supabase/) to set up and seed a local Postgres + anon read RLS.

---

## How it works

```
┌────────────┐   ┌──────────┐   ┌────────────┐   ┌──────────┐
│  Merchant  │──▶│   OCR    │──▶│  LLM       │──▶│ Database │
│  takes     │   │  (Vision │   │  parser    │   │ (Postgres│
│  a photo   │   │   API)   │   │ (Claude /  │   │  via     │
│            │   │          │   │  GPT)      │   │ Supabase)│
└────────────┘   └──────────┘   └────────────┘   └─────┬────┘
                                                       │
       ┌───────────────────────────────────────────────┘
       ▼
┌────────────┐   ┌──────────┐   ┌────────────┐
│ Generated  │──▶│  Public  │──▶│  Diner     │
│  menu page │   │   URL +  │   │  scans QR  │
│            │   │  QR code │   │  on phone  │
└────────────┘   └──────────┘   └────────────┘
```

See [`docs/architecture.md`](docs/architecture.md) for the full data-flow diagram and component boundaries.

---

## Tech stack

| Layer | Choice | Why |
|---|---|---|
| Merchant app | **Flutter** + Material 3 + Riverpod + go_router | Cross-platform native feel, single codebase |
| Customer view | **SvelteKit 2 + Svelte 5 runes** + Tailwind v4 | Tiny first paint, scan-and-go, SEO-friendly |
| Backend | **Supabase** (Postgres + Auth + Storage + Edge Functions, `pg_cron`) | Open-source BaaS, RLS multi-tenancy, self-hostable |
| OCR + LLM | **OpenAI `gpt-4o-mini`** behind provider-agnostic factory (ADR-010, ADR-020) | Strict JSON Schema responses; mock fallback for CI |
| Billing | **Stripe Checkout + Customer Portal** + WeChat Pay/Alipay rails | No PCI scope; CN payments day-1 |
| i18n | `flutter_localizations` + `.arb` (en + zh) | Standard Flutter approach |

Full reasoning in [`docs/decisions.md`](docs/decisions.md).

---

## Repo layout

```
menuray/
├── docs/                          # All project docs (start here)
│   ├── DESIGN.md                  # Brand colors, typography, design tokens
│   ├── architecture.md            # System overview & data flow
│   ├── decisions.md               # Architecture decision records (ADRs)
│   ├── development.md             # Dev environment setup
│   ├── i18n.md                    # Internationalization strategy
│   ├── roadmap.md                 # Prioritized todo list (P0 → P3) + session map
│   ├── product-decisions.md       # Ratified product decisions (tiers, RBAC, etc.)
│   ├── stitch-prompts.md          # Stitch UI generation prompts
│   ├── logo-prompts.md            # Logo generation prompts
│   └── superpowers/{specs,plans}/ # Per-session design + implementation docs
├── frontend/
│   ├── design/                    # Stitch-generated UI designs (HTML + PNG)
│   ├── merchant/                  # Flutter merchant app
│   └── customer/                  # SvelteKit customer view (scan-to-view web)
├── backend/
│   └── supabase/                  # Migrations, seed, Edge Functions, PgTAP tests
├── .github/                       # Issue & PR templates, CI workflows
├── CLAUDE.md                      # Conventions for AI coding agents
├── CONTRIBUTING.md                # How to contribute
├── CODE_OF_CONDUCT.md
├── SECURITY.md
├── LICENSE                        # MIT
└── README.md                      # ← you are here
```

---

## Documentation map

| Doc | Read this if you want to... |
|---|---|
| [docs/architecture.md](docs/architecture.md) | Understand how the pieces fit together |
| [docs/decisions.md](docs/decisions.md) | Understand *why* we picked Flutter / Supabase / OpenAI / etc. |
| [docs/product-decisions.md](docs/product-decisions.md) | Ratified product decisions (tiers, RBAC roles, retention, ...) |
| [docs/development.md](docs/development.md) | Set up your local environment |
| [docs/i18n.md](docs/i18n.md) | Add a language or work on translations |
| [docs/DESIGN.md](docs/DESIGN.md) | Get pixel-perfect with the brand |
| [docs/roadmap.md](docs/roadmap.md) | See what needs doing + session map |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Submit your first PR |
| [CLAUDE.md](CLAUDE.md) | Use Claude / Cursor / Copilot in this repo |

---

## Contributing

We welcome contributions of all sizes — code, docs, design, translations, bug reports.

- **Found a bug?** Open an issue using the bug template.
- **Want to propose a feature?** Open a discussion first to align before code.
- **Adding a new language?** See [`docs/i18n.md`](docs/i18n.md).
- **Improving the merchant app?** Check open issues + [`docs/roadmap.md`](docs/roadmap.md) for priorities.

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a PR.

By participating you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

---

## Security

Found a vulnerability? Please **do not** file a public issue. See [SECURITY.md](SECURITY.md) for responsible disclosure.

---

## Acknowledgments

- UI designs generated with [Google Stitch](https://stitch.withgoogle.com/)
- Built with [Flutter](https://flutter.dev/) and [Supabase](https://supabase.com/)
- Inspired by every restaurant owner still updating prices with a sharpie

---

## License

[MIT](LICENSE) — do whatever you want, just keep the notice.

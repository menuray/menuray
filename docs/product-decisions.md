# MenuRay — Product Decisions

> **Status**: Ratified 2026-04-20. Authoritative reference for implementation sessions.
> Changes after ratification require a new ADR + doc update (do **not** edit this file in place without a git history note).

## TL;DR — ratified

| # | Area | Decision |
|---|---|---|
| 1 | OCR / LLM providers | OpenAI (ChatGPT) via custom gateway for both |
| 2 | Pricing / subscription | Freemium + Pro $19/mo + Growth $49/mo. Stripe (global, incl. WeChat/Alipay rails) |
| 3 | Auth & multi-tenancy | `store_members` + optional `organizations`; 3 roles (Owner/Manager/Staff); **ADR-018** supersedes ADR-013 |
| 4 | Analytics | Postgres on-the-fly aggregation + `dish_view_logs` (opt-in); 30s polling |
| 5 | Templates | 5 fixed-enum families; **launch MVP with 2 (Minimal + Grid)**, 3 more after designer |

---

## 1. OCR / LLM

- **Provider**: OpenAI for both OCR (`gpt-4o` with vision input) and LLM structuring (`gpt-4o`)
- **Access**: `OPENAI_API_KEY` + `OPENAI_BASE_URL=https://ai-gateway.happy-next.com/v1` (custom gateway, not `api.openai.com` — keep configurable via env)
- **Cost**: ~$0.01–0.05 per menu parse
- **Fallback**: None for MVP (single provider acceptable)
- **Enforcement (O-1)**: Per-tier re-parse quotas enforced at **both** merchant app pre-check (soft / UX) **and** Edge Function hard limit (security)
- **Secrets**: `.env.local` (gitignored) + Supabase Edge Function secrets. Never committed.

## 2. Pricing & subscription

### Tiers (ratified)

| | Free | Pro | Growth |
|---|---|---|---|
| **USD / mo** | $0 | $19 | $49 |
| **RMB / mo** | ¥0 | ¥138 | ¥358 |
| **Annual (USD)** | — | $192 ($16/mo, ~15% off) | $504 ($42/mo, ~15% off) |
| **Menus** | 1 | 5 | Unlimited |
| **Dishes per menu** | 30 | 200 | Unlimited |
| **AI re-parses / menu / mo** | 1 | 5 | 50 (ToS fair-use, P-2) |
| **QR views / mo** (P-1) | 2,000 | 20,000 | Unlimited |
| **Languages on customer view** (P-5) | 2 (en + user-chosen 2nd) | 5 | All |
| **Custom branding on QR page** | No (MenuRay badge) | Yes | Yes |
| **Multi-store** (A-1) | ✗ | ✗ | ✓ |
| **Analytics** | None | Basic | Full + CSV export (S-3) |
| **Support** | Community | Email 48h | Priority 24h |

- Freemium permanent (no trial expiry); self-serve only
- Annual billing = ~15% discount
- **Refund policy (P-6)**: 7 days monthly (pro-rated), 30 days annual
- **China payments (P-3)**: **Day-1** via Stripe's native WeChat Pay + Alipay rails (does not require China entity)
- **China annual billing (P-4)**: monthly only initially (WeChat/Alipay don't natively support recurring; revisit when China revenue warrants a third-party recurring solution)

### Implementation implications
- `subscriptions(store_id, tier, current_period_end)` table in Postgres
- Edge-function quota enforcement pre-check on every AI parse + QR view tick
- `qr_views_monthly` counter column on stores with cron reset
- Stripe Billing for subscriptions + WeChat Pay + Alipay (all via Stripe's global payment methods API)
- Free-tier soft-block page served from SvelteKit customer view when quota hit

## 3. Auth & multi-tenancy (ADR-018, supersedes ADR-013)

### Model
- Drop `stores.owner_id UNIQUE`; keep column for migration then remove
- `store_members(store_id, user_id, role, accepted_at, invited_by)` — single source of truth
- Optional `organizations` table for chain owners; `stores.org_id` nullable
- Growth-tier upgrade auto-creates an Organization row (A-5)
- Three roles: **Owner / Manager / Staff**

### Permission matrix (ratified, including A-4 adjustment)

| Action | Owner | Manager | Staff |
|---|---|---|---|
| View menus & dishes | ✓ | ✓ | ✓ |
| Edit menus / dishes / categories | ✓ | ✓ | ✗ |
| Run OCR parse | ✓ | ✓ | ✓ |
| Publish / unpublish | ✓ | ✓ | ✗ |
| **Mark dish sold-out (A-4)** | ✓ | ✓ | ✓ |
| Invite users | ✓ | ✓ | ✗ |
| Remove a member | ✓ | ✗ | ✗ |
| Edit store settings | ✓ | ✗ | ✗ |
| Change billing tier | ✓ | ✗ | ✗ |
| Transfer store ownership | ✓ | ✗ | ✗ |
| Delete store | ✓ | ✗ | ✗ |

### Invites
- Email (global default, Supabase magic link) or phone (China self-host)
- **A-3 China SMS provider default: 短信宝** (free tier, no ICP requirement for small senders). Pluggable behind same provider-agnostic interface as OCR/LLM (ADR-010). 阿里云 SMS available as opt-in override.
- Token TTL: **7 days** (A-6)
- **Pending invites count against seat limit** (A-2)

### Store-switching
- Single-store merchant: no change (straight to home)
- Multi-store (Growth): Store Picker after login; active store persisted to `SharedPreferences`
- Header affordance (bottom sheet) always visible when user has ≥ 2 stores

### Migration plan
Step 1: additive DDL → Step 2: backfill `store_members` from `stores.owner_id` → Step 3: swap RLS policies in one transaction → Step 4: deploy app → Step 5: drop `stores.owner_id` next sprint.

## 4. Analytics / Statistics

### Approach
- Postgres on-the-fly aggregation (indexes only) up to 5M rows
- Separate `dish_view_logs` table, **opt-in per store** via `stores.dish_tracking_enabled boolean DEFAULT false` (S-1)
- **30-second polling**, not Supabase Realtime (S-5 — over-eager for aggregated metric)
- Nightly `mv_view_logs_daily` materialized view past 5M rows; partition past 50M

### Privacy boundaries
- Never log: IP, user-agent, fingerprint
- Do log: session_id (random UUID per sessionStorage), locale, referrer_domain (domain only)
- **QR variant tracking (S-4)**: separate `qr_variant` column on `view_logs` (e.g., `table-5`, `door`, `instagram`), not crammed into referrer_domain
- **Retention (S-2)**: 12 months fixed; `pg_cron` DELETE job; not merchant-configurable initially (revisit if merchants ask)
- **CSV export (S-3)**: available on **Pro and Growth** tiers

### Key schema
```sql
CREATE TABLE dish_view_logs (
  menu_id FK, store_id FK, dish_id FK,
  session_id text, viewed_at timestamptz DEFAULT now()
);

ALTER TABLE stores ADD COLUMN dish_tracking_enabled boolean DEFAULT false;
ALTER TABLE view_logs ADD COLUMN qr_variant text;
```

Edge Function `log-dish-view` called from SvelteKit customer view via IntersectionObserver (2-sec debounce). Returns 204 when `dish_tracking_enabled=false`.

## 5. Templates

### Approach
- Fixed-enum template set (not data-driven JSON)
- One SvelteKit component per template
- **Launch MVP: 2 templates (Minimal + Grid)** — no designer needed
- 3 more (Bistro / Izakaya / Street) added after hiring designer 2-3 days, in a later release

### Launch templates

| Name | Character | Target |
|---|---|---|
| **Minimal** | Clean, single-column, whitespace-first | Cafe, ramen, fast-casual |
| **Grid** | 2/3-col photo-led cards | Bubble tea, pizza, photo-rich |

### Customization v1 (ratified)
- Template selection from the 2 launch templates
- Primary color from a curated 12-color swatch (T-3 — enough for launch)
- Logo upload (square or horizontal)
- Cover image (template-dependent; Minimal = no cover, Grid = optional)

### Locked at v1
- Font family (per-template, fixed)
- Section order (follows menu's category order)
- Dish-card layout within template
- Background / card radius / spacing

### Schema
```sql
CREATE TABLE templates (
  id text PK,                          -- 'minimal' | 'grid' | ...
  display_name text, thumbnail_url text,
  supports_dish_photos boolean,
  default_primary_color text
);

ALTER TABLE menus
  ADD COLUMN template_id text NOT NULL DEFAULT 'minimal' FK templates,
  ADD COLUMN theme_overrides jsonb DEFAULT '{}';
```

### Preview UX (T-2)
Live webview via `?preview=true&template=X&primary=%23...` on the customer view SSR endpoint. Requires customer view deployed first → Session 1 scope.

### Other decisions
- **CDN cache (T-4)**: deferred; no-cache SSR at launch, add cache + purge in a later session when traffic warrants
- **Template switching after publish (T-5)**: **not locked** — merchants retain freedom; if a diner UX issue surfaces we lock later

---

## Roadmap — implementation sessions

Total estimated: **4-6 sessions** to ship everything in this doc.

| # | Session | Scope | Gated by |
|---|---|---|---|
| 1 | Customer view + merchant polish | SvelteKit project setup; B1/B2/B3/B4 screens; 2 templates (Minimal + Grid); merchant logout verify + register wire; form validation (phone/price/required); 17-screen loading/error/empty audit; merchant-customer link (slug URL from `published` screen) | — |
| 2 | OCR / LLM real providers | OpenAI adapter in `_shared/providers/`; edge-fn pre-check for tier quotas; swap `MENURAY_*_PROVIDER=openai` | — |
| 3 | Auth migration (ADR-018) | Additive DDL; `store_members` backfill; RLS rewrite; `handle_new_user` trigger update; Flutter store-picker + team-management screens; invite flow (email magic link first, SMS P1) | — |
| 4 | Billing (Stripe) | Subscriptions table + webhook handling; tier enforcement edge-fns; WeChat/Alipay via Stripe; refund policy wire; RMB pricing | — |
| 5 | Statistics real data | Index additions; `dish_view_logs` table; customer view IntersectionObserver emitter; Flutter stats screen with filters (today/7d/30d/custom); CSV export for Pro+ | Session 1 customer view live |
| 6 | Remaining templates + P2 polish | Bistro / Izakaya / Street (after designer); real-device iOS+Android passes; App Store / Play Store submission prep | T-1 designer decision |

Deferred beyond P0: statistics AI insights, translate-all / description rewrite (needs LLM adapter), auto-generate dish images, sub-accounts SMS plugin for China self-host.

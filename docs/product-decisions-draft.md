# MenuRay — Product Decisions (Draft)

> **Status**: Pending founder ratification. Proposed by subagent research 2026-04-20.
> Once ratified: rename to `product-decisions.md`, supersede ADR-013 with new ADR-018, and use as the authoritative reference for implementation sessions. Changes after ratification require a new ADR + doc update.

## TL;DR

| # | Area | Recommendation | Status |
|---|---|---|---|
| 1 | OCR / LLM providers | OpenAI (ChatGPT) for both, via custom gateway | **DECIDED** |
| 2 | Pricing / subscription | Freemium + Pro $19/mo + Growth $49/mo; Stripe (global + Alipay/WeChat via Stripe) | Proposed |
| 3 | Auth & multi-tenancy | Drop `stores.owner_id UNIQUE`; add `store_members` + optional `organizations`; 3 roles (Owner / Manager / Staff). Supersedes ADR-013. | Proposed |
| 4 | Analytics | Postgres on-the-fly aggregation + separate `dish_view_logs` table (opt-in). 30-sec polling, not Realtime. | Proposed |
| 5 | Templates | 5 fixed-enum families; launch MVP with 2 (Minimal + Grid, no designer needed) | Proposed |

**Total open questions for founder**: 22 across areas. See consolidated checklist at bottom — priority-ordered, with 5 blocking items.

---

## 1. OCR / LLM — DECIDED

- **Provider**: OpenAI (ChatGPT) for both OCR and LLM structuring
- **Access**: `OPENAI_API_KEY` + `OPENAI_BASE_URL=https://ai-gateway.happy-next.com/v1` (custom gateway — not `api.openai.com`)
- **Models**: `gpt-4o` with vision input for OCR, `gpt-4o` for structuring
- **Cost**: ~$0.01–$0.05 per menu parse
- **Fallback**: None for MVP; single provider acceptable

### Implementation notes (for future session)
- Credentials live in `.env.local` (gitignored) + Supabase Edge Function secrets. **Never in repo**.
- Add OpenAI adapter in `backend/supabase/functions/_shared/providers/`
- `MENURAY_OCR_PROVIDER=openai` + `MENURAY_LLM_PROVIDER=openai`
- Gateway base URL must be env-configurable (not hard-coded to api.openai.com)

### Open question
- **O-1**: Per-tier re-parse quota enforcement — in merchant app pre-check, edge function hard limit, or both?

---

## 2. Pricing & subscription — PROPOSED

### Tier structure

| | Free | Pro | Growth |
|---|---|---|---|
| **USD / mo** | $0 | $19 | $49 |
| **RMB / mo** | ¥0 | ¥138 | ¥358 |
| **Annual (USD)** | — | $192 ($16/mo) | $504 ($42/mo) |
| **Menus** | 1 | 5 | Unlimited |
| **Dishes per menu** | 30 | 200 | Unlimited |
| **AI re-parses / menu / mo** | 1 | 5 | Unlimited (soft cap 50 in ToS) |
| **QR views / mo** | 2,000 | 20,000 | Unlimited |
| **Languages on customer view** | 2 | 5 | All |
| **Custom branding on QR page** | No (MenuRay badge) | Yes | Yes |
| **Analytics** | None | Basic | Full |
| **Support** | Community | Email 48h | Priority 24h |

- Annual billing = 15% discount (~2 free months)
- Freemium permanent, no trial expiry
- Self-serve only, no sales motion

### Rationale
- **$19 is market-clearing**: TableQR $18.75, MenuTiger $17 — validated band for QR-menu SaaS
- **Freemium > trial**: SMBs churn easily; permanent free tier with hard limits drives word-of-mouth
- **Two paid tiers, not three**: less cognitive load; Pro is main conversion, Growth serves small chains
- **RMB pricing explicit** (¥138 / ¥358 are clean numbers that don't anchor-bait)
- **AI cost exposure**: Pro $0.25/mo, Growth ~$1/mo → gross margin 97-98%

### Open questions
- **P-1**: Free QR view cap — 2,000/mo (67/day) or 5,000/mo? (Tight vs generous)
- **P-2**: Growth re-parse cap — true unlimited or 50/mo fair-use?
- **P-3**: China payments at launch — launch Day-1 via Stripe's WeChat/Alipay support, or defer until China entity?
- **P-4**: Annual billing in China — third-party recurring (WeChat/Alipay don't natively support) or monthly-only?
- **P-5**: Free-tier 2nd language — user-chosen or locked to registration locale?
- **P-6**: Refund window — 7d monthly / 30d annual, or longer?

### Implementation implications
- Stripe Billing handles subscriptions + pro-ration + WeChat/Alipay
- Entitlement enforcement via `subscriptions(store_id, tier)` table + edge-function pre-checks
- QR view metering: `qr_views_monthly` counter in Postgres, cron-reset
- Customer view gets a soft-block page for Free tier at 2,000 views

---

## 3. Auth & multi-tenancy — PROPOSED

**Supersedes ADR-013.** New ADR-018 to be written after ratification.

### Model

- Drop `stores.owner_id UNIQUE` constraint
- Add `store_members(store_id, user_id, role, accepted_at, invited_by)` join table
- Add `organizations(id, name, created_by)` table, **nullable** `stores.org_id` (solo stores have NULL)
- Three roles: Owner / Manager / Staff
- Migration is **additive + zero-downtime**

### Permission matrix

| Action | Owner | Manager | Staff |
|---|---|---|---|
| View menus & dishes | ✓ | ✓ | ✓ |
| Edit menus / dishes / categories | ✓ | ✓ | ✗ |
| Run OCR parse | ✓ | ✓ | ✓ |
| Publish / unpublish | ✓ | ✓ | ✗ |
| Mark dish sold_out | ✓ | ✓ | (✗ — but see A-4) |
| Invite users | ✓ | ✓ | ✗ |
| Remove a member | ✓ | ✗ | ✗ |
| Edit store settings | ✓ | ✗ | ✗ |
| Change billing tier | ✓ | ✗ | ✗ |
| Transfer store ownership | ✓ | ✗ | ✗ |
| Delete store | ✓ | ✗ | ✗ |

### Key schema additions

```sql
CREATE TABLE organizations (id uuid PK, name text, created_by uuid FK auth.users);

CREATE TABLE store_members (
  store_id uuid FK stores, user_id uuid FK auth.users,
  role text CHECK (role IN ('owner','manager','staff')),
  accepted_at timestamptz, invited_by uuid FK auth.users,
  UNIQUE(store_id, user_id)
);
CREATE UNIQUE INDEX store_members_one_owner ON store_members(store_id) WHERE role='owner';

ALTER TABLE stores ADD COLUMN org_id uuid FK organizations;

CREATE TABLE store_invites (
  store_id FK stores, email text, phone text, role text,
  token text UNIQUE, expires_at timestamptz, accepted_at timestamptz
);
```

### RLS pattern (example — `menus`)

```sql
-- Read: any accepted member
CREATE POLICY menus_member_read ON menus FOR SELECT TO authenticated
  USING (store_id IN (
    SELECT store_id FROM store_members
    WHERE user_id = auth.uid() AND accepted_at IS NOT NULL
  ));

-- Write: owner or manager only
CREATE POLICY menus_manager_write ON menus FOR ALL TO authenticated
  USING (store_id IN (
    SELECT store_id FROM store_members
    WHERE user_id = auth.uid() AND role IN ('owner','manager') AND accepted_at IS NOT NULL
  ));
```

Trigger enforces "at least one owner per store" to prevent orphaned stores.

### Invite UX
- Owner/Manager → Store Settings → Team → Invite (role + email or phone)
- Magic link email (global) or SMS OTP (China self-host plugin)
- `/invite/{token}` redeems → inserts `store_members` row with `accepted_at`
- Token TTL 7 days

### Store-switching UX
- On login: if multiple stores, show picker screen; else go direct to home
- Active store ID persisted in `SharedPreferences` + in-memory `StateProvider`
- Header affordance when ≥ 2 stores (bottom sheet to switch)

### Open questions
- **A-1** 🚩: Is multi-store gated to a paid tier, or allowed on all plans?
- **A-2**: Pending invites count against seat limit?
- **A-3** 🚩: China self-host SMS provider default — 短信宝 or 阿里云 SMS?
- **A-4**: Staff mark dishes sold-out? (Common floor-staff need; current matrix says no)
- **A-5**: `org_id` on stores — nullable (solo merchants) or always required after chain plan?
- **A-6**: Invite token TTL — 7 days OK or shorter?

### Migration plan
Step 1 (additive DDL) → Step 2 (backfill `store_members` from `stores.owner_id`) → Step 3 (swap RLS policies inside a transaction) → Step 4 (deploy app) → Step 5 (drop `stores.owner_id` next sprint).

### Cost estimate: **M** (~2.5 weeks for one engineer)

---

## 4. Analytics / Statistics — PROPOSED

### Approach

- **On-the-fly Postgres aggregation**, not materialized views (until > 5M rows)
- **Separate `dish_view_logs` table** for dish-level, **opt-in per store**
- **30-second polling**, not Supabase Realtime (over-eager for aggregated metric)
- Add indexes: `(store_id, viewed_at DESC)`, `(menu_id, viewed_at DESC)`, `(store_id, referrer_domain, viewed_at DESC)`, `(store_id, locale, viewed_at DESC)`

### Key schema

```sql
CREATE TABLE dish_view_logs (
  menu_id FK menus, store_id FK stores, dish_id FK dishes,
  session_id text, viewed_at timestamptz
  -- NO ip_address, NO user_agent, NO diner_id (yet)
);

ALTER TABLE stores ADD COLUMN dish_tracking_enabled boolean DEFAULT false;
```

Edge Function `log-dish-view` called from customer view (SvelteKit) via IntersectionObserver + 2-sec debounce. Returns 204 immediately when store has `dish_tracking_enabled=false`.

### Privacy boundaries

| Field | Logged? | Note |
|---|---|---|
| ip_address | ✗ | Never stored |
| user_agent | ✗ | Not useful for MenuRay metrics |
| session_id | ✓ | Random UUID per browser session (sessionStorage), no identity link |
| locale | ✓ | Browser/OS locale |
| referrer_domain | ✓ | Domain only (e.g. `instagram.com`), not full URL |

### Scale path
- Indexes only up to **5M rows** (~137 store-days @ 100K/day)
- Nightly `mv_view_logs_daily` materialized view beyond 5M
- Range-partitioning by month beyond 50M
- Only evaluate TimescaleDB/ClickHouse beyond 500M

### Open questions
- **S-1** 🚩: Dish-level tracking opt-**in** (proposed) or opt-**out** (more data, more useful default)?
- **S-2**: 12-month retention — merchant-configurable?
- **S-3**: Raw CSV export for merchants?
- **S-4**: Track QR-code variant (table-specific vs door) as a separate column?
- **S-5**: 30-sec polling OK, or want <5-sec near-realtime?

### Cost estimate: **M** (~3-4 dev-days)

---

## 5. Templates — PROPOSED

### Approach

- **Fixed-enum template set** (not data-driven JSON)
- One SvelteKit component per template (all bundled, ~15-25 KB gz each)
- Customization surface: primary color + logo + optional cover image (per-template)
- **Launch MVP with 2 templates (Minimal + Grid)** — dev-implementable without designer
- Add 3 more (Bistro, Izakaya, Street) after hiring a designer 2-3 days

### Template families

| Name | Character | Target |
|---|---|---|
| **Minimal** | Clean, single-column, whitespace-first | Cafe, ramen shop, fast-casual |
| **Grid** | 2/3-col photo-led cards | Bubble tea, pizza, photo-rich |
| **Bistro** (v1.1) | Warm cream, serif headings, brasserie feel | European bistro, wine bar |
| **Izakaya** (v1.1) | Dark, amber accents, scrolling tabs | Japanese izakaya, Korean BBQ |
| **Street** (v1.1) | Bold, high-contrast, chalkboard-style | Street food, taco stand |

### Schema

```sql
CREATE TABLE templates (
  id text PK,           -- 'minimal' | 'grid' | ...
  display_name text,
  thumbnail_url text,
  supports_dish_photos boolean,
  default_primary_color text
);

ALTER TABLE menus ADD COLUMN template_id text NOT NULL DEFAULT 'minimal' FK templates;
ALTER TABLE menus ADD COLUMN theme_overrides jsonb DEFAULT '{}';
-- { "primaryColor": "#C2553F", "logoUrl": "..." }
```

### Customization v1
- Template selection from 5 options (or 2 at MVP)
- Primary color swap (12-color curated swatch; free hex in v2)
- Logo upload (square or horizontal)
- Cover image (Bistro + Izakaya templates only)

### Locked at v1 (deliberately)
- Font family
- Section order (follows menu's category order)
- Dish-card layout within template
- Background / card radius / spacing

### Preview UX
Merchant app → "Appearance" tab → bottom sheet with 5 cards → tap to preview → opens live customer-view URL with `?preview=true&template=X&primary=%23...`

### Open questions
- **T-1** 🚩: Launch with 2 templates (no designer, ship in ~1 week) or 5 (hire designer 2-3 days, ship in ~3 weeks)?
- **T-2**: Preview via live webview (requires customer view deployed first) or static screenshots?
- **T-3**: Primary-color-only customization enough, or need brand-color-system support at launch?
- **T-4**: Customer view CDN cache now or later?
- **T-5**: Lock template change after menu is published (avoid jarring diner UX)?

### Cost estimate: **M** (2 templates, ~6-7 dev-days) or **L** (all 5, ~14 dev-days + 2-3 designer-days)

---

## Consolidated ratification checklist

**22 open questions total.** Answer priority-flagged (🚩) ones first — they block the most work. The rest can default to the recommendations above unless you explicitly flip them.

### 🚩 Blocking (must answer before any impl session)

1. **A-1** Multi-store gated to paid tier?
2. **P-3** China payments strategy at launch?
3. **T-1** Launch templates: 2 or 5?
4. **S-1** Dish-level tracking opt-in or opt-out?
5. **A-3** China self-host SMS provider default?

### Remaining 17 questions (O-1, P-1/2/4/5/6, A-2/4/5/6, S-2/3/4/5, T-2/3/4/5) can default to the recommendations if you don't flip them.

---

## Next steps after ratification

1. You answer the 5 🚩 + any of the other 17 you want to flip
2. Rename `product-decisions-draft.md` → `product-decisions.md`
3. Write ADR-018 (auth model, supersedes ADR-013)
4. Implementation sessions (estimated 4-6 to ship everything):

| # | Session scope | Gated by |
|---|---|---|
| 1 | Customer view (SvelteKit) + launch templates + merchant polish (logout/register wire, form validation, 17-screen loading/error pass) | T-1 answer |
| 2 | OCR/LLM real providers (OpenAI adapter) | — |
| 3 | Auth model migration (store_members, RBAC, store-picker UX) | A-1, A-3 answers |
| 4 | Billing (Stripe, tier enforcement, Alipay/WeChat) | P-3 answer |
| 5 | Statistics (real data pipeline, dashboard) | S-1 answer + customer view live |
| 6 | Remaining templates (if T-1 = 5) + P1/P2 polish | — |

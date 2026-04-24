# Stripe Billing — Design

Date: 2026-04-24
Scope: First-time monetisation. Adds the `subscriptions` table, denormalises `tier` onto `stores`, ships four new Edge Functions (`create-checkout-session`, `create-portal-session`, `handle-stripe-webhook`, `create-store`), enforces quotas across the existing `parse-menu` pipeline + customer-view SSR + Flutter merchant app, and adds a Flutter Upgrade screen. Stripe Customer Portal handles already-subscribed-user actions (cancel / change card / renew). Tiers + caps are pre-ratified in `docs/product-decisions.md` §2 — this spec implements them.
Audience: whoever picks up the implementation plan after spec approval. Tier numbers are NOT up for re-negotiation here.

## 1. Goal & Scope

Lifecycle once shipped:

```
Free signup           → handle_new_user() inserts subscriptions(tier='free') + stores.tier='free'
                        merchant uses app freely; QR views capped at 2 000/mo
                        AI re-parses capped at 1/menu/mo
                        MenuRay badge always rendered on customer view

Click "Upgrade to Pro" → POST /create-checkout-session
                        → returns Stripe Checkout URL (USD/CNY × monthly/annual)
                        → user pays on Stripe-hosted page (cards + WeChat Pay + Alipay)
                        → Stripe webhook fires → handle-stripe-webhook flips tier
                        → stores.tier updates → caps lift, badge hides

Click "Upgrade to Growth" → same flow + handle-stripe-webhook auto-creates an
                        organizations row and links every owner-store of the user
                        to it via stores.org_id

Click "+ New store"   → POST /create-store (gated: tier === 'growth')
                        → on success, store inherits org_id; new store inherits 'growth' tier

Click "Manage billing" → POST /create-portal-session → Stripe Portal redirect
                        Customer Portal handles: change card, change plan,
                        cancel, view invoices, request refund (manual approval).

Quota hits during normal use:
  - QR views over 2 000/mo → SvelteKit returns 402 + paywall page
  - AI re-parses over cap  → parse-menu Edge Function returns 402 with code
  - Menu count over cap    → create_menu RPC raises
  - Dish count over cap    → insert_menu_draft RPC raises
  - Languages over cap     → dish_translations INSERT blocked by RPC

Webhook fires (subscription cancelled / payment failed):
  → tier flips to 'free' on next period boundary; data not deleted; existing
    over-cap content remains accessible but no new creations allowed.
```

**In scope**

- **Schema migration `20260424000002_billing.sql`** adds:
  - `subscriptions(owner_user_id PK, tier, stripe_customer_id, stripe_subscription_id, current_period_end, billing_currency, period, created_at, updated_at)`.
  - `stripe_events_seen(event_id PK, processed_at)` for webhook idempotency.
  - `stores.tier text NOT NULL DEFAULT 'free' CHECK (tier IN ('free','pro','growth'))`.
  - `stores.qr_views_monthly_count int NOT NULL DEFAULT 0` + INSERT trigger on `view_logs` that increments it.
  - `pg_cron` job resetting `stores.qr_views_monthly_count = 0` at 00:01 UTC on the first of every month.
  - SQL function `public.store_tier(p_store_id uuid)` STABLE returning the store's tier (denormalized read).
  - Hard-gate RPCs:
    - `assert_menu_count_under_cap(p_store_id)` — checks tier and menus count, raises if exceeded.
    - `assert_dish_count_under_cap(p_menu_id, p_dish_count_to_add int)` — same for dishes per menu.
    - `assert_translation_count_under_cap(p_dish_id, p_locale)` — same for languages per dish.
  - Backfill: every existing store row gets `tier='free'`; every existing user gets a `subscriptions` row with `tier='free'`. Idempotent INSERT … ON CONFLICT DO NOTHING.
  - RLS for `subscriptions`: owner-of-the-row SELECT only; service_role bypasses for writes from webhook.
- **Four new Edge Functions** under `backend/supabase/functions/`:
  - `create-checkout-session` (POST { tier, currency, period } → returns `{ url }`).
  - `create-portal-session` (POST → returns `{ url }`).
  - `handle-stripe-webhook` (POST raw body, HMAC verify, idempotent updates).
  - `create-store` (POST { name } → checks tier='growth', creates store + member row, auto-links org_id).
- **`parse-menu` Edge Function patch** — pre-check before invoking the orchestrator:
  - Look up `parse_runs.menu_id` (if re-parse on existing menu); count this calendar month's `parse_runs` for that menu; reject with 402 + `{ error: 'reparse_quota_exceeded' }` if over the tier cap.
- **SvelteKit customer-view patch** — `[slug]/+page.server.ts`:
  - Load step now joins `stores.tier` + `stores.qr_views_monthly_count`.
  - If `tier='free'` and `qr_views_monthly_count >= 2000`, throw `error(402)` rendered by `+error.svelte` as a friendly "this menu is over its monthly quota — please come back next month" page (i18n'd).
  - Otherwise log view as today; the count auto-increments via the DB trigger.
  - The `MenurayBadge` component reads `tier` from page data; rendered only when `tier === 'free'`.
- **Flutter merchant patches:**
  - New `currentTierProvider: FutureProvider<Tier>` keyed off `activeStoreProvider` reading `stores.tier`.
  - New `/upgrade` screen showing the tier comparison table + "Subscribe to Pro / Growth" buttons.
  - New `/manage-billing` flow that calls `create-portal-session` + opens the URL.
  - Settings screen gets a "升级订阅 / 管理订阅" entry.
  - Existing screens add tier gates:
    - Home: "+ New menu" button calls a pre-check via SQL function `public.menu_count_under_cap()` (a STABLE wrapper around the RPC body); if cap reached, button taps go to `/upgrade` with a "you've reached your menu limit" snackbar.
    - Edit dish: language/translation count gate.
    - Customise theme: primary-colour picker behind RoleGate-style `TierGate(allowed: {'pro','growth'}, child: …)`.
  - One new shared widget `TierGate` (mirrors `RoleGate` from Session 3).
- **Stripe Price IDs** loaded from env vars: `STRIPE_PRICE_PRO_USD_MONTHLY`, `STRIPE_PRICE_PRO_USD_ANNUAL`, `STRIPE_PRICE_PRO_CNY_MONTHLY`, `STRIPE_PRICE_GROWTH_USD_MONTHLY`, `STRIPE_PRICE_GROWTH_USD_ANNUAL`, `STRIPE_PRICE_GROWTH_CNY_MONTHLY` (6 total — CNY annual deferred per P-4).
- **i18n** — ~28 keys in en + zh under `billing*` / `plan*` / `paywall*` prefixes.
- **Testing:**
  - PgTAP regression script `backend/supabase/tests/billing_quotas.sql` covering:
    - `store_tier()` returns correct value for free/pro/growth.
    - `view_logs` INSERT increments `stores.qr_views_monthly_count`.
    - QR-view-counter cron resets to 0 (manual call to the cron function).
    - `assert_menu_count_under_cap` raises at the right thresholds.
    - `assert_dish_count_under_cap` and `assert_translation_count_under_cap` likewise.
    - `stripe_events_seen` rejects duplicate `event_id`.
  - Deno tests for each new Edge Function (mocked Stripe API + mocked supabase fetch). Webhook tests cover: `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`, signature failure, replay (event_id seen), unknown event type → 200 ack but no-op.
  - Flutter smoke tests:
    - `upgrade_screen_smoke_test.dart` renders 3 tiers + tap "Subscribe Pro" calls `create-checkout-session` (mocked).
    - Existing `home_screen_smoke_test.dart` extended: assert "+ New menu" tap → `/upgrade` redirect when tier='free' AND menus.length === 1.
  - Manual smoke (documented in plan): one full Stripe test-mode purchase, end-to-end (US card 4242, CN card via WeChat Pay), verifying webhook → tier flip → cap lifted.

**Out of scope (deferred)**

- **Flutter "+ New store" UI button.** Multi-store creation Edge Function ships, gate works, but the merchant UI button to invoke it is not designed in this session. Growth-tier users who want a second store call the API manually until the next polish session lands the button + revised store-picker. Documented limitation, surfaced via roadmap.
- **CSV export (Pro+)** — Session 5 (Statistics) handles.
- **`dish_view_logs` opt-in tracking** — Session 5.
- **AI insights / translate-all / image generation** — beyond the current roadmap.
- **Tier-downgrade grace cron** — current behaviour: webhook flips tier instantly on `customer.subscription.deleted`; existing over-cap data stays accessible (no deletion); no new creations allowed. We do NOT implement a 7-day grace before flipping.
- **Refund automation cron** — Customer Portal handles cancellations; refund decisions stay manual via Stripe Dashboard. P-6's 7d/30d windows are policy on our website, not enforced code.
- **CNY annual billing** — P-4 explicitly defers; only the `STRIPE_PRICE_*_CNY_MONTHLY` IDs are wired.
- **Custom Stripe Connect** for marketplace splitting — not on roadmap.
- **Stripe TaxJar / VAT calculations** — Stripe Tax handles automatically when enabled in Dashboard; no app-side code needed.
- **Multiple Stripe customers per user** — one `subscriptions` row per `auth.user.id`. Users with many stores share one subscription.
- **In-app push of "your subscription is about to expire"** — email is Stripe's job; in-app banner deferred.

## 2. Context

- Tier table + tier-related decisions ratified in `docs/product-decisions.md` §2 (P-1 through P-6, A-1 through A-6 from Session 3 ADR-018). Re-quoting the row that drives nearly every cap is unnecessary here — the spec assumes the table is authoritative. If a number changes, this spec changes too.
- ADR-018 (Session 3) established `store_members` + `organizations` as the auth boundary. The billing implementation does NOT touch the auth boundary; it adds a parallel "billing entity = `auth.users.id`" key. The bridge: `subscriptions.owner_user_id` is the user who pays; the `tier` they pay for fans out to all `stores` rows where they are a member with `role='owner'` (set by the webhook handler via UPDATE).
- ADR-010 (provider-agnostic OCR/LLM) hints at provider abstraction. We don't apply that to Stripe — Stripe is the only payments provider we'll ship, China rails included via Stripe's `payment_method_types`.
- ADR-019 (`menu.theme_overrides`) gates "Pro custom theme" via `tier ≠ 'free'`. The customer SSR loader already reads `theme_overrides`; we just add the read of `tier`.
- Existing Edge Functions live at `backend/supabase/functions/<name>/index.ts`. Pattern: handler that's `Deno.serve(handleRequest)`, helper `_shared/db.ts` for client constructors. New billing functions follow the same pattern.
- Customer SvelteKit's SSR loader is `frontend/customer/src/routes/[slug]/+page.server.ts`. It already calls `logView(supabase, menuId, storeId, locale, headers, url)` from `lib/data/logView.ts` (fire-and-forget). The quota soft-block lives in the SSR loader (BEFORE the menu render returns), not inside `logView`.
- Flutter merchant paths under `frontend/merchant/lib/features/`. Riverpod providers in `*_providers.dart`. The Session 3 `RoleGate` widget at `lib/shared/widgets/role_gate.dart` is the model for the new `TierGate`.
- `pg_cron` is enabled in Supabase by default (extension `pg_cron`). Migration just calls `cron.schedule('reset-monthly-qr-views', '1 0 1 * *', 'UPDATE stores SET qr_views_monthly_count = 0;')`.
- `npm:` imports in Deno work since Deno 1.28 — verified by Session 3's `accept-invite` Edge Function. We'll use `import Stripe from 'npm:stripe@latest';` directly.

## 3. Decisions

### 3.1 Schema — `subscriptions` + denormalised `tier`

```sql
CREATE TABLE subscriptions (
  owner_user_id          uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  tier                   text NOT NULL DEFAULT 'free'
                              CHECK (tier IN ('free','pro','growth')),
  stripe_customer_id     text UNIQUE,                  -- NULL for free
  stripe_subscription_id text UNIQUE,                  -- NULL for free
  current_period_end     timestamptz,                  -- NULL for free
  billing_currency       text CHECK (billing_currency IN ('USD','CNY')),
  period                 text CHECK (period IN ('monthly','annual')),
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER subscriptions_touch_updated_at BEFORE UPDATE ON subscriptions
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
```

Extension to `stores`:
```sql
ALTER TABLE stores
  ADD COLUMN tier text NOT NULL DEFAULT 'free'
       CHECK (tier IN ('free','pro','growth')),
  ADD COLUMN qr_views_monthly_count int NOT NULL DEFAULT 0;
```

`store_tier(p_store_id uuid)` STABLE function — used by both customer SSR (anon, via PostgREST RPC) and merchant paths:

```sql
CREATE FUNCTION public.store_tier(p_store_id uuid) RETURNS text
  LANGUAGE sql STABLE AS $$
  SELECT tier FROM stores WHERE id = p_store_id
$$;
```

**Why denormalise:** anon customer view already has SELECT on `stores` via the `stores_anon_read_of_published` policy. Re-using that same row for `tier + qr_views_monthly_count` avoids a second RPC + simplifies the loader. Webhook keeps it consistent (single point of truth for write: handle-stripe-webhook updates BOTH `subscriptions.tier` and every `stores.tier` for stores the user owns).

`subscriptions` RLS:
```sql
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY subscriptions_self_select ON subscriptions FOR SELECT TO authenticated
  USING (owner_user_id = auth.uid());
-- No INSERT/UPDATE/DELETE policies for authenticated. Only service_role
-- writes (via the webhook).
```

`stripe_events_seen` for idempotency:
```sql
CREATE TABLE stripe_events_seen (
  event_id     text PRIMARY KEY,
  event_type   text NOT NULL,
  processed_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE stripe_events_seen ENABLE ROW LEVEL SECURITY;
-- No policies → only service_role can read/write. anon/authenticated cannot see this table at all.
```

### 3.2 Counter trigger + monthly reset cron

```sql
CREATE FUNCTION view_logs_increment_count() RETURNS trigger
  LANGUAGE plpgsql AS $$
BEGIN
  UPDATE stores SET qr_views_monthly_count = qr_views_monthly_count + 1
   WHERE id = NEW.store_id;
  RETURN NEW;
END $$;

CREATE TRIGGER view_logs_increment_count_trg
  AFTER INSERT ON view_logs
  FOR EACH ROW EXECUTE FUNCTION view_logs_increment_count();
```

Cron reset (uses `pg_cron`):
```sql
CREATE EXTENSION IF NOT EXISTS pg_cron;
SELECT cron.schedule(
  'reset-monthly-qr-views',
  '1 0 1 * *',                                          -- 00:01 UTC, 1st of month
  $$ UPDATE public.stores SET qr_views_monthly_count = 0; $$
);
```

### 3.3 Hard-gate RPCs

`assert_menu_count_under_cap(p_store_id uuid)`:
```sql
CREATE FUNCTION public.assert_menu_count_under_cap(p_store_id uuid) RETURNS void
  LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_tier text; v_count int; v_cap int;
BEGIN
  SELECT tier INTO v_tier FROM stores WHERE id = p_store_id;
  v_cap := CASE v_tier
    WHEN 'free'   THEN 1
    WHEN 'pro'    THEN 5
    WHEN 'growth' THEN 2147483647   -- effectively unlimited
  END;
  SELECT count(*) INTO v_count FROM menus
   WHERE store_id = p_store_id AND status <> 'archived';
  IF v_count >= v_cap THEN
    RAISE EXCEPTION 'menu_count_cap_exceeded'
      USING ERRCODE = 'check_violation';
  END IF;
END $$;
GRANT EXECUTE ON FUNCTION public.assert_menu_count_under_cap TO authenticated;
```

`assert_dish_count_under_cap(p_menu_id uuid, p_to_add int)`:
```sql
CREATE FUNCTION public.assert_dish_count_under_cap(p_menu_id uuid, p_to_add int) RETURNS void
  LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_tier text; v_existing int; v_cap int;
BEGIN
  SELECT s.tier INTO v_tier
    FROM stores s JOIN menus m ON m.store_id = s.id
   WHERE m.id = p_menu_id;
  v_cap := CASE v_tier
    WHEN 'free'   THEN 30
    WHEN 'pro'    THEN 200
    WHEN 'growth' THEN 2147483647
  END;
  SELECT count(*) INTO v_existing FROM dishes WHERE menu_id = p_menu_id;
  IF v_existing + p_to_add > v_cap THEN
    RAISE EXCEPTION 'dish_count_cap_exceeded'
      USING ERRCODE = 'check_violation';
  END IF;
END $$;
GRANT EXECUTE ON FUNCTION public.assert_dish_count_under_cap TO authenticated;
```

`assert_translation_count_under_cap(p_dish_id uuid, p_locale text)`:
```sql
CREATE FUNCTION public.assert_translation_count_under_cap(p_dish_id uuid, p_locale text) RETURNS void
  LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_tier text; v_existing int; v_cap int; v_already_present boolean;
BEGIN
  SELECT s.tier INTO v_tier
    FROM stores s JOIN dishes d ON d.store_id = s.id
   WHERE d.id = p_dish_id;
  v_cap := CASE v_tier
    WHEN 'free'   THEN 1   -- 1 translation locale beyond source_locale → 2 total
    WHEN 'pro'    THEN 4   -- 4 beyond source_locale → 5 total
    WHEN 'growth' THEN 2147483647
  END;
  SELECT EXISTS (SELECT 1 FROM dish_translations
                  WHERE dish_id = p_dish_id AND locale = p_locale)
    INTO v_already_present;
  IF v_already_present THEN RETURN; END IF;       -- updating existing locale OK
  SELECT count(*) INTO v_existing FROM dish_translations WHERE dish_id = p_dish_id;
  IF v_existing >= v_cap THEN
    RAISE EXCEPTION 'translation_count_cap_exceeded'
      USING ERRCODE = 'check_violation';
  END IF;
END $$;
GRANT EXECUTE ON FUNCTION public.assert_translation_count_under_cap TO authenticated;
```

These RPCs are called from Edge Functions and merchant Flutter paths just before INSERT operations. Application code wraps the RPC + INSERT in a single transaction at the supabase-js level so the cap check sees current state.

### 3.4 `handle_new_user()` extension

Update existing trigger from Session 3 to also seed a `subscriptions` row:

```sql
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_store_id uuid;
BEGIN
  INSERT INTO public.stores (name) VALUES ('My restaurant') RETURNING id INTO v_store_id;
  INSERT INTO public.store_members (store_id, user_id, role, accepted_at)
    VALUES (v_store_id, NEW.id, 'owner', now());
  INSERT INTO public.subscriptions (owner_user_id, tier)
    VALUES (NEW.id, 'free')
    ON CONFLICT (owner_user_id) DO NOTHING;
  RETURN NEW;
END $$;
```

### 3.5 Edge Function — `create-checkout-session`

Path: `backend/supabase/functions/create-checkout-session/index.ts`

```ts
// Pseudocode shape; full code in plan.
export async function handleRequest(req: Request): Promise<Response> {
  // 1. Auth header → user JWT → user id (supabase anon client).
  // 2. Parse body { tier: 'pro'|'growth', currency: 'USD'|'CNY', period: 'monthly'|'annual' }.
  // 3. Validate combo: CNY + annual rejected (P-4). Free tier rejected.
  // 4. Look up the user's existing stripe_customer_id. If null, Stripe.customers.create.
  //    Persist the new customer_id on subscriptions via service_role.
  // 5. Pick the price ID from env vars: STRIPE_PRICE_<TIER>_<CCY>_<PERIOD>.
  // 6. Stripe.checkout.sessions.create:
  //      mode: 'subscription',
  //      customer: customer_id,
  //      line_items: [{ price: priceId, quantity: 1 }],
  //      payment_method_types: currency === 'CNY'
  //        ? ['card', 'wechat_pay', 'alipay']
  //        : ['card'],
  //      success_url: <app deep link>,
  //      cancel_url: <app deep link>,
  //      metadata: { owner_user_id: user.id }
  // 7. Return { url: session.url }.
}
```

Errors:
- 401 missing/bad auth.
- 400 invalid combo (CNY+annual, free tier requested).
- 500 Stripe API error.

### 3.6 Edge Function — `create-portal-session`

Same pattern as `create-checkout-session` but calls `Stripe.billingPortal.sessions.create({ customer: customer_id, return_url: <app deep link> })` and returns `{ url }`. 404 if user has no `stripe_customer_id` (i.e., still on free tier — they shouldn't see "manage billing" button anyway, but defensive).

### 3.7 Edge Function — `handle-stripe-webhook`

Path: `backend/supabase/functions/handle-stripe-webhook/index.ts`

Flow:
1. **Read raw body** via `await req.arrayBuffer()` then `new TextDecoder().decode(bodyArrayBuffer)`.
2. **Verify signature** with `stripe.webhooks.constructEvent(rawBody, signatureHeader, STRIPE_WEBHOOK_SECRET)`. Reject with 400 if invalid.
3. **Idempotency check** — `INSERT INTO stripe_events_seen (event_id, event_type) VALUES (event.id, event.type) ON CONFLICT DO NOTHING RETURNING id`. If RETURNING is empty, return 200 (already processed, no-op).
4. **Handle event** (subset only this session):
   - `checkout.session.completed`:
     - Pull `metadata.owner_user_id`, `customer`, `subscription` from event.
     - Look up tier from session.line_items[0].price.id (compare against env price IDs to map back to tier).
     - UPDATE subscriptions SET tier=…, stripe_customer_id=…, stripe_subscription_id=…, current_period_end=…, billing_currency=…, period=… WHERE owner_user_id=…
     - Fan out tier change to all owned stores: UPDATE stores SET tier=… WHERE id IN (SELECT store_id FROM store_members WHERE user_id=… AND role='owner').
     - If tier='growth' and the user has no organizations row tied to them: create one + UPDATE every owned store's org_id (per A-5).
   - `customer.subscription.updated`: update `current_period_end` + `tier` (in case plan switched).
   - `customer.subscription.deleted`: tier → 'free' on owner; cascade to owned stores. Leave `stripe_customer_id` for re-subscription possibility. Don't delete data; existing over-cap menus stay accessible.
   - `invoice.payment_failed`: log + ignore (Stripe retries). Do NOT downgrade on first failure.
   - Other events: no-op (return 200 ack).
5. Return 200.

Service-role client used throughout (writes bypass RLS).

### 3.8 Edge Function — `create-store`

Path: `backend/supabase/functions/create-store/index.ts`

```ts
export async function handleRequest(req: Request): Promise<Response> {
  // 1. Auth header → user JWT.
  // 2. Body { name: string, currency?: string, source_locale?: string }.
  // 3. Look up subscriptions.tier for user. Reject if !== 'growth' with 403 + 'multi_store_requires_growth'.
  // 4. Look up user's organization (created on growth upgrade). If somehow missing, create one.
  // 5. INSERT INTO stores (name, currency, source_locale, org_id, tier) — tier='growth'.
  // 6. INSERT INTO store_members (store_id, user_id, role, accepted_at) values (newStore.id, user.id, 'owner', now()).
  // 7. Return { storeId }.
}
```

### 3.9 `parse-menu` Edge Function patch

In `backend/supabase/functions/parse-menu/index.ts`, after RLS confirms ownership of the run (existing line ~44) and before `await runParse(runId)`:

```ts
// Quota gate — only on re-parses (where parse_runs.menu_id is NOT NULL).
if (row.menu_id) {
  const { data: countRow } = await serviceRoleDb
    .from('parse_runs')
    .select('id', { count: 'exact', head: true })
    .eq('menu_id', row.menu_id)
    .gte('created_at', firstOfThisMonthISO());
  const tier = await fetchTierByStoreId(row.store_id);
  const cap = ({ free: 1, pro: 5, growth: 50 })[tier];
  if (countRow.count >= cap) {
    return jsonResponse({ error: 'reparse_quota_exceeded', tier, cap }, 402);
  }
}
```

(`firstOfThisMonthISO()` is a 5-line helper. The check is a hard 402; merchant Flutter shows an upgrade prompt.)

Initial parse (parse_runs.menu_id IS NULL) is NOT counted — it's the user's first parse for that menu and always free of cap. The cap only applies to re-parses.

### 3.10 Customer SvelteKit — QR view soft block

Patch `frontend/customer/src/routes/[slug]/+page.server.ts`:

```ts
export const load: PageServerLoad = async ({ locals, params, url, request }) => {
  const menu = await fetchPublishedMenu(locals.supabase, params.slug);
  if (!menu) throw error(404, 'menu_not_found');

  // Soft-block when Free-tier merchant exceeds 2 000 QR views this month.
  if (menu.store.tier === 'free' && menu.store.qr_views_monthly_count >= 2000) {
    throw error(402, 'qr_view_quota_exceeded');
  }

  const locale = resolveLocale({ /* … existing args … */ });
  // Fire-and-forget log; the DB trigger increments stores.qr_views_monthly_count.
  logView(locals.supabase, menu.id, menu.store.id, locale, request.headers, url);
  return { menu, lang: locale, jsonLd: buildMenuJsonLd(menu, locale) };
};
```

`fetchPublishedMenu` already SELECTs from `stores` (joined). Update the select string to include `tier, qr_views_monthly_count`. Update the TypeScript `Store` type at `src/lib/types/menu.ts` accordingly.

`+error.svelte` extended to handle 402 with branded copy:
```svelte
{#if status === 402 && message === 'qr_view_quota_exceeded'}
  <h1>{$_('paywall.qrQuotaTitle')}</h1>
  <p>{$_('paywall.qrQuotaBody')}</p>
{:else if status === 404}
  …
{/if}
```

i18n strings on customer side: add `paywall.qrQuotaTitle`, `paywall.qrQuotaBody` to en + zh. (Customer i18n lives at `frontend/customer/src/lib/i18n/strings.ts`.)

### 3.11 MenurayBadge custom-branding gate

`MenurayBadge.svelte` already has `hidden: boolean = false`. The customer +layout.svelte / +page.svelte code paths receive the `Store` from page data. Pass `hidden={menu.store.tier !== 'free'}`:

```svelte
<MenurayBadge {locale} hidden={menu.store.tier !== 'free'} />
```

### 3.12 Flutter — `currentTierProvider` + `TierGate`

`lib/features/billing/billing_providers.dart` (new):
```dart
enum Tier { free, pro, growth }
extension TierX on Tier {
  bool get isPaid => this == Tier.pro || this == Tier.growth;
  bool get isGrowth => this == Tier.growth;
  String get apiName => name; // 'free' / 'pro' / 'growth'
  static Tier fromString(String s) =>
      Tier.values.firstWhere((t) => t.apiName == s, orElse: () => Tier.free);
}

final currentTierProvider = FutureProvider<Tier>((ref) async {
  final ctx = ref.watch(activeStoreProvider);
  if (ctx == null) return Tier.free;
  // Read denormalised tier off the active store's row.
  final store = await ref.watch(currentStoreProvider.future);
  return TierX.fromString(/* stores.tier — add to model + mapper */);
});
```

The `Store` Dart model + mapper get a new `tier` field (string, default 'free'). Thread through `storeFromSupabase`, `currentStoreProvider`'s upstream `StoreRepository.fetchById` already does `SELECT *`, so `tier` arrives.

`TierGate` (new shared widget at `lib/shared/widgets/tier_gate.dart`):
```dart
class TierGate extends ConsumerWidget {
  final Set<Tier> allowed;
  final Widget child;
  final Widget? fallback;
  const TierGate({required this.allowed, required this.child, this.fallback, super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tierAsync = ref.watch(currentTierProvider);
    final tier = tierAsync.valueOrNull;
    final show = tier != null && allowed.contains(tier);
    return show ? child : (fallback ?? const SizedBox.shrink());
  }
}
```

### 3.13 Flutter Upgrade screen

New `lib/features/billing/presentation/upgrade_screen.dart` at `/upgrade`. Layout (vertical, scrollable on small screens):

- Header: "升级订阅 / Upgrade subscription"
- Tier comparison: 3 cards (Free / Pro / Growth) showing key caps (menus, dishes, AI parses, languages, QR views, custom branding, multi-store, support). "Current" badge on user's tier.
- Currency toggle: USD ↔ CNY (default from the user's locale; CNY shows monthly only, hides annual toggle).
- Period toggle: Monthly ↔ Annual (USD only). Annual shows "≈15% off".
- Subscribe buttons: per non-current tier card. Tap → `BillingRepository.createCheckoutSession(tier, currency, period)` → returns URL → `url_launcher.launch(url)` opens Stripe Checkout in external browser.
- "Manage billing" button (visible only when `tier != 'free'`) → `createPortalSession()` → `url_launcher`.

`BillingRepository`:
```dart
class BillingRepository {
  BillingRepository(this._client);
  final SupabaseClient _client;
  Future<String> createCheckoutSession({required Tier tier, required String currency, required String period}) async {
    final res = await _client.functions.invoke('create-checkout-session',
      body: {'tier': tier.apiName, 'currency': currency, 'period': period});
    return res.data['url'] as String;
  }
  Future<String> createPortalSession() async {
    final res = await _client.functions.invoke('create-portal-session');
    return res.data['url'] as String;
  }
}
```

Riverpod `billingRepositoryProvider` mirrors the pattern from `MembershipRepository`.

### 3.14 Tier-gated screens

- **Home** (`lib/features/home/presentation/home_screen.dart`):
  - "+ New menu" button is NOT gated visually — it's always visible. Tap handler does:
    1. `await ref.read(supabaseClientProvider).rpc('assert_menu_count_under_cap', params: {'p_store_id': ctx.storeId})`.
    2. On `check_violation`, navigate to `/upgrade` with snackbar `t.paywallMenuCapReached`.
    3. Otherwise proceed as today.
- **Custom theme** (`lib/features/publish/presentation/custom_theme_screen.dart`):
  - Wrap the primary-colour picker in `TierGate(allowed: {Tier.pro, Tier.growth}, child: …, fallback: <UpgradeCallout>)`.
- **Edit dish translation** (deferred: no UI exists yet for adding translations — Flutter app is currently translation-aware only via parse). Schema gate via RPC stays in place; UI gate added when translation editor lands in a future session.
- **Settings** (`lib/features/store/presentation/settings_screen.dart`): new tile "升级订阅 / Upgrade subscription" navigating to `/upgrade`. When `tier != 'free'` it shows "管理订阅 / Manage billing" instead.

### 3.15 i18n — ~28 keys (en + zh)

```
billingPlanFree                 → "Free"  / "免费版"
billingPlanPro                  → "Pro"   / "Pro"
billingPlanGrowth               → "Growth"/ "Growth"
billingMenusCap                 → "{count} menu(s)" / "{count} 个菜单"
billingDishesPerMenuCap         → "{count} dishes per menu" / "每菜单 {count} 道"
billingReparsesCap              → "{count} AI re-parses / month" / "每月 {count} 次再解析"
billingQrViewsCap               → "{count} QR views / month" / "每月 {count} 次扫码"
billingLanguagesCap             → "{count} languages" / "{count} 个语言"
billingMultiStore               → "Multiple stores" / "多门店"
billingCustomBranding           → "Remove MenuRay badge" / "去除 MenuRay 徽标"
billingPriorityCsv              → "CSV export & priority support" / "CSV 导出 + 优先支持"
billingCurrentTag               → "Current" / "当前"
billingMonthlyToggle            → "Monthly" / "月付"
billingAnnualToggle             → "Annual (~15% off)" / "年付（约 8.5 折）"
billingCurrencyUsd              → "USD" / "美元"
billingCurrencyCny              → "CNY" / "人民币"
billingSubscribePro             → "Subscribe to Pro" / "订阅 Pro"
billingSubscribeGrowth          → "Subscribe to Growth" / "订阅 Growth"
billingManageBilling            → "Manage billing" / "管理订阅"
billingUpgradeTitle             → "Upgrade subscription" / "升级订阅"
billingCheckoutOpening          → "Opening Stripe Checkout…" / "正在打开 Stripe…"
billingCheckoutFailed           → "Couldn't open checkout. Please try again." / "无法打开支付页，请重试。"
paywallMenuCapReached           → "You've reached the menu limit for the {tier} plan." / "已达到 {tier} 套餐菜单上限。"
paywallReparseQuotaReached      → "Monthly AI re-parse quota reached." / "本月 AI 再解析次数已用完。"
paywallTranslationCapReached    → "Language limit reached for the {tier} plan." / "{tier} 套餐语言数上限。"
paywallCustomThemeLocked        → "Custom theme available on Pro+" / "自定义主题需 Pro 以上"
paywallMultiStoreLocked         → "Multi-store available on Growth" / "多门店需 Growth"
paywallQrQuotaTitle             → "This menu is over its monthly view quota" / "此菜单本月浏览次数已达上限"
paywallQrQuotaBody              → "Please come back next month, or ask the restaurant to upgrade." / "请下月再来，或请商户升级。"
```

(28 keys; some carry `{tier}` or `{count}` placeholders.)

Customer SvelteKit i18n adds the two `paywall.qrQuota*` keys to its strings.ts (en + zh).

### 3.16 Stripe Price IDs — 6 env vars

```
STRIPE_SECRET_KEY=sk_test_…
STRIPE_WEBHOOK_SECRET=whsec_…

STRIPE_PRICE_PRO_USD_MONTHLY=price_…
STRIPE_PRICE_PRO_USD_ANNUAL=price_…
STRIPE_PRICE_PRO_CNY_MONTHLY=price_…
STRIPE_PRICE_GROWTH_USD_MONTHLY=price_…
STRIPE_PRICE_GROWTH_USD_ANNUAL=price_…
STRIPE_PRICE_GROWTH_CNY_MONTHLY=price_…
```

Documented in `backend/supabase/.env.example` (committed). Real values live in Supabase secrets / local `.env.local` (gitignored). The plan also enumerates the 6 product+price rows the user creates manually in Stripe Dashboard before deployment.

### 3.17 Test strategy

**PgTAP regression** (`backend/supabase/tests/billing_quotas.sql`):
- Fixtures: 3 users — A (free, 1 menu), B (pro, will hit 6th menu cap), C (growth, no cap).
- Section A: tier reads — `store_tier()` returns 'free'/'pro'/'growth' correctly.
- Section B: counter trigger — INSERT into view_logs increments `stores.qr_views_monthly_count`; cron reset zeroes it.
- Section C: hard-gate RPCs — assert each RAISE on threshold + each pass under threshold.
- Section D: webhook idempotency — inserting the same `event_id` twice into `stripe_events_seen` succeeds first then no-ops second (unique violation handling via ON CONFLICT path).

**Deno tests** for each new Edge Function:
- `create-checkout-session/test.ts` — 4 cases: happy path returns URL, missing auth → 401, invalid combo (CNY+annual) → 400, free tier → 400.
- `create-portal-session/test.ts` — happy path, no customer → 404.
- `handle-stripe-webhook/test.ts` — 6 cases: signature OK + checkout.session.completed updates row, signature OK + subscription.deleted flips tier, replay returns 200 no-op, signature fails → 400, unknown event type → 200 ack, growth upgrade auto-creates org row.
- `create-store/test.ts` — happy path on growth, 403 on free/pro, missing auth → 401.

Each Deno test reuses the `withStubbedFetch` pattern from `accept-invite/test.ts`. Stripe API is mocked via stubbed fetch responses with realistic shapes.

**Flutter smoke** — `upgrade_screen_smoke_test.dart`:
- Renders 3 tier cards with currency toggle.
- Tap "Subscribe to Pro" calls a fake `BillingRepository.createCheckoutSession` and verifies the URL handler is invoked with the expected URL.

**Manual smoke** (documented in plan):
- Real Stripe test mode: card 4242 4242 4242 4242 → checkout completes → webhook to local Edge Function → tier flips.
- WeChat Pay test mode in CN currency.
- Manage billing → Stripe Customer Portal → Cancel → tier flips back to free at period end.

### 3.18 Local dev workflow

- `cd backend/supabase && supabase db reset` — rebuilds with new migration.
- `pg_cron` schedule fires only in production-like environments. Local runs document a manual `SELECT cron.schedule(...)` test by calling the wrapped UPDATE directly.
- Stripe CLI used for local webhook forwarding: `stripe listen --forward-to http://127.0.0.1:54321/functions/v1/handle-stripe-webhook`. Dev signing secret printed by Stripe CLI is the value of `STRIPE_WEBHOOK_SECRET` in `.env.local`.
- New file `backend/supabase/functions/create-checkout-session/README.md` documents the env-var requirements + Stripe CLI dev flow. Same for the other 3 functions.

## 4. Data model

### Postgres (additive)

```
subscriptions     (owner_user_id PK FK auth.users, tier, stripe_customer_id, stripe_subscription_id,
                   current_period_end, billing_currency, period, created_at, updated_at)
stripe_events_seen (event_id PK, event_type, processed_at)
stores            …existing… + tier text, qr_views_monthly_count int
```

### Dart (extend existing)

```dart
class Store {
  // …existing fields…
  final String tier;            // 'free' | 'pro' | 'growth'
  final int qrViewsMonthlyCount;
  // …
}
```

### TypeScript (customer)

```ts
export interface Store {
  id: string;
  source_name: string;
  // …existing…
  tier: 'free'|'pro'|'growth';
  qr_views_monthly_count: number;
}
```

## 5. Dependencies (new)

- **Deno**: `npm:stripe@latest` (installed lazily by Deno on first run; pinned in each function's `deno.json` import map for reproducibility).
- **Flutter**: `url_launcher: ^6.x` (for opening Stripe Checkout in external browser). Likely already a transitive dep — verify; add if missing.
- **Postgres**: `pg_cron` (already shipped with Supabase).
- **No new merchant package besides `url_launcher`.** No `flutter_stripe` (we use Checkout via browser).

## 6. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Webhook signature mismatch in production after deploy | Smoke check via Stripe CLI before going live; Edge Function logs every signature failure with type only (not body). |
| Stripe API rate limits during traffic spikes | Webhook is async by nature; Stripe retries automatically. Edge Function returns 200 quickly after DB UPDATE. |
| Tier denormalisation drift between `subscriptions` and `stores` | Single point of write: webhook handler in a transaction. Manual integrity test in PgTAP: `SELECT count(*) FROM stores s JOIN store_members m ON m.store_id=s.id JOIN subscriptions sub ON sub.owner_user_id=m.user_id WHERE m.role='owner' AND s.tier <> sub.tier` should be 0. |
| `pg_cron` not enabled on hosted Supabase | Supabase has it on by default for Pro projects. Document as deploy prerequisite; for self-hosters, the migration's `CREATE EXTENSION IF NOT EXISTS pg_cron` is best-effort. |
| WeChat Pay / Alipay availability per Stripe account | Requires Stripe account to be enabled for these methods (Stripe Dashboard, may require business verification). Document as deploy prerequisite. |
| User has multiple owner-stores, then upgrades to Growth — webhook fans out tier | Webhook does `UPDATE stores SET tier='growth' WHERE id IN (SELECT store_id FROM store_members WHERE user_id=… AND role='owner')`. Single SQL statement, atomic. |
| User cancels mid-period | Stripe sends `customer.subscription.updated` with `cancel_at_period_end=true` first, then `customer.subscription.deleted` at period end. We DOWNGRADE on the deleted event; no early downgrade. |
| QR view counter race | UPDATE is a single SQL statement; concurrent inserts serialize per row in Postgres. Counter is monotonic until cron reset. |
| Free user with 6 menus from a previous Pro period | Hard-gated only on INSERT. Existing rows stay accessible. UI shows them but disables edit / publish. Mitigation already in spec §3.14. |
| Manual Stripe Price ID setup error (wrong price wired) | Plan documents exact Stripe Dashboard click-by-click steps + lookup table. Manual smoke (test card) catches mis-wires before production. |
| `url_launcher` may fail on some platforms | Wrap launch in try-catch; show snackbar `billingCheckoutFailed`; user can retry. |
| China access to Stripe-hosted Checkout | Stripe is reachable from Chinese networks; if blocked, user will see a clear failure on the merchant app. Out-of-scope mitigation: deploying a CN-region Stripe alternative (Sessions 5+). |
| Anon user spamming the QR view endpoint to drain quota | view_logs INSERT under RLS only allows anon for published menus AND store_id matches; `referrer_domain` and `session_id` are recorded; deeper bot filtering is Session 5. Some abuse possible; cost containment is the 2 000-cap soft block (no real $$ harm) + the 20 000 cap on Pro. |

## 7. Open questions

None for this spec — the decision matrix at session start resolved them. Two operational notes for the deployer:

1. Stripe Dashboard: 6 prices must be created before deploy. Plan documents the names and the env-var mapping.
2. CN payment methods: Stripe account must be approved for WeChat Pay + Alipay. Document on the deploy runbook.

## 8. Success criteria

- `cd backend/supabase && supabase db reset` applies cleanly with the new migration; `psql -f backend/supabase/tests/billing_quotas.sql` is all green.
- `deno test` is green for all 4 new Edge Functions.
- `cd frontend/merchant && flutter analyze && flutter test` clean. ≥1 new smoke test (upgrade screen) passes.
- `cd frontend/customer && pnpm check && pnpm test` clean.
- Manual smoke: a Stripe test-mode purchase on `card 4242` flips the seed user from `free` to `pro`; their `stores.tier` updates; the MenuRay badge disappears on the customer view; "+ New menu" button creates a 2nd menu without paywall.
- `git grep STRIPE_PRICE_` shows only env-var references (no hardcoded price IDs in source).
- All 28 i18n keys present in both `app_en.arb` and `app_zh.arb`; `flutter gen-l10n` clean.

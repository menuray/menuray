# Stripe Billing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship MenuRay's first paid tier system — atomic billing migration (subscriptions, denormalised `stores.tier`, QR-view counter, `pg_cron` reset, hard-gate RPCs); four new Edge Functions wrapping Stripe Checkout, Customer Portal, webhook handler, and multi-store creation; `parse-menu` quota gate; SvelteKit customer-view paywall; Flutter Upgrade screen + tier-aware providers; 28 i18n keys; full test battery + manual Stripe smoke. Spec: `docs/superpowers/specs/2026-04-24-stripe-billing-design.md`.

**Architecture:** A single SQL migration adds `subscriptions` (keyed by `owner_user_id`), `stripe_events_seen`, `stores.tier` + `stores.qr_views_monthly_count`, three `assert_*_under_cap` RPCs, a `view_logs`-INSERT trigger that bumps the counter, a `pg_cron` job resetting it monthly, and an extension to `handle_new_user()` that seeds a free subscription row. The `handle-stripe-webhook` Deno Edge Function is the single point of truth for tier writes — it updates `subscriptions` *and* fans out tier to every store the user owns (and auto-creates an `organizations` row on Growth upgrade). `create-checkout-session` and `create-portal-session` build Stripe redirect URLs; `create-store` gates multi-store creation behind tier='growth'. The merchant Flutter app exposes a `/upgrade` screen that hits Checkout via `url_launcher`; gated screens (Home `+New menu`, Custom theme picker) call the assert RPC then bounce to `/upgrade` on `check_violation`. Customer SvelteKit's SSR loader joins `stores.tier` + the counter, throws 402 on Free-tier overage, and hides MenuRayBadge for Pro+.

**Tech Stack:** Postgres 15 (Supabase) + `pg_cron`; Deno 2 + `npm:stripe@^17`; SvelteKit 2 + Svelte 5 (`+error.svelte` extension); Flutter 3 stable + Riverpod + `url_launcher` (already transitive). No new merchant package required.

---

## File structure

**New (backend):**
```
backend/supabase/migrations/20260424000002_billing.sql
backend/supabase/tests/billing_quotas.sql
backend/supabase/functions/create-checkout-session/index.ts
backend/supabase/functions/create-checkout-session/test.ts
backend/supabase/functions/create-checkout-session/deno.json
backend/supabase/functions/create-portal-session/index.ts
backend/supabase/functions/create-portal-session/test.ts
backend/supabase/functions/create-portal-session/deno.json
backend/supabase/functions/handle-stripe-webhook/index.ts
backend/supabase/functions/handle-stripe-webhook/test.ts
backend/supabase/functions/handle-stripe-webhook/deno.json
backend/supabase/functions/create-store/index.ts
backend/supabase/functions/create-store/test.ts
backend/supabase/functions/create-store/deno.json
backend/supabase/functions/_shared/stripe.ts                     # shared Stripe client + price-ID lookup
backend/supabase/.env.example                                     # documents 8 Stripe env vars
```

**New (merchant flutter):**
```
frontend/merchant/lib/features/billing/billing_repository.dart
frontend/merchant/lib/features/billing/billing_providers.dart
frontend/merchant/lib/features/billing/tier.dart
frontend/merchant/lib/features/billing/presentation/upgrade_screen.dart
frontend/merchant/lib/shared/widgets/tier_gate.dart
frontend/merchant/test/unit/tier_test.dart
frontend/merchant/test/widgets/tier_gate_test.dart
frontend/merchant/test/smoke/upgrade_screen_smoke_test.dart
```

**Modified (backend):**
```
backend/supabase/functions/parse-menu/index.ts                    (re-parse quota gate)
backend/supabase/functions/parse-menu/test.ts                     (or new fixture if absent)
```

**Modified (customer):**
```
frontend/customer/src/routes/[slug]/+page.server.ts               (402 paywall)
frontend/customer/src/routes/+layout.svelte                       (badge gate via page data)
frontend/customer/src/routes/+error.svelte                        (402 paywall body)
frontend/customer/src/lib/data/fetchPublishedMenu.ts              (select tier + counter)
frontend/customer/src/lib/types/menu.ts                           (Store gains tier + counter)
frontend/customer/src/lib/i18n/strings.ts                         (paywall.qrQuotaTitle/Body)
```

**Modified (merchant flutter):**
```
frontend/merchant/lib/shared/models/store.dart                    (add tier field)
frontend/merchant/lib/shared/models/_mappers.dart                 (storeFromSupabase reads tier)
frontend/merchant/lib/router/app_router.dart                      (new /upgrade route)
frontend/merchant/lib/features/home/presentation/home_screen.dart (RPC pre-check on +New menu)
frontend/merchant/lib/features/publish/presentation/custom_theme_screen.dart (TierGate on picker)
frontend/merchant/lib/features/store/presentation/settings_screen.dart       (Upgrade tile)
frontend/merchant/lib/l10n/app_en.arb                             (28 new keys)
frontend/merchant/lib/l10n/app_zh.arb                             (28 new keys)
frontend/merchant/test/unit/mappers_test.dart                     (storeFromSupabase tier)
frontend/merchant/test/smoke/home_screen_smoke_test.dart          (paywall redirect path)
docs/architecture.md                                              (new "Billing" subsection)
docs/roadmap.md                                                   (Session 4 marked shipped)
CLAUDE.md                                                         (Active work + test totals)
```

---

## Task 1: Billing migration (atomic)

**Files:**
- Create: `backend/supabase/migrations/20260424000002_billing.sql`

- [ ] **Step 1: Create the migration file**

Write the following complete contents to `backend/supabase/migrations/20260424000002_billing.sql`:

```sql
-- ============================================================================
-- MenuRay — Billing (Stripe). One atomic migration.
-- See docs/superpowers/specs/2026-04-24-stripe-billing-design.md for rationale.
-- ============================================================================

-- ---------- 1. subscriptions table ------------------------------------------
CREATE TABLE subscriptions (
  owner_user_id          uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  tier                   text NOT NULL DEFAULT 'free'
                              CHECK (tier IN ('free','pro','growth')),
  stripe_customer_id     text UNIQUE,
  stripe_subscription_id text UNIQUE,
  current_period_end     timestamptz,
  billing_currency       text CHECK (billing_currency IN ('USD','CNY')),
  period                 text CHECK (period IN ('monthly','annual')),
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER subscriptions_touch_updated_at BEFORE UPDATE ON subscriptions
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY subscriptions_self_select ON subscriptions FOR SELECT TO authenticated
  USING (owner_user_id = auth.uid());

-- ---------- 2. stripe_events_seen (webhook idempotency) ---------------------
CREATE TABLE stripe_events_seen (
  event_id     text PRIMARY KEY,
  event_type   text NOT NULL,
  processed_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE stripe_events_seen ENABLE ROW LEVEL SECURITY;
-- No policies — only service_role accesses this table.

-- ---------- 3. stores.tier + qr_views_monthly_count -------------------------
ALTER TABLE stores
  ADD COLUMN tier text NOT NULL DEFAULT 'free'
       CHECK (tier IN ('free','pro','growth')),
  ADD COLUMN qr_views_monthly_count int NOT NULL DEFAULT 0;

-- ---------- 4. store_tier helper --------------------------------------------
CREATE FUNCTION public.store_tier(p_store_id uuid) RETURNS text
  LANGUAGE sql STABLE AS $$
  SELECT tier FROM stores WHERE id = p_store_id
$$;
GRANT EXECUTE ON FUNCTION public.store_tier(uuid) TO anon, authenticated;

-- ---------- 5. view_logs INSERT trigger increments counter ------------------
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

-- ---------- 6. pg_cron monthly reset ----------------------------------------
CREATE EXTENSION IF NOT EXISTS pg_cron;
SELECT cron.schedule(
  'reset-monthly-qr-views',
  '1 0 1 * *',                                          -- 00:01 UTC, 1st of month
  $$ UPDATE public.stores SET qr_views_monthly_count = 0; $$
);

-- ---------- 7. Hard-gate RPCs -----------------------------------------------
CREATE FUNCTION public.assert_menu_count_under_cap(p_store_id uuid) RETURNS void
  LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_tier text; v_count int; v_cap int;
BEGIN
  SELECT tier INTO v_tier FROM stores WHERE id = p_store_id;
  IF v_tier IS NULL THEN
    RAISE EXCEPTION 'store_not_found' USING ERRCODE = 'no_data_found';
  END IF;
  v_cap := CASE v_tier
    WHEN 'free'   THEN 1
    WHEN 'pro'    THEN 5
    WHEN 'growth' THEN 2147483647
  END;
  SELECT count(*) INTO v_count FROM menus
   WHERE store_id = p_store_id AND status <> 'archived';
  IF v_count >= v_cap THEN
    RAISE EXCEPTION 'menu_count_cap_exceeded'
      USING ERRCODE = 'check_violation';
  END IF;
END $$;
GRANT EXECUTE ON FUNCTION public.assert_menu_count_under_cap(uuid) TO authenticated;

CREATE FUNCTION public.assert_dish_count_under_cap(p_menu_id uuid, p_to_add int)
  RETURNS void
  LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_tier text; v_existing int; v_cap int;
BEGIN
  SELECT s.tier INTO v_tier
    FROM stores s JOIN menus m ON m.store_id = s.id
   WHERE m.id = p_menu_id;
  IF v_tier IS NULL THEN
    RAISE EXCEPTION 'menu_not_found' USING ERRCODE = 'no_data_found';
  END IF;
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
GRANT EXECUTE ON FUNCTION public.assert_dish_count_under_cap(uuid, int) TO authenticated;

CREATE FUNCTION public.assert_translation_count_under_cap(p_dish_id uuid, p_locale text)
  RETURNS void
  LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_tier text; v_existing int; v_cap int; v_already_present boolean;
BEGIN
  SELECT s.tier INTO v_tier
    FROM stores s JOIN dishes d ON d.store_id = s.id
   WHERE d.id = p_dish_id;
  IF v_tier IS NULL THEN
    RAISE EXCEPTION 'dish_not_found' USING ERRCODE = 'no_data_found';
  END IF;
  v_cap := CASE v_tier
    WHEN 'free'   THEN 1
    WHEN 'pro'    THEN 4
    WHEN 'growth' THEN 2147483647
  END;
  SELECT EXISTS (SELECT 1 FROM dish_translations
                  WHERE dish_id = p_dish_id AND locale = p_locale)
    INTO v_already_present;
  IF v_already_present THEN RETURN; END IF;
  SELECT count(*) INTO v_existing FROM dish_translations WHERE dish_id = p_dish_id;
  IF v_existing >= v_cap THEN
    RAISE EXCEPTION 'translation_count_cap_exceeded'
      USING ERRCODE = 'check_violation';
  END IF;
END $$;
GRANT EXECUTE ON FUNCTION public.assert_translation_count_under_cap(uuid, text) TO authenticated;

-- ---------- 8. Extend handle_new_user() to seed a free subscription ---------
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

-- ---------- 9. Backfill: existing users + stores ----------------------------
-- Every existing auth.users row that owns at least one store should have a
-- 'free' subscription row.
INSERT INTO subscriptions (owner_user_id, tier)
SELECT DISTINCT m.user_id, 'free'
  FROM store_members m
 WHERE m.role = 'owner' AND m.accepted_at IS NOT NULL
ON CONFLICT (owner_user_id) DO NOTHING;
-- stores.tier defaults to 'free'; nothing else to backfill.
```

- [ ] **Step 2: Commit**

```bash
cd /home/coder/workspaces/menuray
git add backend/supabase/migrations/20260424000002_billing.sql
git -c commit.gpgsign=false commit -m "$(cat <<'EOF'
feat(backend): billing migration — subscriptions, tier denormalisation, hard-gate RPCs

Single atomic migration adding:
- subscriptions table (owner_user_id PK) + RLS self-select
- stripe_events_seen (webhook idempotency)
- stores.tier + stores.qr_views_monthly_count (denormalised)
- store_tier(p_store_id) STABLE helper
- view_logs INSERT trigger that increments the counter
- pg_cron job resetting counter on the 1st of every month
- assert_menu_count_under_cap / assert_dish_count_under_cap /
  assert_translation_count_under_cap (SECURITY DEFINER)
- handle_new_user() extended to seed a free subscription
- backfill: existing owner-memberships → free subscriptions

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: PgTAP regression script

**Files:**
- Create: `backend/supabase/tests/billing_quotas.sql`

- [ ] **Step 1: Create the test file**

Write the following to `backend/supabase/tests/billing_quotas.sql`:

```sql
-- ============================================================================
-- Billing quota regression — Session 4 (Stripe billing).
-- Usage:  supabase db reset && \
--         docker exec -i supabase_db_menuray psql -U postgres -d postgres \
--           -v ON_ERROR_STOP=1 < backend/supabase/tests/billing_quotas.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
BEGIN;

-- Fixtures: 3 users, 3 stores (one per user), each with different tier.
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                        is_super_admin, created_at, updated_at,
                        confirmation_token, email_change, email_change_token_new, recovery_token)
VALUES
  ('11110000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','free@test','', now(),'{}','{}',false,now(),now(),'','','',''),
  ('11110000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','pro@test','', now(),'{}','{}',false,now(),now(),'','','',''),
  ('11110000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','growth@test','', now(),'{}','{}',false,now(),now(),'','','','')
ON CONFLICT (id) DO NOTHING;

INSERT INTO stores (id, name, tier) VALUES
  ('22220000-0000-0000-0000-000000000001','Free shop',   'free'),
  ('22220000-0000-0000-0000-000000000002','Pro shop',    'pro'),
  ('22220000-0000-0000-0000-000000000003','Growth shop', 'growth')
ON CONFLICT (id) DO NOTHING;

INSERT INTO store_members (store_id, user_id, role, accepted_at) VALUES
  ('22220000-0000-0000-0000-000000000001','11110000-0000-0000-0000-000000000001','owner',now()),
  ('22220000-0000-0000-0000-000000000002','11110000-0000-0000-0000-000000000002','owner',now()),
  ('22220000-0000-0000-0000-000000000003','11110000-0000-0000-0000-000000000003','owner',now())
ON CONFLICT (store_id, user_id) DO NOTHING;

INSERT INTO subscriptions (owner_user_id, tier) VALUES
  ('11110000-0000-0000-0000-000000000001','free'),
  ('11110000-0000-0000-0000-000000000002','pro'),
  ('11110000-0000-0000-0000-000000000003','growth')
ON CONFLICT (owner_user_id) DO UPDATE SET tier = EXCLUDED.tier;

-- =============== A. store_tier reads =========================================
DO $$ BEGIN
  ASSERT public.store_tier('22220000-0000-0000-0000-000000000001') = 'free',  'free tier read';
  ASSERT public.store_tier('22220000-0000-0000-0000-000000000002') = 'pro',   'pro tier read';
  ASSERT public.store_tier('22220000-0000-0000-0000-000000000003') = 'growth','growth tier read';
END $$;

-- =============== B. counter trigger ==========================================
INSERT INTO menus (id, store_id, name, status, slug, source_locale)
VALUES ('33330000-0000-0000-0000-000000000001','22220000-0000-0000-0000-000000000001','Free menu','published','free-menu','en')
ON CONFLICT DO NOTHING;
DO $$ BEGIN
  PERFORM 1 FROM stores WHERE id = '22220000-0000-0000-0000-000000000001' AND qr_views_monthly_count = 0;
  ASSERT FOUND, 'counter starts at 0';

  INSERT INTO view_logs (menu_id, store_id) VALUES
    ('33330000-0000-0000-0000-000000000001','22220000-0000-0000-0000-000000000001');
  INSERT INTO view_logs (menu_id, store_id) VALUES
    ('33330000-0000-0000-0000-000000000001','22220000-0000-0000-0000-000000000001');

  PERFORM 1 FROM stores WHERE id = '22220000-0000-0000-0000-000000000001' AND qr_views_monthly_count = 2;
  ASSERT FOUND, 'counter incremented by 2';

  -- Manual reset (simulating cron job).
  UPDATE stores SET qr_views_monthly_count = 0;
  PERFORM 1 FROM stores WHERE id = '22220000-0000-0000-0000-000000000001' AND qr_views_monthly_count = 0;
  ASSERT FOUND, 'counter reset to 0';
END $$;

-- =============== C. assert_menu_count_under_cap ==============================
-- Free shop has 1 menu already (above). Adding a 2nd should raise.
DO $$ BEGIN
  -- Below cap (count=1, cap=1) means count >= cap → already at the cap.
  -- The assertion fires when count_existing >= cap, so even the *current* state
  -- raises. So before adding any further menu, the assert already fails.
  -- Verify by raising:
  BEGIN
    PERFORM public.assert_menu_count_under_cap('22220000-0000-0000-0000-000000000001');
    ASSERT false, 'free shop with 1 menu should fail the cap check';
  EXCEPTION WHEN check_violation THEN NULL; END;

  -- Pro shop with 1 menu is fine.
  INSERT INTO menus (id, store_id, name, status, slug, source_locale)
  VALUES ('33330000-0000-0000-0000-000000000002','22220000-0000-0000-0000-000000000002','Pro menu','published','pro-menu','en')
  ON CONFLICT DO NOTHING;
  PERFORM public.assert_menu_count_under_cap('22220000-0000-0000-0000-000000000002');
  -- No assertion here means it passed.

  -- Growth shop never raises.
  PERFORM public.assert_menu_count_under_cap('22220000-0000-0000-0000-000000000003');
END $$;

-- =============== D. assert_dish_count_under_cap ==============================
INSERT INTO categories (id, menu_id, store_id, source_name) VALUES
  ('44440000-0000-0000-0000-000000000001','33330000-0000-0000-0000-000000000001','22220000-0000-0000-0000-000000000001','c1')
ON CONFLICT DO NOTHING;

-- Add 30 dishes to the Free menu (at cap).
DO $$ DECLARE i int; BEGIN
  FOR i IN 1..30 LOOP
    INSERT INTO dishes (category_id, menu_id, store_id, source_name, price)
      VALUES ('44440000-0000-0000-0000-000000000001',
              '33330000-0000-0000-0000-000000000001',
              '22220000-0000-0000-0000-000000000001',
              'd' || i, 1);
  END LOOP;

  -- Adding 1 more should raise.
  BEGIN
    PERFORM public.assert_dish_count_under_cap('33330000-0000-0000-0000-000000000001', 1);
    ASSERT false, 'free dish cap (30) should raise on attempt to add 31st';
  EXCEPTION WHEN check_violation THEN NULL; END;

  -- Adding 0 (no-op check) is fine — counts as "still under or at cap".
  PERFORM public.assert_dish_count_under_cap('33330000-0000-0000-0000-000000000001', 0);
END $$;

-- =============== E. assert_translation_count_under_cap =======================
DO $$ DECLARE v_dish uuid; BEGIN
  -- Pick the first dish on Pro menu (Pro cap = 4 translations).
  INSERT INTO categories (id, menu_id, store_id, source_name) VALUES
    ('44440000-0000-0000-0000-000000000002','33330000-0000-0000-0000-000000000002','22220000-0000-0000-0000-000000000002','c2')
  ON CONFLICT DO NOTHING;
  INSERT INTO dishes (id, category_id, menu_id, store_id, source_name, price)
    VALUES ('55550000-0000-0000-0000-000000000001',
            '44440000-0000-0000-0000-000000000002',
            '33330000-0000-0000-0000-000000000002',
            '22220000-0000-0000-0000-000000000002',
            'pro-d', 1)
  ON CONFLICT DO NOTHING;
  v_dish := '55550000-0000-0000-0000-000000000001';

  -- Add 4 translations (at cap).
  INSERT INTO dish_translations (dish_id, store_id, locale, name) VALUES
    (v_dish, '22220000-0000-0000-0000-000000000002', 'fr', 'Plat 1'),
    (v_dish, '22220000-0000-0000-0000-000000000002', 'es', 'Plato 1'),
    (v_dish, '22220000-0000-0000-0000-000000000002', 'ja', 'Dish 1'),
    (v_dish, '22220000-0000-0000-0000-000000000002', 'ko', 'Dish 1')
  ON CONFLICT DO NOTHING;

  -- 5th locale should raise.
  BEGIN
    PERFORM public.assert_translation_count_under_cap(v_dish, 'de');
    ASSERT false, 'pro translation cap (4) should raise on 5th locale';
  EXCEPTION WHEN check_violation THEN NULL; END;

  -- Updating an existing locale (fr) is fine.
  PERFORM public.assert_translation_count_under_cap(v_dish, 'fr');
END $$;

-- =============== F. stripe_events_seen idempotency ===========================
INSERT INTO stripe_events_seen (event_id, event_type) VALUES ('evt_1', 'test');
DO $$ DECLARE v_inserted int; BEGIN
  INSERT INTO stripe_events_seen (event_id, event_type) VALUES ('evt_1', 'test')
  ON CONFLICT DO NOTHING;
  SELECT count(*) INTO v_inserted FROM stripe_events_seen WHERE event_id = 'evt_1';
  ASSERT v_inserted = 1, 'duplicate event_id stays as one row';
END $$;

ROLLBACK;

\echo 'billing_quotas.sql: all assertions passed'
```

- [ ] **Step 2: Commit**

```bash
cd /home/coder/workspaces/menuray
git add backend/supabase/tests/billing_quotas.sql
git -c commit.gpgsign=false commit -m "$(cat <<'EOF'
test(backend): PgTAP regression for billing quotas

Covers: store_tier reads, view_logs counter trigger increments,
manual cron reset, assert_menu/dish/translation_count_under_cap raises
at thresholds + passes under cap + permits updating existing locale,
stripe_events_seen idempotency.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Run migration + tests

**Files:** none changed, just verification.

- [ ] **Step 1: Reset DB to apply migration**

```bash
cd /home/coder/workspaces/menuray/backend/supabase
supabase db reset
```

Expected: tail ends with `Finished supabase db reset on branch main`. No `ERROR:` lines.

- [ ] **Step 2: Run PgTAP regression**

```bash
docker exec -i supabase_db_menuray psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  < /home/coder/workspaces/menuray/backend/supabase/tests/billing_quotas.sql 2>&1 | tail -10
```

Expected: last line `billing_quotas.sql: all assertions passed`. No `ERROR:` lines.

- [ ] **Step 3: Re-run Session 3 PgTAP regression to confirm no regressions**

```bash
docker exec -i supabase_db_menuray psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  < /home/coder/workspaces/menuray/backend/supabase/tests/rls_auth_expansion.sql 2>&1 | tail -5
```

Expected: `rls_auth_expansion.sql: all assertions passed`.

If either fails, do NOT proceed. Investigate (most likely: a missing INSERT into `subscriptions` for the seed user — Session 3 fixtures may need a corresponding subscription row inserted by `handle_new_user`, but the trigger fires only on auth.users INSERT in those tests, so the backfill should cover them).

- [ ] **Step 4: No commit needed** (verification only). Move to Task 4.

---

## Task 4: Shared Stripe helper + .env.example

**Files:**
- Create: `backend/supabase/functions/_shared/stripe.ts`
- Create: `backend/supabase/.env.example`

- [ ] **Step 1: Stripe helper**

Write to `backend/supabase/functions/_shared/stripe.ts`:

```typescript
import Stripe from "npm:stripe@^17";

let _client: Stripe | null = null;

/** Lazy-construct the Stripe client. Throws if STRIPE_SECRET_KEY is missing. */
export function stripeClient(): Stripe {
  if (_client) return _client;
  const key = Deno.env.get("STRIPE_SECRET_KEY");
  if (!key) throw new Error("STRIPE_SECRET_KEY must be set");
  _client = new Stripe(key, {
    httpClient: Stripe.createFetchHttpClient(),  // Deno-friendly
  });
  return _client;
}

/** Map (tier, currency, period) → Stripe Price ID via env vars. Returns null if
 * the combination is unsupported (e.g. CNY + annual). */
export function priceIdFor(
  tier: "pro" | "growth",
  currency: "USD" | "CNY",
  period: "monthly" | "annual",
): string | null {
  if (currency === "CNY" && period === "annual") return null;       // P-4
  const envName = `STRIPE_PRICE_${tier.toUpperCase()}_${currency}_${period.toUpperCase()}`;
  return Deno.env.get(envName) ?? null;
}

/** Reverse-map a Stripe Price ID back to a tier so the webhook can decide what
 * tier to flip to. Returns 'free' if no env var matches. */
export function tierFromPriceId(priceId: string): "free" | "pro" | "growth" {
  const tiers: Array<"pro" | "growth"> = ["pro", "growth"];
  const currencies: Array<"USD" | "CNY"> = ["USD", "CNY"];
  const periods: Array<"monthly" | "annual"> = ["monthly", "annual"];
  for (const tier of tiers) {
    for (const currency of currencies) {
      for (const period of periods) {
        const envName = `STRIPE_PRICE_${tier.toUpperCase()}_${currency}_${period.toUpperCase()}`;
        if (Deno.env.get(envName) === priceId) return tier;
      }
    }
  }
  return "free";
}
```

- [ ] **Step 2: `.env.example`**

Write to `backend/supabase/.env.example`:

```
# Stripe — required for the billing Edge Functions in production.
# Local dev: copy to .env.local (gitignored) and fill values from your Stripe test-mode dashboard.
STRIPE_SECRET_KEY=sk_test_XXXXXXXX
STRIPE_WEBHOOK_SECRET=whsec_XXXXXXXX

# Six Stripe Price IDs. CNY annual is intentionally absent (deferred per P-4).
STRIPE_PRICE_PRO_USD_MONTHLY=price_XXXXXXXX
STRIPE_PRICE_PRO_USD_ANNUAL=price_XXXXXXXX
STRIPE_PRICE_PRO_CNY_MONTHLY=price_XXXXXXXX
STRIPE_PRICE_GROWTH_USD_MONTHLY=price_XXXXXXXX
STRIPE_PRICE_GROWTH_USD_ANNUAL=price_XXXXXXXX
STRIPE_PRICE_GROWTH_CNY_MONTHLY=price_XXXXXXXX

# Public app URL — Stripe Checkout uses this for success/cancel redirects.
PUBLIC_APP_URL=http://localhost:5173
```

- [ ] **Step 3: Commit**

```bash
cd /home/coder/workspaces/menuray
git add backend/supabase/functions/_shared/stripe.ts backend/supabase/.env.example
git -c commit.gpgsign=false commit -m "$(cat <<'EOF'
feat(backend): shared Stripe client + env.example

Lazy Stripe client via npm:stripe@^17 with Deno fetch HTTP client.
priceIdFor()/tierFromPriceId() map between (tier, currency, period)
and Stripe Price IDs sourced from env vars. CNY+annual returns null
(deferred per P-4). .env.example documents the eight required
variables; CNY annual is intentionally absent.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: `create-checkout-session` Edge Function

**Files:**
- Create: `backend/supabase/functions/create-checkout-session/deno.json`
- Create: `backend/supabase/functions/create-checkout-session/index.ts`
- Create: `backend/supabase/functions/create-checkout-session/test.ts`

- [ ] **Step 1: deno.json**

```json
{
  "importMap": "../../import_map.json",
  "tasks": { "test": "deno test --allow-env --allow-net" }
}
```

- [ ] **Step 2: index.ts**

```typescript
import { createAnonClientWithJwt, createServiceRoleClient } from "../_shared/db.ts";
import { stripeClient, priceIdFor } from "../_shared/stripe.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

export async function handleRequest(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  const auth = req.headers.get("Authorization");
  if (!auth || !auth.startsWith("Bearer ")) return jsonResponse({ error: "must_be_signed_in" }, 401);
  const jwt = auth.slice("Bearer ".length);

  let body: { tier?: string; currency?: string; period?: string };
  try { body = await req.json(); } catch { return jsonResponse({ error: "invalid_json_body" }, 400); }
  const tier = body.tier;
  const currency = body.currency;
  const period = body.period;
  if (tier !== "pro" && tier !== "growth") return jsonResponse({ error: "invalid_tier" }, 400);
  if (currency !== "USD" && currency !== "CNY") return jsonResponse({ error: "invalid_currency" }, 400);
  if (period !== "monthly" && period !== "annual") return jsonResponse({ error: "invalid_period" }, 400);

  const priceId = priceIdFor(tier, currency, period);
  if (!priceId) return jsonResponse({ error: "unsupported_combo" }, 400);

  // Resolve user.id from the JWT.
  const anonDb = createAnonClientWithJwt(jwt);
  const { data: userResp, error: userErr } = await anonDb.auth.getUser();
  if (userErr || !userResp.user) return jsonResponse({ error: "must_be_signed_in" }, 401);
  const userId = userResp.user.id;

  // Fetch existing customer_id (or null).
  const adminDb = createServiceRoleClient();
  const { data: subRow } = await adminDb
    .from("subscriptions").select("stripe_customer_id")
    .eq("owner_user_id", userId).maybeSingle();
  let customerId = subRow?.stripe_customer_id ?? null;

  const stripe = stripeClient();
  if (!customerId) {
    const customer = await stripe.customers.create({ metadata: { owner_user_id: userId } });
    customerId = customer.id;
    await adminDb.from("subscriptions")
      .update({ stripe_customer_id: customerId })
      .eq("owner_user_id", userId);
  }

  const appUrl = Deno.env.get("PUBLIC_APP_URL") ?? "http://localhost:5173";
  const session = await stripe.checkout.sessions.create({
    mode: "subscription",
    customer: customerId,
    line_items: [{ price: priceId, quantity: 1 }],
    payment_method_types: currency === "CNY"
      ? ["card", "wechat_pay", "alipay"]
      : ["card"],
    success_url: `${appUrl}/upgrade?status=success`,
    cancel_url: `${appUrl}/upgrade?status=cancel`,
    metadata: { owner_user_id: userId, tier, currency, period },
  });

  return jsonResponse({ url: session.url });
}

Deno.serve(handleRequest);
```

- [ ] **Step 3: test.ts**

```typescript
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

// Set env BEFORE importing index (which inits Stripe lazily but priceIdFor
// reads env on every call so order isn't strict, but be safe).
Deno.env.set("SUPABASE_URL", "http://stub");
Deno.env.set("SUPABASE_ANON_KEY", "anon-key");
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "service-role-key");
Deno.env.set("STRIPE_SECRET_KEY", "sk_test_dummy");
Deno.env.set("STRIPE_PRICE_PRO_USD_MONTHLY", "price_pro_usd_monthly");
Deno.env.set("STRIPE_PRICE_PRO_CNY_MONTHLY", "price_pro_cny_monthly");
Deno.env.set("PUBLIC_APP_URL", "http://app");

const { handleRequest } = await import("./index.ts");

function withStubbedFetch(
  responder: (url: string, init?: RequestInit) => Response | Promise<Response>,
) {
  const original = globalThis.fetch;
  globalThis.fetch = ((input, init) => {
    const url = typeof input === "string" ? input : input.toString();
    return Promise.resolve(responder(url, init));
  }) as typeof fetch;
  return () => { globalThis.fetch = original; };
}

function makeReq(body: unknown, bearer = "user-jwt"): Request {
  return new Request("http://stub/create-checkout-session", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${bearer}` },
    body: JSON.stringify(body),
  });
}

Deno.test("400 on invalid tier", async () => {
  const restore = withStubbedFetch(() => new Response("{}", { status: 200 }));
  try {
    const res = await handleRequest(makeReq({ tier: "diamond", currency: "USD", period: "monthly" }));
    assertEquals(res.status, 400);
    assertEquals((await res.json()).error, "invalid_tier");
  } finally { restore(); }
});

Deno.test("400 on CNY+annual", async () => {
  const restore = withStubbedFetch(() => new Response("{}", { status: 200 }));
  try {
    const res = await handleRequest(makeReq({ tier: "pro", currency: "CNY", period: "annual" }));
    assertEquals(res.status, 400);
    assertEquals((await res.json()).error, "unsupported_combo");
  } finally { restore(); }
});

Deno.test("401 missing auth", async () => {
  const restore = withStubbedFetch(() => new Response("{}", { status: 200 }));
  try {
    const req = new Request("http://stub/create-checkout-session", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ tier: "pro", currency: "USD", period: "monthly" }),
    });
    const res = await handleRequest(req);
    assertEquals(res.status, 401);
  } finally { restore(); }
});

Deno.test("200 happy path returns session URL", async () => {
  const calls: Array<{ url: string; method: string }> = [];
  const restore = withStubbedFetch((url, init) => {
    calls.push({ url, method: init?.method ?? "GET" });
    // 1) Auth user lookup
    if (url.includes("/auth/v1/user")) {
      return new Response(JSON.stringify({ id: "user-1", email: "u@x" }), {
        status: 200, headers: { "Content-Type": "application/json" },
      });
    }
    // 2) PostgREST select on subscriptions (returns existing customer)
    if (url.includes("/rest/v1/subscriptions") && (init?.method === "GET" || !init?.method)) {
      return new Response(JSON.stringify([{ stripe_customer_id: "cus_existing" }]), {
        status: 200, headers: { "Content-Type": "application/json" },
      });
    }
    // 3) Stripe Checkout sessions create
    if (url.includes("checkout/sessions")) {
      return new Response(JSON.stringify({
        id: "cs_test_1", url: "https://checkout.stripe.com/c/cs_test_1",
      }), { status: 200, headers: { "Content-Type": "application/json" } });
    }
    return new Response("{}", { status: 200 });
  });
  try {
    const res = await handleRequest(makeReq({ tier: "pro", currency: "USD", period: "monthly" }));
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.url, "https://checkout.stripe.com/c/cs_test_1");
  } finally { restore(); }
});
```

- [ ] **Step 4: Run tests**

```bash
cd /home/coder/workspaces/menuray/backend/supabase/functions/create-checkout-session
deno test --allow-env --allow-net
```

Expected: 4/4 passed.

- [ ] **Step 5: Commit**

```bash
cd /home/coder/workspaces/menuray
git add backend/supabase/functions/create-checkout-session/
git -c commit.gpgsign=false commit -m "$(cat <<'EOF'
feat(backend): create-checkout-session Edge Function

POST { tier, currency, period } → returns Stripe Checkout URL.
Resolves the user's existing stripe_customer_id (or creates one via
Stripe.customers.create), picks the price ID via env vars, builds a
Checkout Session with payment_method_types tailored to currency
(card+WeChat+Alipay for CNY; card for USD), persists metadata for the
webhook to read. 4 Deno tests with stubbed fetch cover invalid combos
+ happy path.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: `create-portal-session` Edge Function

**Files:**
- Create: `backend/supabase/functions/create-portal-session/{deno.json,index.ts,test.ts}`

- [ ] **Step 1: deno.json**

```json
{
  "importMap": "../../import_map.json",
  "tasks": { "test": "deno test --allow-env --allow-net" }
}
```

- [ ] **Step 2: index.ts**

```typescript
import { createAnonClientWithJwt, createServiceRoleClient } from "../_shared/db.ts";
import { stripeClient } from "../_shared/stripe.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

export async function handleRequest(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  const auth = req.headers.get("Authorization");
  if (!auth || !auth.startsWith("Bearer ")) return jsonResponse({ error: "must_be_signed_in" }, 401);
  const jwt = auth.slice("Bearer ".length);

  const anonDb = createAnonClientWithJwt(jwt);
  const { data: userResp, error: userErr } = await anonDb.auth.getUser();
  if (userErr || !userResp.user) return jsonResponse({ error: "must_be_signed_in" }, 401);

  const adminDb = createServiceRoleClient();
  const { data: subRow } = await adminDb
    .from("subscriptions").select("stripe_customer_id")
    .eq("owner_user_id", userResp.user.id).maybeSingle();
  if (!subRow?.stripe_customer_id) return jsonResponse({ error: "no_customer" }, 404);

  const appUrl = Deno.env.get("PUBLIC_APP_URL") ?? "http://localhost:5173";
  const session = await stripeClient().billingPortal.sessions.create({
    customer: subRow.stripe_customer_id,
    return_url: `${appUrl}/upgrade`,
  });
  return jsonResponse({ url: session.url });
}

Deno.serve(handleRequest);
```

- [ ] **Step 3: test.ts**

```typescript
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.env.set("SUPABASE_URL", "http://stub");
Deno.env.set("SUPABASE_ANON_KEY", "anon-key");
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "service-role-key");
Deno.env.set("STRIPE_SECRET_KEY", "sk_test_dummy");
Deno.env.set("PUBLIC_APP_URL", "http://app");

const { handleRequest } = await import("./index.ts");

function withStubbedFetch(
  responder: (url: string, init?: RequestInit) => Response | Promise<Response>,
) {
  const original = globalThis.fetch;
  globalThis.fetch = ((input, init) => {
    const url = typeof input === "string" ? input : input.toString();
    return Promise.resolve(responder(url, init));
  }) as typeof fetch;
  return () => { globalThis.fetch = original; };
}

function makeReq(): Request {
  return new Request("http://stub/create-portal-session", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: "Bearer user-jwt" },
    body: "{}",
  });
}

Deno.test("404 when user has no customer_id", async () => {
  const restore = withStubbedFetch((url) => {
    if (url.includes("/auth/v1/user")) {
      return new Response(JSON.stringify({ id: "u1" }), { status: 200 });
    }
    if (url.includes("/rest/v1/subscriptions")) {
      return new Response(JSON.stringify([{ stripe_customer_id: null }]), { status: 200 });
    }
    return new Response("{}", { status: 200 });
  });
  try {
    const res = await handleRequest(makeReq());
    assertEquals(res.status, 404);
    assertEquals((await res.json()).error, "no_customer");
  } finally { restore(); }
});

Deno.test("200 happy path returns portal URL", async () => {
  const restore = withStubbedFetch((url) => {
    if (url.includes("/auth/v1/user")) {
      return new Response(JSON.stringify({ id: "u1" }), { status: 200 });
    }
    if (url.includes("/rest/v1/subscriptions")) {
      return new Response(JSON.stringify([{ stripe_customer_id: "cus_1" }]), { status: 200 });
    }
    if (url.includes("billing_portal/sessions")) {
      return new Response(JSON.stringify({ url: "https://billing.stripe.com/p/session_1" }), { status: 200 });
    }
    return new Response("{}", { status: 200 });
  });
  try {
    const res = await handleRequest(makeReq());
    assertEquals(res.status, 200);
    assertEquals((await res.json()).url, "https://billing.stripe.com/p/session_1");
  } finally { restore(); }
});

Deno.test("401 missing auth", async () => {
  const restore = withStubbedFetch(() => new Response("{}", { status: 200 }));
  try {
    const req = new Request("http://stub/create-portal-session", {
      method: "POST", headers: { "Content-Type": "application/json" }, body: "{}",
    });
    const res = await handleRequest(req);
    assertEquals(res.status, 401);
  } finally { restore(); }
});
```

- [ ] **Step 4: Run + commit**

```bash
cd /home/coder/workspaces/menuray/backend/supabase/functions/create-portal-session
deno test --allow-env --allow-net
cd /home/coder/workspaces/menuray
git add backend/supabase/functions/create-portal-session/
git -c commit.gpgsign=false commit -m "$(cat <<'EOF'
feat(backend): create-portal-session Edge Function

POST → Stripe Customer Portal URL for the signed-in user. 404 when
the user has no stripe_customer_id (still on free). 3 Deno tests.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: `handle-stripe-webhook` Edge Function

**Files:**
- Create: `backend/supabase/functions/handle-stripe-webhook/{deno.json,index.ts,test.ts}`

- [ ] **Step 1: deno.json**

```json
{
  "importMap": "../../import_map.json",
  "tasks": { "test": "deno test --allow-env --allow-net" }
}
```

- [ ] **Step 2: index.ts**

```typescript
import { createServiceRoleClient } from "../_shared/db.ts";
import { stripeClient, tierFromPriceId } from "../_shared/stripe.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "stripe-signature, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

export async function handleRequest(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  const sig = req.headers.get("stripe-signature");
  const secret = Deno.env.get("STRIPE_WEBHOOK_SECRET");
  if (!sig || !secret) return jsonResponse({ error: "missing_signature" }, 400);

  const rawBody = await req.text();
  const stripe = stripeClient();
  let event;
  try {
    // Use the async variant — Deno's WebCrypto-compatible signature verifier.
    event = await stripe.webhooks.constructEventAsync(rawBody, sig, secret);
  } catch (e) {
    console.error("webhook signature failed", (e as Error).message);
    return jsonResponse({ error: "signature_failed" }, 400);
  }

  const adminDb = createServiceRoleClient();

  // Idempotency: try to record the event_id; if it already exists, no-op.
  const { error: insertErr } = await adminDb.from("stripe_events_seen")
    .insert({ event_id: event.id, event_type: event.type });
  if (insertErr) {
    // Postgres unique_violation = 23505. Treat as already-processed.
    if ((insertErr as { code?: string }).code === "23505") {
      return jsonResponse({ ok: true, replay: true });
    }
    console.error("stripe_events_seen insert failed", insertErr);
    return jsonResponse({ error: "internal_error" }, 500);
  }

  switch (event.type) {
    case "checkout.session.completed": {
      const session = event.data.object as {
        metadata?: { owner_user_id?: string; tier?: string; currency?: string; period?: string };
        customer: string;
        subscription: string;
      };
      const ownerUserId = session.metadata?.owner_user_id;
      const tier = session.metadata?.tier as "pro" | "growth" | undefined;
      const currency = session.metadata?.currency as "USD" | "CNY" | undefined;
      const period = session.metadata?.period as "monthly" | "annual" | undefined;
      if (!ownerUserId || !tier) {
        console.warn("checkout.session.completed missing metadata", session);
        break;
      }
      const sub = await stripe.subscriptions.retrieve(session.subscription);
      await adminDb.from("subscriptions").update({
        tier,
        stripe_customer_id: session.customer,
        stripe_subscription_id: sub.id,
        current_period_end: new Date(sub.current_period_end * 1000).toISOString(),
        billing_currency: currency,
        period,
      }).eq("owner_user_id", ownerUserId);

      // Fan out tier to every store this user owns.
      const { data: ownedRows } = await adminDb
        .from("store_members").select("store_id")
        .eq("user_id", ownerUserId).eq("role", "owner")
        .not("accepted_at", "is", null);
      const storeIds = (ownedRows ?? []).map((r) => r.store_id as string);
      if (storeIds.length > 0) {
        await adminDb.from("stores").update({ tier }).in("id", storeIds);
      }

      // Auto-create organization on Growth upgrade if absent.
      if (tier === "growth" && storeIds.length > 0) {
        // Re-read stores.org_id to see if any already linked.
        const { data: storeRows } = await adminDb
          .from("stores").select("id, org_id").in("id", storeIds);
        const existingOrgIds = (storeRows ?? [])
          .map((s) => s.org_id as string | null).filter(Boolean) as string[];
        let orgId: string;
        if (existingOrgIds.length > 0) {
          orgId = existingOrgIds[0];
        } else {
          const { data: newOrg } = await adminDb.from("organizations")
            .insert({ name: "Default organization", created_by: ownerUserId })
            .select("id").single();
          orgId = newOrg!.id as string;
        }
        await adminDb.from("stores").update({ org_id: orgId }).in("id", storeIds);
      }
      break;
    }
    case "customer.subscription.updated": {
      const sub = event.data.object as {
        id: string; customer: string;
        current_period_end: number;
        items: { data: Array<{ price: { id: string } }> };
      };
      const newTier = tierFromPriceId(sub.items.data[0].price.id);
      const { data: subRow } = await adminDb
        .from("subscriptions").select("owner_user_id")
        .eq("stripe_subscription_id", sub.id).maybeSingle();
      if (!subRow) break;
      const ownerUserId = subRow.owner_user_id as string;
      await adminDb.from("subscriptions").update({
        tier: newTier,
        current_period_end: new Date(sub.current_period_end * 1000).toISOString(),
      }).eq("owner_user_id", ownerUserId);
      const { data: ownedRows } = await adminDb
        .from("store_members").select("store_id")
        .eq("user_id", ownerUserId).eq("role", "owner")
        .not("accepted_at", "is", null);
      const storeIds = (ownedRows ?? []).map((r) => r.store_id as string);
      if (storeIds.length > 0) {
        await adminDb.from("stores").update({ tier: newTier }).in("id", storeIds);
      }
      break;
    }
    case "customer.subscription.deleted": {
      const sub = event.data.object as { id: string };
      const { data: subRow } = await adminDb
        .from("subscriptions").select("owner_user_id")
        .eq("stripe_subscription_id", sub.id).maybeSingle();
      if (!subRow) break;
      const ownerUserId = subRow.owner_user_id as string;
      await adminDb.from("subscriptions").update({
        tier: "free",
        stripe_subscription_id: null,
        current_period_end: null,
        billing_currency: null,
        period: null,
      }).eq("owner_user_id", ownerUserId);
      const { data: ownedRows } = await adminDb
        .from("store_members").select("store_id")
        .eq("user_id", ownerUserId).eq("role", "owner")
        .not("accepted_at", "is", null);
      const storeIds = (ownedRows ?? []).map((r) => r.store_id as string);
      if (storeIds.length > 0) {
        await adminDb.from("stores").update({ tier: "free" }).in("id", storeIds);
      }
      break;
    }
    case "invoice.payment_failed":
      // Stripe retries automatically. Don't downgrade on first failure.
      console.log("invoice.payment_failed observed", event.id);
      break;
    default:
      // Other event types: no-op acknowledge.
      break;
  }

  return jsonResponse({ ok: true });
}

Deno.serve(handleRequest);
```

- [ ] **Step 3: test.ts**

```typescript
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.env.set("SUPABASE_URL", "http://stub");
Deno.env.set("SUPABASE_ANON_KEY", "anon-key");
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "service-role-key");
Deno.env.set("STRIPE_SECRET_KEY", "sk_test_dummy");
Deno.env.set("STRIPE_WEBHOOK_SECRET", "whsec_dummy");
Deno.env.set("STRIPE_PRICE_PRO_USD_MONTHLY", "price_pro_usd_monthly");

// We need to monkey-patch stripe.webhooks.constructEventAsync because verifying
// real signatures in tests is overkill. Done via stubbing the npm module:
//   import Stripe from "npm:stripe@^17";
//   const stripe = stripeClient();
// We can patch the Stripe instance after first construction.

const { handleRequest } = await import("./index.ts");
const { stripeClient } = await import("../_shared/stripe.ts");

// Force the lazy stripe singleton + override webhooks.
const stripe = stripeClient();
type ConstructedEvent = {
  id: string; type: string; data: { object: unknown };
};
let stubbedEvent: ConstructedEvent | null = null;
let signatureValid = true;
// deno-lint-ignore no-explicit-any
(stripe.webhooks as any).constructEventAsync = async (
  _body: string, _sig: string, _secret: string,
) => {
  if (!signatureValid) throw new Error("bad sig");
  return stubbedEvent;
};
// deno-lint-ignore no-explicit-any
(stripe.subscriptions as any).retrieve = async (_id: string) => ({
  id: _id, current_period_end: 1900000000,
});

function withStubbedFetch(
  responder: (url: string, init?: RequestInit) => Response | Promise<Response>,
) {
  const original = globalThis.fetch;
  globalThis.fetch = ((input, init) => {
    const url = typeof input === "string" ? input : input.toString();
    return Promise.resolve(responder(url, init));
  }) as typeof fetch;
  return () => { globalThis.fetch = original; };
}
function makeReq(body = "{}"): Request {
  return new Request("http://stub/handle-stripe-webhook", {
    method: "POST",
    headers: { "Content-Type": "application/json", "stripe-signature": "t=0,v1=stub" },
    body,
  });
}

Deno.test("400 when signature header missing", async () => {
  const req = new Request("http://stub/handle-stripe-webhook", {
    method: "POST", body: "{}",
  });
  const res = await handleRequest(req);
  assertEquals(res.status, 400);
});

Deno.test("400 on bad signature", async () => {
  signatureValid = false;
  const restore = withStubbedFetch(() => new Response("{}", { status: 200 }));
  try {
    const res = await handleRequest(makeReq());
    assertEquals(res.status, 400);
    assertEquals((await res.json()).error, "signature_failed");
  } finally { restore(); signatureValid = true; }
});

Deno.test("checkout.session.completed flips tier + writes stores", async () => {
  stubbedEvent = {
    id: "evt_1", type: "checkout.session.completed",
    data: { object: {
      metadata: { owner_user_id: "u-1", tier: "pro", currency: "USD", period: "monthly" },
      customer: "cus_1", subscription: "sub_1",
    } },
  };
  const writes: Array<{ url: string; method?: string; body?: string }> = [];
  const restore = withStubbedFetch((url, init) => {
    writes.push({ url, method: init?.method, body: init?.body as string | undefined });
    if (url.includes("stripe_events_seen")) {
      return new Response(JSON.stringify([{ event_id: "evt_1" }]), { status: 201 });
    }
    if (url.includes("subscriptions") && init?.method === "PATCH") {
      return new Response("[]", { status: 200 });
    }
    if (url.includes("store_members") && (init?.method === "GET" || !init?.method)) {
      return new Response(JSON.stringify([{ store_id: "s-1" }, { store_id: "s-2" }]), { status: 200 });
    }
    if (url.includes("/rest/v1/stores") && init?.method === "PATCH") {
      return new Response("[]", { status: 200 });
    }
    return new Response("[]", { status: 200 });
  });
  try {
    const res = await handleRequest(makeReq());
    assertEquals(res.status, 200);
    assertEquals((await res.json()).ok, true);
    // We expect at least one PATCH to subscriptions and one PATCH to stores.
    const subPatches = writes.filter((w) => w.url.includes("subscriptions") && w.method === "PATCH");
    const storePatches = writes.filter((w) => w.url.includes("/rest/v1/stores") && w.method === "PATCH");
    assertEquals(subPatches.length >= 1, true);
    assertEquals(storePatches.length >= 1, true);
  } finally { restore(); }
});

Deno.test("replay is no-op", async () => {
  stubbedEvent = {
    id: "evt_replay", type: "checkout.session.completed",
    data: { object: { metadata: {}, customer: "c", subscription: "s" } },
  };
  const restore = withStubbedFetch((url) => {
    if (url.includes("stripe_events_seen")) {
      return new Response(JSON.stringify({ code: "23505", message: "duplicate" }), { status: 409 });
    }
    return new Response("[]", { status: 200 });
  });
  try {
    const res = await handleRequest(makeReq());
    assertEquals(res.status, 200);
    assertEquals((await res.json()).replay, true);
  } finally { restore(); }
});

Deno.test("unknown event type returns 200 ack", async () => {
  stubbedEvent = { id: "evt_unknown", type: "ping.pong", data: { object: {} } };
  const restore = withStubbedFetch(() => new Response("[]", { status: 201 }));
  try {
    const res = await handleRequest(makeReq());
    assertEquals(res.status, 200);
  } finally { restore(); }
});
```

- [ ] **Step 4: Run + commit**

```bash
cd /home/coder/workspaces/menuray/backend/supabase/functions/handle-stripe-webhook
deno test --allow-env --allow-net
cd /home/coder/workspaces/menuray
git add backend/supabase/functions/handle-stripe-webhook/
git -c commit.gpgsign=false commit -m "$(cat <<'EOF'
feat(backend): handle-stripe-webhook Edge Function

Verifies HMAC via stripe.webhooks.constructEventAsync (Deno-friendly),
deduplicates by event_id in stripe_events_seen, then handles three
event types: checkout.session.completed flips tier + persists Stripe
ids + fans out tier across owned stores + auto-creates an organization
on growth upgrade; customer.subscription.updated re-derives tier from
the price ID (in case plan switched); customer.subscription.deleted
flips back to free. invoice.payment_failed logged + ignored. Other
event types ack 200 no-op. 5 Deno tests with stubbed fetch + monkey-
patched signature verifier.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: `create-store` Edge Function

**Files:**
- Create: `backend/supabase/functions/create-store/{deno.json,index.ts,test.ts}`

- [ ] **Step 1: deno.json**

```json
{
  "importMap": "../../import_map.json",
  "tasks": { "test": "deno test --allow-env --allow-net" }
}
```

- [ ] **Step 2: index.ts**

```typescript
import { createAnonClientWithJwt, createServiceRoleClient } from "../_shared/db.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

export async function handleRequest(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  const auth = req.headers.get("Authorization");
  if (!auth || !auth.startsWith("Bearer ")) return jsonResponse({ error: "must_be_signed_in" }, 401);
  const jwt = auth.slice("Bearer ".length);

  let body: { name?: string; currency?: string; source_locale?: string };
  try { body = await req.json(); } catch { return jsonResponse({ error: "invalid_json_body" }, 400); }
  const name = (body.name ?? "").trim();
  if (!name) return jsonResponse({ error: "name_required" }, 400);

  const anonDb = createAnonClientWithJwt(jwt);
  const { data: userResp, error: userErr } = await anonDb.auth.getUser();
  if (userErr || !userResp.user) return jsonResponse({ error: "must_be_signed_in" }, 401);
  const userId = userResp.user.id;

  const adminDb = createServiceRoleClient();
  const { data: subRow } = await adminDb
    .from("subscriptions").select("tier")
    .eq("owner_user_id", userId).maybeSingle();
  if (subRow?.tier !== "growth") {
    return jsonResponse({ error: "multi_store_requires_growth" }, 403);
  }

  // Find an existing organization for this user (an owned store with a non-null org_id).
  const { data: ownedRows } = await adminDb
    .from("store_members").select("store_id")
    .eq("user_id", userId).eq("role", "owner")
    .not("accepted_at", "is", null);
  const ownedIds = (ownedRows ?? []).map((r) => r.store_id as string);
  let orgId: string | null = null;
  if (ownedIds.length > 0) {
    const { data: storeRows } = await adminDb
      .from("stores").select("org_id").in("id", ownedIds);
    orgId = (storeRows ?? []).map((s) => s.org_id as string | null).find(Boolean) ?? null;
  }
  if (!orgId) {
    const { data: newOrg } = await adminDb.from("organizations")
      .insert({ name: "Default organization", created_by: userId })
      .select("id").single();
    orgId = newOrg!.id as string;
    if (ownedIds.length > 0) {
      await adminDb.from("stores").update({ org_id: orgId }).in("id", ownedIds);
    }
  }

  const { data: created, error: createErr } = await adminDb.from("stores").insert({
    name,
    currency: body.currency ?? "USD",
    source_locale: body.source_locale ?? "en",
    tier: "growth",
    org_id: orgId,
  }).select("id").single();
  if (createErr || !created) {
    console.error("store create failed", createErr);
    return jsonResponse({ error: "internal_error" }, 500);
  }
  const storeId = created.id as string;

  await adminDb.from("store_members").insert({
    store_id: storeId, user_id: userId, role: "owner", accepted_at: new Date().toISOString(),
  });

  return jsonResponse({ storeId });
}

Deno.serve(handleRequest);
```

- [ ] **Step 3: test.ts**

```typescript
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.env.set("SUPABASE_URL", "http://stub");
Deno.env.set("SUPABASE_ANON_KEY", "anon-key");
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "service-role-key");

const { handleRequest } = await import("./index.ts");

function withStubbedFetch(
  responder: (url: string, init?: RequestInit) => Response | Promise<Response>,
) {
  const original = globalThis.fetch;
  globalThis.fetch = ((input, init) => {
    const url = typeof input === "string" ? input : input.toString();
    return Promise.resolve(responder(url, init));
  }) as typeof fetch;
  return () => { globalThis.fetch = original; };
}
function makeReq(body: unknown, bearer = "user-jwt"): Request {
  return new Request("http://stub/create-store", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${bearer}` },
    body: JSON.stringify(body),
  });
}

Deno.test("400 when name missing", async () => {
  const restore = withStubbedFetch(() => new Response("{}", { status: 200 }));
  try {
    const res = await handleRequest(makeReq({}));
    assertEquals(res.status, 400);
    assertEquals((await res.json()).error, "name_required");
  } finally { restore(); }
});

Deno.test("403 when user is not on growth tier", async () => {
  const restore = withStubbedFetch((url) => {
    if (url.includes("/auth/v1/user")) {
      return new Response(JSON.stringify({ id: "u1" }), { status: 200 });
    }
    if (url.includes("/rest/v1/subscriptions")) {
      return new Response(JSON.stringify([{ tier: "pro" }]), { status: 200 });
    }
    return new Response("{}", { status: 200 });
  });
  try {
    const res = await handleRequest(makeReq({ name: "New shop" }));
    assertEquals(res.status, 403);
    assertEquals((await res.json()).error, "multi_store_requires_growth");
  } finally { restore(); }
});

Deno.test("200 happy path returns storeId", async () => {
  let storeIdReturned = false;
  const restore = withStubbedFetch((url, init) => {
    if (url.includes("/auth/v1/user")) {
      return new Response(JSON.stringify({ id: "u1" }), { status: 200 });
    }
    if (url.includes("/rest/v1/subscriptions")) {
      return new Response(JSON.stringify([{ tier: "growth" }]), { status: 200 });
    }
    if (url.includes("/rest/v1/store_members") && (init?.method === "GET" || !init?.method)) {
      return new Response(JSON.stringify([{ store_id: "existing-1" }]), { status: 200 });
    }
    if (url.includes("/rest/v1/stores") && (init?.method === "GET" || !init?.method)) {
      return new Response(JSON.stringify([{ org_id: "org-1" }]), { status: 200 });
    }
    if (url.includes("/rest/v1/stores") && init?.method === "POST") {
      storeIdReturned = true;
      return new Response(JSON.stringify([{ id: "new-store-1" }]), {
        status: 201, headers: { "Content-Type": "application/json" },
      });
    }
    if (url.includes("/rest/v1/store_members") && init?.method === "POST") {
      return new Response("[]", { status: 201 });
    }
    return new Response("[]", { status: 200 });
  });
  try {
    const res = await handleRequest(makeReq({ name: "Second shop" }));
    assertEquals(res.status, 200);
    assertEquals((await res.json()).storeId, "new-store-1");
    assertEquals(storeIdReturned, true);
  } finally { restore(); }
});

Deno.test("401 missing auth", async () => {
  const restore = withStubbedFetch(() => new Response("{}", { status: 200 }));
  try {
    const req = new Request("http://stub/create-store", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: "x" }),
    });
    const res = await handleRequest(req);
    assertEquals(res.status, 401);
  } finally { restore(); }
});
```

- [ ] **Step 4: Run + commit**

```bash
cd /home/coder/workspaces/menuray/backend/supabase/functions/create-store
deno test --allow-env --allow-net
cd /home/coder/workspaces/menuray
git add backend/supabase/functions/create-store/
git -c commit.gpgsign=false commit -m "$(cat <<'EOF'
feat(backend): create-store Edge Function

POST { name, currency?, source_locale? } → returns { storeId }.
Gated to tier='growth' (403 otherwise). Resolves or auto-creates the
caller's organizations row, links new store to it, and inserts an
owner store_members row. 4 Deno tests cover validation, tier gate,
happy path with auto-org-link, and missing auth.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: `parse-menu` quota gate

**Files:**
- Modify: `backend/supabase/functions/parse-menu/index.ts`

- [ ] **Step 1: Read the file in full**

```bash
cat /home/coder/workspaces/menuray/backend/supabase/functions/parse-menu/index.ts
```

Locate the section after the run-ownership check (around line 44–55) and before `const finalStatus = await runParse(runId)`.

- [ ] **Step 2: Insert the quota gate**

Add a service-role client + the gate. Update imports at top:

```typescript
import { createAnonClientWithJwt, createServiceRoleClient } from "../_shared/db.ts";
```

After the existing `if (!row) return jsonResponse({ error: "run_not_found_or_forbidden" }, 404);` line, BEFORE `const finalStatus = await runParse(runId);`, insert:

```typescript
  // Re-parse quota gate (initial parse with menu_id IS NULL is uncapped — it's
  // bounded by the menu count cap instead).
  const adminDb = createServiceRoleClient();
  const { data: runDetail } = await adminDb
    .from("parse_runs").select("menu_id, store_id")
    .eq("id", runId).maybeSingle();
  if (runDetail?.menu_id) {
    const monthStart = new Date();
    monthStart.setUTCDate(1);
    monthStart.setUTCHours(0, 0, 0, 0);
    const { count } = await adminDb
      .from("parse_runs")
      .select("id", { count: "exact", head: true })
      .eq("menu_id", runDetail.menu_id)
      .gte("created_at", monthStart.toISOString());
    const { data: storeRow } = await adminDb
      .from("stores").select("tier")
      .eq("id", runDetail.store_id).single();
    const tier = (storeRow?.tier ?? "free") as "free" | "pro" | "growth";
    const cap = ({ free: 1, pro: 5, growth: 50 } as const)[tier];
    if ((count ?? 0) >= cap) {
      return jsonResponse({
        error: "reparse_quota_exceeded", tier, cap,
      }, 402);
    }
  }
```

- [ ] **Step 3: Existing tests still pass**

```bash
cd /home/coder/workspaces/menuray/backend/supabase/functions/parse-menu
deno test --allow-env --allow-net
```

If `parse-menu/test.ts` exists, run it. If existing tests cover only the orchestrator (which hasn't changed), they should still pass. If a test exercises the full handleRequest and expects the old behavior, update its stub to return `{ menu_id: null, store_id: 's' }` for the new `runDetail` lookup so the quota gate is bypassed (initial parse).

If tests stay green, proceed. If any test fails specifically because of the new quota path, add a fixture branch in the test's stubbedFetch:

```typescript
if (url.includes("parse_runs") && url.includes("menu_id")) {
  return new Response(JSON.stringify([{ menu_id: null, store_id: "s" }]), { status: 200 });
}
```

- [ ] **Step 4: Commit**

```bash
cd /home/coder/workspaces/menuray
git add backend/supabase/functions/parse-menu/
git -c commit.gpgsign=false commit -m "$(cat <<'EOF'
feat(backend): parse-menu re-parse quota gate

After the existing RLS ownership check and before invoking the
orchestrator, look up the run's menu_id; if non-null (re-parse),
count this calendar month's parse_runs for that menu and reject with
402 + { error: 'reparse_quota_exceeded', tier, cap } when at cap.
Initial parses (menu_id IS NULL) are uncapped — they're bounded by
the menu count cap instead.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: SvelteKit customer paywall + badge gate

**Files:**
- Modify: `frontend/customer/src/lib/types/menu.ts`
- Modify: `frontend/customer/src/lib/data/fetchPublishedMenu.ts`
- Modify: `frontend/customer/src/routes/[slug]/+page.server.ts`
- Modify: `frontend/customer/src/routes/+layout.svelte`
- Modify: `frontend/customer/src/routes/+error.svelte`
- Modify: `frontend/customer/src/lib/i18n/strings.ts`

- [ ] **Step 1: Extend Store type**

Edit `frontend/customer/src/lib/types/menu.ts`. Find the `Store` interface and add 2 fields:

```typescript
export interface Store {
  id: string;
  logoUrl: string | null;
  sourceName: string;
  sourceAddress: string | null;
  translations: Record<Locale, { name: string; address: string | null }>;
  customBrandingOff: boolean;
  tier: 'free' | 'pro' | 'growth';
  qrViewsMonthlyCount: number;
}
```

- [ ] **Step 2: Update the fetch query + mapper**

Edit `frontend/customer/src/lib/data/fetchPublishedMenu.ts`. In `JoinedMenuRow.store`, add the new fields to the type:

```typescript
  store: {
    id: string; logo_url: string | null; name: string; address: string | null;
    source_locale: string;
    tier: 'free' | 'pro' | 'growth';
    qr_views_monthly_count: number;
    store_translations: Array<{ locale: string; name: string; address: string | null }>;
  } | null;
```

Update the `.select(...)` string — add `tier, qr_views_monthly_count` to the inner store join:

```typescript
      store:stores (
        id, logo_url, name, address, source_locale, tier, qr_views_monthly_count,
        store_translations ( locale, name, address )
      ),
```

In `mapRow`, set the two new fields on the returned `store`:

```typescript
  const store: Store = {
    id: row.store!.id,
    logoUrl: row.store!.logo_url,
    sourceName: row.store!.name,
    sourceAddress: row.store!.address,
    translations: Object.fromEntries(
      row.store!.store_translations.map((t) => [t.locale, { name: t.name, address: t.address }]),
    ),
    customBrandingOff: false,
    tier: row.store!.tier,
    qrViewsMonthlyCount: row.store!.qr_views_monthly_count,
  };
```

- [ ] **Step 3: Update SSR loader**

Edit `frontend/customer/src/routes/[slug]/+page.server.ts`:

```typescript
import type { PageServerLoad } from './$types';
import { error } from '@sveltejs/kit';
import { fetchPublishedMenu } from '$lib/data/fetchPublishedMenu';
import { logView } from '$lib/data/logView';
import { resolveLocale } from '$lib/i18n/resolveLocale';
import { buildMenuJsonLd } from '$lib/seo/jsonLd';

const FREE_QR_CAP = 2000;

export const load: PageServerLoad = async ({ locals, params, url, request }) => {
  const menu = await fetchPublishedMenu(locals.supabase, params.slug);
  if (!menu) throw error(404, 'Menu not found');

  if (menu.store.tier === 'free' && menu.store.qrViewsMonthlyCount >= FREE_QR_CAP) {
    throw error(402, 'qr_view_quota_exceeded');
  }

  const locale = resolveLocale({
    urlLang: url.searchParams.get('lang'),
    storedLang: null,
    acceptLanguage: request.headers.get('accept-language'),
    available: menu.availableLocales,
    source: menu.sourceLocale,
  });

  logView(locals.supabase, menu.id, menu.store.id, locale, request.headers, url);

  return {
    menu,
    lang: locale,
    jsonLd: buildMenuJsonLd(menu, locale),
  };
};
```

- [ ] **Step 4: Update +layout.svelte for badge gate**

Edit `frontend/customer/src/routes/+layout.svelte`. Read tier from page data (which is the `menu` shape on `[slug]` routes; root `/` and `/accept-invite` don't have a menu, so default `hidden=false`).

Replace the existing script with:

```svelte
<script lang="ts">
  import '../app.css';
  import MenurayBadge from '$lib/components/MenurayBadge.svelte';
  import type { Snippet } from 'svelte';

  type LayoutData = { lang?: string; menu?: { store?: { tier?: string } } };
  let { children, data }: { children: Snippet; data?: LayoutData } = $props();
  const locale = $derived(data?.lang ?? 'en');
  const badgeHidden = $derived(
    data?.menu?.store?.tier !== undefined &&
    data.menu.store.tier !== 'free'
  );
</script>

<svelte:head>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
  <link
    rel="stylesheet"
    href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Noto+Sans+SC:wght@400;500;600;700&display=swap"
  />
</svelte:head>

{@render children()}

<MenurayBadge {locale} hidden={badgeHidden} />
```

- [ ] **Step 5: Update i18n strings**

Edit `frontend/customer/src/lib/i18n/strings.ts`. Add two new keys to the `StringKey` type and to both `en` and `zh` tables:

```typescript
type StringKey =
  // …existing…
  | 'paywall.qrQuotaTitle'
  | 'paywall.qrQuotaBody';
```

Add to `en`:
```typescript
  'paywall.qrQuotaTitle': 'This menu is over its monthly view quota',
  'paywall.qrQuotaBody':
    'Please come back next month, or ask the restaurant to upgrade their MenuRay plan.',
```

Add to `zh`:
```typescript
  'paywall.qrQuotaTitle': '此菜单本月浏览次数已达上限',
  'paywall.qrQuotaBody': '请下月再来，或请商家升级 MenuRay 套餐。',
```

- [ ] **Step 6: Update +error.svelte**

Edit `frontend/customer/src/routes/+error.svelte`:

```svelte
<script lang="ts">
  import { page } from '$app/state';
  import { t } from '$lib/i18n/strings';
  const locale = 'en';
  const is402 = $derived(page.status === 402);
  const is410 = $derived(page.status === 410);
  const titleKey = $derived(
    is402 ? 'paywall.qrQuotaTitle'
    : is410 ? 'error.gone.title'
    : 'error.notFound.title'
  );
  const bodyKey = $derived(
    is402 ? 'paywall.qrQuotaBody'
    : is410 ? 'error.gone.body'
    : 'error.notFound.body'
  );
</script>

<main class="min-h-dvh flex flex-col items-center justify-center p-8 text-center gap-4">
  <h1 class="text-2xl font-semibold text-ink">{t(locale, titleKey)}</h1>
  <p class="text-secondary max-w-md">{t(locale, bodyKey)}</p>
  <a href="https://menuray.com" class="text-primary underline underline-offset-4">menuray.com</a>
</main>
```

- [ ] **Step 7: Verify**

```bash
cd /home/coder/workspaces/menuray/frontend/customer
pnpm check
pnpm test
```

Expected: `0 errors 0 warnings` + Vitest passes (probably 18 tests).

If the existing `fetchPublishedMenu.test.ts` (or similar Vitest) breaks because the SELECT string changed, update its mocked Supabase response to include `tier: 'free'` and `qr_views_monthly_count: 0` in the store mock. Investigate with the file open before assuming a failure means a fixture update — could also be a real bug.

- [ ] **Step 8: Commit**

```bash
cd /home/coder/workspaces/menuray
git add frontend/customer/
git -c commit.gpgsign=false commit -m "$(cat <<'EOF'
feat(customer): QR-view paywall + tier-gated MenuRay badge

SSR loader joins stores.tier + qr_views_monthly_count, throws 402
when free-tier merchant exceeds 2 000 views/mo. +error.svelte renders
a friendly i18n'd "over quota" page on 402. +layout.svelte hides the
MenuRay badge when tier !== 'free'. Two new i18n strings (en + zh).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Flutter — Tier model + currentTierProvider + Store mapper

**Files:**
- Create: `frontend/merchant/lib/features/billing/tier.dart`
- Create: `frontend/merchant/lib/features/billing/billing_providers.dart`
- Create: `frontend/merchant/test/unit/tier_test.dart`
- Modify: `frontend/merchant/lib/shared/models/store.dart`
- Modify: `frontend/merchant/lib/shared/models/_mappers.dart`
- Modify: `frontend/merchant/test/unit/mappers_test.dart`

- [ ] **Step 1: Tier enum**

File: `frontend/merchant/lib/features/billing/tier.dart`

```dart
enum Tier { free, pro, growth }

extension TierX on Tier {
  bool get isPaid => this == Tier.pro || this == Tier.growth;
  bool get isGrowth => this == Tier.growth;
  String get apiName => name; // 'free' | 'pro' | 'growth'

  static Tier fromString(String? raw) {
    switch (raw) {
      case 'pro':
        return Tier.pro;
      case 'growth':
        return Tier.growth;
      case 'free':
      default:
        return Tier.free;
    }
  }
}
```

- [ ] **Step 2: Add `tier` to Store**

Edit `frontend/merchant/lib/shared/models/store.dart`:

```dart
class Store {
  final String id;
  final String name;
  final String? address;
  final String? logoUrl;
  final int menuCount;
  final int weeklyVisits;
  final bool isCurrent;
  final String tier; // 'free' | 'pro' | 'growth'

  const Store({
    required this.id,
    required this.name,
    this.address,
    this.logoUrl,
    this.menuCount = 0,
    this.weeklyVisits = 0,
    this.isCurrent = false,
    this.tier = 'free',
  });
}
```

- [ ] **Step 3: Update mapper**

Edit `frontend/merchant/lib/shared/models/_mappers.dart`. Update `storeFromSupabase`:

```dart
Store storeFromSupabase(Map<String, dynamic> json) => Store(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      logoUrl: json['logo_url'] as String?,
      menuCount: 0,
      weeklyVisits: 0,
      isCurrent: true,
      tier: (json['tier'] as String?) ?? 'free',
    );
```

- [ ] **Step 4: Billing providers**

File: `frontend/merchant/lib/features/billing/billing_providers.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../home/home_providers.dart';
import 'tier.dart';

final currentTierProvider = FutureProvider<Tier>((ref) async {
  // Reads the active store's denormalised tier column. Throws if no active
  // store (caller should be inside a router-guarded route).
  final store = await ref.watch(currentStoreProvider.future);
  return TierX.fromString(store.tier);
});
```

- [ ] **Step 5: Tier unit test**

File: `frontend/merchant/test/unit/tier_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/billing/tier.dart';

void main() {
  group('TierX.fromString', () {
    test('maps known strings', () {
      expect(TierX.fromString('free'), Tier.free);
      expect(TierX.fromString('pro'), Tier.pro);
      expect(TierX.fromString('growth'), Tier.growth);
    });
    test('falls back to free on null/unknown', () {
      expect(TierX.fromString(null), Tier.free);
      expect(TierX.fromString('something-else'), Tier.free);
    });
  });

  group('TierX.isPaid / isGrowth', () {
    test('isPaid', () {
      expect(Tier.free.isPaid, false);
      expect(Tier.pro.isPaid, true);
      expect(Tier.growth.isPaid, true);
    });
    test('isGrowth', () {
      expect(Tier.free.isGrowth, false);
      expect(Tier.pro.isGrowth, false);
      expect(Tier.growth.isGrowth, true);
    });
  });

  group('TierX.apiName', () {
    test('round-trips', () {
      for (final t in Tier.values) {
        expect(TierX.fromString(t.apiName), t);
      }
    });
  });
}
```

- [ ] **Step 6: Extend mapper test**

Edit `frontend/merchant/test/unit/mappers_test.dart`. Find the existing `storeFromSupabase` test (or add a new one if absent). Add a case asserting `tier`:

```dart
  test('storeFromSupabase reads tier (defaults to free)', () {
    final s = storeFromSupabase({
      'id': 's-1', 'name': 'X', 'address': null, 'logo_url': null,
    });
    expect(s.tier, 'free');
  });

  test('storeFromSupabase preserves explicit pro tier', () {
    final s = storeFromSupabase({
      'id': 's-1', 'name': 'X', 'address': null, 'logo_url': null, 'tier': 'pro',
    });
    expect(s.tier, 'pro');
  });
```

If `mappers_test.dart` doesn't import `_mappers.dart` already, add `import 'package:menuray_merchant/shared/models/_mappers.dart';` at the top.

- [ ] **Step 7: Verify**

```bash
cd /home/coder/workspaces/menuray/frontend/merchant
export PATH="$PATH:/home/coder/flutter/bin"
flutter analyze
flutter test test/unit/tier_test.dart test/unit/mappers_test.dart
```

Expected: analyze clean; new tests pass + existing mapper tests pass.

- [ ] **Step 8: Commit**

```bash
cd /home/coder/workspaces/menuray
git add frontend/merchant/lib/features/billing/ frontend/merchant/lib/shared/models/ frontend/merchant/test/unit/tier_test.dart frontend/merchant/test/unit/mappers_test.dart
git -c commit.gpgsign=false commit -m "$(cat <<'EOF'
feat(billing): Tier enum + currentTierProvider; Store gains tier field

Tier { free, pro, growth } with isPaid / isGrowth / apiName helpers.
storeFromSupabase reads the new stores.tier column (defaults to 'free'
if absent, e.g. older joins). currentTierProvider derives Tier from
the active store. Unit tests cover Tier round-trip + Store mapper
default.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: TierGate widget

**Files:**
- Create: `frontend/merchant/lib/shared/widgets/tier_gate.dart`
- Create: `frontend/merchant/test/widgets/tier_gate_test.dart`

- [ ] **Step 1: Widget**

File: `frontend/merchant/lib/shared/widgets/tier_gate.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/billing/billing_providers.dart';
import '../../features/billing/tier.dart';

/// Hides its child unless the active store's tier is in [allowed].
class TierGate extends ConsumerWidget {
  final Set<Tier> allowed;
  final Widget child;
  final Widget? fallback;
  const TierGate({
    required this.allowed,
    required this.child,
    this.fallback,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tierAsync = ref.watch(currentTierProvider);
    final tier = tierAsync.valueOrNull;
    final show = tier != null && allowed.contains(tier);
    return show ? child : (fallback ?? const SizedBox.shrink());
  }
}
```

- [ ] **Step 2: Widget tests**

File: `frontend/merchant/test/widgets/tier_gate_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/billing/billing_providers.dart';
import 'package:menuray_merchant/features/billing/tier.dart';
import 'package:menuray_merchant/shared/widgets/tier_gate.dart';

Widget _harness({required Tier? tier, required Widget child}) {
  return ProviderScope(
    overrides: [
      currentTierProvider.overrideWith(
        (ref) async => tier ?? Tier.free,
      ),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('shows child when tier is allowed', (tester) async {
    await tester.pumpWidget(_harness(
      tier: Tier.pro,
      child: const TierGate(
        allowed: {Tier.pro, Tier.growth},
        child: Text('paid-feature'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('paid-feature'), findsOneWidget);
  });

  testWidgets('hides child for free tier', (tester) async {
    await tester.pumpWidget(_harness(
      tier: Tier.free,
      child: const TierGate(
        allowed: {Tier.pro, Tier.growth},
        child: Text('paid-feature'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('paid-feature'), findsNothing);
  });

  testWidgets('renders fallback when provided', (tester) async {
    await tester.pumpWidget(_harness(
      tier: Tier.free,
      child: const TierGate(
        allowed: {Tier.pro},
        fallback: Text('upgrade-callout'),
        child: Text('paid-feature'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('paid-feature'), findsNothing);
    expect(find.text('upgrade-callout'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Verify + commit**

```bash
cd /home/coder/workspaces/menuray/frontend/merchant
export PATH="$PATH:/home/coder/flutter/bin"
flutter analyze
flutter test test/widgets/tier_gate_test.dart
cd /home/coder/workspaces/menuray
git add frontend/merchant/lib/shared/widgets/tier_gate.dart frontend/merchant/test/widgets/tier_gate_test.dart
git -c commit.gpgsign=false commit -m "$(cat <<'EOF'
feat(shared): TierGate widget

Hides child unless currentTierProvider's value is in allowed set.
Mirrors the RoleGate pattern from Session 3. 3 widget tests cover
allowed/hidden/fallback paths.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: Flutter i18n — 28 billing/paywall keys

**Files:**
- Modify: `frontend/merchant/lib/l10n/app_en.arb`
- Modify: `frontend/merchant/lib/l10n/app_zh.arb`

- [ ] **Step 1: EN keys**

Open `frontend/merchant/lib/l10n/app_en.arb`. Before the closing `}`, insert (comma after the last existing entry):

```json
  "billingPlanFree": "Free",
  "billingPlanPro": "Pro",
  "billingPlanGrowth": "Growth",
  "billingMenusCap": "{count} menu(s)",
  "@billingMenusCap": { "placeholders": { "count": { "type": "int" } } },
  "billingDishesPerMenuCap": "{count} dishes per menu",
  "@billingDishesPerMenuCap": { "placeholders": { "count": { "type": "int" } } },
  "billingReparsesCap": "{count} AI re-parses / month",
  "@billingReparsesCap": { "placeholders": { "count": { "type": "int" } } },
  "billingQrViewsCap": "{count} QR views / month",
  "@billingQrViewsCap": { "placeholders": { "count": { "type": "int" } } },
  "billingLanguagesCap": "{count} languages",
  "@billingLanguagesCap": { "placeholders": { "count": { "type": "int" } } },
  "billingMultiStore": "Multiple stores",
  "billingCustomBranding": "Remove MenuRay badge",
  "billingPriorityCsv": "CSV export & priority support",
  "billingCurrentTag": "Current",
  "billingMonthlyToggle": "Monthly",
  "billingAnnualToggle": "Annual (~15% off)",
  "billingCurrencyUsd": "USD",
  "billingCurrencyCny": "CNY",
  "billingSubscribePro": "Subscribe to Pro",
  "billingSubscribeGrowth": "Subscribe to Growth",
  "billingManageBilling": "Manage billing",
  "billingUpgradeTitle": "Upgrade subscription",
  "billingCheckoutOpening": "Opening Stripe Checkout…",
  "billingCheckoutFailed": "Couldn't open checkout. Please try again.",
  "paywallMenuCapReached": "You've reached the menu limit for the {tier} plan.",
  "@paywallMenuCapReached": { "placeholders": { "tier": { "type": "String" } } },
  "paywallReparseQuotaReached": "Monthly AI re-parse quota reached.",
  "paywallTranslationCapReached": "Language limit reached for the {tier} plan.",
  "@paywallTranslationCapReached": { "placeholders": { "tier": { "type": "String" } } },
  "paywallCustomThemeLocked": "Custom theme available on Pro+",
  "paywallMultiStoreLocked": "Multi-store available on Growth"
```

- [ ] **Step 2: ZH keys**

Open `frontend/merchant/lib/l10n/app_zh.arb`. Same insertion pattern:

```json
  "billingPlanFree": "免费版",
  "billingPlanPro": "Pro",
  "billingPlanGrowth": "Growth",
  "billingMenusCap": "{count} 个菜单",
  "@billingMenusCap": { "placeholders": { "count": { "type": "int" } } },
  "billingDishesPerMenuCap": "每菜单 {count} 道",
  "@billingDishesPerMenuCap": { "placeholders": { "count": { "type": "int" } } },
  "billingReparsesCap": "每月 {count} 次再解析",
  "@billingReparsesCap": { "placeholders": { "count": { "type": "int" } } },
  "billingQrViewsCap": "每月 {count} 次扫码",
  "@billingQrViewsCap": { "placeholders": { "count": { "type": "int" } } },
  "billingLanguagesCap": "{count} 个语言",
  "@billingLanguagesCap": { "placeholders": { "count": { "type": "int" } } },
  "billingMultiStore": "多门店",
  "billingCustomBranding": "去除 MenuRay 徽标",
  "billingPriorityCsv": "CSV 导出 + 优先支持",
  "billingCurrentTag": "当前",
  "billingMonthlyToggle": "月付",
  "billingAnnualToggle": "年付（约 8.5 折）",
  "billingCurrencyUsd": "美元",
  "billingCurrencyCny": "人民币",
  "billingSubscribePro": "订阅 Pro",
  "billingSubscribeGrowth": "订阅 Growth",
  "billingManageBilling": "管理订阅",
  "billingUpgradeTitle": "升级订阅",
  "billingCheckoutOpening": "正在打开 Stripe…",
  "billingCheckoutFailed": "无法打开支付页，请重试。",
  "paywallMenuCapReached": "已达到 {tier} 套餐菜单上限。",
  "@paywallMenuCapReached": { "placeholders": { "tier": { "type": "String" } } },
  "paywallReparseQuotaReached": "本月 AI 再解析次数已用完。",
  "paywallTranslationCapReached": "{tier} 套餐语言数上限。",
  "@paywallTranslationCapReached": { "placeholders": { "tier": { "type": "String" } } },
  "paywallCustomThemeLocked": "自定义主题需 Pro 以上",
  "paywallMultiStoreLocked": "多门店需 Growth"
```

- [ ] **Step 3: Regenerate + verify**

```bash
cd /home/coder/workspaces/menuray/frontend/merchant
export PATH="$PATH:/home/coder/flutter/bin"
flutter gen-l10n
flutter analyze
```

Expected: clean.

- [ ] **Step 4: Commit**

```bash
cd /home/coder/workspaces/menuray
git add frontend/merchant/lib/l10n/
git -c commit.gpgsign=false commit -m "$(cat <<'EOF'
feat(i18n): 28 billing + paywall keys (en + zh)

Tier names, cap lines, currency/period toggles, subscribe/manage CTAs,
checkout state strings, and 5 paywall messages with {tier}/{count}
placeholders. Regenerated app_localizations_*.dart.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 14: BillingRepository + Upgrade screen + smoke test

**Files:**
- Create: `frontend/merchant/lib/features/billing/billing_repository.dart`
- Create: `frontend/merchant/lib/features/billing/presentation/upgrade_screen.dart`
- Create: `frontend/merchant/test/smoke/upgrade_screen_smoke_test.dart`
- Modify: `frontend/merchant/lib/features/billing/billing_providers.dart` (add repo provider)
- Modify: `frontend/merchant/lib/router/app_router.dart` (add `/upgrade` route)

- [ ] **Step 1: Repository**

File: `frontend/merchant/lib/features/billing/billing_repository.dart`

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import 'tier.dart';

class BillingRepository {
  BillingRepository(this._client);
  final SupabaseClient _client;

  Future<String> createCheckoutSession({
    required Tier tier,
    required String currency, // 'USD' | 'CNY'
    required String period,   // 'monthly' | 'annual'
  }) async {
    final res = await _client.functions.invoke(
      'create-checkout-session',
      body: {'tier': tier.apiName, 'currency': currency, 'period': period},
    );
    final data = res.data;
    if (data is Map && data['url'] is String) return data['url'] as String;
    throw StateError('Checkout session response missing url');
  }

  Future<String> createPortalSession() async {
    final res = await _client.functions.invoke('create-portal-session');
    final data = res.data;
    if (data is Map && data['url'] is String) return data['url'] as String;
    throw StateError('Portal session response missing url');
  }
}
```

- [ ] **Step 2: Provider for the repo**

Edit `frontend/merchant/lib/features/billing/billing_providers.dart`. Add at the bottom:

```dart
import '../auth/auth_providers.dart';
import 'billing_repository.dart';

final billingRepositoryProvider = Provider<BillingRepository>(
  (ref) => BillingRepository(ref.watch(supabaseClientProvider)),
);
```

(Place the new imports at the top with the existing imports.)

- [ ] **Step 3: Upgrade screen**

File: `frontend/merchant/lib/features/billing/presentation/upgrade_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../billing_providers.dart';
import '../tier.dart';

class UpgradeScreen extends ConsumerStatefulWidget {
  const UpgradeScreen({super.key});
  @override
  ConsumerState<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends ConsumerState<UpgradeScreen> {
  String _currency = 'USD';
  String _period = 'monthly';
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final currentTier = ref.watch(currentTierProvider).valueOrNull ?? Tier.free;

    return Scaffold(
      appBar: AppBar(title: Text(t.billingUpgradeTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CurrencyToggle(
              value: _currency,
              onChanged: (c) => setState(() {
                _currency = c;
                if (c == 'CNY') _period = 'monthly'; // CNY annual deferred
              }),
            ),
            if (_currency == 'USD') ...[
              const SizedBox(height: 12),
              _PeriodToggle(
                value: _period,
                onChanged: (p) => setState(() => _period = p),
              ),
            ],
            const SizedBox(height: 24),
            _TierCard(tier: Tier.free,   isCurrent: currentTier == Tier.free,   onSubscribe: null),
            const SizedBox(height: 12),
            _TierCard(
              tier: Tier.pro,
              isCurrent: currentTier == Tier.pro,
              onSubscribe: () => _subscribe(Tier.pro),
            ),
            const SizedBox(height: 12),
            _TierCard(
              tier: Tier.growth,
              isCurrent: currentTier == Tier.growth,
              onSubscribe: () => _subscribe(Tier.growth),
            ),
            if (currentTier.isPaid) ...[
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('manage-billing-button'),
                onPressed: _busy ? null : _manageBilling,
                child: Text(t.billingManageBilling),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _subscribe(Tier tier) async {
    final t = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      final url = await ref
          .read(billingRepositoryProvider)
          .createCheckoutSession(tier: tier, currency: _currency, period: _period);
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('launchUrl returned false');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.billingCheckoutFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _manageBilling() async {
    final t = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      final url = await ref.read(billingRepositoryProvider).createPortalSession();
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.billingCheckoutFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _CurrencyToggle extends StatelessWidget {
  const _CurrencyToggle({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(value: 'USD', label: Text(t.billingCurrencyUsd)),
        ButtonSegment(value: 'CNY', label: Text(t.billingCurrencyCny)),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(value: 'monthly', label: Text(t.billingMonthlyToggle)),
        ButtonSegment(value: 'annual',  label: Text(t.billingAnnualToggle)),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({required this.tier, required this.isCurrent, required this.onSubscribe});
  final Tier tier;
  final bool isCurrent;
  final VoidCallback? onSubscribe;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final name = switch (tier) {
      Tier.free => t.billingPlanFree,
      Tier.pro => t.billingPlanPro,
      Tier.growth => t.billingPlanGrowth,
    };
    final menus = switch (tier) {
      Tier.free => 1,
      Tier.pro => 5,
      Tier.growth => 9999,
    };
    final dishes = switch (tier) {
      Tier.free => 30,
      Tier.pro => 200,
      Tier.growth => 9999,
    };
    final reparses = switch (tier) {
      Tier.free => 1,
      Tier.pro => 5,
      Tier.growth => 50,
    };
    final qrViews = switch (tier) {
      Tier.free => 2000,
      Tier.pro => 20000,
      Tier.growth => 9999999,
    };
    final languages = switch (tier) {
      Tier.free => 2,
      Tier.pro => 5,
      Tier.growth => 9999,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(name, style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                if (isCurrent)
                  Chip(label: Text(t.billingCurrentTag)),
              ],
            ),
            const SizedBox(height: 8),
            Text(t.billingMenusCap(menus)),
            Text(t.billingDishesPerMenuCap(dishes)),
            Text(t.billingReparsesCap(reparses)),
            Text(t.billingQrViewsCap(qrViews)),
            Text(t.billingLanguagesCap(languages)),
            if (tier.isPaid) Text(t.billingCustomBranding),
            if (tier == Tier.growth) Text(t.billingMultiStore),
            if (tier.isPaid) Text(t.billingPriorityCsv),
            const SizedBox(height: 12),
            if (!isCurrent && onSubscribe != null)
              FilledButton(
                key: Key('subscribe-${tier.apiName}-button'),
                onPressed: onSubscribe,
                child: Text(
                  tier == Tier.pro ? t.billingSubscribePro : t.billingSubscribeGrowth,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Add `/upgrade` route**

Edit `frontend/merchant/lib/router/app_router.dart`. Add to `AppRoutes`:

```dart
  static const upgrade = '/upgrade';
```

Add the import:

```dart
import '../features/billing/presentation/upgrade_screen.dart';
```

Add the route inside `routes:`:

```dart
      GoRoute(path: AppRoutes.upgrade, builder: (c, s) => const UpgradeScreen()),
```

- [ ] **Step 5: Smoke test**

File: `frontend/merchant/test/smoke/upgrade_screen_smoke_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/billing/billing_providers.dart';
import 'package:menuray_merchant/features/billing/billing_repository.dart';
import 'package:menuray_merchant/features/billing/presentation/upgrade_screen.dart';
import 'package:menuray_merchant/features/billing/tier.dart';

import '../support/test_harness.dart';

class _FakeBillingRepository implements BillingRepository {
  String? lastSubscribeTier;
  String? lastSubscribeCurrency;
  String? lastSubscribePeriod;
  int portalCalls = 0;

  @override
  Future<String> createCheckoutSession({
    required Tier tier, required String currency, required String period,
  }) async {
    lastSubscribeTier = tier.apiName;
    lastSubscribeCurrency = currency;
    lastSubscribePeriod = period;
    return 'https://checkout.stripe.com/test';
  }

  @override
  Future<String> createPortalSession() async {
    portalCalls++;
    return 'https://billing.stripe.com/test';
  }
}

void main() {
  testWidgets('renders 3 tier cards + currency/period toggles', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentTierProvider.overrideWith((ref) async => Tier.free),
          billingRepositoryProvider.overrideWithValue(_FakeBillingRepository()),
        ],
        child: zhMaterialApp(home: const UpgradeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('免费版'), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget);
    expect(find.text('Growth'), findsOneWidget);
    expect(find.text('美元'), findsOneWidget);
    expect(find.text('人民币'), findsOneWidget);
    expect(find.text('月付'), findsOneWidget);
    // Free user shows Subscribe buttons on Pro & Growth (not Free).
    expect(find.byKey(const Key('subscribe-pro-button')), findsOneWidget);
    expect(find.byKey(const Key('subscribe-growth-button')), findsOneWidget);
    // Manage-billing only on paid tiers; free user → not present.
    expect(find.byKey(const Key('manage-billing-button')), findsNothing);
  });

  testWidgets('tap Subscribe Pro calls createCheckoutSession with correct args',
      (tester) async {
    final repo = _FakeBillingRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentTierProvider.overrideWith((ref) async => Tier.free),
          billingRepositoryProvider.overrideWithValue(repo),
        ],
        child: zhMaterialApp(home: const UpgradeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('subscribe-pro-button')));
    await tester.pump();

    expect(repo.lastSubscribeTier, 'pro');
    expect(repo.lastSubscribeCurrency, 'USD');
    expect(repo.lastSubscribePeriod, 'monthly');
  });

  testWidgets('paid user sees Manage billing button', (tester) async {
    final repo = _FakeBillingRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentTierProvider.overrideWith((ref) async => Tier.pro),
          billingRepositoryProvider.overrideWithValue(repo),
        ],
        child: zhMaterialApp(home: const UpgradeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('manage-billing-button')), findsOneWidget);
    // No Subscribe Pro button (current tier).
    expect(find.byKey(const Key('subscribe-pro-button')), findsNothing);
    // Subscribe to Growth still visible.
    expect(find.byKey(const Key('subscribe-growth-button')), findsOneWidget);
  });
}
```

- [ ] **Step 6: Verify**

```bash
cd /home/coder/workspaces/menuray/frontend/merchant
export PATH="$PATH:/home/coder/flutter/bin"
flutter analyze
flutter test test/smoke/upgrade_screen_smoke_test.dart
```

Expected: analyze clean; 3/3 tests pass. The `url_launcher` calls fire in test mode but the smoke test taps don't actually wait on launch — they just verify the repo method was called. (`launchUrl` may throw `MissingPluginException` in widget tests; that's caught in `_subscribe`'s catch block and surfaces a snackbar — tests can still assert the repo call happened first.)

- [ ] **Step 7: Commit**

```bash
cd /home/coder/workspaces/menuray
git add frontend/merchant/lib/features/billing/ frontend/merchant/lib/router/app_router.dart frontend/merchant/test/smoke/upgrade_screen_smoke_test.dart
git -c commit.gpgsign=false commit -m "$(cat <<'EOF'
feat(billing): UpgradeScreen + BillingRepository + /upgrade route

Renders three tier cards with USD/CNY currency toggle and monthly/
annual period toggle (annual hidden for CNY per P-4). Tap "Subscribe"
calls create-checkout-session and opens the Stripe URL via
url_launcher. Paid users see "Manage billing" → create-portal-session.
3 smoke tests cover render, subscribe flow, and paid-user portal CTA.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 15: Apply tier gates to existing screens

**Files:**
- Modify: `frontend/merchant/lib/features/home/presentation/home_screen.dart`
- Modify: `frontend/merchant/lib/features/publish/presentation/custom_theme_screen.dart`
- Modify: `frontend/merchant/lib/features/store/presentation/settings_screen.dart`
- Modify: `frontend/merchant/test/smoke/home_screen_smoke_test.dart`

- [ ] **Step 1: Home — RPC pre-check on +New menu**

Read `lib/features/home/presentation/home_screen.dart`. Locate the "+ New menu" button's `onPressed`. Wrap the existing navigation in an RPC call:

```dart
// At the top of the file, add imports:
import 'package:flutter/services.dart';
import '../../auth/auth_providers.dart';        // for supabaseClientProvider
import '../../store/active_store_provider.dart';
import '../../../router/app_router.dart';
```

Replace the button's `onPressed` body with (preserving the current navigation target — typically `context.push(AppRoutes.camera)` or similar; quote the existing target verbatim):

```dart
onPressed: () async {
  final ctx = ref.read(activeStoreProvider);
  if (ctx == null) return;
  final t = AppLocalizations.of(context)!;
  try {
    await ref.read(supabaseClientProvider).rpc(
      'assert_menu_count_under_cap',
      params: {'p_store_id': ctx.storeId},
    );
  } on PostgrestException catch (e) {
    if (e.message.contains('menu_count_cap_exceeded')) {
      if (context.mounted) {
        // The cap is only ever hit on Free (Pro=5, Growth=unlimited),
        // so the literal "Free" is fine for the snackbar.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.paywallMenuCapReached('Free'))),
        );
        context.go(AppRoutes.upgrade);
      }
      return;
    }
    rethrow;
  }
  if (context.mounted) context.go(AppRoutes.camera); // <-- adjust to whatever the existing target is
},
```

The exact existing button shape may differ; preserve onPressed signature. If the home screen's "new menu" button is not an obvious `FilledButton` or FAB, search for the i18n key that labels it (likely `homeFabNewMenu` or similar) — wrap that one specifically.

- [ ] **Step 2: Custom theme — TierGate the picker**

Read `lib/features/publish/presentation/custom_theme_screen.dart`. Find the primary-colour picker widget (likely a `Wrap` of swatches). Wrap it in `TierGate`:

```dart
// Add imports:
import '../../billing/tier.dart';
import '../../../shared/widgets/tier_gate.dart';

// Wrap the picker:
TierGate(
  allowed: const {Tier.pro, Tier.growth},
  fallback: _UpgradeCallout(),
  child: <existing picker widget>,
),

// Add the inline private callout class at the bottom of the file:
class _UpgradeCallout extends StatelessWidget {
  const _UpgradeCallout();
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: Text(t.paywallCustomThemeLocked)),
          TextButton(
            onPressed: () => context.go(AppRoutes.upgrade),
            child: Text(t.billingUpgradeTitle),
          ),
        ],
      ),
    );
  }
}
```

Add `import '../../../router/app_router.dart';` at the top.

- [ ] **Step 3: Settings — Upgrade tile**

Read `lib/features/store/presentation/settings_screen.dart`. Add a new `ListTile` to the existing settings list. Position: above the logout button.

```dart
// Add import:
import '../../billing/billing_providers.dart';
import '../../billing/tier.dart';
import '../../../router/app_router.dart';

// Inside build, where the existing list of ListTiles is rendered, insert
// (using a Consumer so we can read currentTierProvider):
Consumer(
  builder: (context, ref, _) {
    final t = AppLocalizations.of(context)!;
    final tierAsync = ref.watch(currentTierProvider);
    final isPaid = tierAsync.valueOrNull?.isPaid ?? false;
    return ListTile(
      key: const Key('settings-upgrade-tile'),
      leading: const Icon(Icons.workspace_premium_outlined),
      title: Text(isPaid ? t.billingManageBilling : t.billingUpgradeTitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.go(AppRoutes.upgrade),
    );
  },
),
```

- [ ] **Step 4: Update home_screen smoke test**

Read `test/smoke/home_screen_smoke_test.dart`. The existing tests need an additional override: stub `supabaseClientProvider`'s `.rpc('assert_menu_count_under_cap', ...)` calls. Simplest path: provide a `currentTierProvider` override + pre-set `activeStoreProvider` (already in place), and let the RPC actually fire — but the test's fake supabase doesn't simulate RPCs.

Pragmatic fix: add a defensive `try/catch` around the existing assertions, OR add `currentTierProvider.overrideWith((ref) async => Tier.growth)` so the cap is effectively unlimited (no menu cap reached). The cap check still fires but the fake supabase RPC will throw a different error which the new code lets propagate. To avoid this complication, the cleanest approach is:

In `_FakeStoreRepository`, add a stub for the RPC interaction. But repositories don't go through Supabase RPC directly — the home screen calls `ref.read(supabaseClientProvider).rpc(...)`. The smoke test currently does NOT override `supabaseClientProvider` (the real Supabase client is constructed but doesn't connect anywhere because the test never taps the new-menu button).

If the existing smoke test tests the rendering path only and never taps the new-menu button, NO change is required. If the test does tap it, gate the new behavior behind an existence check + accept the snackbar.

Run the existing test first:
```bash
cd /home/coder/workspaces/menuray/frontend/merchant
export PATH="$PATH:/home/coder/flutter/bin"
flutter test test/smoke/home_screen_smoke_test.dart
```

If it passes as-is, no test edits are needed. If it fails specifically because of the new RPC call, add the following to the existing override list:

```dart
currentTierProvider.overrideWith((ref) async => Tier.growth),
```

That keeps the cap check successful (Growth tier never raises). The actual RPC call still fires; if the fake supabase client can't handle it, you may need to also override `supabaseClientProvider` with a fake. Investigate the failure mode before adding workarounds.

- [ ] **Step 5: Run full suite**

```bash
cd /home/coder/workspaces/menuray/frontend/merchant
export PATH="$PATH:/home/coder/flutter/bin"
flutter analyze
flutter test
```

Expected: analyze clean; full suite green (90+ tests).

- [ ] **Step 6: Commit**

```bash
cd /home/coder/workspaces/menuray
git add frontend/merchant/
git -c commit.gpgsign=false commit -m "$(cat <<'EOF'
feat(billing): apply tier gates to home / custom-theme / settings

Home screen "+New menu" button calls assert_menu_count_under_cap RPC
before navigation; on check_violation surfaces paywallMenuCapReached
snackbar and redirects to /upgrade. Custom-theme primary-colour picker
wrapped in TierGate (Pro+) with an UpgradeCallout fallback. Settings
gets a new tile that flips between "Upgrade subscription" (free) and
"Manage billing" (paid) → /upgrade.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 16: Final verification + docs

**Files:**
- Modify: `docs/roadmap.md`
- Modify: `CLAUDE.md`
- Modify: `docs/architecture.md`
- Create: `backend/supabase/functions/STRIPE_DEPLOY.md`

- [ ] **Step 1: Full verification battery**

```bash
# 1. Backend migration applies
cd /home/coder/workspaces/menuray/backend/supabase
supabase db reset 2>&1 | tail -5

# 2. PgTAP both regressions
docker exec -i supabase_db_menuray psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  < /home/coder/workspaces/menuray/backend/supabase/tests/billing_quotas.sql 2>&1 | tail -3
docker exec -i supabase_db_menuray psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  < /home/coder/workspaces/menuray/backend/supabase/tests/rls_auth_expansion.sql 2>&1 | tail -3

# 3. Deno tests for all 4 new edge fns + parse-menu (if it has tests)
for fn in create-checkout-session create-portal-session handle-stripe-webhook create-store accept-invite parse-menu; do
  echo "=== $fn ==="
  cd /home/coder/workspaces/menuray/backend/supabase/functions/$fn
  deno test --allow-env --allow-net 2>&1 | tail -3
done

# 4. Merchant Flutter
cd /home/coder/workspaces/menuray/frontend/merchant
export PATH="$PATH:/home/coder/flutter/bin"
flutter analyze 2>&1 | tail -3
flutter test 2>&1 | tail -3

# 5. Customer SvelteKit
cd /home/coder/workspaces/menuray/frontend/customer
pnpm check 2>&1 | tail -3
pnpm test 2>&1 | tail -3
```

Expected: every command zero-exit, every test count green. If any fails, do NOT proceed; investigate.

- [ ] **Step 2: STRIPE_DEPLOY.md**

Write to `backend/supabase/functions/STRIPE_DEPLOY.md`:

```markdown
# Stripe deployment runbook

Six prerequisites before billing flips on in production.

## 1. Create products + prices in Stripe Dashboard (test + live)

| Product | Currency | Period | Amount | Price ID env var |
|---|---|---|---|---|
| Pro    | USD | Monthly | $19    | `STRIPE_PRICE_PRO_USD_MONTHLY`     |
| Pro    | USD | Annual  | $192   | `STRIPE_PRICE_PRO_USD_ANNUAL`      |
| Pro    | CNY | Monthly | ¥138   | `STRIPE_PRICE_PRO_CNY_MONTHLY`     |
| Growth | USD | Monthly | $49    | `STRIPE_PRICE_GROWTH_USD_MONTHLY`  |
| Growth | USD | Annual  | $504   | `STRIPE_PRICE_GROWTH_USD_ANNUAL`   |
| Growth | CNY | Monthly | ¥358   | `STRIPE_PRICE_GROWTH_CNY_MONTHLY`  |

CNY annual is intentionally absent (P-4: WeChat/Alipay don't natively support recurring annual yet).

## 2. Enable WeChat Pay + Alipay (Stripe Dashboard → Settings → Payment methods)

Required for CNY checkout flow. May require business verification.

## 3. Configure webhook endpoint (Dashboard → Developers → Webhooks)

URL: `https://<your-project>.supabase.co/functions/v1/handle-stripe-webhook`
Events: `checkout.session.completed`, `customer.subscription.updated`,
        `customer.subscription.deleted`, `invoice.payment_failed`
Copy signing secret → `STRIPE_WEBHOOK_SECRET` Edge Function secret.

## 4. Set Edge Function secrets

```
supabase secrets set \
  STRIPE_SECRET_KEY=sk_live_… \
  STRIPE_WEBHOOK_SECRET=whsec_… \
  STRIPE_PRICE_PRO_USD_MONTHLY=price_… \
  STRIPE_PRICE_PRO_USD_ANNUAL=price_… \
  STRIPE_PRICE_PRO_CNY_MONTHLY=price_… \
  STRIPE_PRICE_GROWTH_USD_MONTHLY=price_… \
  STRIPE_PRICE_GROWTH_USD_ANNUAL=price_… \
  STRIPE_PRICE_GROWTH_CNY_MONTHLY=price_… \
  PUBLIC_APP_URL=https://app.menuray.com
```

## 5. Local dev with Stripe CLI

```
stripe listen --forward-to http://127.0.0.1:54321/functions/v1/handle-stripe-webhook
```

Copy the printed signing secret to `.env.local`.

## 6. Manual smoke (test mode)

1. Open `/upgrade` in the merchant app.
2. Tap **Subscribe to Pro**, currency USD.
3. On Stripe Checkout: card `4242 4242 4242 4242`, any future expiry, any CVC.
4. Wait for redirect; webhook should flip `subscriptions.tier` and the user's owned `stores.tier`.
5. Open the customer view for any of those stores' published menus → MenuRay badge gone.
6. Repeat with currency CNY + WeChat Pay test method (Stripe test mode supports it).
7. **Manage billing → Cancel subscription** → wait for `customer.subscription.deleted` webhook → tier flips back to `free`.
```

- [ ] **Step 3: Update `docs/roadmap.md`**

Read the file. Find the Sessions table. Mark Session 4 ✅ shipped and add a one-line summary in the shipped section (mirrors Session 3's entry style).

- [ ] **Step 4: Update `CLAUDE.md`**

Append a Session 4 paragraph under "✅ Shipped" that mirrors Session 1/2/3 voice. Include test totals: ≈92 Flutter tests · 18 Vitest + 8 Playwright · ≈22 Deno (9 parse-menu + 5 accept-invite + 4 each new fn = the actual count). Bump the "Current test totals" line accordingly. Update the "Next" table to remove Session 4 / promote Session 5/6.

- [ ] **Step 5: Update `docs/architecture.md`**

Add a new "Billing" subsection under the backend section:

```markdown
### Billing

`subscriptions` (keyed by `auth.users.id`) is the source of truth for the
billing entity; `stores.tier` is denormalised so anon customer reads and
hot-path RLS gates avoid extra joins. The single point of write is
`handle-stripe-webhook`, which updates the `subscriptions` row and fans
the new tier out to every store the user owns. Quota enforcement is
mixed: hard-gate Postgres RPCs (`assert_menu_count_under_cap` etc.)
raise on violation; the Free-tier QR-view cap is a soft block in the
SvelteKit SSR loader (HTTP 402 + paywall page). Upgrades go through
Stripe Checkout (hosted) and existing subscribers manage via the Stripe
Customer Portal — no in-app payment sheet. WeChat Pay + Alipay are
day-1 supported when currency is CNY (P-3). Details: spec
`docs/superpowers/specs/2026-04-24-stripe-billing-design.md`.
```

- [ ] **Step 6: Final commit**

```bash
cd /home/coder/workspaces/menuray
git add docs/roadmap.md CLAUDE.md docs/architecture.md backend/supabase/functions/STRIPE_DEPLOY.md
git -c commit.gpgsign=false commit -m "$(cat <<'EOF'
docs: session 4 stripe billing shipped

Roadmap marks Session 4 complete; CLAUDE.md Active-work paragraph
added; architecture.md gains a Billing subsection. New
STRIPE_DEPLOY.md runbook covers Stripe Dashboard prerequisites,
webhook setup, Edge Function secrets, local dev flow, and the manual
smoke checklist (test card 4242, WeChat Pay test method).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-review checklist (planner-only — not executed by agents)

- ✅ Spec §1 in-scope items → all map to tasks: schema (T1), counter trigger + cron (T1), assert RPCs (T1), `handle_new_user()` extension (T1), backfill (T1); 4 Edge Functions (T5–T8); parse-menu gate (T9); SvelteKit paywall + badge gate (T10); `currentTierProvider` + Tier + Store mapper (T11); TierGate (T12); i18n (T13); Upgrade screen + repo + route (T14); existing-screen tier gates (T15); docs + verification (T16).
- ✅ Spec §3.7 webhook — three event types (`checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`) + idempotency + auto-org-create on Growth — all in T7.
- ✅ Spec §3.13 Upgrade screen — currency toggle, period toggle, 3 tier cards, subscribe + manage CTAs — all in T14.
- ✅ Spec §6 risks — webhook signature mismatch (mitigated by smoke test in T7), tier denormalisation drift (single-write through webhook in T7), pg_cron not enabled (best-effort in T1), Stripe Dashboard pre-setup (documented in T16).
- ✅ Spec §8 success criteria — all verifiable by Task 16's verification battery + manual smoke (documented in `STRIPE_DEPLOY.md`).
- ✅ Type names consistent: `Tier`, `TierX`, `Store.tier`, `currentTierProvider`, `BillingRepository`, `assert_menu_count_under_cap`/`assert_dish_count_under_cap`/`assert_translation_count_under_cap`, `tierFromPriceId`, `priceIdFor`, `subscriptions`, `stripe_events_seen`.
- ✅ No "TBD"/"implement later". Task 15 step 4 is an investigative step (run test → decide whether to override) but the plan documents both possible outcomes with full code.
- ✅ `+New menu` button gate in T15 documents that the existing button's navigation target may differ — engineer is told to read the file first and preserve the target. Acceptable; the alternative is over-specifying a moving part.

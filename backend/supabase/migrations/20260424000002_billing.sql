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

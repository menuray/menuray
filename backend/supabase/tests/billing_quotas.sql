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

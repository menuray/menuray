-- ============================================================================
-- Analytics regression — Session 5.
-- Usage:
--   supabase db reset && \
--   docker exec -i supabase_db_menuray psql -U postgres -d postgres \
--     -v ON_ERROR_STOP=1 < backend/supabase/tests/analytics_aggregations.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
BEGIN;

-- Fixtures: one owner user + one non-member user + one store w/ menu + 2 dishes.
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                        is_super_admin, created_at, updated_at,
                        confirmation_token, email_change, email_change_token_new, recovery_token)
VALUES
  ('aa000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','owner@x','', now(),'{}','{}',false,now(),now(),'','','',''),
  ('aa000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','nonmember@x','', now(),'{}','{}',false,now(),now(),'','','','')
ON CONFLICT (id) DO NOTHING;

INSERT INTO stores (id, name, tier, dish_tracking_enabled)
VALUES ('bb000000-0000-0000-0000-000000000001','Analytics store','free', false)
ON CONFLICT (id) DO NOTHING;

INSERT INTO store_members (store_id, user_id, role, accepted_at) VALUES
  ('bb000000-0000-0000-0000-000000000001','aa000000-0000-0000-0000-000000000001','owner', now())
ON CONFLICT (store_id, user_id) DO NOTHING;

INSERT INTO menus (id, store_id, name, status, slug, source_locale)
VALUES ('cc000000-0000-0000-0000-000000000001','bb000000-0000-0000-0000-000000000001','M','published','m-slug','en')
ON CONFLICT (id) DO NOTHING;
INSERT INTO categories (id, menu_id, store_id, source_name)
VALUES ('dd000000-0000-0000-0000-000000000001','cc000000-0000-0000-0000-000000000001','bb000000-0000-0000-0000-000000000001','c')
ON CONFLICT (id) DO NOTHING;
INSERT INTO dishes (id, category_id, menu_id, store_id, source_name, price)
VALUES
  ('ee000000-0000-0000-0000-000000000001','dd000000-0000-0000-0000-000000000001','cc000000-0000-0000-0000-000000000001','bb000000-0000-0000-0000-000000000001','dish-A',10),
  ('ee000000-0000-0000-0000-000000000002','dd000000-0000-0000-0000-000000000001','cc000000-0000-0000-0000-000000000001','bb000000-0000-0000-0000-000000000001','dish-B',10)
ON CONFLICT (id) DO NOTHING;

-- 10 view_logs rows across 2 days, varied locales. Day1 = 4 rows, Day2 = 6 rows.
INSERT INTO view_logs (menu_id, store_id, locale, session_id, viewed_at) VALUES
  ('cc000000-0000-0000-0000-000000000001','bb000000-0000-0000-0000-000000000001','zh-CN','s1', now() - interval '1 day 6 hours'),
  ('cc000000-0000-0000-0000-000000000001','bb000000-0000-0000-0000-000000000001','zh-CN','s1', now() - interval '1 day 5 hours'),
  ('cc000000-0000-0000-0000-000000000001','bb000000-0000-0000-0000-000000000001','en',   's2', now() - interval '1 day 4 hours'),
  ('cc000000-0000-0000-0000-000000000001','bb000000-0000-0000-0000-000000000001','en',   's3', now() - interval '1 day 3 hours'),
  ('cc000000-0000-0000-0000-000000000001','bb000000-0000-0000-0000-000000000001','zh-CN','s4', now() - interval '6 hours'),
  ('cc000000-0000-0000-0000-000000000001','bb000000-0000-0000-0000-000000000001','zh-CN','s5', now() - interval '5 hours'),
  ('cc000000-0000-0000-0000-000000000001','bb000000-0000-0000-0000-000000000001','zh-CN','s6', now() - interval '4 hours'),
  ('cc000000-0000-0000-0000-000000000001','bb000000-0000-0000-0000-000000000001','en',   's7', now() - interval '3 hours'),
  ('cc000000-0000-0000-0000-000000000001','bb000000-0000-0000-0000-000000000001','ja',   's8', now() - interval '2 hours'),
  ('cc000000-0000-0000-0000-000000000001','bb000000-0000-0000-0000-000000000001','ja',   's9', now() - interval '1 hour');

-- Helper to run queries as a given user.
CREATE OR REPLACE FUNCTION pg_temp.as_user(p_uid uuid) RETURNS void
  LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('role','authenticated',true);
  PERFORM set_config('request.jwt.claim.sub', p_uid::text, true);
END $$;

-- =============== A. Overview + by-day + by-locale ===========================
SELECT pg_temp.as_user('aa000000-0000-0000-0000-000000000001');
DO $$ DECLARE v_over jsonb; v_byday jsonb; v_byloc jsonb; BEGIN
  v_over := public.get_visits_overview(
    'bb000000-0000-0000-0000-000000000001',
    now() - interval '30 days', now() + interval '1 day');
  ASSERT (v_over->>'total_views')::int     = 10, 'total_views=10';
  ASSERT (v_over->>'unique_sessions')::int = 9,  'unique_sessions=9 (s1 repeats)';

  v_byday := public.get_visits_by_day(
    'bb000000-0000-0000-0000-000000000001',
    now() - interval '2 days', now() + interval '1 day');
  ASSERT jsonb_array_length(v_byday) >= 2, 'at least 2 days in range';

  v_byloc := public.get_traffic_by_locale(
    'bb000000-0000-0000-0000-000000000001',
    now() - interval '30 days', now() + interval '1 day');
  -- zh-CN=5, en=3, ja=2 → first should be zh-CN.
  ASSERT v_byloc->0->>'locale' = 'zh-CN', 'zh-CN is top locale';
END $$;

-- =============== B. Top dishes opt-in gate ==================================
DO $$ DECLARE v_top jsonb; BEGIN
  -- Opt-in currently off → empty array.
  v_top := public.get_top_dishes(
    'bb000000-0000-0000-0000-000000000001',
    now() - interval '30 days', now() + interval '1 day');
  ASSERT v_top = '[]'::jsonb, 'opt-in off returns []';
END $$;

-- Turn on tracking; insert dish views; re-query.
UPDATE stores SET dish_tracking_enabled = true
  WHERE id = 'bb000000-0000-0000-0000-000000000001';
INSERT INTO dish_view_logs (menu_id, store_id, dish_id, session_id) VALUES
  ('cc000000-0000-0000-0000-000000000001','bb000000-0000-0000-0000-000000000001','ee000000-0000-0000-0000-000000000001','sa'),
  ('cc000000-0000-0000-0000-000000000001','bb000000-0000-0000-0000-000000000001','ee000000-0000-0000-0000-000000000001','sb'),
  ('cc000000-0000-0000-0000-000000000001','bb000000-0000-0000-0000-000000000001','ee000000-0000-0000-0000-000000000001','sc'),
  ('cc000000-0000-0000-0000-000000000001','bb000000-0000-0000-0000-000000000001','ee000000-0000-0000-0000-000000000001','sd'),
  ('cc000000-0000-0000-0000-000000000001','bb000000-0000-0000-0000-000000000001','ee000000-0000-0000-0000-000000000001','se'),
  ('cc000000-0000-0000-0000-000000000001','bb000000-0000-0000-0000-000000000001','ee000000-0000-0000-0000-000000000002','sf'),
  ('cc000000-0000-0000-0000-000000000001','bb000000-0000-0000-0000-000000000001','ee000000-0000-0000-0000-000000000002','sg');

DO $$ DECLARE v_top jsonb; BEGIN
  v_top := public.get_top_dishes(
    'bb000000-0000-0000-0000-000000000001',
    now() - interval '30 days', now() + interval '1 day');
  ASSERT jsonb_array_length(v_top) = 2, '2 dishes in top list';
  ASSERT (v_top->0->>'count')::int = 5, 'dish-A wins with 5';
  ASSERT v_top->0->>'dish_name' = 'dish-A', 'dish-A is first';
END $$;

-- =============== C. Cross-store isolation ===================================
SELECT pg_temp.as_user('aa000000-0000-0000-0000-000000000002');  -- non-member
DO $$ BEGIN
  BEGIN
    PERFORM public.get_visits_overview(
      'bb000000-0000-0000-0000-000000000001',
      now() - interval '30 days', now() + interval '1 day');
    ASSERT false, 'non-member must raise insufficient_privilege';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

ROLLBACK;

\echo 'analytics_aggregations.sql: all assertions passed'

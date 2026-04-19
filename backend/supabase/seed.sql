-- ============================================================================
-- MenuRay local seed data
--
-- Creates a demo auth user (seed@menuray.app / demo1234); signup trigger
-- auto-creates a store; seed then updates store name and populates one
-- published menu with two categories and five dishes (mirroring mock_data.dart).
-- ============================================================================

-- Demo user. Fixed UUID so tests can reference it.
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  is_super_admin, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token
) VALUES (
  '11111111-1111-1111-1111-111111111111',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated',
  'seed@menuray.app',
  crypt('demo1234', gen_salt('bf')),
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb,
  false, now(), now(),
  '', '', '', ''
) ON CONFLICT (id) DO NOTHING;

INSERT INTO auth.identities (
  id, user_id, provider_id, identity_data, provider,
  last_sign_in_at, created_at, updated_at
) VALUES (
  gen_random_uuid(),
  '11111111-1111-1111-1111-111111111111',
  '11111111-1111-1111-1111-111111111111',
  '{"sub":"11111111-1111-1111-1111-111111111111","email":"seed@menuray.app"}'::jsonb,
  'email',
  now(), now(), now()
) ON CONFLICT DO NOTHING;

-- Update auto-created store to match mock data.
UPDATE stores
SET name = '云间小厨 · 静安店',
    address = '上海市静安区南京西路 1234 号',
    source_locale = 'zh-CN'
WHERE owner_id = '11111111-1111-1111-1111-111111111111';

-- Populate the rest in a DO block so we can use intermediate uuids.
DO $$
DECLARE
  v_store_id uuid;
  v_menu_id  uuid;
  v_cold_id  uuid;
  v_hot_id   uuid;
  d1 uuid; d2 uuid; d3 uuid; d4 uuid; d5 uuid;
BEGIN
  SELECT id INTO v_store_id FROM stores
    WHERE owner_id = '11111111-1111-1111-1111-111111111111';

  -- One published menu.
  INSERT INTO menus (store_id, name, status, slug, time_slot, time_slot_description,
                     currency, source_locale, published_at)
  VALUES (v_store_id, '午市套餐 2025 春', 'published',
          'yun-jian-xiao-chu-lunch-2025',
          'lunch', '午市 11:00–14:00',
          'CNY', 'zh-CN', now())
  RETURNING id INTO v_menu_id;

  -- Categories.
  INSERT INTO categories (menu_id, store_id, source_name, position)
    VALUES (v_menu_id, v_store_id, '凉菜', 0) RETURNING id INTO v_cold_id;
  INSERT INTO categories (menu_id, store_id, source_name, position)
    VALUES (v_menu_id, v_store_id, '热菜', 1) RETURNING id INTO v_hot_id;

  -- Dishes — cold.
  INSERT INTO dishes (category_id, menu_id, store_id, source_name, price, position,
                      spice_level, confidence, is_signature, is_recommended, is_vegetarian,
                      allergens)
    VALUES (v_cold_id, v_menu_id, v_store_id, '口水鸡', 38, 0,
            'medium', 'high', false, false, false, '{}'::text[])
    RETURNING id INTO d1;

  INSERT INTO dishes (category_id, menu_id, store_id, source_name, price, position,
                      spice_level, confidence, is_signature, is_recommended, is_vegetarian,
                      allergens)
    VALUES (v_cold_id, v_menu_id, v_store_id, '凉拌黄瓜', 18, 1,
            'none', 'high', false, false, true, '{}'::text[])
    RETURNING id INTO d2;

  INSERT INTO dishes (category_id, menu_id, store_id, source_name, price, position,
                      spice_level, confidence, is_signature, is_recommended, is_vegetarian,
                      allergens)
    VALUES (v_cold_id, v_menu_id, v_store_id, '川北凉粉', 22, 2,
            'medium', 'low', false, false, false, '{}'::text[])
    RETURNING id INTO d3;

  -- Dishes — hot.
  INSERT INTO dishes (category_id, menu_id, store_id, source_name, source_description,
                      price, position,
                      spice_level, confidence, is_signature, is_recommended, is_vegetarian,
                      allergens)
    VALUES (v_hot_id, v_menu_id, v_store_id, '宫保鸡丁',
            '经典川菜，鸡丁、花生与干辣椒同炒，咸甜微辣。',
            48, 0,
            'medium', 'high', true, true, false, ARRAY['花生']::text[])
    RETURNING id INTO d4;

  INSERT INTO dishes (category_id, menu_id, store_id, source_name, price, position,
                      spice_level, confidence, is_signature, is_recommended, is_vegetarian,
                      allergens)
    VALUES (v_hot_id, v_menu_id, v_store_id, '麻婆豆腐', 32, 1,
            'hot', 'high', false, false, false, '{}'::text[])
    RETURNING id INTO d5;

  -- English dish_translations for the two named dishes that have nameEn in mock_data.dart.
  INSERT INTO dish_translations (dish_id, store_id, locale, name) VALUES
    (d1, v_store_id, 'en', 'Mouth-Watering Chicken'),
    (d2, v_store_id, 'en', 'Smashed Cucumber'),
    (d4, v_store_id, 'en', 'Kung Pao Chicken'),
    (d5, v_store_id, 'en', 'Mapo Tofu');

  -- Category translations.
  INSERT INTO category_translations (category_id, store_id, locale, name) VALUES
    (v_cold_id, v_store_id, 'en', 'Cold dishes'),
    (v_hot_id,  v_store_id, 'en', 'Hot dishes');

  -- Store translation.
  INSERT INTO store_translations (store_id, locale, name, address) VALUES
    (v_store_id, 'en', 'Cloud Kitchen · Jing''an',
     '1234 Nanjing West Rd, Jing''an District, Shanghai');

  -- One completed parse_runs row (for realtime + idempotency smoke testing).
  INSERT INTO parse_runs (id, store_id, menu_id, source_photo_paths,
                          status, ocr_provider, llm_provider,
                          started_at, finished_at)
  VALUES ('22222222-2222-2222-2222-222222222222',
          v_store_id, v_menu_id,
          ARRAY[v_store_id || '/seed-menu.jpg']::text[],
          'succeeded', 'mock', 'mock', now(), now());
END $$;

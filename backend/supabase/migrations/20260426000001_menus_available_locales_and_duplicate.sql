-- ============================================================================
-- MenuRay — menus.available_locales column + duplicate_menu RPC (Session 8).
--
-- 1. Adds `menus.available_locales text[]` (referenced by S7 translate-menu
--    Edge Function but never declared in schema — backfill ARRAY[source_locale]
--    so existing rows pass tier-cap arithmetic immediately).
-- 2. Adds the `duplicate_menu(p_source_menu_id)` SECURITY DEFINER RPC that
--    deep-clones a menu (categories + dishes + translations) into a draft.
--    See docs/superpowers/specs/2026-04-26-merchant-polish-design.md §4.1.
-- ============================================================================

-- ---------- 1. menus.available_locales -------------------------------------
ALTER TABLE menus
  ADD COLUMN available_locales text[] NOT NULL DEFAULT ARRAY[]::text[];

-- Backfill: every existing menu has at least its source locale + any locales
-- already represented in dish_translations (the customer-side derivation
-- already used this set; we materialise it here so translate-menu's tier-cap
-- arithmetic sees the right count).
UPDATE menus m SET available_locales = (
  SELECT ARRAY(
    SELECT DISTINCT locale
      FROM (
        SELECT m.source_locale AS locale
        UNION
        SELECT dt.locale
          FROM dish_translations dt
          JOIN dishes d ON d.id = dt.dish_id
         WHERE d.menu_id = m.id
        UNION
        SELECT ct.locale
          FROM category_translations ct
          JOIN categories c ON c.id = ct.category_id
         WHERE c.menu_id = m.id
      ) src
  )
);


-- ---------- 2. duplicate_menu RPC ------------------------------------------
CREATE OR REPLACE FUNCTION public.duplicate_menu(p_source_menu_id uuid)
RETURNS uuid LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_store_id   uuid;
  v_role       text;
  v_new_menu   uuid;
  v_old_cat    record;
  v_new_cat    uuid;
  v_old_dish   record;
  v_new_dish   uuid;
  cat_map      jsonb := '{}'::jsonb;
  dish_map     jsonb := '{}'::jsonb;
BEGIN
  SELECT store_id INTO v_store_id FROM menus WHERE id = p_source_menu_id;
  IF v_store_id IS NULL THEN
    RAISE EXCEPTION 'menu_not_found' USING ERRCODE = 'no_data_found';
  END IF;

  v_role := public.user_store_role(v_store_id);
  IF v_role IS NULL OR v_role NOT IN ('owner','manager') THEN
    RAISE EXCEPTION 'insufficient_role' USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- Tier menu-cap gate (S4 hard-gate function).
  PERFORM public.assert_menu_count_under_cap(v_store_id);

  -- Clone the menu row → draft, slug NULL, suffix " (copy)" on name.
  INSERT INTO menus (
    store_id, name, source_locale, available_locales,
    status, currency, time_slot, time_slot_description,
    cover_image_url, template_id, theme_overrides
  )
  SELECT
    store_id, name || ' (copy)', source_locale, available_locales,
    'draft', currency, time_slot, time_slot_description,
    cover_image_url, template_id, theme_overrides
  FROM menus WHERE id = p_source_menu_id
  RETURNING id INTO v_new_menu;

  -- Clone categories.
  FOR v_old_cat IN
    SELECT * FROM categories WHERE menu_id = p_source_menu_id ORDER BY position
  LOOP
    INSERT INTO categories (store_id, menu_id, source_name, position)
    VALUES (v_old_cat.store_id, v_new_menu, v_old_cat.source_name, v_old_cat.position)
    RETURNING id INTO v_new_cat;
    cat_map := cat_map || jsonb_build_object(v_old_cat.id::text, v_new_cat::text);
  END LOOP;

  -- Clone dishes.
  FOR v_old_dish IN
    SELECT * FROM dishes WHERE menu_id = p_source_menu_id
  LOOP
    INSERT INTO dishes (
      store_id, menu_id, category_id, source_name, source_description,
      price, position, spice_level, confidence,
      is_signature, is_recommended, is_vegetarian, allergens,
      sold_out, image_url
    )
    VALUES (
      v_old_dish.store_id, v_new_menu,
      (cat_map->>(v_old_dish.category_id::text))::uuid,
      v_old_dish.source_name, v_old_dish.source_description,
      v_old_dish.price, v_old_dish.position,
      v_old_dish.spice_level, v_old_dish.confidence,
      v_old_dish.is_signature, v_old_dish.is_recommended,
      v_old_dish.is_vegetarian, v_old_dish.allergens,
      false,                 -- new dishes start NOT sold out
      v_old_dish.image_url   -- URL string copied; bucket object NOT cloned
    )
    RETURNING id INTO v_new_dish;
    dish_map := dish_map || jsonb_build_object(v_old_dish.id::text, v_new_dish::text);
  END LOOP;

  -- Clone category translations.
  INSERT INTO category_translations (category_id, store_id, locale, name)
  SELECT
    (cat_map->>(category_id::text))::uuid,
    store_id, locale, name
  FROM category_translations
  WHERE category_id IN (SELECT id FROM categories WHERE menu_id = p_source_menu_id);

  -- Clone dish translations.
  INSERT INTO dish_translations (dish_id, store_id, locale, name, description)
  SELECT
    (dish_map->>(dish_id::text))::uuid,
    store_id, locale, name, description
  FROM dish_translations
  WHERE dish_id IN (SELECT id FROM dishes WHERE menu_id = p_source_menu_id);

  RETURN v_new_menu;
END;
$$;

GRANT EXECUTE ON FUNCTION public.duplicate_menu(uuid) TO authenticated;

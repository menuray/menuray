-- ============================================================================
-- MenuRay — Initial schema
-- ============================================================================
-- 9 tables: stores, menus, categories, dishes, dish_translations,
-- category_translations, store_translations, parse_runs, view_logs.
--
-- Conventions:
--   - Every table has id uuid PK, created_at, updated_at (timestamptz default now()).
--   - Every "owned" table carries a redundant store_id for RLS.
--   - text + CHECK constraint over Postgres ENUM (see ADR-014).
-- ============================================================================

-- Required by gen_random_uuid().
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------- stores ----------------------------------------------------------
CREATE TABLE stores (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id      uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  name          text NOT NULL,
  address       text,
  logo_url      text,
  source_locale text NOT NULL DEFAULT 'en',
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

-- ---------- menus -----------------------------------------------------------
CREATE TABLE menus (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id              uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  name                  text NOT NULL,
  status                text NOT NULL DEFAULT 'draft'
                          CHECK (status IN ('draft','published','archived')),
  slug                  text UNIQUE,
  time_slot             text NOT NULL DEFAULT 'all_day'
                          CHECK (time_slot IN ('all_day','lunch','dinner','seasonal')),
  time_slot_description text,
  cover_image_url       text,
  currency              text NOT NULL DEFAULT 'USD',
  source_locale         text NOT NULL DEFAULT 'en',
  published_at          timestamptz,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT published_requires_slug CHECK (status <> 'published' OR slug IS NOT NULL)
);

-- ---------- categories ------------------------------------------------------
CREATE TABLE categories (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  menu_id     uuid NOT NULL REFERENCES menus(id) ON DELETE CASCADE,
  store_id    uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  source_name text NOT NULL,
  position    int  NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- ---------- dishes ----------------------------------------------------------
CREATE TABLE dishes (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id        uuid NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  menu_id            uuid NOT NULL REFERENCES menus(id) ON DELETE CASCADE,
  store_id           uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  source_name        text NOT NULL,
  source_description text,
  price              numeric(12,2) NOT NULL,
  image_url          text,
  position           int  NOT NULL DEFAULT 0,
  spice_level        text NOT NULL DEFAULT 'none'
                       CHECK (spice_level IN ('none','mild','medium','hot')),
  confidence         text NOT NULL DEFAULT 'high'
                       CHECK (confidence IN ('high','low')),
  is_signature       boolean NOT NULL DEFAULT false,
  is_recommended     boolean NOT NULL DEFAULT false,
  is_vegetarian      boolean NOT NULL DEFAULT false,
  sold_out           boolean NOT NULL DEFAULT false,
  allergens          text[]  NOT NULL DEFAULT '{}',
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);

-- ---------- dish_translations ----------------------------------------------
CREATE TABLE dish_translations (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dish_id     uuid NOT NULL REFERENCES dishes(id) ON DELETE CASCADE,
  store_id    uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  locale      text NOT NULL,
  name        text NOT NULL,
  description text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (dish_id, locale)
);

-- ---------- category_translations ------------------------------------------
CREATE TABLE category_translations (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id uuid NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  store_id    uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  locale      text NOT NULL,
  name        text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (category_id, locale)
);

-- ---------- store_translations ---------------------------------------------
CREATE TABLE store_translations (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id    uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  locale      text NOT NULL,
  name        text NOT NULL,
  address     text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (store_id, locale)
);

-- ---------- parse_runs ------------------------------------------------------
CREATE TABLE parse_runs (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id           uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  menu_id            uuid REFERENCES menus(id) ON DELETE SET NULL,
  source_photo_paths text[] NOT NULL,
  status             text NOT NULL DEFAULT 'pending'
                       CHECK (status IN ('pending','ocr','structuring','succeeded','failed')),
  error_stage        text CHECK (error_stage IN ('ocr','structure')),
  error_message      text,
  ocr_provider       text,
  llm_provider       text,
  started_at         timestamptz,
  finished_at        timestamptz,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);

-- ---------- view_logs -------------------------------------------------------
CREATE TABLE view_logs (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  menu_id         uuid NOT NULL REFERENCES menus(id) ON DELETE CASCADE,
  store_id        uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  locale          text,
  session_id      text,
  referrer_domain text,
  viewed_at       timestamptz NOT NULL DEFAULT now(),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

-- ============================================================================
-- Indexes
-- ============================================================================
CREATE INDEX menus_store_id_idx        ON menus(store_id);
CREATE INDEX menus_slug_published_idx  ON menus(slug) WHERE status = 'published';
CREATE INDEX categories_menu_pos_idx   ON categories(menu_id, position);
CREATE INDEX dishes_category_pos_idx   ON dishes(category_id, position);
CREATE INDEX dishes_menu_id_idx        ON dishes(menu_id);
CREATE INDEX view_logs_menu_time_idx   ON view_logs(menu_id, viewed_at DESC);
CREATE INDEX view_logs_store_time_idx  ON view_logs(store_id, viewed_at DESC);
CREATE INDEX parse_runs_store_time_idx ON parse_runs(store_id, created_at DESC);

-- ============================================================================
-- insert_menu_draft(store_id, draft jsonb) RETURNS uuid
-- Transactionally inserts a menu (status='draft') + its categories + dishes.
-- Called from the parse-menu Edge Function via .rpc(). Per spec §7.3, this
-- entire pipeline step must be atomic — if any dish fails to insert, the
-- whole draft is rolled back, leaving no partial state.
-- ============================================================================
CREATE FUNCTION insert_menu_draft(p_store_id uuid, p_draft jsonb)
RETURNS uuid
LANGUAGE plpgsql AS $$
DECLARE
  v_menu_id uuid;
  v_cat_id  uuid;
  v_cat     jsonb;
  v_dish    jsonb;
BEGIN
  INSERT INTO menus (store_id, name, status, time_slot, currency, source_locale)
  VALUES (
    p_store_id,
    p_draft->>'name',
    'draft',
    'all_day',
    COALESCE(p_draft->>'currency', 'USD'),
    COALESCE(p_draft->>'sourceLocale', 'en')
  )
  RETURNING id INTO v_menu_id;

  FOR v_cat IN SELECT * FROM jsonb_array_elements(p_draft->'categories') LOOP
    INSERT INTO categories (menu_id, store_id, source_name, position)
    VALUES (
      v_menu_id,
      p_store_id,
      v_cat->>'sourceName',
      COALESCE((v_cat->>'position')::int, 0)
    )
    RETURNING id INTO v_cat_id;

    FOR v_dish IN SELECT * FROM jsonb_array_elements(v_cat->'dishes') LOOP
      INSERT INTO dishes (
        category_id, menu_id, store_id,
        source_name, source_description,
        price, position,
        spice_level, confidence,
        is_signature, is_recommended, is_vegetarian,
        allergens
      ) VALUES (
        v_cat_id, v_menu_id, p_store_id,
        v_dish->>'sourceName',
        v_dish->>'sourceDescription',
        (v_dish->>'price')::numeric,
        COALESCE((v_dish->>'position')::int, 0),
        COALESCE(v_dish->>'spiceLevel', 'none'),
        COALESCE(v_dish->>'confidence', 'high'),
        COALESCE((v_dish->>'isSignature')::boolean, false),
        COALESCE((v_dish->>'isRecommended')::boolean, false),
        COALESCE((v_dish->>'isVegetarian')::boolean, false),
        COALESCE(
          ARRAY(SELECT jsonb_array_elements_text(v_dish->'allergens')),
          '{}'::text[]
        )
      );
    END LOOP;
  END LOOP;

  RETURN v_menu_id;
END $$;

-- ============================================================================
-- touch_updated_at trigger — keeps updated_at honest
-- ============================================================================
CREATE FUNCTION touch_updated_at() RETURNS trigger
  LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END $$;

CREATE TRIGGER stores_touch_updated_at BEFORE UPDATE ON stores
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER menus_touch_updated_at BEFORE UPDATE ON menus
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER categories_touch_updated_at BEFORE UPDATE ON categories
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER dishes_touch_updated_at BEFORE UPDATE ON dishes
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER dish_translations_touch_updated_at BEFORE UPDATE ON dish_translations
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER category_translations_touch_updated_at BEFORE UPDATE ON category_translations
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER store_translations_touch_updated_at BEFORE UPDATE ON store_translations
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER parse_runs_touch_updated_at BEFORE UPDATE ON parse_runs
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER view_logs_touch_updated_at BEFORE UPDATE ON view_logs
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

# Supabase Backend MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the MenuRay Supabase backend scaffold — database schema, RLS, Storage, Auth config, and a mock-adapter `parse-menu` Edge Function — so a future session can wire the merchant app and plug in real OCR/LLM providers without touching orchestration.

**Architecture:** Single Supabase project with 9 Postgres tables in `public` schema, RLS policies keyed off a redundant `store_id` column, three Storage buckets with `{store_id}/<uuid>.<ext>` path-prefix policies, and one Deno Edge Function (`parse-menu`) whose pipeline is split into injectable `OcrProvider` + `LlmProvider` interfaces with mock adapters. Per `docs/superpowers/specs/2026-04-19-supabase-backend-mvp-design.md`.

**Tech Stack:** Postgres 15, Supabase CLI, Supabase Auth (phone OTP + email/password), Supabase Storage, Deno 1.x, TypeScript, SQL migrations.

**Out of scope (do not implement):** changes to `frontend/merchant/`, real OCR/LLM API calls, `translate-menu` function, deploying to hosted Supabase, rate-limiting on `view_logs`, billing, memberships / chain accounts.

---

## Conventions used throughout this plan

- **Working directory:** `/home/coder/workspaces/menuray` (the repo root). All paths are relative to it unless noted.
- **Migration timestamp prefix:** `20260420000001` through `20260420000004`. Do not alter; they must sort lexically.
- **Fixed seed UUIDs** (so tests and seed data reference the same rows):
  - Demo auth user: `11111111-1111-1111-1111-111111111111`
  - Demo parse_runs row (seeded for Realtime smoke test): `22222222-2222-2222-2222-222222222222`
- **Commit message format:** Conventional Commits with scopes `backend`, `docs`, or `chore` plus the AI coauthor trailer.
- **Never use `--no-verify` or skip hooks.**
- **Never modify anything under `frontend/merchant/`.** Verify via `git diff frontend/` before each commit.
- **When a step says "run supabase db reset"**, make sure `supabase start` has been run first and Docker is up. If a step fails, do not delete the `supabase/` directory to "try again" — read the error and fix the SQL.

---

## File structure produced by this plan

```
backend/
├── .gitignore                                                   [Task 1]
├── README.md                                                    [Task 12]
└── supabase/
    ├── config.toml                                              [Task 1]
    ├── seed.sql                                                 [Task 7]
    ├── migrations/
    │   ├── 20260420000001_init_schema.sql                       [Task 2]
    │   ├── 20260420000002_rls_policies.sql                      [Task 3]
    │   ├── 20260420000003_storage_buckets.sql                   [Task 4]
    │   └── 20260420000004_signup_trigger.sql                    [Task 5]
    └── functions/
        ├── _shared/
        │   ├── providers/
        │   │   ├── types.ts                                     [Task 8]
        │   │   ├── mock_ocr.ts                                  [Task 9]
        │   │   ├── mock_llm.ts                                  [Task 9]
        │   │   └── factory.ts                                   [Task 9]
        │   └── db.ts                                            [Task 10]
        ├── parse-menu/
        │   ├── index.ts                                         [Task 11]
        │   ├── orchestrator.ts                                  [Task 10]
        │   ├── README.md                                        [Task 11]
        │   └── fixtures/
        │       └── yun_jian_xiao_chu.json                       [Task 8]
        └── import_map.json                                      [Task 8]

docs/
├── decisions.md                         (append ADR-013 … 016)  [Task 13]
├── architecture.md                      (annotate Backend section) [Task 13]
└── plans/execution-log.md               (task verifications)    [Task 14]

README.md                                (tech stack row updated) [Task 13]
```

---

## Task 1: Install tooling + scaffold `backend/` directory

**Goal:** Get Supabase CLI installed, run `supabase init`, commit the generated `config.toml` with MenuRay-specific tweaks.

**Files:**
- Create: `backend/.gitignore`
- Create: `backend/supabase/config.toml` (via `supabase init`, then edited)

- [ ] **Step 1.1: Install the Supabase CLI**

```bash
# Use the latest stable channel. Do not use npm global install — it's flagged as unstable by Supabase.
# macOS / Linux with Homebrew:
brew install supabase/tap/supabase

# Or via direct binary (no Homebrew):
curl -fsSL https://supabase.com/install.sh | sh
```

Verify:
```bash
supabase --version
# Expect: a semver like 1.x.y (e.g., 1.200.3)
```

If the version is older than 1.150, upgrade: `brew upgrade supabase/tap/supabase`.

- [ ] **Step 1.2: Verify Docker is running**

```bash
docker ps
# Expect: a non-error output (empty list is fine).
```

If Docker is not running, start Docker Desktop / `colima start` before proceeding. `supabase start` requires Docker.

- [ ] **Step 1.3: Scaffold `backend/` via `supabase init`**

```bash
cd /home/coder/workspaces/menuray
mkdir -p backend
cd backend
supabase init
# When prompted "Generate VS Code settings?": No
# When prompted "Generate IntelliJ settings?": No
```

This creates `backend/supabase/config.toml` and an empty `backend/supabase/migrations/` directory.

- [ ] **Step 1.4: Edit `backend/supabase/config.toml` — set project_id and auth providers**

Open `backend/supabase/config.toml` and make these edits:

```toml
# project_id is the local-stack identifier (not the hosted project ref).
# Pick a short slug matching the repo.
project_id = "menuray"

[api]
enabled = true
port = 54321
schemas = ["public", "storage", "graphql_public"]
extra_search_path = ["public", "extensions"]
max_rows = 1000

[db]
port = 54322
shadow_port = 54320
major_version = 15

[studio]
enabled = true
port = 54323

[auth]
enabled = true
site_url = "http://localhost:3000"
additional_redirect_urls = ["http://localhost:3000"]
jwt_expiry = 3600
enable_signup = true
enable_anonymous_sign_ins = false
enable_manual_linking = false

[auth.email]
enable_signup = true
double_confirm_changes = true
enable_confirmations = false  # local dev only; hosted project toggles this via dashboard

[auth.sms]
enable_signup = true
enable_confirmations = true
# The specific SMS provider (twilio / messagebird / vonage) is configured on the
# hosted project via the dashboard — not in this file, because it requires secrets.

[storage]
enabled = true
file_size_limit = "50MiB"

[edge_runtime]
enabled = true
policy = "per_worker"
# Do not commit inspector_port; local-only concern.

# OAuth providers explicitly disabled.
[auth.external.apple]
enabled = false
[auth.external.google]
enabled = false
[auth.external.github]
enabled = false
```

Keep any other stanzas that `supabase init` generated (e.g. `[analytics]`, `[inbucket]`) at their defaults — do not delete them.

- [ ] **Step 1.5: Create `backend/.gitignore`**

```bash
cat > backend/.gitignore <<'EOF'
# Supabase CLI local state
supabase/.branches/
supabase/.temp/
supabase/.env

# Function runtime artifacts
supabase/functions/*/node_modules/

# Local environment overrides (secrets live in the repo-root .env.local, not here)
.env
.env.local
EOF
```

- [ ] **Step 1.6: Verify scaffold + commit**

```bash
ls backend/supabase/
# Expect: config.toml, migrations/, (seed.sql may or may not exist)

git status
# Expect: backend/ untracked; no changes to frontend/.

git diff frontend/
# Expect: empty output.
```

Commit:
```bash
cd /home/coder/workspaces/menuray
git add backend/.gitignore backend/supabase/config.toml
git commit -m "$(cat <<'EOF'
chore(backend): scaffold supabase project via supabase init

project_id=menuray; phone OTP + email/password enabled; OAuth providers
explicitly disabled per spec.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Migration 1 — schema, indexes, touch trigger

**Goal:** Define all 9 tables with constraints + indexes + `updated_at` auto-maintenance.

**Files:**
- Create: `backend/supabase/migrations/20260420000001_init_schema.sql`

- [ ] **Step 2.1: Write the migration file**

Create `backend/supabase/migrations/20260420000001_init_schema.sql` with the exact contents below:

```sql
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
-- dish_translations / category_translations / store_translations get the
-- UNIQUE (x, locale) indexes for free via the UNIQUE constraint.

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
```

- [ ] **Step 2.2: Apply locally via `supabase start` + `db reset`**

```bash
cd /home/coder/workspaces/menuray/backend
supabase start
# First run pulls Docker images — takes a few minutes.
# Expect final output with API/DB/Studio URLs.

supabase db reset
# Applies every migration in migrations/ and (if present) seed.sql.
# Expect: "Finished supabase db reset on branch ...".
```

If `supabase db reset` fails:
- Read the SQL error carefully — missing extension, typo in CHECK constraint, etc.
- Do NOT delete the `supabase/` directory or wipe local state to "retry" — fix the SQL and run `supabase db reset` again.
- If `pgcrypto` is complained about: check `extra_search_path = ["public", "extensions"]` is in `config.toml` and that the `CREATE EXTENSION IF NOT EXISTS pgcrypto;` is the first statement.

- [ ] **Step 2.3: Verify table + index structure**

```bash
supabase db dump --local --schema public --data-only=false --file /tmp/menuray_schema.sql
# Should succeed; /tmp/menuray_schema.sql now holds the reconstructed schema.

grep -c "^CREATE TABLE" /tmp/menuray_schema.sql
# Expect: 9

grep -c "^CREATE INDEX" /tmp/menuray_schema.sql
# Expect: at least 8 (the explicit ones; UNIQUE indexes may appear differently).
```

Also confirm the 9 `touch_updated_at` triggers exist:
```bash
psql "postgresql://postgres:postgres@localhost:54322/postgres" -c \
  "SELECT tgname FROM pg_trigger WHERE tgname LIKE '%touch_updated_at' ORDER BY tgname;"
# Expect: 9 rows.
```

- [ ] **Step 2.4: Commit**

```bash
git add backend/supabase/migrations/20260420000001_init_schema.sql
git commit -m "$(cat <<'EOF'
feat(backend): init schema — 9 tables, indexes, touch_updated_at trigger, insert_menu_draft rpc

stores / menus / categories / dishes / dish_translations /
category_translations / store_translations / parse_runs / view_logs.
Redundant store_id on all owned tables for uniform RLS; TEXT+CHECK
over Postgres ENUM per ADR-014. insert_menu_draft(store_id, draft jsonb)
gives the parse-menu orchestrator a single-transaction write path
for menu + categories + dishes.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Migration 2 — RLS policies

**Goal:** Enable RLS on every table and add the four policy patterns from spec §4.

**Files:**
- Create: `backend/supabase/migrations/20260420000002_rls_policies.sql`

- [ ] **Step 3.1: Write the migration file**

Create `backend/supabase/migrations/20260420000002_rls_policies.sql`:

```sql
-- ============================================================================
-- Row-Level Security policies
-- See spec §4 for rationale.
-- ============================================================================

-- Enable RLS on all 9 tables.
ALTER TABLE stores                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE menus                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories             ENABLE ROW LEVEL SECURITY;
ALTER TABLE dishes                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE dish_translations      ENABLE ROW LEVEL SECURITY;
ALTER TABLE category_translations  ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_translations     ENABLE ROW LEVEL SECURITY;
ALTER TABLE parse_runs             ENABLE ROW LEVEL SECURITY;
ALTER TABLE view_logs              ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- Pattern 1 — owner R/W (authenticated role)
-- ============================================================================
CREATE POLICY stores_owner_rw ON stores FOR ALL TO authenticated
  USING      (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY menus_owner_rw ON menus FOR ALL TO authenticated
  USING      (store_id IN (SELECT id FROM stores WHERE owner_id = auth.uid()))
  WITH CHECK (store_id IN (SELECT id FROM stores WHERE owner_id = auth.uid()));

CREATE POLICY categories_owner_rw ON categories FOR ALL TO authenticated
  USING      (store_id IN (SELECT id FROM stores WHERE owner_id = auth.uid()))
  WITH CHECK (store_id IN (SELECT id FROM stores WHERE owner_id = auth.uid()));

CREATE POLICY dishes_owner_rw ON dishes FOR ALL TO authenticated
  USING      (store_id IN (SELECT id FROM stores WHERE owner_id = auth.uid()))
  WITH CHECK (store_id IN (SELECT id FROM stores WHERE owner_id = auth.uid()));

CREATE POLICY dish_translations_owner_rw ON dish_translations FOR ALL TO authenticated
  USING      (store_id IN (SELECT id FROM stores WHERE owner_id = auth.uid()))
  WITH CHECK (store_id IN (SELECT id FROM stores WHERE owner_id = auth.uid()));

CREATE POLICY category_translations_owner_rw ON category_translations FOR ALL TO authenticated
  USING      (store_id IN (SELECT id FROM stores WHERE owner_id = auth.uid()))
  WITH CHECK (store_id IN (SELECT id FROM stores WHERE owner_id = auth.uid()));

CREATE POLICY store_translations_owner_rw ON store_translations FOR ALL TO authenticated
  USING      (store_id IN (SELECT id FROM stores WHERE owner_id = auth.uid()))
  WITH CHECK (store_id IN (SELECT id FROM stores WHERE owner_id = auth.uid()));

CREATE POLICY parse_runs_owner_rw ON parse_runs FOR ALL TO authenticated
  USING      (store_id IN (SELECT id FROM stores WHERE owner_id = auth.uid()))
  WITH CHECK (store_id IN (SELECT id FROM stores WHERE owner_id = auth.uid()));

CREATE POLICY view_logs_owner_rw ON view_logs FOR ALL TO authenticated
  USING      (store_id IN (SELECT id FROM stores WHERE owner_id = auth.uid()))
  WITH CHECK (store_id IN (SELECT id FROM stores WHERE owner_id = auth.uid()));

-- ============================================================================
-- Pattern 2 — anon SELECT on published menus + children
-- ============================================================================
CREATE POLICY menus_anon_read_published ON menus FOR SELECT TO anon
  USING (status = 'published');

CREATE POLICY categories_anon_read ON categories FOR SELECT TO anon
  USING (menu_id IN (SELECT id FROM menus WHERE status = 'published'));

CREATE POLICY dishes_anon_read ON dishes FOR SELECT TO anon
  USING (menu_id IN (SELECT id FROM menus WHERE status = 'published'));

CREATE POLICY dish_translations_anon_read ON dish_translations FOR SELECT TO anon
  USING (dish_id IN (
    SELECT id FROM dishes
    WHERE menu_id IN (SELECT id FROM menus WHERE status = 'published')
  ));

CREATE POLICY category_translations_anon_read ON category_translations FOR SELECT TO anon
  USING (category_id IN (
    SELECT id FROM categories
    WHERE menu_id IN (SELECT id FROM menus WHERE status = 'published')
  ));

CREATE POLICY store_translations_anon_read ON store_translations FOR SELECT TO anon
  USING (store_id IN (SELECT store_id FROM menus WHERE status = 'published'));

-- ============================================================================
-- Pattern 3 — anon INSERT on view_logs for published menus only
-- ============================================================================
CREATE POLICY view_logs_anon_insert ON view_logs FOR INSERT TO anon
  WITH CHECK (
    menu_id IN (SELECT id FROM menus WHERE status = 'published')
    AND store_id = (SELECT store_id FROM menus WHERE id = menu_id)
  );
-- Intentionally no anon SELECT/UPDATE/DELETE on view_logs.

-- ============================================================================
-- Pattern 4 — service_role bypasses RLS automatically; no policy needed.
-- Note: anon and authenticated do NOT have SELECT on stores by default — only
-- the owner sees their own store via stores_owner_rw.
-- ============================================================================
```

- [ ] **Step 3.2: Apply + verify**

```bash
cd /home/coder/workspaces/menuray/backend
supabase db reset
# Expect: all migrations apply cleanly.
```

Verify RLS is enabled everywhere:
```bash
psql "postgresql://postgres:postgres@localhost:54322/postgres" -c \
  "SELECT relname, relrowsecurity FROM pg_class
   WHERE relname IN ('stores','menus','categories','dishes','dish_translations',
                     'category_translations','store_translations','parse_runs','view_logs')
   ORDER BY relname;"
# Expect: 9 rows, all with relrowsecurity = t.
```

Verify policies:
```bash
psql "postgresql://postgres:postgres@localhost:54322/postgres" -c \
  "SELECT COUNT(*) FROM pg_policies WHERE schemaname = 'public';"
# Expect: 16 (9 owner_rw + 6 anon_read + 1 anon_insert).
```

- [ ] **Step 3.3: Commit**

```bash
git add backend/supabase/migrations/20260420000002_rls_policies.sql
git commit -m "$(cat <<'EOF'
feat(backend): RLS policies — 16 policies across 9 tables

4 patterns: owner R/W via store_id, anon SELECT on published
menus/children, anon INSERT on view_logs with anti-forgery store_id
check, service_role implicit bypass.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Migration 3 — Storage buckets and policies

**Goal:** Create 3 buckets and the 10 `storage.objects` policies (3 per bucket + public read passthrough).

**Files:**
- Create: `backend/supabase/migrations/20260420000003_storage_buckets.sql`

- [ ] **Step 4.1: Write the migration file**

Create `backend/supabase/migrations/20260420000003_storage_buckets.sql`:

```sql
-- ============================================================================
-- Storage buckets
-- ============================================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('menu-photos', 'menu-photos', false, 10485760,  ARRAY['image/jpeg','image/png']::text[]),
  ('dish-images', 'dish-images', true,  5242880,   ARRAY['image/jpeg','image/png','image/webp']::text[]),
  ('store-logos', 'store-logos', true,  2097152,   ARRAY['image/png','image/svg+xml']::text[])
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- menu-photos — private bucket
--   owner INSERT / UPDATE / DELETE / SELECT via path prefix {store_id}/...
-- ============================================================================
CREATE POLICY owner_insert_menu_photos ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'menu-photos'
    AND (storage.foldername(name))[1]::uuid IN (
      SELECT id FROM public.stores WHERE owner_id = auth.uid()
    )
  );

CREATE POLICY owner_update_menu_photos ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'menu-photos'
    AND (storage.foldername(name))[1]::uuid IN (
      SELECT id FROM public.stores WHERE owner_id = auth.uid()
    )
  )
  WITH CHECK (
    bucket_id = 'menu-photos'
    AND (storage.foldername(name))[1]::uuid IN (
      SELECT id FROM public.stores WHERE owner_id = auth.uid()
    )
  );

CREATE POLICY owner_delete_menu_photos ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'menu-photos'
    AND (storage.foldername(name))[1]::uuid IN (
      SELECT id FROM public.stores WHERE owner_id = auth.uid()
    )
  );

CREATE POLICY owner_select_menu_photos ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'menu-photos'
    AND (storage.foldername(name))[1]::uuid IN (
      SELECT id FROM public.stores WHERE owner_id = auth.uid()
    )
  );

-- ============================================================================
-- dish-images — public bucket; public READ is automatic; owners write.
-- ============================================================================
CREATE POLICY owner_insert_dish_images ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'dish-images'
    AND (storage.foldername(name))[1]::uuid IN (
      SELECT id FROM public.stores WHERE owner_id = auth.uid()
    )
  );

CREATE POLICY owner_update_dish_images ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'dish-images'
    AND (storage.foldername(name))[1]::uuid IN (
      SELECT id FROM public.stores WHERE owner_id = auth.uid()
    )
  )
  WITH CHECK (
    bucket_id = 'dish-images'
    AND (storage.foldername(name))[1]::uuid IN (
      SELECT id FROM public.stores WHERE owner_id = auth.uid()
    )
  );

CREATE POLICY owner_delete_dish_images ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'dish-images'
    AND (storage.foldername(name))[1]::uuid IN (
      SELECT id FROM public.stores WHERE owner_id = auth.uid()
    )
  );

-- ============================================================================
-- store-logos — public bucket; public READ is automatic; owners write.
-- ============================================================================
CREATE POLICY owner_insert_store_logos ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'store-logos'
    AND (storage.foldername(name))[1]::uuid IN (
      SELECT id FROM public.stores WHERE owner_id = auth.uid()
    )
  );

CREATE POLICY owner_update_store_logos ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'store-logos'
    AND (storage.foldername(name))[1]::uuid IN (
      SELECT id FROM public.stores WHERE owner_id = auth.uid()
    )
  )
  WITH CHECK (
    bucket_id = 'store-logos'
    AND (storage.foldername(name))[1]::uuid IN (
      SELECT id FROM public.stores WHERE owner_id = auth.uid()
    )
  );

CREATE POLICY owner_delete_store_logos ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'store-logos'
    AND (storage.foldername(name))[1]::uuid IN (
      SELECT id FROM public.stores WHERE owner_id = auth.uid()
    )
  );
```

- [ ] **Step 4.2: Apply + verify**

```bash
cd /home/coder/workspaces/menuray/backend
supabase db reset
```

Verify buckets and policies:
```bash
psql "postgresql://postgres:postgres@localhost:54322/postgres" -c \
  "SELECT id, public FROM storage.buckets ORDER BY id;"
# Expect 3 rows:
#   dish-images | t
#   menu-photos | f
#   store-logos | t

psql "postgresql://postgres:postgres@localhost:54322/postgres" -c \
  "SELECT COUNT(*) FROM pg_policies WHERE schemaname='storage';"
# Expect: 10 (4 for menu-photos + 3 each for dish-images and store-logos).
```

- [ ] **Step 4.3: Commit**

```bash
git add backend/supabase/migrations/20260420000003_storage_buckets.sql
git commit -m "$(cat <<'EOF'
feat(backend): storage buckets — menu-photos (private), dish-images + store-logos (public)

10 storage.objects policies enforce {store_id}/<uuid>.<ext> path
prefix via storage.foldername(name)[1]. No image transforms
(paid Supabase feature; would break self-host parity).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Migration 4 — Signup trigger

**Goal:** Create `handle_new_user()` + AFTER INSERT trigger on `auth.users`.

**Files:**
- Create: `backend/supabase/migrations/20260420000004_signup_trigger.sql`

- [ ] **Step 5.1: Write the migration file**

Create `backend/supabase/migrations/20260420000004_signup_trigger.sql`:

```sql
-- ============================================================================
-- Signup trigger — auto-create a default store row when a new auth.users row
-- is inserted. SECURITY DEFINER + empty search_path is the Supabase-recommended
-- pattern (prevents search_path injection).
-- ============================================================================

CREATE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.stores (owner_id, name)
  VALUES (NEW.id, 'My restaurant');
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

- [ ] **Step 5.2: Apply + verify trigger fires**

```bash
cd /home/coder/workspaces/menuray/backend
supabase db reset
```

Simulate a signup and confirm the store appears:
```bash
psql "postgresql://postgres:postgres@localhost:54322/postgres" <<'SQL'
-- Insert a probe user directly into auth.users (this is what Supabase Auth does on signup).
INSERT INTO auth.users (id, instance_id, email, aud, role, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                        confirmation_token, email_change, email_change_token_new, recovery_token)
VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        '00000000-0000-0000-0000-000000000000',
        'trigger-probe@menuray.test',
        'authenticated', 'authenticated',
        now(),
        '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
        now(), now(),
        '', '', '', '');

SELECT id, owner_id, name FROM stores WHERE owner_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
-- Expect: 1 row with name = 'My restaurant'.

-- Clean up.
DELETE FROM auth.users WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
SELECT count(*) FROM stores WHERE owner_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
-- Expect: 0 (ON DELETE CASCADE removed the store).
SQL
```

- [ ] **Step 5.3: Commit**

```bash
git add backend/supabase/migrations/20260420000004_signup_trigger.sql
git commit -m "$(cat <<'EOF'
feat(backend): signup trigger — auto-create default store on auth.users INSERT

SECURITY DEFINER with empty search_path per Supabase guidance. Each
new auth.users row spawns one stores row with placeholder name
'My restaurant'; merchant UI updates it post-signup. Tied to
ADR-013 tenancy model.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Verify migrations replay cleanly from scratch

**Goal:** Sanity check that all 4 migrations can run from an empty DB. This is the "green build" checkpoint before building on top.

**Files:** none modified

- [ ] **Step 6.1: Full reset + re-verify counts**

```bash
cd /home/coder/workspaces/menuray/backend
supabase db reset
# Expect: clean success.

psql "postgresql://postgres:postgres@localhost:54322/postgres" <<'SQL'
SELECT 'tables' AS what, count(*) AS n FROM pg_tables WHERE schemaname='public'
UNION ALL
SELECT 'rls_enabled', count(*) FROM pg_class
  WHERE relnamespace='public'::regnamespace AND relrowsecurity=true AND relkind='r'
UNION ALL
SELECT 'public_policies', count(*) FROM pg_policies WHERE schemaname='public'
UNION ALL
SELECT 'storage_policies', count(*) FROM pg_policies WHERE schemaname='storage'
UNION ALL
SELECT 'buckets', count(*) FROM storage.buckets
UNION ALL
SELECT 'touch_triggers', count(*) FROM pg_trigger WHERE tgname LIKE '%_touch_updated_at'
UNION ALL
SELECT 'signup_trigger', count(*) FROM pg_trigger WHERE tgname='on_auth_user_created';
SQL
```

Expected counts:
| what | n |
|---|---|
| tables | 9 |
| rls_enabled | 9 |
| public_policies | 16 |
| storage_policies | 10 |
| buckets | 3 |
| touch_triggers | 9 |
| signup_trigger | 1 |

If any row's `n` is off, stop and investigate before moving on.

- [ ] **Step 6.2: Verify no frontend drift**

```bash
cd /home/coder/workspaces/menuray
git diff frontend/
# Expect: empty output.
```

No commit for this task — verification only.

---

## Task 7: Seed data (`seed.sql`)

**Goal:** After `supabase db reset`, the local DB should contain a demo user with a published menu mirroring `frontend/merchant/lib/shared/mock/mock_data.dart`.

**Files:**
- Create: `backend/supabase/seed.sql`

- [ ] **Step 7.1: Write seed.sql**

Create `backend/supabase/seed.sql`:

```sql
-- ============================================================================
-- MenuRay local seed data
--
-- Creates a demo auth user (seed@menuray.com / demo1234); signup trigger
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
  'seed@menuray.com',
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
  '{"sub":"11111111-1111-1111-1111-111111111111","email":"seed@menuray.com"}'::jsonb,
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
```

- [ ] **Step 7.2: Apply + verify row counts**

```bash
cd /home/coder/workspaces/menuray/backend
supabase db reset
# seed.sql runs automatically after migrations.

psql "postgresql://postgres:postgres@localhost:54322/postgres" <<'SQL'
SELECT 'users', count(*) FROM auth.users WHERE email='seed@menuray.com'
UNION ALL SELECT 'stores', count(*) FROM stores
UNION ALL SELECT 'menus', count(*) FROM menus WHERE status='published'
UNION ALL SELECT 'categories', count(*) FROM categories
UNION ALL SELECT 'dishes', count(*) FROM dishes
UNION ALL SELECT 'dish_translations', count(*) FROM dish_translations
UNION ALL SELECT 'category_translations', count(*) FROM category_translations
UNION ALL SELECT 'store_translations', count(*) FROM store_translations
UNION ALL SELECT 'parse_runs', count(*) FROM parse_runs WHERE status='succeeded';
SQL
```

Expected:

| row | count |
|---|---|
| users | 1 |
| stores | 1 |
| menus | 1 |
| categories | 2 |
| dishes | 5 |
| dish_translations | 4 |
| category_translations | 2 |
| store_translations | 1 |
| parse_runs | 1 |

- [ ] **Step 7.3: Commit**

```bash
git add backend/supabase/seed.sql
git commit -m "$(cat <<'EOF'
feat(backend): seed data — demo user + published menu mirroring mock_data.dart

seed@menuray.com / demo1234 owns 云间小厨 · 静安店 with one published
lunch menu (slug yun-jian-xiao-chu-lunch-2025) containing 2 categories
and 5 dishes + English translations for named dishes/categories/store.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Edge function — provider interfaces, fixture, import_map

**Goal:** Define the shared DTO + interface types and the fixture JSON the mock adapters will return.

**Files:**
- Create: `backend/supabase/functions/import_map.json`
- Create: `backend/supabase/functions/_shared/providers/types.ts`
- Create: `backend/supabase/functions/parse-menu/fixtures/yun_jian_xiao_chu.json`

- [ ] **Step 8.1: Write `import_map.json`**

Create `backend/supabase/functions/import_map.json`:

```json
{
  "imports": {
    "std/": "https://deno.land/std@0.224.0/",
    "@supabase/supabase-js": "https://esm.sh/@supabase/supabase-js@2.45.0"
  }
}
```

- [ ] **Step 8.2: Write `_shared/providers/types.ts`**

Create `backend/supabase/functions/_shared/providers/types.ts`:

```typescript
// ============================================================================
// Provider interfaces and shared DTOs for the parse-menu pipeline.
// See docs/superpowers/specs/2026-04-19-supabase-backend-mvp-design.md §7.
// ============================================================================

export type OcrBlock = {
  text: string;
  bbox: [number, number, number, number]; // [x, y, w, h] normalized 0..1
};

export type OcrResult = {
  fullText: string;
  blocks: OcrBlock[];
  sourceLocale?: string;
};

export interface OcrProvider {
  readonly name: string;
  extract(photoUrls: string[]): Promise<OcrResult>;
}

export type SpiceLevel = "none" | "mild" | "medium" | "hot";
export type Confidence = "high" | "low";

export type MenuDraftDish = {
  sourceName: string;
  sourceDescription?: string;
  price: number;
  position: number;
  spiceLevel: SpiceLevel;
  confidence: Confidence;
  isSignature: boolean;
  isRecommended: boolean;
  isVegetarian: boolean;
  allergens: string[];
};

export type MenuDraftCategory = {
  sourceName: string;
  position: number;
  dishes: MenuDraftDish[];
};

export type MenuDraft = {
  name: string;
  sourceLocale: string;
  currency: string; // ISO 4217
  categories: MenuDraftCategory[];
};

export interface LlmProvider {
  readonly name: string;
  structure(
    ocr: OcrResult,
    hints: { sourceLocale?: string; currency?: string },
  ): Promise<MenuDraft>;
}
```

- [ ] **Step 8.3: Write the fixture**

Create `backend/supabase/functions/parse-menu/fixtures/yun_jian_xiao_chu.json`:

```json
{
  "ocr": {
    "fullText": "云间小厨 · 静安店\n午市套餐 2025 春\n\n凉菜\n口水鸡 ¥38\n凉拌黄瓜 ¥18\n川北凉粉 ¥22\n\n热菜\n宫保鸡丁 ¥48 经典川菜，鸡丁、花生与干辣椒同炒\n麻婆豆腐 ¥32\n",
    "blocks": [
      { "text": "云间小厨 · 静安店", "bbox": [0.05, 0.02, 0.90, 0.05] },
      { "text": "午市套餐 2025 春", "bbox": [0.05, 0.08, 0.90, 0.05] },
      { "text": "凉菜",           "bbox": [0.05, 0.18, 0.20, 0.04] },
      { "text": "口水鸡 ¥38",     "bbox": [0.10, 0.24, 0.70, 0.04] },
      { "text": "凉拌黄瓜 ¥18",   "bbox": [0.10, 0.30, 0.70, 0.04] },
      { "text": "川北凉粉 ¥22",   "bbox": [0.10, 0.36, 0.70, 0.04] },
      { "text": "热菜",           "bbox": [0.05, 0.46, 0.20, 0.04] },
      { "text": "宫保鸡丁 ¥48",   "bbox": [0.10, 0.52, 0.70, 0.04] },
      { "text": "经典川菜，鸡丁、花生与干辣椒同炒", "bbox": [0.10, 0.57, 0.80, 0.04] },
      { "text": "麻婆豆腐 ¥32",   "bbox": [0.10, 0.64, 0.70, 0.04] }
    ],
    "sourceLocale": "zh-CN"
  },
  "menu_draft": {
    "name": "午市套餐 2025 春",
    "sourceLocale": "zh-CN",
    "currency": "CNY",
    "categories": [
      {
        "sourceName": "凉菜",
        "position": 0,
        "dishes": [
          {
            "sourceName": "口水鸡",
            "price": 38,
            "position": 0,
            "spiceLevel": "medium",
            "confidence": "high",
            "isSignature": false,
            "isRecommended": false,
            "isVegetarian": false,
            "allergens": []
          },
          {
            "sourceName": "凉拌黄瓜",
            "price": 18,
            "position": 1,
            "spiceLevel": "none",
            "confidence": "high",
            "isSignature": false,
            "isRecommended": false,
            "isVegetarian": true,
            "allergens": []
          },
          {
            "sourceName": "川北凉粉",
            "price": 22,
            "position": 2,
            "spiceLevel": "medium",
            "confidence": "low",
            "isSignature": false,
            "isRecommended": false,
            "isVegetarian": false,
            "allergens": []
          }
        ]
      },
      {
        "sourceName": "热菜",
        "position": 1,
        "dishes": [
          {
            "sourceName": "宫保鸡丁",
            "sourceDescription": "经典川菜，鸡丁、花生与干辣椒同炒，咸甜微辣。",
            "price": 48,
            "position": 0,
            "spiceLevel": "medium",
            "confidence": "high",
            "isSignature": true,
            "isRecommended": true,
            "isVegetarian": false,
            "allergens": ["花生"]
          },
          {
            "sourceName": "麻婆豆腐",
            "price": 32,
            "position": 1,
            "spiceLevel": "hot",
            "confidence": "high",
            "isSignature": false,
            "isRecommended": false,
            "isVegetarian": false,
            "allergens": []
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 8.4: Verify JSON is valid + commit**

```bash
python3 -m json.tool backend/supabase/functions/parse-menu/fixtures/yun_jian_xiao_chu.json > /dev/null
python3 -m json.tool backend/supabase/functions/import_map.json > /dev/null
# Expect: no errors.
```

```bash
git add backend/supabase/functions/import_map.json \
        backend/supabase/functions/_shared/providers/types.ts \
        backend/supabase/functions/parse-menu/fixtures/yun_jian_xiao_chu.json
git commit -m "$(cat <<'EOF'
feat(backend): provider interfaces + fixture for parse-menu

OcrProvider / LlmProvider + MenuDraft DTOs; fixture mirrors the 5
dishes from frontend/merchant/lib/shared/mock/mock_data.dart so the
end-to-end path produces data that matches existing UI.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Edge function — mock providers + factory

**Goal:** Implement `MockOcrProvider`, `MockLlmProvider`, and a `getProvider()` factory that defaults to mock and switches via env var.

**Files:**
- Create: `backend/supabase/functions/_shared/providers/mock_ocr.ts`
- Create: `backend/supabase/functions/_shared/providers/mock_llm.ts`
- Create: `backend/supabase/functions/_shared/providers/factory.ts`

- [ ] **Step 9.1: Write `mock_ocr.ts`**

Create `backend/supabase/functions/_shared/providers/mock_ocr.ts`:

```typescript
import type { OcrProvider, OcrResult } from "./types.ts";

// Read fixture at module init time. Deno supports static fixture paths
// relative to the module URL.
const FIXTURE_URL = new URL(
  "../../parse-menu/fixtures/yun_jian_xiao_chu.json",
  import.meta.url,
);

type Fixture = { ocr: OcrResult };

let cachedFixture: Fixture | null = null;

async function loadFixture(): Promise<Fixture> {
  if (cachedFixture) return cachedFixture;
  const text = await Deno.readTextFile(FIXTURE_URL);
  cachedFixture = JSON.parse(text) as Fixture;
  return cachedFixture;
}

export class MockOcrProvider implements OcrProvider {
  readonly name = "mock";

  async extract(_photoUrls: string[]): Promise<OcrResult> {
    await new Promise((resolve) => setTimeout(resolve, 0));
    const { ocr } = await loadFixture();
    return ocr;
  }
}
```

- [ ] **Step 9.2: Write `mock_llm.ts`**

Create `backend/supabase/functions/_shared/providers/mock_llm.ts`:

```typescript
import type { LlmProvider, MenuDraft, OcrResult } from "./types.ts";

const FIXTURE_URL = new URL(
  "../../parse-menu/fixtures/yun_jian_xiao_chu.json",
  import.meta.url,
);

type Fixture = { menu_draft: MenuDraft };

let cachedFixture: Fixture | null = null;

async function loadFixture(): Promise<Fixture> {
  if (cachedFixture) return cachedFixture;
  const text = await Deno.readTextFile(FIXTURE_URL);
  cachedFixture = JSON.parse(text) as Fixture;
  return cachedFixture;
}

export class MockLlmProvider implements LlmProvider {
  readonly name = "mock";

  async structure(
    _ocr: OcrResult,
    _hints: { sourceLocale?: string; currency?: string },
  ): Promise<MenuDraft> {
    await new Promise((resolve) => setTimeout(resolve, 0));
    const { menu_draft } = await loadFixture();
    return menu_draft;
  }
}
```

- [ ] **Step 9.3: Write `factory.ts`**

Create `backend/supabase/functions/_shared/providers/factory.ts`:

```typescript
import type { LlmProvider, OcrProvider } from "./types.ts";
import { MockOcrProvider } from "./mock_ocr.ts";
import { MockLlmProvider } from "./mock_llm.ts";

export function getOcrProvider(): OcrProvider {
  const name = Deno.env.get("MENURAY_OCR_PROVIDER") ?? "mock";
  switch (name) {
    case "mock":
      return new MockOcrProvider();
    // case "google": return new GoogleVisionProvider();  // future session
    default:
      throw new Error(`Unknown OCR provider: ${name}`);
  }
}

export function getLlmProvider(): LlmProvider {
  const name = Deno.env.get("MENURAY_LLM_PROVIDER") ?? "mock";
  switch (name) {
    case "mock":
      return new MockLlmProvider();
    // case "anthropic": return new AnthropicLlmProvider();  // future session
    // case "openai":    return new OpenAiLlmProvider();     // future session
    default:
      throw new Error(`Unknown LLM provider: ${name}`);
  }
}
```

- [ ] **Step 9.4: Type-check**

The Supabase CLI bundles Deno. Run:
```bash
cd /home/coder/workspaces/menuray/backend
supabase functions deploy parse-menu --dry-run 2>&1 | head -20
# Expect: either "deployment skipped" or a type check pass. If errors, read them.
```

If `--dry-run` is not supported on your CLI version, use:
```bash
deno check --import-map=backend/supabase/functions/import_map.json \
  backend/supabase/functions/_shared/providers/factory.ts
```
(If `deno` isn't installed: `brew install deno` or `curl -fsSL https://deno.land/install.sh | sh`.)

Expect: no type errors. If Deno complains about missing `supabase-js` types for `factory.ts`, ignore — this file doesn't use it. Type errors in the provider files proper are real and must be fixed.

- [ ] **Step 9.5: Commit**

```bash
git add backend/supabase/functions/_shared/providers/
git commit -m "$(cat <<'EOF'
feat(backend): mock OCR + LLM providers + env-var factory

MockOcrProvider + MockLlmProvider both load and cache the same
fixture; factory defaults to 'mock' and switches via MENURAY_OCR_PROVIDER /
MENURAY_LLM_PROVIDER. Real providers slot in as new files + one
case each in the factory.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Edge function — DB client + orchestrator

**Goal:** Implement the service-role DB client helper and the pipeline orchestrator.

**Files:**
- Create: `backend/supabase/functions/_shared/db.ts`
- Create: `backend/supabase/functions/parse-menu/orchestrator.ts`

- [ ] **Step 10.1: Write `_shared/db.ts`**

Create `backend/supabase/functions/_shared/db.ts`:

```typescript
import { createClient, SupabaseClient } from "@supabase/supabase-js";

export function createServiceRoleClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) {
    throw new Error(
      "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in the function environment.",
    );
  }
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export function createAnonClientWithJwt(jwt: string): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !anonKey) {
    throw new Error(
      "SUPABASE_URL and SUPABASE_ANON_KEY must be set in the function environment.",
    );
  }
  return createClient(url, anonKey, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
```

- [ ] **Step 10.2: Write `parse-menu/orchestrator.ts`**

Create `backend/supabase/functions/parse-menu/orchestrator.ts`:

```typescript
import type { SupabaseClient } from "@supabase/supabase-js";
import type { LlmProvider, MenuDraft, OcrProvider } from "../_shared/providers/types.ts";
import { createServiceRoleClient } from "../_shared/db.ts";
import { getLlmProvider, getOcrProvider } from "../_shared/providers/factory.ts";

type ParseRunRow = {
  id: string;
  store_id: string;
  menu_id: string | null;
  source_photo_paths: string[];
  status: "pending" | "ocr" | "structuring" | "succeeded" | "failed";
};

async function fetchRun(db: SupabaseClient, runId: string): Promise<ParseRunRow> {
  const { data, error } = await db
    .from("parse_runs")
    .select("id, store_id, menu_id, source_photo_paths, status")
    .eq("id", runId)
    .single();
  if (error) throw new Error(`parse_runs.select failed: ${error.message}`);
  if (!data) throw new Error(`parse_runs row ${runId} not found`);
  return data as ParseRunRow;
}

async function updateRun(
  db: SupabaseClient,
  runId: string,
  patch: Record<string, unknown>,
): Promise<void> {
  const { error } = await db.from("parse_runs").update(patch).eq("id", runId);
  if (error) throw new Error(`parse_runs.update failed: ${error.message}`);
}

async function insertDraftMenu(
  db: SupabaseClient,
  storeId: string,
  draft: MenuDraft,
): Promise<string> {
  // Call the plpgsql function insert_menu_draft which inserts
  // menu + categories + dishes in a single transaction. See migration
  // 20260420000001_init_schema.sql for the function definition.
  const { data, error } = await db.rpc("insert_menu_draft", {
    p_store_id: storeId,
    p_draft: draft,
  });
  if (error) throw new Error(`insert_menu_draft rpc failed: ${error.message}`);
  if (!data) throw new Error("insert_menu_draft returned no menu id");
  return data as string;
}

export async function runParse(
  runId: string,
  opts: {
    db?: SupabaseClient;
    ocr?: OcrProvider;
    llm?: LlmProvider;
  } = {},
): Promise<ParseRunRow["status"]> {
  const db = opts.db ?? createServiceRoleClient();
  const ocr = opts.ocr ?? getOcrProvider();
  const llm = opts.llm ?? getLlmProvider();

  const run = await fetchRun(db, runId);

  // Idempotency: terminal states return immediately.
  if (run.status === "succeeded" || run.status === "failed") return run.status;

  let stage: "ocr" | "structure" = "ocr";
  try {
    await updateRun(db, runId, {
      status: "ocr",
      ocr_provider: ocr.name,
      started_at: new Date().toISOString(),
    });
    const ocrResult = await ocr.extract(run.source_photo_paths);

    stage = "structure";
    await updateRun(db, runId, {
      status: "structuring",
      llm_provider: llm.name,
    });
    const draft = await llm.structure(ocrResult, {
      sourceLocale: ocrResult.sourceLocale,
    });

    const menuId = await insertDraftMenu(db, run.store_id, draft);

    await updateRun(db, runId, {
      status: "succeeded",
      menu_id: menuId,
      finished_at: new Date().toISOString(),
    });
    return "succeeded";
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    await updateRun(db, runId, {
      status: "failed",
      error_stage: stage,
      error_message: message,
      finished_at: new Date().toISOString(),
    });
    return "failed";
  }
}
```

- [ ] **Step 10.3: Type-check**

```bash
deno check --import-map=backend/supabase/functions/import_map.json \
  backend/supabase/functions/parse-menu/orchestrator.ts
# Expect: no errors.
```

- [ ] **Step 10.4: Commit**

```bash
git add backend/supabase/functions/_shared/db.ts \
        backend/supabase/functions/parse-menu/orchestrator.ts
git commit -m "$(cat <<'EOF'
feat(backend): orchestrator + service-role DB client for parse-menu

runParse(runId) is idempotent (terminal states return immediately),
executes ocr→structure→insert_menu_draft (rpc)→mark-succeeded; on
any throw marks failed with error_stage+message. Menu/categories/
dishes INSERT is atomic via the insert_menu_draft plpgsql function
(spec §7.3). Providers and db client injected via opts for future
unit testing.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Edge function — HTTP handler, function README, end-to-end smoke

**Goal:** Wire the orchestrator to an HTTP handler, document invocation, and run a smoke test against the seeded demo run.

**Files:**
- Create: `backend/supabase/functions/parse-menu/index.ts`
- Create: `backend/supabase/functions/parse-menu/README.md`

- [ ] **Step 11.1: Write `index.ts`**

Create `backend/supabase/functions/parse-menu/index.ts`:

```typescript
import { createAnonClientWithJwt } from "../_shared/db.ts";
import { runParse } from "./orchestrator.ts";

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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const auth = req.headers.get("Authorization");
  if (!auth || !auth.startsWith("Bearer ")) {
    return jsonResponse({ error: "missing_authorization" }, 401);
  }
  const jwt = auth.slice("Bearer ".length);

  let body: { run_id?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json_body" }, 400);
  }
  const runId = body.run_id;
  if (!runId) {
    return jsonResponse({ error: "run_id_required" }, 400);
  }

  // Check user owns this run via their JWT (RLS kicks in on the anon client).
  const anonDb = createAnonClientWithJwt(jwt);
  const { data: row, error } = await anonDb
    .from("parse_runs")
    .select("id")
    .eq("id", runId)
    .maybeSingle();
  if (error) return jsonResponse({ error: "lookup_failed", detail: error.message }, 500);
  if (!row) return jsonResponse({ error: "run_not_found_or_forbidden" }, 404);

  // Proceed with service_role client for the actual work.
  const finalStatus = await runParse(runId);
  return jsonResponse({ run_id: runId, status: finalStatus });
});
```

- [ ] **Step 11.2: Write `parse-menu/README.md`**

Create `backend/supabase/functions/parse-menu/README.md`:

````markdown
# parse-menu — Edge Function

Turns `{ run_id }` into a completed draft menu by running the OCR → structuring pipeline. P0 uses mock adapters; real OCR / LLM providers are a future session.

## Contract

- **Method:** `POST`
- **Auth:** user JWT in `Authorization: Bearer <token>`.
- **Body:** `{ "run_id": "<uuid>" }`. The `parse_runs` row must already exist and belong to the caller (enforced by RLS).
- **Response:** `{ "run_id": "<uuid>", "status": "succeeded" | "failed" }`.
- **Idempotency:** re-invoking with the same `run_id` after terminal status returns the existing status without reprocessing.

## Local test

After `supabase start` + `supabase db reset`, the seed has a pre-completed run `22222222-...`. Smoke-test by creating a fresh pending run:

```bash
# Grab the seed user's JWT via email/password.
curl -s -X POST "http://localhost:54321/auth/v1/token?grant_type=password" \
  -H "apikey: $(supabase status --output json | jq -r .ANON_KEY)" \
  -H "Content-Type: application/json" \
  -d '{"email":"seed@menuray.com","password":"demo1234"}' \
  | jq -r .access_token > /tmp/seed_jwt.txt

# Insert a fresh pending parse_runs row (via service_role; migration RLS would normally allow the owner too).
JWT=$(cat /tmp/seed_jwt.txt)
psql "postgresql://postgres:postgres@localhost:54322/postgres" <<'SQL'
INSERT INTO parse_runs (store_id, source_photo_paths, status)
SELECT id, ARRAY[id || '/smoke-test.jpg']::text[], 'pending'
FROM stores WHERE owner_id = '11111111-1111-1111-1111-111111111111';
SQL

NEW_RUN=$(psql -t -A "postgresql://postgres:postgres@localhost:54322/postgres" -c \
  "SELECT id FROM parse_runs WHERE status='pending' ORDER BY created_at DESC LIMIT 1;")

curl -s -X POST "http://localhost:54321/functions/v1/parse-menu" \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d "{\"run_id\":\"$NEW_RUN\"}"
# Expect: {"run_id":"<uuid>","status":"succeeded"}
```

Then verify the resulting menu was inserted:

```bash
psql "postgresql://postgres:postgres@localhost:54322/postgres" -c \
  "SELECT name, status FROM menus ORDER BY created_at DESC LIMIT 2;"
```

## Swapping providers

Two env vars control which provider runs:
- `MENURAY_OCR_PROVIDER` (default `mock`)
- `MENURAY_LLM_PROVIDER` (default `mock`)

Add a new provider by:
1. Implementing `OcrProvider` or `LlmProvider` (see `../_shared/providers/types.ts`).
2. Dropping the file in `../_shared/providers/`.
3. Adding one `case` in `../_shared/providers/factory.ts`.
4. Setting the env var in the Supabase dashboard (or `supabase/.env` locally).
````

- [ ] **Step 11.3: Serve function locally + smoke test**

In one terminal:
```bash
cd /home/coder/workspaces/menuray/backend
supabase functions serve parse-menu --import-map supabase/functions/import_map.json
# Leave running.
```

In another terminal, follow the README's `curl` block. Confirm:
- Response is `{"run_id":"...","status":"succeeded"}`.
- `menus` now has a second row with `name='午市套餐 2025 春'` and `status='draft'`.
- The new menu has 2 categories and 5 dishes (same as the seeded published one — distinct rows).

Stop the `supabase functions serve` process (Ctrl-C).

- [ ] **Step 11.4: Commit**

```bash
git add backend/supabase/functions/parse-menu/index.ts \
        backend/supabase/functions/parse-menu/README.md
git commit -m "$(cat <<'EOF'
feat(backend): parse-menu HTTP handler + README

POST { run_id } → verifies JWT-scoped ownership via RLS, then runs
orchestrator with service-role client, returns final status. Handler
synchronous for P0 (mock providers are instant); real providers will
flip to EdgeRuntime.waitUntil() in a later session without changing
the orchestrator.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: `backend/README.md`

**Goal:** A newcomer can clone the repo and get a working local backend + parse-menu demo in ~5 minutes.

**Files:**
- Create: `backend/README.md`

- [ ] **Step 12.1: Write `backend/README.md`**

Create `backend/README.md`:

````markdown
# MenuRay — Backend

Supabase-powered backend: Postgres + Auth + Storage + Edge Functions. This directory holds schema migrations, RLS policies, seed data, and the `parse-menu` Edge Function scaffold (with mock OCR / LLM adapters).

Design spec: [`docs/superpowers/specs/2026-04-19-supabase-backend-mvp-design.md`](../docs/superpowers/specs/2026-04-19-supabase-backend-mvp-design.md).

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) running.
- [Supabase CLI](https://supabase.com/docs/guides/cli) ≥ 1.150: `brew install supabase/tap/supabase` or `curl -fsSL https://supabase.com/install.sh | sh`.
- [Deno](https://deno.land/) (optional; only needed for direct `deno check` / function development outside the Supabase CLI).

## First-run setup

```bash
cd backend
supabase start        # pulls Docker images on first run
supabase db reset     # applies migrations + seed.sql
```

The `supabase start` output prints local URLs:

```
API URL:   http://localhost:54321
DB URL:    postgresql://postgres:postgres@localhost:54322/postgres
Studio:    http://localhost:54323
```

Studio (http://localhost:54323) is a local web UI for inspecting tables, running SQL, and browsing Storage.

## Seeded demo

`supabase db reset` runs `seed.sql` after migrations, producing:

- Demo user: `seed@menuray.com` / `demo1234` (email login).
- Store: 云间小厨 · 静安店 (auto-created via signup trigger, then updated).
- One published menu `午市套餐 2025 春`, slug `yun-jian-xiao-chu-lunch-2025`, CNY, `zh-CN`, containing 凉菜 (3 dishes) + 热菜 (2 dishes) — mirrors `frontend/merchant/lib/shared/mock/mock_data.dart`.
- English translations for named dishes, categories, and the store.
- One completed `parse_runs` row (for testing idempotency / Realtime subscription).

## Running `parse-menu`

See [`supabase/functions/parse-menu/README.md`](supabase/functions/parse-menu/README.md) for the full curl-based demo.

Quick version:
```bash
supabase functions serve parse-menu --import-map supabase/functions/import_map.json
# In another terminal, follow the README's curl block.
```

## Schema overview

9 tables in the `public` schema — `stores`, `menus`, `categories`, `dishes`, `dish_translations`, `category_translations`, `store_translations`, `parse_runs`, `view_logs` — all with RLS enabled. Owner access is keyed off a redundant `store_id` column; anonymous diner reads are limited to children of `menus.status='published'`.

3 Storage buckets: `menu-photos` (private — OCR input), `dish-images` (public read), `store-logos` (public read). All paths follow `{store_id}/<uuid>.<ext>`.

## Adding a new OCR / LLM provider

1. Add one file under `supabase/functions/_shared/providers/` implementing `OcrProvider` or `LlmProvider` from `types.ts`.
2. Add one `case` to `factory.ts`.
3. Set `MENURAY_OCR_PROVIDER` or `MENURAY_LLM_PROVIDER` in the Supabase dashboard (or `supabase/.env` locally).

No orchestrator change required. See ADR-010 in [`docs/decisions.md`](../docs/decisions.md).

## Common commands

| Purpose | Command |
|---|---|
| Start local stack | `supabase start` |
| Stop local stack | `supabase stop` |
| Reset local DB + re-run migrations + seed | `supabase db reset` |
| Tail logs | `supabase functions logs parse-menu` |
| Serve a function locally | `supabase functions serve parse-menu --import-map supabase/functions/import_map.json` |
| Push migrations to hosted project | `supabase db push --db-url "$SUPABASE_DB_URL"` |
| Deploy function to hosted project | `supabase functions deploy parse-menu --project-ref idwhukvigkoevaakhsqv` |

> **Do not run `db push` or `functions deploy` as part of the initial scaffold work.** Those happen in a separate, reviewed session after the hosted project's env is confirmed.

## Deploying to hosted Supabase

Credentials live in the repo-root `.env.local` (gitignored). The committed `.env.local.example` lists the expected variables (`SUPABASE_URL`, `SUPABASE_PROJECT_REF`, `SUPABASE_DB_URL`, `SUPABASE_SERVICE_ROLE_KEY`, etc.).

Before deploying:
1. Confirm the hosted project's ref matches `SUPABASE_PROJECT_REF`.
2. Set `MENURAY_OCR_PROVIDER` and `MENURAY_LLM_PROVIDER` (default `mock`; override per session).
3. Set the SMS provider credentials in the dashboard (Auth → Providers → Phone).

`supabase db push` is one-way — review migrations carefully first.
````

- [ ] **Step 12.2: Commit**

```bash
git add backend/README.md
git commit -m "$(cat <<'EOF'
docs(backend): README — setup, seed walkthrough, provider-swap guide

Covers prerequisites, supabase start + db reset first run, seeded
demo user/menu, parse-menu smoke test pointer, schema overview, and
how to add a provider without touching the orchestrator.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: ADRs + architecture.md + root README updates

**Goal:** Record the 4 new architecture decisions and update the top-level docs to reflect that the backend scaffold now exists.

**Files:**
- Modify: `docs/decisions.md` (append ADR-013 through ADR-016)
- Modify: `docs/architecture.md` (annotate Backend section)
- Modify: `README.md` (tech stack row)

- [ ] **Step 13.1: Append ADRs to `docs/decisions.md`**

Open `docs/decisions.md` and find the "How to add an ADR" section near the bottom. Insert the following four ADRs directly above that section (after ADR-012):

```markdown
---

## ADR-013 — Tenancy: `stores.owner_id` 1:1 with `auth.users`

**Date:** 2026-04-19
**Status:** Accepted

**Context:** The P0 backend needs a multi-tenancy boundary for RLS. Roadmap defers multi-store / chain accounts and staff sub-accounts to P2.

**Decision:** `stores.owner_id uuid UNIQUE REFERENCES auth.users(id)` — one user owns exactly one store. A `handle_new_user()` trigger on `auth.users` INSERT auto-creates a default store row so `auth.uid()` always maps to exactly one store.

**Alternatives considered:**
- A `memberships(user_id, store_id, role)` junction from day 1. Cleaner future migration path, but unnecessary ceremony for P0/P1 where no shared-ownership scenario exists.

**Consequences:**
- ✅ RLS policies are one-line subqueries: `store_id IN (SELECT id FROM stores WHERE owner_id = auth.uid())`.
- ✅ Zero join overhead in hot paths.
- ⚠️ Adding P2 chain / staff will require a one-time migration: introduce `memberships`, seed it with `(owner_id, store_id, 'owner')` for every existing store, flip RLS policies to reference `memberships`. Cost is small and localized.

---

## ADR-014 — Postgres conventions: `TEXT + CHECK` over `ENUM`; redundant `store_id` on owned tables

**Date:** 2026-04-19
**Status:** Accepted

**Context:** Several columns are constrained to a small set of values (`menu.status`, `dish.spice_level`, `parse_runs.status`, etc.). The schema also repeatedly asks "does this row belong to the current user's store?" for RLS.

**Decision:**
- Use `TEXT` columns with `CHECK (col IN (...))` constraints rather than Postgres `ENUM` types.
- Every owned table carries a redundant `store_id` column (even when derivable from a parent FK).

**Alternatives considered:**
- Postgres `ENUM`: harder to migrate (cannot `DROP VALUE`; requires careful `ALTER TYPE … ADD VALUE` with transaction quirks); cast-unfriendly in policy subqueries.
- Normalized access-control: derive `store_id` via joins in every RLS policy — more joins at every read, higher CPU.

**Consequences:**
- ✅ Adding/removing a value is a one-line `ALTER TABLE … DROP CONSTRAINT … ADD CONSTRAINT` migration.
- ✅ One RLS policy template applies verbatim to every owned table.
- ⚠️ `store_id` must be kept correct on writes. The orchestrator carries `store_id` explicitly through the pipeline; application code does too. Application-level bugs that write the wrong `store_id` would create cross-tenant visibility — caught by integration tests.

---

## ADR-015 — Parse pipeline: single `parse-menu` Edge Function + `parse_runs` status table

**Date:** 2026-04-19
**Status:** Accepted

**Context:** The photo-to-digital-menu pipeline has two distinct stages (OCR, LLM structuring) plus a DB write. It runs 10–30s once real providers are wired in. We need both a clean provider-swap boundary (ADR-010) and a status-tracking mechanism for clients.

**Decision:** One Edge Function `parse-menu` that orchestrates both stages in a linear pipeline. Progress and final outcome are recorded on a `parse_runs` row, keyed by `id`. Clients subscribe to Realtime updates or poll the row.

**Alternatives considered:**
- Split into three functions (`extract-text`, `structure-menu`, `translate-menu`). More boundaries; more deployment surface for P0.
- A step-parameterized single function, driven by the client. Adds client-side orchestration complexity without a clear benefit.

**Consequences:**
- ✅ P0 is simple: one function, one HTTP contract, one RLS-scoped table.
- ✅ `parse_runs.error_stage` ∈ `{'ocr','structure'}` records the seam where a split could later happen.
- ⚠️ If OCR caching by photo hash becomes a need, it lives inside the function for now (or in a new helper table) rather than its own function.

---

## ADR-016 — Storage path convention: `{store_id}/<uuid>.<ext>`

**Date:** 2026-04-19
**Status:** Accepted

**Context:** Three Storage buckets (`menu-photos`, `dish-images`, `store-logos`) all scope by store. We need a way to enforce per-store isolation via RLS on `storage.objects`.

**Decision:** All object keys start with `{store_id}/`, and all three buckets share one RLS-policy template that tests `(storage.foldername(name))[1]::uuid` against `stores.owner_id = auth.uid()`. File names inside that prefix are random UUIDs plus extension, generated client-side.

**Alternatives considered:**
- A central `files(id, bucket, path, store_id, …)` index table + RLS on it — requires a new table + sync on every upload.
- Signed URLs for all reads — OK for private bucket, wasteful for public buckets where the CDN benefits from stable keys.

**Consequences:**
- ✅ Uniform policy across three buckets.
- ✅ Listing/filtering objects by store is fast (common prefix).
- ⚠️ Path traversal attempts (`../`) are blocked by Supabase Storage's name normalization — but we rely on it being correct. Any change there is a breach condition for this convention.
```

Also update the header row table at the top of `docs/decisions.md` if there's an ADR index (the current file doesn't have one, so nothing to do there).

- [ ] **Step 13.2: Annotate `docs/architecture.md`**

Find the section `### 3. Backend — Supabase`. After the paragraph ending "...primarily orchestrating OCR + LLM calls for menu parsing.", insert this new subsection:

```markdown
**Data schema:** 9 tables in `public` schema: `stores`, `menus`, `categories`, `dishes`, `dish_translations`, `category_translations`, `store_translations`, `parse_runs`, `view_logs`. All owned tables carry a redundant `store_id` for a uniform RLS template (ADR-014). Three Storage buckets (`menu-photos`, `dish-images`, `store-logos`) share a `{store_id}/<uuid>.<ext>` path convention (ADR-016). See `backend/supabase/migrations/` for the concrete DDL and `docs/superpowers/specs/2026-04-19-supabase-backend-mvp-design.md` for the design rationale.

**Parse pipeline status tracking:** The `parse-menu` Edge Function writes progress onto a `parse_runs` row (`pending → ocr → structuring → succeeded | failed`). Clients subscribe via Supabase Realtime (or poll the row) and pick up the final `menu_id` from it. See ADR-015.
```

Find the `Data flow: photo to digital menu` diagram. On the line `│ Edge Function  │` box, optionally add a note below the diagram: "*The Edge Function updates a `parse_runs` row after each stage; the merchant app subscribes via Realtime for progress updates.*"

- [ ] **Step 13.3: Update root `README.md`**

Find the tech-stack row for "Backend" in `README.md`. It likely reads:
```markdown
| Backend | Supabase (planned: Postgres + Auth + Storage + Edge Functions) |
```

Replace with:
```markdown
| Backend | Supabase — schema + RLS + Storage + `parse-menu` Edge Function scaffold (mock OCR/LLM adapters). Real AI providers plug into `OcrProvider` / `LlmProvider` interfaces. See [`backend/README.md`](backend/README.md). |
```

If the README has a different table format, keep the existing formatting and just swap the content. Do not restructure the table.

- [ ] **Step 13.4: Commit**

```bash
git add docs/decisions.md docs/architecture.md README.md
git commit -m "$(cat <<'EOF'
docs: add ADR-013 through ADR-016; architecture + README backend refs

ADR-013 tenancy (stores.owner_id 1:1 with auth.users); ADR-014
TEXT+CHECK over ENUM + redundant store_id; ADR-015 single parse-menu
function with parse_runs status table; ADR-016 {store_id}/<uuid>.<ext>
storage path. Architecture doc gets a Data schema + Parse pipeline
subsection; README tech-stack row reflects the new scaffold.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 14: Final integration verification

**Goal:** End-to-end smoke of the whole scaffold from a clean state + record the verification.

**Files:** none modified (verification only)

- [ ] **Step 14.1: Fresh reset + replay**

```bash
cd /home/coder/workspaces/menuray/backend
supabase stop     # in case a stale stack is running
supabase start
supabase db reset
```

Expect: migrations + seed run without error.

- [ ] **Step 14.2: Run the parse-menu smoke path**

Follow the instructions in `backend/supabase/functions/parse-menu/README.md`:

1. `supabase functions serve parse-menu --import-map supabase/functions/import_map.json` (in a separate terminal).
2. Obtain a seed-user JWT via the Auth endpoint.
3. Create a new pending `parse_runs` row.
4. POST to the function.
5. Confirm response = `{ status: 'succeeded' }`.
6. Confirm `menus` now has 2 rows (the published seed one + the newly inserted draft), `categories` has 4 rows total, `dishes` has 10.

- [ ] **Step 14.3: Verify frontend is untouched**

```bash
cd /home/coder/workspaces/menuray
git diff main -- frontend/merchant/
# Expect: empty output.

export PATH="$HOME/flutter/bin:$PATH"
cd frontend/merchant && flutter analyze && flutter test && cd -
# Expect: "No issues found!" and "All tests passed!" (27 tests).
```

- [ ] **Step 14.4: Stop local stack**

```bash
cd /home/coder/workspaces/menuray/backend
supabase stop
```

No commit for this task — if anything fails, fix the underlying issue in the relevant task and re-run the verification.

---

## Self-review checklist (run after writing the plan)

The plan must cover every requirement in the spec. Cross-check:

| Spec section | Covered by |
|---|---|
| §1 Goal & constraints | Task 14 frontend-untouched check; commit messages tag scope |
| §3 Data schema — 9 tables + indexes + touch trigger | Task 2 |
| §3.4 Signup trigger | Task 5 |
| §4 RLS — Pattern 1 owner R/W | Task 3 |
| §4 RLS — Pattern 2 anon read | Task 3 |
| §4 RLS — Pattern 3 view_logs anon insert | Task 3 |
| §4 RLS — Pattern 4 service_role | Tasks 10–11 (no policy; verified by orchestrator writing successfully) |
| §5 Storage buckets + policies | Task 4 |
| §6 Auth config | Task 1 (config.toml) |
| §7.1 File layout | Tasks 8–11 |
| §7.2 Interfaces | Task 8 |
| §7.3 Orchestrator | Task 10 |
| §7.4 HTTP handler | Task 11 |
| §7.5 Mock adapters | Task 9 |
| §7.6 Env vars | Task 9 |
| §8.1 Repo layout | All tasks produce the expected files |
| §8.3 Seed data | Task 7 |
| §8.4 backend/README | Task 12 |
| §9 Verification | Task 14 |
| §10 ADRs 013–016 + doc updates | Task 13 |
| §11 Non-goals | Plan preamble; Task 14 frontend check |

No spec requirement is orphaned. No task produces a placeholder.

---

Execution: after this plan is saved and the user approves, the ONLY skills to invoke next are:
- `superpowers:subagent-driven-development` (recommended), or
- `superpowers:executing-plans` (inline batch).

Do not invoke a domain-specific skill (e.g., `mcp-builder`) from this plan.

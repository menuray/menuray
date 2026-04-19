# MenuRay Supabase backend — MVP design

- **Date:** 2026-04-19
- **Status:** Approved (awaiting implementation plan)
- **Scope:** P0 backend scaffold per [roadmap.md](../../roadmap.md) — DB schema, RLS, Storage, Auth config, and a mock-adapter `parse-menu` Edge Function. No real OCR/LLM calls.
- **Out of scope (explicit):** wiring Flutter merchant app; `translate-menu` function; real AI provider adapters; rate-limiting; Stripe/billing; multi-store / memberships; deploying to hosted Supabase.

## 1. Goal & constraints

Stand up the MenuRay backend so a future session can (a) wire the merchant app to real APIs and (b) plug in a real OCR/LLM provider without touching the orchestration code.

Constraints carried in from `CLAUDE.md`, `docs/architecture.md`, and the initial task prompt:

- Do not modify `frontend/merchant/`.
- Do not call real OCR/LLM APIs — interface + mock adapter only.
- Do not commit secrets. `.env.local` is already gitignored; `.env.local.example` is the committable template.
- Follow conventional commits + add new ADRs when a non-obvious choice is made.
- Global-first: English docs, no China-specific defaults.

## 2. High-level architecture

```
auth.users ──1:1 owner_id──▶ stores
                               │
                               ├── menus (slug unique when published)
                               │     ├── categories
                               │     │     └── dishes
                               │     │           └── dish_translations (locale)
                               │     ├── category_translations (locale)
                               │     └── view_logs (diner writes, anon)
                               ├── store_translations (locale)
                               └── parse_runs (async status)

Edge Function: parse-menu
  HTTP → orchestrator → OcrProvider → LlmProvider → INSERT menu/categories/dishes
  Providers selected by env var; mock adapter default; fixture-backed.

Storage buckets:
  menu-photos   (private)      — OCR input
  dish-images   (public read)  — dish photos
  store-logos   (public read)  — store logos
  All paths: {store_id}/<uuid>.<ext>
```

## 3. Data schema

All tables live in `public` schema. All have `id uuid PK default gen_random_uuid()`, `created_at timestamptz default now()`, `updated_at timestamptz default now()`. A single `touch_updated_at()` trigger function maintains `updated_at` on every UPDATE.

**Owned-table convention:** every table that belongs to a store carries a redundant `store_id uuid NOT NULL` column, even when derivable from a parent FK. This lets a single RLS policy template apply to all of them.

### 3.1 Tables (DDL)

```sql
-- stores: 1:1 with auth.users via owner_id
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

CREATE TABLE menus (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id             uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  name                 text NOT NULL,
  status               text NOT NULL DEFAULT 'draft'
                         CHECK (status IN ('draft','published','archived')),
  slug                 text UNIQUE,
  time_slot            text NOT NULL DEFAULT 'all_day'
                         CHECK (time_slot IN ('all_day','lunch','dinner','seasonal')),
  time_slot_description text,
  cover_image_url      text,
  currency             text NOT NULL DEFAULT 'USD',       -- ISO 4217
  source_locale        text NOT NULL DEFAULT 'en',
  published_at         timestamptz,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT published_requires_slug CHECK (status <> 'published' OR slug IS NOT NULL)
);

CREATE TABLE categories (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  menu_id     uuid NOT NULL REFERENCES menus(id) ON DELETE CASCADE,
  store_id    uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  source_name text NOT NULL,
  position    int  NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

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
```

### 3.2 Indexes

```sql
CREATE INDEX menus_store_id_idx          ON menus(store_id);
CREATE INDEX menus_slug_published_idx    ON menus(slug) WHERE status = 'published';
CREATE INDEX categories_menu_pos_idx     ON categories(menu_id, position);
CREATE INDEX dishes_category_pos_idx     ON dishes(category_id, position);
CREATE INDEX dishes_menu_id_idx          ON dishes(menu_id);
CREATE INDEX view_logs_menu_time_idx     ON view_logs(menu_id, viewed_at DESC);
CREATE INDEX view_logs_store_time_idx    ON view_logs(store_id, viewed_at DESC);
CREATE INDEX parse_runs_store_time_idx   ON parse_runs(store_id, created_at DESC);
-- dish_translations + category_translations + store_translations get UNIQUE indexes for free.
```

### 3.3 Triggers

```sql
CREATE FUNCTION touch_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END $$;

-- One concrete CREATE TRIGGER statement per table, applied to:
--   stores, menus, categories, dishes, dish_translations,
--   category_translations, store_translations, parse_runs, view_logs.
-- Example:
CREATE TRIGGER stores_touch_updated_at BEFORE UPDATE ON stores
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
-- (view_logs rows are never updated in normal flow; trigger is harmless boilerplate.)
```

### 3.4 Signup trigger (auto-create store)

```sql
CREATE FUNCTION public.handle_new_user() RETURNS trigger
  LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.stores (owner_id, name)
  VALUES (NEW.id, 'My restaurant');
  RETURN NEW;
END $$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

## 4. Row-level security

All 9 tables run `ALTER TABLE <t> ENABLE ROW LEVEL SECURITY`. Four policy patterns cover every rule:

### Pattern 1 — owner R/W (`authenticated`)

```sql
CREATE POLICY stores_owner_rw ON stores FOR ALL TO authenticated
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());
```

For `menus`, `categories`, `dishes`, `dish_translations`, `category_translations`, `store_translations`, `parse_runs`, `view_logs`:

```sql
CREATE POLICY <table>_owner_rw ON <table> FOR ALL TO authenticated
  USING      (store_id IN (SELECT id FROM stores WHERE owner_id = auth.uid()))
  WITH CHECK (store_id IN (SELECT id FROM stores WHERE owner_id = auth.uid()));
```

### Pattern 2 — anon SELECT on published menus

Each policy uses the shortest subquery path to reach `menus.status = 'published'`. Translation tables join through their parent (`dish_translations → dishes → menus`, `category_translations → categories → menus`), which keeps the schema lean (no extra `menu_id` column on translation tables).

```sql
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
```

`stores` table stays **unreadable** by `anon` entirely — diners see store name/address via `store_translations`.

### Pattern 3 — anon INSERT on view_logs

```sql
CREATE POLICY view_logs_anon_insert ON view_logs FOR INSERT TO anon
  WITH CHECK (
    menu_id IN (SELECT id FROM menus WHERE status = 'published')
    AND store_id = (SELECT store_id FROM menus WHERE id = menu_id)
  );
```

No anon SELECT on view_logs. Rate-limiting is P1.

### Pattern 4 — service role bypasses RLS (Edge Function)

`parse-menu` connects with `SUPABASE_SERVICE_ROLE_KEY`, which bypasses RLS. The function still writes `store_id` on every INSERT (it's NOT NULL), reading the value from `parse_runs.store_id`.

## 5. Storage

Three buckets created in a migration:

| Bucket | Public | MIME | Max size |
|---|---|---|---|
| `menu-photos` | false | `image/jpeg`, `image/png` | 10 MB |
| `dish-images` | true | `image/jpeg`, `image/png`, `image/webp` | 5 MB |
| `store-logos` | true | `image/png`, `image/svg+xml` | 2 MB |

**Path convention:** `{store_id}/<uuid>.<ext>`. Enforced by RLS (not by constraint).

### Storage RLS (`storage.objects`)

Three policies per bucket (INSERT / UPDATE / DELETE), same template. Example for `menu-photos`:

```sql
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
```

Same three policies for `dish-images` and `store-logos` (9 total). `menu-photos` also gets an owner-SELECT policy (owners can re-download their own uploads); public buckets are readable by default.

Image transform / resize is **not** enabled (paid Supabase feature; hurts self-host path).

## 6. Auth configuration

- **Phone OTP** enabled (provider is configured out-of-band in Supabase dashboard — Twilio by default but swappable).
- **Email + password** enabled (fallback; lets contributors without SMS provider run end-to-end).
- **OAuth providers disabled.**
- **Email magic link disabled** (P1 upgrade; requires SMTP config).

Auth config lives in `supabase/config.toml`:

```toml
[auth]
enable_signup = true
enable_confirmations = false   # local dev; hosted toggles via dashboard

[auth.email]
enable_signup = true
# magic link disabled

[auth.sms]
enable_signup = true
enable_confirmations = true
# provider configured in dashboard, not here
```

## 7. Edge Function: `parse-menu`

### 7.1 File layout

```
backend/supabase/functions/
├── _shared/
│   ├── providers/
│   │   ├── types.ts         # OcrProvider, LlmProvider + DTOs
│   │   ├── mock_ocr.ts
│   │   ├── mock_llm.ts
│   │   └── factory.ts       # env-var switch; default = mock
│   ├── db.ts                # createServiceRoleClient()
│   └── types.ts             # MenuDraft, OcrResult shared DTOs
├── parse-menu/
│   ├── index.ts             # HTTP handler
│   ├── orchestrator.ts      # pipeline (testable without HTTP)
│   ├── README.md            # invocation + local test
│   └── fixtures/
│       └── yun_jian_xiao_chu.json
└── import_map.json
```

### 7.2 Interfaces

```ts
export type OcrBlock = { text: string; bbox: [number, number, number, number] };
export type OcrResult = {
  fullText: string;
  blocks: OcrBlock[];
  sourceLocale?: string;
};

export interface OcrProvider {
  readonly name: string;
  extract(photoUrls: string[]): Promise<OcrResult>;
}

export type MenuDraft = {
  name: string;
  sourceLocale: string;
  currency: string;
  categories: Array<{
    sourceName: string;
    position: number;
    dishes: Array<{
      sourceName: string;
      sourceDescription?: string;
      price: number;
      position: number;
      spiceLevel: 'none'|'mild'|'medium'|'hot';
      confidence: 'high'|'low';
      isSignature: boolean;
      isRecommended: boolean;
      isVegetarian: boolean;
      allergens: string[];
    }>;
  }>;
};

export interface LlmProvider {
  readonly name: string;
  structure(
    ocr: OcrResult,
    hints: { sourceLocale?: string; currency?: string }
  ): Promise<MenuDraft>;
}
```

### 7.3 Orchestrator

```ts
export async function runParse(
  runId: string,
  db = createServiceRoleClient(),
  ocr = getOcrProvider(),
  llm = getLlmProvider()
): Promise<void> {
  // 1. Load parse_runs row; if already succeeded/failed, return (idempotent).
  // 2. UPDATE status='ocr', ocr_provider=ocr.name, started_at=now().
  // 3. const result = await ocr.extract(row.source_photo_paths).
  // 4. UPDATE status='structuring', llm_provider=llm.name.
  // 5. const draft = await llm.structure(result, { sourceLocale, currency }).
  // 6. In one transaction: INSERT menu (status='draft'), categories, dishes
  //    using draft data; all rows carry store_id from the parse_runs row.
  // 7. UPDATE parse_runs SET status='succeeded', menu_id=<new>, finished_at=now().
  // Any throw → UPDATE status='failed', error_stage=<step>, error_message.
}
```

### 7.4 HTTP handler (`index.ts`)

```ts
Deno.serve(async (req) => {
  // 1. Extract user JWT from Authorization header.
  // 2. Parse body: { run_id: string }.
  // 3. Using an anon-role client with the user's JWT,
  //    SELECT parse_runs WHERE id = run_id — if 0 rows, RLS rejected it → 403/404.
  // 4. Using service-role client, await runParse(run_id).
  //    (P0: synchronous. Real providers will flip this to background; see design section 4.)
  // 5. Return { run_id, status: final status from parse_runs }.
});
```

### 7.5 Mock adapters

- `MockOcrProvider.extract()`: returns an `OcrResult` built from `fixtures/yun_jian_xiao_chu.json`'s `ocr` section (≈10 fake blocks, `sourceLocale: 'zh-CN'`).
- `MockLlmProvider.structure()`: returns `fixtures/yun_jian_xiao_chu.json`'s `menu_draft` section, matching the 凉菜/热菜 categories and 5 dishes from `frontend/merchant/lib/shared/mock/mock_data.dart`.
- Both use `await new Promise(r => setTimeout(r, 0))` to keep the async contract honest.

### 7.6 Provider factory env vars

```
MENURAY_OCR_PROVIDER   default 'mock' (alt: 'google' — future session)
MENURAY_LLM_PROVIDER   default 'mock' (alt: 'anthropic' | 'openai' — future session)
```

Factory throws on unknown value. New provider = new file + one case in the `switch`.

## 8. Migrations, tooling, seed

### 8.1 Repo layout

```
backend/
├── README.md
├── .gitignore
└── supabase/
    ├── config.toml
    ├── seed.sql
    ├── migrations/
    │   ├── 20260420000001_init_schema.sql
    │   ├── 20260420000002_rls_policies.sql
    │   ├── 20260420000003_storage_buckets.sql
    │   └── 20260420000004_signup_trigger.sql
    └── functions/ …
```

### 8.2 Common commands

| Purpose | Command |
|---|---|
| Initialize project (once) | `supabase init` |
| Start local stack | `supabase start` |
| Reset local DB (re-run all migrations + seed) | `supabase db reset` |
| Run `parse-menu` locally | `supabase functions serve parse-menu --no-verify-jwt` (with seed user) |
| Push migrations to hosted | `supabase db push --db-url "$SUPABASE_DB_URL"` (**NOT run in this session**) |
| Deploy function to hosted | `supabase functions deploy parse-menu --project-ref idwhukvigkoevaakhsqv` (**NOT run in this session**) |

### 8.3 Seed data (`seed.sql`)

Inserted after migrations so `supabase db reset` produces a working local dev env:

- One demo auth user (`seed@menuray.com`, password `demo1234`). Trigger auto-creates a `stores` row.
- Update the demo store's `name` to `'云间小厨 · 静安店'` to match the mock data.
- One published menu `'午市套餐 2025 春'` with slug `'yun-jian-xiao-chu-lunch-2025'`.
- Two categories (`凉菜`, `热菜`) with three and two dishes respectively — the same content as `frontend/merchant/lib/shared/mock/mock_data.dart`.
- One English `dish_translations` row per dish (where a `nameEn` exists in mock data).
- One completed `parse_runs` row that produced the demo menu (for subscribing to in tests).

### 8.4 `backend/README.md` contents

Sections:

1. Prerequisites (Docker, Supabase CLI v1.x, Deno).
2. Setup (`supabase init` already committed, just `supabase start`).
3. Common commands (table above).
4. How to run `parse-menu` locally (with `curl` example).
5. Schema overview (one paragraph + link to this spec).
6. How to add a new OCR/LLM provider (one file in `_shared/providers/`, one case in `factory.ts`).
7. Deploy to hosted Supabase (warning that it requires `.env.local` and push bypasses `main` checks; link to `.env.local.example`).

## 9. Verification (what "done" looks like)

Before declaring the task complete:

1. `supabase start` succeeds locally.
2. `supabase db reset` runs all 4 migrations cleanly and loads seed.sql.
3. A manual `psql` or `supabase db inspect` confirms:
   - 9 tables exist with expected columns + CHECK constraints.
   - All 9 tables have RLS enabled.
   - 3 storage buckets exist.
   - `on_auth_user_created` trigger fires (creating a new auth user auto-creates a store row).
4. `supabase functions serve parse-menu` starts without error.
5. `curl` with a seed-user JWT and a valid `run_id` returns `{ status: 'succeeded' }` and the DB now has a draft menu + categories + dishes whose content matches the fixture.
6. A minimal orchestrator unit test (Deno `Deno.test`) runs mock providers end-to-end against the seeded DB and asserts the final `parse_runs.status='succeeded'` and row counts match the fixture.
7. No change to `frontend/merchant/` (confirm via `git diff frontend/`).

## 10. ADRs to add

These go into `docs/decisions.md` as part of this work:

- **ADR-013 — Tenancy: `stores.owner_id` 1:1 with `auth.users`.** Documents the YAGNI decision to skip `memberships` for P0; describes the one-table migration path when P2 adds chain accounts.
- **ADR-014 — Postgres conventions: `TEXT + CHECK` over `ENUM`; redundant `store_id` on owned tables.** Rationale: enums resist migration; redundant `store_id` lets one RLS template work everywhere.
- **ADR-015 — Parse pipeline: single `parse-menu` function + `parse_runs` status table.** Documents why we didn't split into `ocr`/`structure`/`translate` at P0, and that `parse_runs.error_stage` is the seam where we'd split later.
- **ADR-016 — Storage path convention: `{store_id}/<uuid>.<ext>`.** Documents why path-prefix RLS works for three buckets with identical policies.

`docs/architecture.md` gets a small update under "Backend — Supabase" pointing to this spec and the migrations directory, and the data-flow diagram adds a `parse_runs` annotation on the Edge Function box.

`README.md` root tech stack line updates from "Backend: Supabase (planned)" to "Backend: Supabase (schema + `parse-menu` scaffold — real AI wired in a later milestone)".

## 11. Explicit non-goals

- **No real OCR/LLM calls.** Mock adapters only.
- **No deploy to hosted Supabase.** Local verification only. Future session owns push/deploy.
- **No changes to `frontend/merchant/`.** Wiring is the next task.
- **No `translate-menu` function.** P0 roadmap item but not part of this scaffold session.
- **No rate-limiting on `view_logs` INSERT.** RLS prevents forged `menu_id`; rate-limit is P1.
- **No memberships / multi-store / staff roles.** P2 material.
- **No billing, Stripe, quotas.** P2.
- **No image transform / resize.** Paid feature; would break self-host parity.

## 12. Open questions

None blocking the plan. Items surfaced as deliberately deferred:

- Supabase CLI version pin — pick current stable in the plan and record in README.
- Local Deno version — CLI ships compatible runtime; no separate install needed.
- Exact fixture dish content — mirror the 5 dishes from `mock_data.dart`; plan step will copy values.

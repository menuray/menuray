# Analytics Real Data — Design

Date: 2026-04-25
Scope: Wire the Statistics screen to real Postgres aggregations. Adds `qr_variant` to `view_logs`, new `dish_view_logs` table (opt-in via `stores.dish_tracking_enabled`), 4 aggregation RPCs, two new Edge Functions (`log-dish-view` anon ingest, `export-statistics-csv` merchant-authenticated), SvelteKit client-side `session_id` generation + IntersectionObserver dish-view emission, Flutter Statistics screen rewire (30-sec polling, tier-gated, CSV export on Growth), 12-month retention via `pg_cron`. Tier gating follows product-decisions.md §2 (Free = None, Pro = Basic, Growth = Full + CSV). Materialized views deferred per product spec (>5M rows).
Audience: whoever picks up the implementation plan after spec approval.

## 1. Goal & Scope

Lifecycle once shipped:

```
Customer SSR                    session_id generated client-side (sessionStorage UUID)
  GET /<slug>?qr=table-5      ─────────────────────────────────────────────────
                                → SSR inserts view_logs(store_id, menu_id,
                                                          session_id, locale,
                                                          referrer_domain,
                                                          qr_variant)

                                IntersectionObserver on each dish card (2-sec debounce)
                                  if store.dish_tracking_enabled → POST
                                  /functions/v1/log-dish-view
                                  → writes dish_view_logs(store_id, menu_id,
                                                          dish_id, session_id)

Merchant Statistics screen      /statistics (Flutter)
  → TierGate:
    - Free   → UpgradeCallout (no data fetch)
    - Pro    → 4 aggregation RPCs: visits overview / visits by day /
               top dishes (only if dish_tracking_enabled) /
               traffic by locale
               Auto-refresh every 30 seconds via Timer.periodic → ref.invalidate.
    - Growth → Pro + "Export CSV" button → create-statistics-csv Edge Function →
               Flutter writes temp file → share_plus invokes system share sheet.

Settings screen                 New tile "Dish heat tracking" (all tiers) → toggle
                                writes stores.dish_tracking_enabled.

Retention                       pg_cron DELETE nightly at 02:00 UTC:
                                  view_logs WHERE viewed_at < now() - 12 months
                                  dish_view_logs WHERE viewed_at < now() - 12 months
```

**In scope**

- **Schema migration `20260425000001_analytics.sql`**:
  - `ALTER TABLE view_logs ADD COLUMN qr_variant text` (nullable).
  - `ALTER TABLE stores ADD COLUMN dish_tracking_enabled boolean NOT NULL DEFAULT false`.
  - New `dish_view_logs(id, menu_id, store_id, dish_id, session_id, viewed_at, created_at)` table + RLS policies mirroring `view_logs` (member SELECT / anon INSERT when parent menu published AND `store.dish_tracking_enabled=true`).
  - Indexes: `(store_id, viewed_at DESC)`, `(dish_id, viewed_at DESC)` on `dish_view_logs`; a new `view_logs_store_session_idx ON view_logs(store_id, session_id)` for dedup-count queries.
  - Four aggregation RPCs (SECURITY DEFINER, STABLE, return JSON):
    - `get_visits_overview(p_store_id uuid, p_from timestamptz, p_to timestamptz)` → `{total_views int, unique_sessions int, avg_session_seconds int}`.
    - `get_visits_by_day(p_store_id uuid, p_from timestamptz, p_to timestamptz)` → `[{day date, count int}]` — one row per day in range (0-filled).
    - `get_top_dishes(p_store_id uuid, p_from timestamptz, p_to timestamptz, p_limit int DEFAULT 5)` → `[{dish_id uuid, dish_name text, count int}]` — empty list if `dish_tracking_enabled=false`.
    - `get_traffic_by_locale(p_store_id uuid, p_from timestamptz, p_to timestamptz)` → `[{locale text, count int}]` ordered by count DESC.
  - Two `pg_cron` jobs:
    - `retain-view-logs` nightly at 02:00 UTC → `DELETE FROM view_logs WHERE viewed_at < now() - interval '12 months'`.
    - `retain-dish-view-logs` at 02:01 UTC → same pattern for `dish_view_logs`.
- **Two new Edge Functions** (Deno):
  - `log-dish-view` (anon POST): `{menu_id, dish_id, session_id, qr_variant?}` → validates session_id is UUID, validates menu is published + dish belongs to menu, checks `store.dish_tracking_enabled` (204 no-op if off), INSERT into `dish_view_logs`. Returns `{ok:true}` or `{ok:false, code:<reason>}` with 204/200/400/404.
  - `export-statistics-csv` (authenticated POST): `{store_id, from, to}` → tier-gated (`tier='growth'` only; 402 otherwise), runs the 4 aggregation RPCs, serialises to multi-section CSV, returns `text/csv` body directly (not JSON).
- **Customer SvelteKit patches**:
  - New file `frontend/customer/src/lib/i18n/session.ts`: `getOrCreateSessionId()` → sessionStorage UUID helper, re-uses across page reloads within the tab.
  - `[slug]/+page.server.ts` reads `url.searchParams.get('qr')` (free-form text, null if absent) + passes to `logView`.
  - `logView.ts` accepts `qr_variant` and writes it; accepts `session_id` from client (via hidden form POST on hydration) OR falls back to server-generated UUID if client hydration hasn't fired yet.
  - New shared component `frontend/customer/src/lib/components/DishViewTracker.svelte`: mounts an IntersectionObserver on its children, calls `logDishView` on first intersection (debounced 2 sec, fires once per session per dish). Only active when `data.menu.store.dishTrackingEnabled === true`.
  - `frontend/customer/src/lib/data/logDishView.ts` new file: POSTs to `log-dish-view` Edge Function via `fetch`. Client-only (runs in browser).
  - `Store` type adds `dishTrackingEnabled: boolean`; `fetchPublishedMenu.ts` query + mapper extended.
  - Two existing Svelte templates (Minimal, Grid) wrap each dish card in `<DishViewTracker dishId={d.id} menuId={menu.id}>`. Keep wrapping optional; Minimal and Grid are the two files.
- **Flutter merchant patches**:
  - New `lib/features/manage/statistics_repository.dart` (read-only aggregator over the 4 RPCs). Pure functions mapping the JSON replies to typed records.
  - New `lib/features/manage/statistics_providers.dart` with `statisticsProvider` (`FutureProvider.family<StatisticsData, StatisticsRange>`).
  - `StatisticsScreen` rewire: remove MockData imports, replace hardcoded values with `ref.watch(statisticsProvider(range)).when(...)`. On top of the existing design, add `Timer.periodic(Duration(seconds:30), _refresh)` in `initState`, cancel in `dispose`. Wrap in `TierGate(allowed:{Tier.pro,Tier.growth}, fallback: UpgradeCallout)`.
  - Add "Export CSV" button inside a nested `TierGate(allowed:{Tier.growth})` — visible only to Growth. On tap, calls `statisticsRepository.exportCsv(range)` → returns `String` (raw CSV) → writes temp file via `path_provider` → invokes `Share.shareXFiles`.
  - `StatisticsRepository.exportCsv`: calls `_client.functions.invoke('export-statistics-csv', body:{store_id, from, to})`. Response data is a String (the raw CSV body); function uses text/csv content type.
  - New tile in `SettingsScreen`: "菜品热度跟踪 / Dish heat tracking" with a Switch that writes `stores.dish_tracking_enabled` via `storeRepository.setDishTracking(bool)`. Available to all tiers (opt-in privacy choice).
  - New shared widget `lib/features/manage/presentation/upgrade_callout.dart` mirroring the one from Session 4 custom_theme screen (or extract the existing one to a shared place — spec keeps it local to reduce scope).
  - `Store` model adds `dishTrackingEnabled: bool`; mapper updated.
  - ~12 new i18n keys under `statistics*` prefix (en + zh).
- **Dependencies**:
  - Flutter: add `share_plus: ^10.x` (not yet present). `path_provider` is a transitive dep of `supabase_flutter`; verify.
  - No new Deno or pnpm deps.
- **Testing**:
  - PgTAP regression `backend/supabase/tests/analytics_aggregations.sql` covering: each RPC returns expected shape + counts, cross-store isolation via RLS, opt-in gate (dish_tracking_enabled=false → empty top dishes), retention query is idempotent.
  - Deno tests: `log-dish-view/test.ts` (5 cases: missing body, invalid session UUID, tracking disabled → 204, happy path → 200, cross-store dish → 404); `export-statistics-csv/test.ts` (4 cases: free tier → 402, pro tier → 402 (CSV is Growth-only), growth happy path → 200 + text/csv body, missing auth → 401).
  - Flutter smoke tests: `statistics_screen_smoke_test.dart` rewrite (3 cases: free tier shows UpgradeCallout, pro tier shows data + no CSV, growth tier shows data + CSV button); `settings_screen_smoke_test.dart` extension (toggles dish_tracking_enabled).
  - No Playwright changes (IntersectionObserver + debounce flaky).

**Out of scope (deferred)**

- **Materialized view `mv_view_logs_daily`** (product spec mentions for >5M rows). Current aggregation runs live; deferred. Session 6+ will add MV if throughput demands it.
- **Partitioning on `viewed_at`** (product spec >50M rows). Deferred to a later session.
- **Per-dish time-on-page / scroll depth** — current `dish_view_logs` records only the intersection event. Richer engagement (dwell time, taps) is not part of this session.
- **Real-time dashboard updates** — 30-sec polling satisfies S-5; Supabase Realtime integration is explicitly declined.
- **IP / User-Agent / fingerprint logging** — product spec bars these permanently.
- **Bot detection beyond UUID + published-menu + dish-belongs-to-menu** — no UA/IP filters this session. Observe traffic; add heuristics later if abuse surfaces.
- **QR variant management UI** — this session only READS `qr_variant` from `?qr=` query param. A merchant UI to generate/label variants (e.g., "Table 5", "Door sign", "Instagram bio") is deferred; merchants can include the param in their QR URLs manually.
- **Custom date ranges beyond 12 months** — retention caps data at 12 months; the date picker's range is capped to the last 12 months (UI blocks older).
- **Per-menu breakdown in stats** — this session aggregates at store level. "Which menu gets more views" is a natural follow-up.
- **Paywall for `view_logs` data to Pro+ at the DB layer** — RLS stays permissive for authenticated members; tier gating is enforced in the Flutter UI + in the CSV Edge Function. If a Pro user were to call the aggregation RPC directly they'd get data; that's acceptable (they have the read path anyway, just no screen).
- **Consent banner** — no GDPR consent UI in this session. session_id + referrer_domain + locale + qr_variant are non-PII; retention is 12 months. Future compliance work would add a consent banner if markets demand.

## 2. Context

- Statistics screen already exists at `frontend/merchant/lib/features/manage/presentation/statistics_screen.dart`, fully designed with MockData — this session rewires it to real providers, preserving visual layout.
- `view_logs` already has the trigger that increments `stores.qr_views_monthly_count` (billing Session 4). The new schema + aggregation is additive; the counter trigger keeps firing.
- Product-decisions.md §4 provides the authoritative tier + privacy + retention decisions. This spec implements them.
- Edge Function scaffolding pattern established in `backend/supabase/functions/accept-invite/index.ts` and `handle-stripe-webhook/index.ts`; reused here.
- Tier gating uses `TierGate` (commit 686644d). Free → UpgradeCallout; Pro → Basic data; Growth → Basic + CSV export.
- Anon RLS on `view_logs` already permits INSERT where the menu is published (Session 2 migration). The new `dish_view_logs` RLS adds the `dish_tracking_enabled` check as an additional gate.
- Existing `session_id` column on `view_logs` is populated as `null` today (by `logView.ts`). This session populates it from a sessionStorage UUID on the client.

## 3. Decisions

### 3.1 Schema migration `20260425000001_analytics.sql`

```sql
-- qr_variant column (S-4): free-form text the merchant chooses per QR.
ALTER TABLE view_logs ADD COLUMN qr_variant text;

-- dish tracking per-store opt-in (S-1).
ALTER TABLE stores ADD COLUMN dish_tracking_enabled boolean NOT NULL DEFAULT false;

-- dish_view_logs table.
CREATE TABLE dish_view_logs (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  menu_id    uuid NOT NULL REFERENCES menus(id)  ON DELETE CASCADE,
  store_id   uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  dish_id    uuid NOT NULL REFERENCES dishes(id) ON DELETE CASCADE,
  session_id text,
  viewed_at  timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX dish_view_logs_store_time_idx ON dish_view_logs(store_id, viewed_at DESC);
CREATE INDEX dish_view_logs_dish_time_idx  ON dish_view_logs(dish_id, viewed_at DESC);
CREATE INDEX view_logs_store_session_idx   ON view_logs(store_id, session_id);

ALTER TABLE dish_view_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY dish_view_logs_member_select ON dish_view_logs FOR SELECT TO authenticated
  USING (store_id IN (SELECT public.user_store_ids()));
CREATE POLICY dish_view_logs_anon_insert ON dish_view_logs FOR INSERT TO anon
  WITH CHECK (
    menu_id IN (SELECT id FROM menus WHERE status = 'published')
    AND dish_id IN (SELECT id FROM dishes WHERE menu_id = dish_view_logs.menu_id)
    AND store_id = (SELECT store_id FROM menus WHERE id = menu_id)
    AND (SELECT dish_tracking_enabled FROM stores WHERE id = store_id) = true
  );
-- No authenticated INSERT/UPDATE/DELETE. Service role bypasses.

-- Retention jobs (pg_cron is already enabled in Session 4's billing migration).
SELECT cron.schedule(
  'retain-view-logs',
  '0 2 * * *',
  $$ DELETE FROM public.view_logs      WHERE viewed_at < now() - interval '12 months'; $$
);
SELECT cron.schedule(
  'retain-dish-view-logs',
  '1 2 * * *',
  $$ DELETE FROM public.dish_view_logs WHERE viewed_at < now() - interval '12 months'; $$
);
```

### 3.2 Aggregation RPCs

All four RPCs are `LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public` and return JSON (`jsonb`). RLS applies to the caller's authentication context; since they're SECURITY DEFINER, we gate access via `GRANT EXECUTE TO authenticated` + an explicit membership check at the top of each function.

```sql
-- 1) Visits overview
CREATE FUNCTION public.get_visits_overview(
  p_store_id uuid, p_from timestamptz, p_to timestamptz
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_total int; v_unique int;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM store_members
     WHERE store_id = p_store_id AND user_id = auth.uid() AND accepted_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'not_a_member' USING ERRCODE = 'insufficient_privilege';
  END IF;
  SELECT count(*)                       INTO v_total
    FROM view_logs WHERE store_id = p_store_id AND viewed_at >= p_from AND viewed_at < p_to;
  SELECT count(DISTINCT session_id)     INTO v_unique
    FROM view_logs
    WHERE store_id = p_store_id AND viewed_at >= p_from AND viewed_at < p_to
      AND session_id IS NOT NULL;
  RETURN jsonb_build_object(
    'total_views',        COALESCE(v_total, 0),
    'unique_sessions',    COALESCE(v_unique, 0)
  );
END $$;
GRANT EXECUTE ON FUNCTION public.get_visits_overview(uuid, timestamptz, timestamptz) TO authenticated;

-- 2) Visits by day (0-filled range)
CREATE FUNCTION public.get_visits_by_day(
  p_store_id uuid, p_from timestamptz, p_to timestamptz
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_rows jsonb;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM store_members
     WHERE store_id = p_store_id AND user_id = auth.uid() AND accepted_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'not_a_member' USING ERRCODE = 'insufficient_privilege';
  END IF;
  WITH days AS (
    SELECT generate_series(date_trunc('day', p_from), date_trunc('day', p_to - interval '1 second'),
                           interval '1 day')::date AS day
  ),
  counts AS (
    SELECT date_trunc('day', viewed_at)::date AS day, count(*) AS c
    FROM view_logs
    WHERE store_id = p_store_id AND viewed_at >= p_from AND viewed_at < p_to
    GROUP BY 1
  )
  SELECT jsonb_agg(jsonb_build_object('day', d.day, 'count', COALESCE(c.c, 0)) ORDER BY d.day)
    INTO v_rows
  FROM days d LEFT JOIN counts c USING (day);
  RETURN COALESCE(v_rows, '[]'::jsonb);
END $$;
GRANT EXECUTE ON FUNCTION public.get_visits_by_day(uuid, timestamptz, timestamptz) TO authenticated;

-- 3) Top dishes (empty array when dish_tracking_enabled=false)
CREATE FUNCTION public.get_top_dishes(
  p_store_id uuid, p_from timestamptz, p_to timestamptz, p_limit int DEFAULT 5
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_enabled boolean; v_rows jsonb;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM store_members
     WHERE store_id = p_store_id AND user_id = auth.uid() AND accepted_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'not_a_member' USING ERRCODE = 'insufficient_privilege';
  END IF;
  SELECT dish_tracking_enabled INTO v_enabled FROM stores WHERE id = p_store_id;
  IF NOT v_enabled THEN RETURN '[]'::jsonb; END IF;

  WITH ranked AS (
    SELECT dvl.dish_id, d.source_name AS dish_name, count(*) AS c
      FROM dish_view_logs dvl JOIN dishes d ON d.id = dvl.dish_id
     WHERE dvl.store_id = p_store_id
       AND dvl.viewed_at >= p_from AND dvl.viewed_at < p_to
     GROUP BY dvl.dish_id, d.source_name
     ORDER BY c DESC
     LIMIT p_limit
  )
  SELECT jsonb_agg(jsonb_build_object('dish_id', dish_id, 'dish_name', dish_name, 'count', c))
    INTO v_rows
  FROM ranked;
  RETURN COALESCE(v_rows, '[]'::jsonb);
END $$;
GRANT EXECUTE ON FUNCTION public.get_top_dishes(uuid, timestamptz, timestamptz, int) TO authenticated;

-- 4) Traffic by locale
CREATE FUNCTION public.get_traffic_by_locale(
  p_store_id uuid, p_from timestamptz, p_to timestamptz
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_rows jsonb;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM store_members
     WHERE store_id = p_store_id AND user_id = auth.uid() AND accepted_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'not_a_member' USING ERRCODE = 'insufficient_privilege';
  END IF;
  WITH ranked AS (
    SELECT COALESCE(locale, 'unknown') AS locale, count(*) AS c
      FROM view_logs
     WHERE store_id = p_store_id
       AND viewed_at >= p_from AND viewed_at < p_to
     GROUP BY 1 ORDER BY c DESC
  )
  SELECT jsonb_agg(jsonb_build_object('locale', locale, 'count', c)) INTO v_rows FROM ranked;
  RETURN COALESCE(v_rows, '[]'::jsonb);
END $$;
GRANT EXECUTE ON FUNCTION public.get_traffic_by_locale(uuid, timestamptz, timestamptz) TO authenticated;
```

The SECURITY DEFINER + explicit membership check is the pattern used elsewhere (`mark_dish_soldout`, Session 3). It avoids re-enabling RLS on aggregation queries while still enforcing cross-store isolation.

### 3.3 Edge Function `log-dish-view`

File: `backend/supabase/functions/log-dish-view/index.ts`. Anonymous POST.

- Body: `{menu_id: string, dish_id: string, session_id: string, qr_variant?: string}`.
- Validation: `session_id` must match UUID regex; `menu_id` + `dish_id` UUIDs; `qr_variant` optional text (no length cap, but single-line — strip newlines).
- Flow (all via service-role client since anon lacks dish_view_logs SELECT):
  1. Fetch the menu: `SELECT store_id, status FROM menus WHERE id = ?`. If not found or `status != 'published'` → return 404 `{code:'menu_not_published'}`.
  2. Verify the dish belongs to that menu: `SELECT 1 FROM dishes WHERE id=? AND menu_id=?`. If not → 404 `{code:'dish_not_in_menu'}`.
  3. Check `stores.dish_tracking_enabled`: `SELECT dish_tracking_enabled FROM stores WHERE id=?`. If false → 204 no-op.
  4. `INSERT INTO dish_view_logs (menu_id, store_id, dish_id, session_id)`.
  5. Return 200 `{ok: true}`.

- CORS wide-open (`*`). No auth header required (anon).

### 3.4 Edge Function `export-statistics-csv`

File: `backend/supabase/functions/export-statistics-csv/index.ts`. Authenticated POST.

- Body: `{store_id: string, from: string (ISO), to: string (ISO)}`.
- Header: `Authorization: Bearer <user JWT>`.
- Tier gate: look up `subscriptions.tier` for the caller; reject `402 csv_requires_growth` if `tier !== 'growth'`.
- Invokes the four aggregation RPCs with the same params (anon client that carries the user JWT so RLS + the functions' internal membership check both apply).
- Serialises to a multi-section CSV:
  ```csv
  # Visits overview (2026-04-01 → 2026-04-25)
  total_views,unique_sessions
  8432,3421

  # Visits by day
  day,count
  2026-04-01,240
  2026-04-02,312
  …

  # Top dishes
  dish_id,dish_name,count
  abc-123,宫保鸡丁,1209
  …

  # Traffic by locale
  locale,count
  zh-CN,5201
  en,2001
  …
  ```
- Returns `text/csv; charset=utf-8` with `Content-Disposition: attachment; filename="menuray-statistics-<from>-<to>.csv"`.

### 3.5 Customer SvelteKit — session_id + qr_variant + dish-view emission

**`session.ts` helper** at `frontend/customer/src/lib/session/session.ts`:
```typescript
export function getOrCreateSessionId(): string {
  const KEY = 'menuray.session_id';
  if (typeof sessionStorage === 'undefined') return crypto.randomUUID();
  let v = sessionStorage.getItem(KEY);
  if (!v) {
    v = crypto.randomUUID();
    sessionStorage.setItem(KEY, v);
  }
  return v;
}
```

**`logView.ts` update:** accept `qrVariant` parameter (string | null), write it to the row. Session_id generation: SSR cannot read the diner's sessionStorage, so this session **generates a request-scoped UUID server-side** (one UUID per SSR render). Two consecutive visits by the same diner will therefore look like two distinct sessions in `view_logs`; we accept that inaccuracy as an MVP approximation. Dish-view emission (client-side) *can* read sessionStorage and uses a stable UUID, so `dish_view_logs.session_id` accurately dedupes per tab. Future work: emit a single client-side "hydration ping" that updates the most-recent `view_logs` row with the sessionStorage UUID — out of scope this session.

**`[slug]/+page.server.ts` patch:**
```typescript
  const qrVariant = url.searchParams.get('qr'); // free-form
  logView(locals.supabase, menu.id, menu.store.id, locale,
          request.headers, url, qrVariant);
```

**`DishViewTracker.svelte`:** a shared wrapper.
```svelte
<script lang="ts">
  import { onMount } from 'svelte';
  import { getOrCreateSessionId } from '$lib/session/session';
  import { logDishView } from '$lib/data/logDishView';

  let { menuId, dishId, storeDishTrackingEnabled, children } = $props();
  let el: HTMLElement;
  let fired = $state(false);

  onMount(() => {
    if (!storeDishTrackingEnabled || fired) return;
    let timer: number | undefined;
    const io = new IntersectionObserver((entries) => {
      const visible = entries.some((e) => e.isIntersecting);
      if (visible && !fired) {
        timer = window.setTimeout(() => {
          if (fired) return;
          fired = true;
          logDishView({ menuId, dishId, sessionId: getOrCreateSessionId() });
        }, 2000);
      } else if (timer) {
        clearTimeout(timer);
        timer = undefined;
      }
    }, { threshold: 0.5 });
    io.observe(el);
    return () => { io.disconnect(); if (timer) clearTimeout(timer); };
  });
</script>

<div bind:this={el}>{@render children()}</div>
```

`logDishView.ts` uses plain `fetch` to `/functions/v1/log-dish-view` with the anon key in `apikey` header; fire-and-forget (errors console.warn, never surfaced to the customer).

Minimal + Grid templates import `<DishViewTracker>` and wrap each dish card. Both templates receive `menu.store.dishTrackingEnabled` via page data.

### 3.6 Flutter — Statistics rewire + polling + export

**Model types** (inside `statistics_repository.dart` — keep close to usage):

```dart
typedef StatisticsRange = ({DateTime from, DateTime to});

class VisitsOverview {
  final int totalViews;
  final int uniqueSessions;
  const VisitsOverview({required this.totalViews, required this.uniqueSessions});
}

class VisitsByDayPoint {
  final DateTime day;
  final int count;
  const VisitsByDayPoint(this.day, this.count);
}

class TopDish {
  final String dishId;
  final String dishName;
  final int count;
  const TopDish({required this.dishId, required this.dishName, required this.count});
}

class LocaleTraffic {
  final String locale;
  final int count;
  const LocaleTraffic(this.locale, this.count);
}

class StatisticsData {
  final VisitsOverview overview;
  final List<VisitsByDayPoint> byDay;
  final List<TopDish> topDishes;
  final List<LocaleTraffic> byLocale;
  const StatisticsData({required this.overview, required this.byDay, required this.topDishes, required this.byLocale});
}
```

**`StatisticsRepository`** thin-wraps the four RPCs in a single call:

```dart
class StatisticsRepository {
  StatisticsRepository(this._client);
  final SupabaseClient _client;

  Future<StatisticsData> fetch({required String storeId, required StatisticsRange range}) async {
    final from = range.from.toUtc().toIso8601String();
    final to = range.to.toUtc().toIso8601String();
    final overview = await _client.rpc('get_visits_overview',
        params: {'p_store_id': storeId, 'p_from': from, 'p_to': to});
    final byDay = await _client.rpc('get_visits_by_day',
        params: {'p_store_id': storeId, 'p_from': from, 'p_to': to});
    final topDishes = await _client.rpc('get_top_dishes',
        params: {'p_store_id': storeId, 'p_from': from, 'p_to': to, 'p_limit': 5});
    final byLocale = await _client.rpc('get_traffic_by_locale',
        params: {'p_store_id': storeId, 'p_from': from, 'p_to': to});
    return StatisticsData(
      overview: _overviewFromJson(overview as Map<String, dynamic>),
      byDay:    ((byDay as List?) ?? const []).cast<Map<String, dynamic>>().map(_dayFromJson).toList(),
      topDishes:((topDishes as List?) ?? const []).cast<Map<String, dynamic>>().map(_topDishFromJson).toList(),
      byLocale: ((byLocale as List?) ?? const []).cast<Map<String, dynamic>>().map(_localeFromJson).toList(),
    );
  }

  Future<String> exportCsv({required String storeId, required StatisticsRange range}) async {
    final res = await _client.functions.invoke('export-statistics-csv',
        body: {'store_id': storeId, 'from': range.from.toUtc().toIso8601String(),
               'to': range.to.toUtc().toIso8601String()});
    final data = res.data;
    if (data is String) return data;
    if (data is List<int>) return String.fromCharCodes(data);
    throw StateError('Unexpected CSV response type: ${data.runtimeType}');
  }
}
```

**Providers**:

```dart
final statisticsRepositoryProvider = Provider<StatisticsRepository>(
  (ref) => StatisticsRepository(ref.watch(supabaseClientProvider)),
);

final statisticsProvider = FutureProvider.autoDispose
    .family<StatisticsData, StatisticsRange>((ref, range) async {
  final ctx = ref.watch(activeStoreProvider);
  if (ctx == null) throw StateError('No active store');
  return ref.watch(statisticsRepositoryProvider).fetch(storeId: ctx.storeId, range: range);
});
```

**Polling**: in `_StatisticsScreenState`:
```dart
Timer? _refreshTimer;
@override
void initState() {
  super.initState();
  _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
    if (mounted) ref.invalidate(statisticsProvider(_currentRange()));
  });
}
@override
void dispose() { _refreshTimer?.cancel(); super.dispose(); }
```

**Tier gate**: wrap the entire screen's body in `TierGate(allowed: const {Tier.pro, Tier.growth}, fallback: const _UpgradeCallout())`. The export button is nested in another `TierGate(allowed: const {Tier.growth}, child: _ExportCsvButton())`.

**Export flow**: `_ExportCsvButton.onPressed`:
```dart
final csv = await ref.read(statisticsRepositoryProvider)
    .exportCsv(storeId: ctx.storeId, range: _currentRange());
final dir = await getTemporaryDirectory();
final file = File('${dir.path}/menuray-statistics.csv');
await file.writeAsString(csv, encoding: utf8);
await Share.shareXFiles([XFile(file.path)], text: t.statisticsExportSubject);
```

### 3.7 Flutter — Settings: dish tracking toggle

New tile in `SettingsScreen`:
```dart
SwitchListTile(
  key: const Key('settings-dish-tracking-toggle'),
  title: Text(t.settingsDishTrackingTitle),
  subtitle: Text(t.settingsDishTrackingSubtitle),
  value: store.dishTrackingEnabled,
  onChanged: (v) async {
    await ref.read(storeRepositoryProvider).setDishTracking(ctx.storeId, v);
    ref.invalidate(currentStoreProvider);
  },
),
```

`StoreRepository.setDishTracking(storeId, enabled)` is a new method — `UPDATE stores SET dish_tracking_enabled=? WHERE id=?`. Gated by Session 3 RLS: owner-only update on stores.

### 3.8 Flutter — Store model + mapper update

```dart
// store.dart
class Store {
  // …existing fields…
  final bool dishTrackingEnabled;
  const Store({
    // …existing…
    this.dishTrackingEnabled = false,
  });
}

// _mappers.dart — storeFromSupabase
tier: (json['tier'] as String?) ?? 'free',
dishTrackingEnabled: (json['dish_tracking_enabled'] as bool?) ?? false,
```

### 3.9 i18n — ~12 new keys (en + zh)

```
statisticsNoData                  → "No visits yet in this range." / "此时段暂无数据。"
statisticsUpgradeCalloutTitle     → "Analytics on Pro+" / "分析需 Pro 以上"
statisticsUpgradeCalloutBody      → "See visits, top dishes, traffic breakdown, and more." / "查看访问量、热门菜品、流量分布等。"
statisticsExport                  → (already exists) used for button text
statisticsExportSubject           → "MenuRay statistics export" / "MenuRay 统计数据"
statisticsExportStarted           → "Preparing your CSV…" / "正在准备 CSV…"
statisticsExportFailed            → "Couldn't export. Please try again." / "导出失败，请重试。"
statisticsTrafficByLocale         → "Traffic by language" / "按语言分布"
statisticsDishTrackingDisabled    → "Enable dish tracking in Settings to see per-dish data." / "请在设置中开启菜品跟踪以查看单菜品数据。"
settingsDishTrackingTitle         → "Dish heat tracking" / "菜品热度跟踪"
settingsDishTrackingSubtitle      → "Count when a diner scrolls past each dish. Anonymous, 12-month retention." / "统计食客滑过各道菜的次数；匿名，保留 12 个月。"
statisticsLoading                 → "Loading analytics…" / "正在加载数据…"
```

Existing `statistics*` keys (19 from the current mock UI) stay — the screen rewire re-uses them where still applicable (`statisticsRangeToday`, `statisticsDailyVisits`, etc.).

### 3.10 Testing

**PgTAP `backend/supabase/tests/analytics_aggregations.sql`**:
- Seed: 2 users (member of store_x, non-member), 1 store `store_x` with `dish_tracking_enabled=false`, a published menu with 2 dishes, 10 view_logs rows across 2 days with varied locales, 0 dish_view_logs (initial).
- Assertions:
  - `get_visits_overview(store_x, …)` returns `total_views=10`, `unique_sessions=<correct count>`.
  - `get_visits_by_day` returns 2 non-zero days + any empty days filled with 0.
  - `get_top_dishes` returns `[]` while `dish_tracking_enabled=false`.
  - Toggle `dish_tracking_enabled=true`, insert 5 dish_view_logs for dish_a + 2 for dish_b, then `get_top_dishes` returns `[{dish_a,5}, {dish_b,2}]`.
  - `get_traffic_by_locale` returns expected rows ordered DESC.
  - Non-member user calling `get_visits_overview(store_x, …)` raises `insufficient_privilege`.
  - Retention DELETE removes rows where `viewed_at < now() - interval '12 months'`.

**Deno tests** for `log-dish-view` + `export-statistics-csv` (10 total):
- `log-dish-view/test.ts` (5):
  - 400 on invalid session_id (not a UUID).
  - 404 on unpublished menu.
  - 204 when `dish_tracking_enabled=false`.
  - 200 on happy path.
  - 400 on body-shape mismatch.
- `export-statistics-csv/test.ts` (5):
  - 401 missing auth.
  - 402 when tier is `free` or `pro`.
  - 200 + text/csv content-type on Growth happy path.
  - CSV body contains all four sections (header lines + at least one row).
  - 403 when caller is not a store member.

**Flutter smoke** (2 test files):
- `statistics_screen_smoke_test.dart` rewrite:
  - Free tier: renders UpgradeCallout, no data fetch.
  - Pro tier with dish_tracking_enabled=true: renders overview numbers + top dishes + locales. No "Export CSV" button visible.
  - Growth tier: same + "Export CSV" button visible. Tap → repo `exportCsv` called.
- `settings_screen_smoke_test.dart` extension:
  - Toggling dish-tracking calls `storeRepository.setDishTracking` with the new value.

### 3.11 Local dev + deploy notes

- `supabase db reset` applies the new migration cleanly. PgTAP runs via `docker exec -i ... psql ... < file.sql`.
- The two new Edge Functions are anon (log-dish-view) and authenticated (export-statistics-csv); no new env vars.
- `pg_cron` jobs will run on the first minute past 02:00 UTC on whatever DB they're applied to. Local dev manually runs `SELECT cron.schedule(...)` so the job is visible but won't fire during short dev sessions.
- For manual smoke: seed some view_logs rows (`supabase db query "INSERT INTO view_logs (...) VALUES (...);"`), open Statistics, verify chart renders; toggle `dish_tracking_enabled=true` and seed `dish_view_logs` to see top dishes.

## 4. Data model

### Postgres (additive)
```
view_logs              …existing… + qr_variant text
stores                 …existing… + dish_tracking_enabled boolean NOT NULL DEFAULT false
dish_view_logs         (id, menu_id FK, store_id FK, dish_id FK, session_id text, viewed_at, created_at)
```

### Dart
```
Store { …existing…, bool dishTrackingEnabled }
StatisticsRange (from, to)
VisitsOverview { totalViews, uniqueSessions }
VisitsByDayPoint { day, count }
TopDish { dishId, dishName, count }
LocaleTraffic { locale, count }
StatisticsData { overview, byDay, topDishes, byLocale }
```

### TypeScript (customer)
```
Store { …existing…, dishTrackingEnabled: boolean }
```

## 5. Dependencies (new)
- **Flutter merchant**: `share_plus: ^10.x`, `path_provider: ^2.x` (may already be transitive — verify with `pubspec.lock`; add if missing).
- **No new Deno or pnpm deps.**

## 6. Risks & mitigations

| Risk | Mitigation |
|---|---|
| `dish_view_logs` grows faster than expected, pushing past the 5M soft threshold within a single busy restaurant's 12-month retention window | Indexes on `(store_id, viewed_at DESC)` and `(dish_id, viewed_at DESC)` keep per-store aggregation fast. If throughput exceeds, add the planned `mv_view_logs_daily` MV + daily refresh cron. Tracked in roadmap. |
| Client-side IntersectionObserver misfires on slow scrolls, double-inserts | The `fired` flag + 2-sec debounce + per-dish-per-session `fired` state keeps it one write per dish per session per component mount. Worst case: a user navigates back and triggers re-observe; that's a new session in a different dish card component, still legitimate. |
| Anon API key abuse (high-volume `log-dish-view` from script kiddies) | Fn validates published-menu + dish-belongs-to-menu + session_id UUID. Rate limit is Supabase's built-in per-fn + per-IP limit. Abusive traffic inflates storage but doesn't leak data; worst case: we add UA/IP filters later. |
| CSV contains PII | No — rows contain `locale`, `qr_variant` (free-form text the merchant chose), session UUIDs (non-PII), aggregated counts. No IP, no user agents, no customer identifiers. |
| `qr_variant` injection attack (merchant sees malicious JS via a crafted `?qr=<script>`) | Merchant screens treat qr_variant as plain text (never rendered as HTML); CSV export escapes commas/quotes per RFC 4180. No XSS surface. |
| Timer.periodic keeps firing after auth change / signOut | `statisticsProvider.autoDispose` invalidates when the screen unmounts; Timer is cancelled in `dispose`. If the user signs out mid-session the provider recreates on next mount. Verified via smoke test. |
| RPC timeouts on large datasets | 12-month window capped; indexes on viewed_at. If a merchant with >1M view_logs triggers timeout, we add MV in follow-up. Document the threshold in the CSV export failure message. |
| `unique_sessions` on view_logs is approximate (SSR generates request-scoped UUID, not sessionStorage) | Accept the MVP approximation: a diner revisiting the URL in the same tab counts as two sessions. Better than zero. Future enhancement: client-side "hydration ping" updates the row with the sessionStorage UUID. Meanwhile `dish_view_logs` has accurate per-tab dedup because its session_id comes from the client. |
| Merchant opts in to dish tracking, diners hit the site from regions that block sessionStorage (e.g., strict privacy browsers) | `getOrCreateSessionId()` falls back to a fresh UUID per call (not stored). Consequence: every page view is counted as a new session for such diners. Acceptable: we get an upper-bound estimate, which is still useful for "top dishes". |

## 7. Open questions

None remaining — decision matrix resolved them. Two operational notes for the deployer:
1. `pg_cron` is already enabled (billing Session 4). The new retention jobs add two more scheduled tasks. Monitor `cron.job_run_details` on live DBs.
2. Supabase Edge Functions have a default 256 MB memory + 30 sec timeout. CSV export for the largest expected dataset (~1M view_logs × 12 months) fits easily; no tuning needed.

## 8. Success criteria

- `supabase db reset` applies `20260425000001_analytics.sql` cleanly; both PgTAP regressions (analytics_aggregations + existing rls_auth_expansion + billing_quotas) pass.
- `deno test` green for `log-dish-view/` (5/5) and `export-statistics-csv/` (5/5). All prior Deno tests still pass.
- `flutter analyze && flutter test` clean. ≥ 3 new smoke tests in Statistics + 1 in Settings.
- `pnpm check && pnpm test` clean in `frontend/customer/`. (Vitest unchanged count; no new tests for IntersectionObserver.)
- Manual smoke:
  - Seed: create a Pro subscription for the seed user; seed ~20 view_logs rows across 3 days via `supabase db query`. Open `/statistics` in the merchant app → see daily chart, overview numbers, traffic by locale. No "Export CSV" button.
  - Upgrade seed to Growth via SQL (`UPDATE subscriptions SET tier='growth' WHERE owner_user_id='…'` + fan out to stores). Refresh `/statistics` → "Export CSV" button appears. Tap → system share sheet opens with a `.csv` file containing all four sections.
  - Toggle `dish_tracking_enabled` ON in Settings. Open customer view for the published menu. Scroll past 3 dishes with 2-sec pauses (or wait 2 seconds after each). Back in Statistics → "Top dishes" populates. 30 seconds later, the list updates automatically (poll).
- `grep -R 'MockData' frontend/merchant/lib/features/manage` returns no hits (Statistics is unplugged from MockData).
- All 12 new i18n keys present in both `app_en.arb` and `app_zh.arb`; `flutter gen-l10n` clean.

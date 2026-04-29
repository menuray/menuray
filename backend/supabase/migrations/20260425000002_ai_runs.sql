-- ============================================================================
-- MenuRay — AI batch quota table (Session 7).
-- See docs/superpowers/specs/2026-04-25-ai-batch-and-multi-store-design.md §4.3.
-- One row per translate-menu / ai-optimize Edge Function call. The Edge
-- Function reads count() per (store_id, current_month) to decide whether the
-- request is allowed; tier caps live in app code (_shared/quotas.ts).
-- ============================================================================

CREATE TABLE ai_runs (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id      uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  kind          text NOT NULL CHECK (kind IN ('translate','optimize')),
  target_locale text,
  dish_count    integer NOT NULL DEFAULT 0,
  ms            integer NOT NULL DEFAULT 0,
  ok            boolean NOT NULL DEFAULT true,
  error         text,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- Per-month rollups read this index for quota enforcement. PG17 forbids
-- date_trunc(timestamptz) in index expressions (STABLE, not IMMUTABLE), so
-- we index plain (store_id, created_at) instead — the planner can still do
-- a range scan for `WHERE store_id = X AND created_at >= date_trunc(month,now())`.
CREATE INDEX ai_runs_store_month_idx
  ON ai_runs (store_id, created_at DESC);

ALTER TABLE ai_runs ENABLE ROW LEVEL SECURITY;

-- Members of the store can read their own runs (quota visibility, future
-- analytics surface). No INSERT/UPDATE/DELETE policies → only the service-role
-- key (used by the Edge Functions) can mutate.
CREATE POLICY ai_runs_member_select ON ai_runs FOR SELECT TO authenticated
  USING (store_id IN (SELECT public.user_store_ids()));

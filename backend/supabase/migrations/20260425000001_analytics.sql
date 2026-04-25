-- ============================================================================
-- MenuRay — Analytics (Session 5). One atomic migration.
-- See docs/superpowers/specs/2026-04-25-analytics-real-data-design.md.
-- ============================================================================

-- ---------- 1. qr_variant + dish_tracking_enabled ---------------------------
ALTER TABLE view_logs ADD COLUMN qr_variant text;
ALTER TABLE stores ADD COLUMN dish_tracking_enabled boolean NOT NULL DEFAULT false;

-- ---------- 2. dish_view_logs table + indexes + RLS -------------------------
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

-- ---------- 3. Aggregation RPCs (SECURITY DEFINER) --------------------------
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
  SELECT count(*) INTO v_total
    FROM view_logs WHERE store_id = p_store_id AND viewed_at >= p_from AND viewed_at < p_to;
  SELECT count(DISTINCT session_id) INTO v_unique
    FROM view_logs
   WHERE store_id = p_store_id AND viewed_at >= p_from AND viewed_at < p_to
     AND session_id IS NOT NULL;
  RETURN jsonb_build_object(
    'total_views',     COALESCE(v_total, 0),
    'unique_sessions', COALESCE(v_unique, 0)
  );
END $$;
GRANT EXECUTE ON FUNCTION public.get_visits_overview(uuid, timestamptz, timestamptz) TO authenticated;

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
    SELECT generate_series(date_trunc('day', p_from),
                           date_trunc('day', p_to - interval '1 second'),
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

-- ---------- 4. Retention cron jobs (pg_cron already enabled) ---------------
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

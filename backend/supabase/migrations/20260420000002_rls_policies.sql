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

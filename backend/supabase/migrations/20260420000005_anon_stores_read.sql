-- ============================================================================
-- Customer view needs store name + logo + source_locale. Today anon has no
-- SELECT on stores (see 20260420000002_rls_policies.sql line ~95). Mirror
-- Pattern 2 from the RLS file: anon SELECT gated by an EXISTS check against
-- a published menu owned by the store.
-- ============================================================================
CREATE POLICY stores_anon_read_of_published ON stores FOR SELECT TO anon
  USING (EXISTS (
    SELECT 1 FROM menus
    WHERE menus.store_id = stores.id
      AND menus.status = 'published'
  ));

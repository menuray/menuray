-- ============================================================================
-- MenuRay — Auth expansion (ADR-018)
-- Supersedes ADR-013's single-owner model. This file is ONE atomic migration:
-- Supabase CLI wraps it in a transaction; any failure rolls the whole thing back.
-- See docs/superpowers/specs/2026-04-24-auth-migration-adr-018-design.md for rationale.
-- ============================================================================

-- ---------- 1. New tables ---------------------------------------------------
CREATE TABLE organizations (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name       text NOT NULL,
  created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE store_members (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id    uuid NOT NULL REFERENCES stores(id)     ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role        text NOT NULL CHECK (role IN ('owner','manager','staff')),
  invited_by  uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  accepted_at timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (store_id, user_id)
);

CREATE TABLE store_invites (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id    uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  email       text,
  phone       text,
  role        text NOT NULL CHECK (role IN ('manager','staff')),
  token       text NOT NULL UNIQUE DEFAULT encode(gen_random_bytes(24), 'hex'),
  invited_by  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  expires_at  timestamptz NOT NULL DEFAULT (now() + interval '7 days'),
  accepted_at timestamptz,
  accepted_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT email_or_phone CHECK ((email IS NOT NULL) <> (phone IS NOT NULL))
);

ALTER TABLE stores ADD COLUMN org_id uuid REFERENCES organizations(id) ON DELETE SET NULL;

-- Indexes
CREATE INDEX store_members_user_accepted_idx  ON store_members(user_id) WHERE accepted_at IS NOT NULL;
CREATE INDEX store_members_store_idx          ON store_members(store_id);
CREATE INDEX store_invites_token_idx          ON store_invites(token) WHERE accepted_at IS NULL;
CREATE INDEX store_invites_store_pending_idx  ON store_invites(store_id) WHERE accepted_at IS NULL;
CREATE INDEX stores_org_idx                   ON stores(org_id) WHERE org_id IS NOT NULL;

-- Touch triggers (mirrors existing pattern)
CREATE TRIGGER organizations_touch_updated_at BEFORE UPDATE ON organizations
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER store_members_touch_updated_at BEFORE UPDATE ON store_members
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER store_invites_touch_updated_at BEFORE UPDATE ON store_invites
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

-- ---------- 2. Helper functions ---------------------------------------------
CREATE FUNCTION public.user_store_ids() RETURNS SETOF uuid
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT store_id FROM store_members
  WHERE user_id = auth.uid() AND accepted_at IS NOT NULL
$$;

CREATE FUNCTION public.user_store_role(p_store_id uuid) RETURNS text
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT role FROM store_members
  WHERE user_id = auth.uid() AND store_id = p_store_id AND accepted_at IS NOT NULL
$$;

-- ---------- 3. guard_last_owner trigger -------------------------------------
CREATE FUNCTION guard_last_owner() RETURNS trigger
  LANGUAGE plpgsql AS $$
DECLARE
  v_affected_store uuid;
  v_owner_count    int;
BEGIN
  v_affected_store := COALESCE(OLD.store_id, NEW.store_id);
  IF (TG_OP = 'DELETE' AND OLD.role = 'owner')
     OR (TG_OP = 'UPDATE' AND OLD.role = 'owner' AND NEW.role <> 'owner') THEN
    SELECT count(*) INTO v_owner_count
    FROM store_members
    WHERE store_id = v_affected_store
      AND role = 'owner'
      AND accepted_at IS NOT NULL
      AND id <> OLD.id;
    IF v_owner_count = 0 THEN
      RAISE EXCEPTION 'Cannot remove or demote last owner of store %', v_affected_store
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN COALESCE(NEW, OLD);
END $$;

CREATE TRIGGER store_members_guard_last_owner
  BEFORE UPDATE OR DELETE ON store_members
  FOR EACH ROW EXECUTE FUNCTION guard_last_owner();

-- ---------- 4. RPCs ---------------------------------------------------------
CREATE FUNCTION mark_dish_soldout(p_dish_id uuid, p_sold_out boolean) RETURNS void
  LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_store uuid; v_role text;
BEGIN
  SELECT store_id INTO v_store FROM dishes WHERE id = p_dish_id;
  IF v_store IS NULL THEN RAISE EXCEPTION 'dish not found'; END IF;
  v_role := public.user_store_role(v_store);
  IF v_role IS NULL OR v_role NOT IN ('owner','manager','staff') THEN
    RAISE EXCEPTION 'not a member of this store' USING ERRCODE = 'insufficient_privilege';
  END IF;
  UPDATE dishes SET sold_out = p_sold_out, updated_at = now() WHERE id = p_dish_id;
END $$;
REVOKE ALL ON FUNCTION mark_dish_soldout FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION mark_dish_soldout TO authenticated;

CREATE FUNCTION accept_invite(p_token text) RETURNS uuid
  LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_inv store_invites; v_member_id uuid;
BEGIN
  SELECT * INTO v_inv FROM store_invites
   WHERE token = p_token AND accepted_at IS NULL
   FOR UPDATE;
  IF v_inv.id IS NULL THEN RAISE EXCEPTION 'invalid_or_expired_invite'; END IF;
  IF v_inv.expires_at < now() THEN RAISE EXCEPTION 'invite_expired'; END IF;
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'must_be_signed_in'; END IF;

  INSERT INTO store_members (store_id, user_id, role, invited_by, accepted_at)
  VALUES (v_inv.store_id, auth.uid(), v_inv.role, v_inv.invited_by, now())
  ON CONFLICT (store_id, user_id) DO UPDATE
    SET role = EXCLUDED.role, accepted_at = now()
  RETURNING id INTO v_member_id;

  UPDATE store_invites SET accepted_at = now(), accepted_by = auth.uid() WHERE id = v_inv.id;
  RETURN v_inv.store_id;
END $$;
GRANT EXECUTE ON FUNCTION accept_invite TO authenticated;

CREATE FUNCTION transfer_ownership(p_target_member_id uuid) RETURNS void
  LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_store uuid;
BEGIN
  SELECT store_id INTO v_store FROM store_members WHERE id = p_target_member_id;
  IF v_store IS NULL THEN RAISE EXCEPTION 'member not found'; END IF;
  IF public.user_store_role(v_store) IS DISTINCT FROM 'owner' THEN
    RAISE EXCEPTION 'only owner can transfer' USING ERRCODE = 'insufficient_privilege';
  END IF;
  UPDATE store_members SET role = 'owner'   WHERE id = p_target_member_id;
  UPDATE store_members SET role = 'manager' WHERE store_id = v_store AND user_id = auth.uid();
END $$;
GRANT EXECUTE ON FUNCTION transfer_ownership TO authenticated;

-- ---------- 5. Drop old Pattern 1 (owner) policies on 9 tables --------------
DROP POLICY IF EXISTS stores_owner_rw                 ON stores;
DROP POLICY IF EXISTS menus_owner_rw                  ON menus;
DROP POLICY IF EXISTS categories_owner_rw             ON categories;
DROP POLICY IF EXISTS dishes_owner_rw                 ON dishes;
DROP POLICY IF EXISTS dish_translations_owner_rw      ON dish_translations;
DROP POLICY IF EXISTS category_translations_owner_rw  ON category_translations;
DROP POLICY IF EXISTS store_translations_owner_rw     ON store_translations;
DROP POLICY IF EXISTS parse_runs_owner_rw             ON parse_runs;
DROP POLICY IF EXISTS view_logs_owner_rw              ON view_logs;

-- ---------- 6. New Pattern 1a — member SELECT on 9 tables -------------------
CREATE POLICY stores_member_select ON stores FOR SELECT TO authenticated
  USING (id IN (SELECT public.user_store_ids()));
CREATE POLICY menus_member_select ON menus FOR SELECT TO authenticated
  USING (store_id IN (SELECT public.user_store_ids()));
CREATE POLICY categories_member_select ON categories FOR SELECT TO authenticated
  USING (store_id IN (SELECT public.user_store_ids()));
CREATE POLICY dishes_member_select ON dishes FOR SELECT TO authenticated
  USING (store_id IN (SELECT public.user_store_ids()));
CREATE POLICY dish_translations_member_select ON dish_translations FOR SELECT TO authenticated
  USING (store_id IN (SELECT public.user_store_ids()));
CREATE POLICY category_translations_member_select ON category_translations FOR SELECT TO authenticated
  USING (store_id IN (SELECT public.user_store_ids()));
CREATE POLICY store_translations_member_select ON store_translations FOR SELECT TO authenticated
  USING (store_id IN (SELECT public.user_store_ids()));
CREATE POLICY parse_runs_member_select ON parse_runs FOR SELECT TO authenticated
  USING (store_id IN (SELECT public.user_store_ids()));
CREATE POLICY view_logs_member_select ON view_logs FOR SELECT TO authenticated
  USING (store_id IN (SELECT public.user_store_ids()));

-- ---------- 7. Pattern 1b — writer RW (owner+manager) on content tables -----
CREATE POLICY menus_writer_insert ON menus FOR INSERT TO authenticated
  WITH CHECK (store_id IN (SELECT public.user_store_ids())
              AND public.user_store_role(store_id) IN ('owner','manager'));
CREATE POLICY menus_writer_update ON menus FOR UPDATE TO authenticated
  USING      (store_id IN (SELECT public.user_store_ids())
              AND public.user_store_role(store_id) IN ('owner','manager'))
  WITH CHECK (store_id IN (SELECT public.user_store_ids())
              AND public.user_store_role(store_id) IN ('owner','manager'));
CREATE POLICY menus_writer_delete ON menus FOR DELETE TO authenticated
  USING (store_id IN (SELECT public.user_store_ids())
         AND public.user_store_role(store_id) IN ('owner','manager'));

CREATE POLICY categories_writer_insert ON categories FOR INSERT TO authenticated
  WITH CHECK (store_id IN (SELECT public.user_store_ids())
              AND public.user_store_role(store_id) IN ('owner','manager'));
CREATE POLICY categories_writer_update ON categories FOR UPDATE TO authenticated
  USING      (store_id IN (SELECT public.user_store_ids())
              AND public.user_store_role(store_id) IN ('owner','manager'))
  WITH CHECK (store_id IN (SELECT public.user_store_ids())
              AND public.user_store_role(store_id) IN ('owner','manager'));
CREATE POLICY categories_writer_delete ON categories FOR DELETE TO authenticated
  USING (store_id IN (SELECT public.user_store_ids())
         AND public.user_store_role(store_id) IN ('owner','manager'));

CREATE POLICY dishes_writer_insert ON dishes FOR INSERT TO authenticated
  WITH CHECK (store_id IN (SELECT public.user_store_ids())
              AND public.user_store_role(store_id) IN ('owner','manager'));
CREATE POLICY dishes_writer_update ON dishes FOR UPDATE TO authenticated
  USING      (store_id IN (SELECT public.user_store_ids())
              AND public.user_store_role(store_id) IN ('owner','manager'))
  WITH CHECK (store_id IN (SELECT public.user_store_ids())
              AND public.user_store_role(store_id) IN ('owner','manager'));
CREATE POLICY dishes_writer_delete ON dishes FOR DELETE TO authenticated
  USING (store_id IN (SELECT public.user_store_ids())
         AND public.user_store_role(store_id) IN ('owner','manager'));

CREATE POLICY dish_translations_writer_insert ON dish_translations FOR INSERT TO authenticated
  WITH CHECK (store_id IN (SELECT public.user_store_ids())
              AND public.user_store_role(store_id) IN ('owner','manager'));
CREATE POLICY dish_translations_writer_update ON dish_translations FOR UPDATE TO authenticated
  USING      (store_id IN (SELECT public.user_store_ids())
              AND public.user_store_role(store_id) IN ('owner','manager'))
  WITH CHECK (store_id IN (SELECT public.user_store_ids())
              AND public.user_store_role(store_id) IN ('owner','manager'));
CREATE POLICY dish_translations_writer_delete ON dish_translations FOR DELETE TO authenticated
  USING (store_id IN (SELECT public.user_store_ids())
         AND public.user_store_role(store_id) IN ('owner','manager'));

CREATE POLICY category_translations_writer_insert ON category_translations FOR INSERT TO authenticated
  WITH CHECK (store_id IN (SELECT public.user_store_ids())
              AND public.user_store_role(store_id) IN ('owner','manager'));
CREATE POLICY category_translations_writer_update ON category_translations FOR UPDATE TO authenticated
  USING      (store_id IN (SELECT public.user_store_ids())
              AND public.user_store_role(store_id) IN ('owner','manager'))
  WITH CHECK (store_id IN (SELECT public.user_store_ids())
              AND public.user_store_role(store_id) IN ('owner','manager'));
CREATE POLICY category_translations_writer_delete ON category_translations FOR DELETE TO authenticated
  USING (store_id IN (SELECT public.user_store_ids())
         AND public.user_store_role(store_id) IN ('owner','manager'));

-- ---------- 8. Pattern 1c — owner-only write on stores + store_translations --
CREATE POLICY stores_owner_update ON stores FOR UPDATE TO authenticated
  USING      (id IN (SELECT public.user_store_ids()) AND public.user_store_role(id) = 'owner')
  WITH CHECK (id IN (SELECT public.user_store_ids()) AND public.user_store_role(id) = 'owner');
CREATE POLICY stores_owner_delete ON stores FOR DELETE TO authenticated
  USING (id IN (SELECT public.user_store_ids()) AND public.user_store_role(id) = 'owner');

CREATE POLICY store_translations_writer_insert ON store_translations FOR INSERT TO authenticated
  WITH CHECK (store_id IN (SELECT public.user_store_ids())
              AND public.user_store_role(store_id) IN ('owner','manager'));
CREATE POLICY store_translations_writer_update ON store_translations FOR UPDATE TO authenticated
  USING      (store_id IN (SELECT public.user_store_ids())
              AND public.user_store_role(store_id) IN ('owner','manager'))
  WITH CHECK (store_id IN (SELECT public.user_store_ids())
              AND public.user_store_role(store_id) IN ('owner','manager'));
CREATE POLICY store_translations_writer_delete ON store_translations FOR DELETE TO authenticated
  USING (store_id IN (SELECT public.user_store_ids())
         AND public.user_store_role(store_id) IN ('owner','manager'));

-- ---------- 9. Pattern 1d — parse_runs INSERT/UPDATE (all roles) ------------
CREATE POLICY parse_runs_member_insert ON parse_runs FOR INSERT TO authenticated
  WITH CHECK (store_id IN (SELECT public.user_store_ids()));
CREATE POLICY parse_runs_member_update ON parse_runs FOR UPDATE TO authenticated
  USING      (store_id IN (SELECT public.user_store_ids()))
  WITH CHECK (store_id IN (SELECT public.user_store_ids()));

CREATE POLICY view_logs_member_insert ON view_logs FOR INSERT TO authenticated
  WITH CHECK (store_id IN (SELECT public.user_store_ids()));
CREATE POLICY view_logs_member_delete ON view_logs FOR DELETE TO authenticated
  USING (store_id IN (SELECT public.user_store_ids())
         AND public.user_store_role(store_id) IN ('owner','manager'));

-- Anon Pattern 2 + Pattern 3 policies from 20260420000002 are UNCHANGED.
-- Do not touch: menus_anon_read_published, categories_anon_read, dishes_anon_read,
--               dish_translations_anon_read, category_translations_anon_read,
--               store_translations_anon_read, view_logs_anon_insert,
--               stores_anon_read_of_published (from 20260420000005).

-- ---------- 10. Storage RLS rewrites ----------------------------------------
DROP POLICY IF EXISTS owner_insert_menu_photos ON storage.objects;
DROP POLICY IF EXISTS owner_update_menu_photos ON storage.objects;
DROP POLICY IF EXISTS owner_delete_menu_photos ON storage.objects;
DROP POLICY IF EXISTS owner_select_menu_photos ON storage.objects;
DROP POLICY IF EXISTS owner_insert_dish_images ON storage.objects;
DROP POLICY IF EXISTS owner_update_dish_images ON storage.objects;
DROP POLICY IF EXISTS owner_delete_dish_images ON storage.objects;
DROP POLICY IF EXISTS owner_insert_store_logos ON storage.objects;
DROP POLICY IF EXISTS owner_update_store_logos ON storage.objects;
DROP POLICY IF EXISTS owner_delete_store_logos ON storage.objects;

-- menu-photos: all roles can upload (needed for parse). SELECT/UPDATE/DELETE member-scoped.
CREATE POLICY member_insert_menu_photos ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'menu-photos'
              AND (storage.foldername(name))[1]::uuid IN (SELECT public.user_store_ids()));
CREATE POLICY member_select_menu_photos ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'menu-photos'
         AND (storage.foldername(name))[1]::uuid IN (SELECT public.user_store_ids()));
CREATE POLICY writer_update_menu_photos ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'menu-photos'
         AND (storage.foldername(name))[1]::uuid IN (SELECT public.user_store_ids())
         AND public.user_store_role((storage.foldername(name))[1]::uuid) IN ('owner','manager'))
  WITH CHECK (bucket_id = 'menu-photos'
         AND (storage.foldername(name))[1]::uuid IN (SELECT public.user_store_ids())
         AND public.user_store_role((storage.foldername(name))[1]::uuid) IN ('owner','manager'));
CREATE POLICY writer_delete_menu_photos ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'menu-photos'
         AND (storage.foldername(name))[1]::uuid IN (SELECT public.user_store_ids())
         AND public.user_store_role((storage.foldername(name))[1]::uuid) IN ('owner','manager'));

-- dish-images: owner+manager write. (Public read via bucket config.)
CREATE POLICY writer_insert_dish_images ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'dish-images'
              AND (storage.foldername(name))[1]::uuid IN (SELECT public.user_store_ids())
              AND public.user_store_role((storage.foldername(name))[1]::uuid) IN ('owner','manager'));
CREATE POLICY writer_update_dish_images ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'dish-images'
         AND (storage.foldername(name))[1]::uuid IN (SELECT public.user_store_ids())
         AND public.user_store_role((storage.foldername(name))[1]::uuid) IN ('owner','manager'))
  WITH CHECK (bucket_id = 'dish-images'
         AND (storage.foldername(name))[1]::uuid IN (SELECT public.user_store_ids())
         AND public.user_store_role((storage.foldername(name))[1]::uuid) IN ('owner','manager'));
CREATE POLICY writer_delete_dish_images ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'dish-images'
         AND (storage.foldername(name))[1]::uuid IN (SELECT public.user_store_ids())
         AND public.user_store_role((storage.foldername(name))[1]::uuid) IN ('owner','manager'));

-- store-logos: owner only write. (Public read via bucket config.)
CREATE POLICY owner_insert_store_logos ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'store-logos'
              AND (storage.foldername(name))[1]::uuid IN (SELECT public.user_store_ids())
              AND public.user_store_role((storage.foldername(name))[1]::uuid) = 'owner');
CREATE POLICY owner_update_store_logos ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'store-logos'
         AND (storage.foldername(name))[1]::uuid IN (SELECT public.user_store_ids())
         AND public.user_store_role((storage.foldername(name))[1]::uuid) = 'owner')
  WITH CHECK (bucket_id = 'store-logos'
         AND (storage.foldername(name))[1]::uuid IN (SELECT public.user_store_ids())
         AND public.user_store_role((storage.foldername(name))[1]::uuid) = 'owner');
CREATE POLICY owner_delete_store_logos ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'store-logos'
         AND (storage.foldername(name))[1]::uuid IN (SELECT public.user_store_ids())
         AND public.user_store_role((storage.foldername(name))[1]::uuid) = 'owner');

-- ---------- 11. RLS on new tables -------------------------------------------
ALTER TABLE organizations  ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_members  ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_invites  ENABLE ROW LEVEL SECURITY;

CREATE POLICY store_members_self_select ON store_members FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR store_id IN (SELECT public.user_store_ids()));
CREATE POLICY store_members_owner_insert ON store_members FOR INSERT TO authenticated
  WITH CHECK (public.user_store_role(store_id) = 'owner');
CREATE POLICY store_members_owner_update ON store_members FOR UPDATE TO authenticated
  USING      (public.user_store_role(store_id) = 'owner')
  WITH CHECK (public.user_store_role(store_id) = 'owner');
CREATE POLICY store_members_owner_delete ON store_members FOR DELETE TO authenticated
  USING (public.user_store_role(store_id) = 'owner');

CREATE POLICY store_invites_writer_rw ON store_invites FOR ALL TO authenticated
  USING      (public.user_store_role(store_id) IN ('owner','manager'))
  WITH CHECK (public.user_store_role(store_id) IN ('owner','manager'));

CREATE POLICY organizations_member_select ON organizations FOR SELECT TO authenticated
  USING (id IN (SELECT DISTINCT org_id FROM stores
                 WHERE id IN (SELECT public.user_store_ids()) AND org_id IS NOT NULL));
CREATE POLICY organizations_creator_update ON organizations FOR UPDATE TO authenticated
  USING      (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());
CREATE POLICY organizations_creator_delete ON organizations FOR DELETE TO authenticated
  USING (created_by = auth.uid());

-- ---------- 12. Rewrite handle_new_user() -----------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_store_id uuid;
BEGIN
  INSERT INTO public.stores (name) VALUES ('My restaurant') RETURNING id INTO v_store_id;
  INSERT INTO public.store_members (store_id, user_id, role, accepted_at)
    VALUES (v_store_id, NEW.id, 'owner', now());
  RETURN NEW;
END $$;

-- ---------- 13. Backfill store_members from stores.owner_id -----------------
INSERT INTO store_members (store_id, user_id, role, accepted_at)
SELECT id, owner_id, 'owner', now() FROM stores WHERE owner_id IS NOT NULL
ON CONFLICT (store_id, user_id) DO NOTHING;

-- ---------- 14. Drop owner_id ------------------------------------------------
ALTER TABLE stores DROP CONSTRAINT IF EXISTS stores_owner_id_key;
ALTER TABLE stores DROP COLUMN IF EXISTS owner_id;

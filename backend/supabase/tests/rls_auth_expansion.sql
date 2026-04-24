-- ============================================================================
-- RLS regression — ADR-018 auth expansion.
-- Usage: supabase db reset && psql "$DATABASE_URL" -f backend/supabase/tests/rls_auth_expansion.sql
-- Exit code non-zero on any FAIL.
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on

BEGIN;

-- Fixtures: 2 stores, 4 users, roles covering every write-matrix row.
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                        is_super_admin, created_at, updated_at,
                        confirmation_token, email_change, email_change_token_new, recovery_token)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','00000000-0000-0000-0000-000000000000','authenticated','authenticated','a@test','', now(),'{}','{}',false,now(),now(),'','','',''),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','00000000-0000-0000-0000-000000000000','authenticated','authenticated','b@test','', now(),'{}','{}',false,now(),now(),'','','',''),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc','00000000-0000-0000-0000-000000000000','authenticated','authenticated','c@test','', now(),'{}','{}',false,now(),now(),'','','',''),
  ('dddddddd-dddd-dddd-dddd-dddddddddddd','00000000-0000-0000-0000-000000000000','authenticated','authenticated','d@test','', now(),'{}','{}',false,now(),now(),'','','','')
ON CONFLICT (id) DO NOTHING;

-- Two stores (created by trigger inserts — but we skip trigger here, manual insert).
INSERT INTO stores (id, name) VALUES
  ('11111111-2222-2222-2222-222222222222','store X'),
  ('33333333-4444-4444-4444-444444444444','store Y')
ON CONFLICT (id) DO NOTHING;

-- Memberships: A=owner(X), B=manager(X), C=staff(X), D=owner(Y).
INSERT INTO store_members (store_id, user_id, role, accepted_at) VALUES
  ('11111111-2222-2222-2222-222222222222','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','owner',   now()),
  ('11111111-2222-2222-2222-222222222222','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','manager', now()),
  ('11111111-2222-2222-2222-222222222222','cccccccc-cccc-cccc-cccc-cccccccccccc','staff',   now()),
  ('33333333-4444-4444-4444-444444444444','dddddddd-dddd-dddd-dddd-dddddddddddd','owner',   now())
ON CONFLICT (store_id, user_id) DO NOTHING;

-- One dish per store for write assertions.
INSERT INTO menus (id, store_id, name, status, slug, source_locale)
VALUES
  ('aaaa1111-0000-0000-0000-000000000001','11111111-2222-2222-2222-222222222222','X menu','published','x-menu','en'),
  ('bbbb1111-0000-0000-0000-000000000002','33333333-4444-4444-4444-444444444444','Y menu','draft',NULL,'en')
ON CONFLICT DO NOTHING;
INSERT INTO categories (id, menu_id, store_id, source_name)
VALUES
  ('cccc1111-0000-0000-0000-000000000001','aaaa1111-0000-0000-0000-000000000001','11111111-2222-2222-2222-222222222222','x-cat'),
  ('dddd1111-0000-0000-0000-000000000002','bbbb1111-0000-0000-0000-000000000002','33333333-4444-4444-4444-444444444444','y-cat')
ON CONFLICT DO NOTHING;
INSERT INTO dishes (id, category_id, menu_id, store_id, source_name, price)
VALUES
  ('eeee1111-0000-0000-0000-000000000001','cccc1111-0000-0000-0000-000000000001','aaaa1111-0000-0000-0000-000000000001','11111111-2222-2222-2222-222222222222','x-dish',10),
  ('ffff1111-0000-0000-0000-000000000002','dddd1111-0000-0000-0000-000000000002','bbbb1111-0000-0000-0000-000000000002','33333333-4444-4444-4444-444444444444','y-dish',10)
ON CONFLICT DO NOTHING;

-- ----- Helper: run a query as a specific user -----
CREATE OR REPLACE FUNCTION pg_temp.as_user(p_uid uuid) RETURNS void
  LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('role','authenticated',true);
  PERFORM set_config('request.jwt.claim.sub', p_uid::text, true);
END $$;

-- =============== A. SELECT assertions ========================================
SELECT pg_temp.as_user('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');  -- Owner(X)
DO $$ BEGIN
  ASSERT (SELECT count(*) FROM stores  WHERE id = '11111111-2222-2222-2222-222222222222') = 1,
         'Owner should see own store';
  ASSERT (SELECT count(*) FROM stores  WHERE id = '33333333-4444-4444-4444-444444444444') = 0,
         'Owner should NOT see other store';
  ASSERT (SELECT count(*) FROM dishes  WHERE store_id = '11111111-2222-2222-2222-222222222222') = 1,
         'Owner should read own dishes';
  ASSERT (SELECT count(*) FROM dishes  WHERE store_id = '33333333-4444-4444-4444-444444444444') = 0,
         'Cross-store dishes hidden';
END $$;

SELECT pg_temp.as_user('cccccccc-cccc-cccc-cccc-cccccccccccc');  -- Staff(X)
DO $$ BEGIN
  ASSERT (SELECT count(*) FROM dishes  WHERE store_id = '11111111-2222-2222-2222-222222222222') = 1,
         'Staff reads own store dishes';
END $$;

SELECT pg_temp.as_user('dddddddd-dddd-dddd-dddd-dddddddddddd');  -- Owner(Y)
DO $$ BEGIN
  ASSERT (SELECT count(*) FROM dishes  WHERE store_id = '11111111-2222-2222-2222-222222222222') = 0,
         'User of store Y cannot see store X dishes';
END $$;

-- Anon read published menu still works.
SELECT set_config('role','anon',true);
DO $$ BEGIN
  ASSERT (SELECT count(*) FROM menus WHERE status = 'published') >= 1,
         'Anon can still read published menus';
  ASSERT (SELECT count(*) FROM menus WHERE status = 'draft') = 0,
         'Anon cannot see draft menus';
END $$;

-- =============== B. Write assertions =========================================
SELECT pg_temp.as_user('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');  -- Manager(X)
DO $$ BEGIN
  UPDATE dishes SET source_name = 'edited' WHERE id = 'eeee1111-0000-0000-0000-000000000001';
  ASSERT (SELECT source_name FROM dishes WHERE id = 'eeee1111-0000-0000-0000-000000000001') = 'edited',
         'Manager can update dish';
END $$;

SELECT pg_temp.as_user('cccccccc-cccc-cccc-cccc-cccccccccccc');  -- Staff(X)
DO $$ DECLARE v_rows int; BEGIN
  UPDATE dishes SET source_name = 'staff-edit' WHERE id = 'eeee1111-0000-0000-0000-000000000001';
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  ASSERT v_rows = 0, 'Staff cannot directly UPDATE dishes (RLS blocks)';
  ASSERT (SELECT source_name FROM public.dishes WHERE id = 'eeee1111-0000-0000-0000-000000000001') = 'edited',
         'Row unchanged by staff UPDATE attempt';
END $$;

-- mark_dish_soldout RPC: staff CAN toggle sold_out.
DO $$ BEGIN
  PERFORM mark_dish_soldout('eeee1111-0000-0000-0000-000000000001', true);
  ASSERT (SELECT sold_out FROM public.dishes WHERE id = 'eeee1111-0000-0000-0000-000000000001') = true,
         'Staff mark_dish_soldout RPC succeeds';
END $$;

-- Staff cannot mark another store's dish.
DO $$ BEGIN
  BEGIN
    PERFORM mark_dish_soldout('ffff1111-0000-0000-0000-000000000002', true);
    ASSERT false, 'mark_dish_soldout should have raised on cross-store';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL; -- expected
  END;
END $$;

-- =============== C. guard_last_owner =========================================
SELECT pg_temp.as_user('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');  -- Owner(X)
-- Remove the sole owner row (A). Store X has only one owner → must raise.
DO $$ BEGIN
  BEGIN
    DELETE FROM store_members WHERE store_id = '11111111-2222-2222-2222-222222222222'
                                AND user_id  = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
    ASSERT false, 'guard_last_owner should have raised on last-owner DELETE';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;
END $$;

-- Demoting A when there's a second owner should succeed.
INSERT INTO store_members (store_id, user_id, role, accepted_at) VALUES
  ('11111111-2222-2222-2222-222222222222','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','owner',now())
ON CONFLICT (store_id, user_id) DO UPDATE SET role='owner';
DO $$ BEGIN
  UPDATE store_members SET role = 'manager'
   WHERE store_id = '11111111-2222-2222-2222-222222222222'
     AND user_id  = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  ASSERT (SELECT role FROM store_members
          WHERE store_id='11111111-2222-2222-2222-222222222222'
            AND user_id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = 'manager',
         'Demotion allowed when a second owner exists';
END $$;

-- =============== D. Invite round-trip ========================================
SELECT pg_temp.as_user('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');  -- Owner(X) now
INSERT INTO store_invites (store_id, email, role, invited_by)
VALUES ('11111111-2222-2222-2222-222222222222','invitee@test.com','manager','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
SELECT pg_temp.as_user('dddddddd-dddd-dddd-dddd-dddddddddddd');  -- Unrelated user
DO $$ DECLARE v_token text; v_store uuid; BEGIN
  SELECT token INTO v_token FROM public.store_invites WHERE email='invitee@test.com';
  v_store := accept_invite(v_token);
  ASSERT v_store = '11111111-2222-2222-2222-222222222222', 'accept_invite returns store';
  ASSERT (SELECT count(*) FROM public.store_members
          WHERE store_id='11111111-2222-2222-2222-222222222222'
            AND user_id='dddddddd-dddd-dddd-dddd-dddddddddddd') = 1,
         'Invited user now has membership';
  ASSERT (SELECT accepted_at FROM public.store_invites WHERE email='invitee@test.com') IS NOT NULL,
         'Invite marked accepted';
END $$;

-- =============== E. store_invites RLS ========================================
SELECT pg_temp.as_user('cccccccc-cccc-cccc-cccc-cccccccccccc');  -- Staff(X)
DO $$ DECLARE v_rows int; BEGIN
  INSERT INTO store_invites (store_id, email, role, invited_by)
  VALUES ('11111111-2222-2222-2222-222222222222','x@t','manager','cccccccc-cccc-cccc-cccc-cccccccccccc');
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  ASSERT v_rows = 0, 'Staff cannot create invites';
EXCEPTION WHEN insufficient_privilege OR check_violation THEN
  NULL;
END $$;

ROLLBACK;

\echo 'rls_auth_expansion.sql: all assertions passed'

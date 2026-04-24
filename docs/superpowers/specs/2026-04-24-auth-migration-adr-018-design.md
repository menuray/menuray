# Auth Migration (ADR-018) — Design

Date: 2026-04-24
Scope: Replace ADR-013's `stores.owner_id UNIQUE` single-owner model with ADR-018's `store_members + organizations + store_invites` tables, 3-role RBAC (Owner / Manager / Staff), and a `guard_last_owner` integrity trigger. One atomic migration. Touches every RLS policy, the signup trigger, seed, Flutter repositories + two new screens, one new Edge Function, one new SvelteKit page, and i18n in en + zh.
Audience: whoever implements the follow-up plan. ADR-018 is already ratified — do not revisit the architectural choices; implement.

## 1. Goal & Scope

High-level outcome:

```
Before                                  After
──────                                  ─────
stores.owner_id UNIQUE  ────────▶       stores.org_id (nullable) → organizations
                                        store_members (store_id, user_id, role, accepted_at, invited_by)
                                        store_invites (7-day token TTL)

RLS pattern                             RLS pattern
  store_id IN (SELECT id FROM            store_id IN (SELECT store_id FROM
    stores WHERE owner_id = auth.uid())    auth.user_store_ids())  ← STABLE helper

Flutter                                  Flutter
  currentStoreProvider → single store    activeStoreProvider (StateProvider<StoreContext?>)
                                         ownerStoresProvider → real List<Membership>
                                         /store-picker route (auto-skip if len<2)
                                         /team-management/:storeId route

handle_new_user()                        handle_new_user()
  INSERT stores(owner_id=NEW.id)         INSERT stores(...) + INSERT store_members(role='owner')

Invite flow                              Invite flow
  none                                   email magic link via Supabase templates
                                         → SvelteKit /accept-invite?token=X
                                         → Edge Function validates + writes store_members
```

**In scope**

- **Single atomic migration** `backend/supabase/migrations/20260424000001_auth_expansion.sql` adding `organizations`, `store_members`, `store_invites`, the `auth.user_store_ids()` helper, the `guard_last_owner` trigger, the `mark_dish_soldout()` RPC, rewritten RLS across 9 tables + 3 storage buckets, rewritten `handle_new_user()`, and a `stores.owner_id` → `store_members` backfill. `stores.owner_id` column + UNIQUE constraint are dropped in the same migration.
- **Seed update** (`backend/supabase/seed.sql`) — existing seed user becomes `role='owner'` of the demo store via `store_members`; no behavior change for the seed account's UX.
- **Flutter merchant:**
  - Top-level `StateProvider<StoreContext?> activeStoreProvider` (storeId + role) persisted to `SharedPreferences` key `menuray.active_store_id`.
  - `MembershipRepository` with `listMyMemberships()`, `listStoreMembers(storeId)`, `listStoreInvites(storeId)`, `createInvite(storeId, email, role)`, `revokeInvite(inviteId)`, `updateMemberRole(memberId, role)`, `removeMember(memberId)`.
  - Rewire all existing providers to consume `activeStoreProvider` instead of `currentStoreProvider.single`.
  - New `/store-picker` screen (dedicated route) shown after login when `memberships.length >= 2`, auto-bypasses to `/` otherwise.
  - New `/team-management/:storeId` screen linked from each card in `StoreManagementScreen`. Lists current members (role pills + avatar) and pending invites. Owner/Manager can invite; Owner can change roles and remove members; `guard_last_owner` protects the last Owner.
  - New `RoleGate` shared widget hiding write-actions for `role='staff'`.
  - `MenuRepository.markDishSoldOut(dishId, bool)` swapped from `UPDATE dishes SET sold_out=?` to `rpc('mark_dish_soldout', …)` so Staff writes succeed.
  - go_router redirect extended: signed-in user with zero memberships → dead-end error page ("Your account has no active store"); signed-in user with ≥ 2 memberships and no active store → `/store-picker`.
  - 22 new i18n keys in en + zh (see §3.11).
- **Backend:**
  - New Edge Function `backend/supabase/functions/accept-invite/` (Deno) that validates a token, inserts `store_members`, flips `store_invites.accepted_at`, and returns the target `store_id`. Token validation is SECURITY DEFINER at the DB level via an RPC `accept_invite(p_token text)`.
  - **Invite delivery this session** is "Copy link" — the merchant creates the invite, the UI shows a modal with the `https://menu.menuray.com/accept-invite?token=…` URL plus a Copy button; merchant pastes it into their own email/chat. Email SMTP delivery (branded template through an Edge Function) is the natural follow-up — deferred. See §3.14.
- **SvelteKit customer project (additive only):**
  - New route `frontend/customer/src/routes/accept-invite/` — SSR page reading `?token=X`, calling the Edge Function, and showing success / expired / already-accepted states. Uses existing brand shell. Does **not** change any customer-view data path for published menus.
- **Testing:**
  - PgTAP-style regression script under `backend/supabase/tests/rls_auth_expansion.sql` exercising: Owner R/W own store, Manager R/W but no delete, Staff R + sold-out only, cross-store read blocked (anon + authenticated), anon read of published still works, `guard_last_owner` raises on last-owner removal.
  - Deno unit tests for `accept-invite` (valid token, expired token, replay, mismatched email).
  - Flutter smoke tests: store_picker_screen, team_management_screen. Extend existing login_screen smoke for multi-membership redirect.
  - Flutter unit tests: mappers for `StoreMember` + `StoreInvite` + `Organization`; `MembershipRepository` happy-path against mock client.

**Out of scope (deferred)**

- **SMS invites via 短信宝** (product-decisions A-3). The `InviteProvider` interface is defined but only the email implementation ships; SMS is a follow-up session. Rationale: ADR-018 explicitly calls SMS "China add-on"; standing up 短信宝 is independent 1–2 days of work.
- **Organizations UI.** The `organizations` table + `stores.org_id` column land in this session, but no "create organization" / "switch organization" / "rename organization" UI. Session 4 billing auto-creates an `organizations` row on Growth-tier upgrade (product-decisions A-5). Until then every store has `org_id = NULL`.
- **Multi-store paywall gating.** ADR-018 explicitly defers paywall enforcement to billing (Session 4): this migration ships with "all tiers can have multi-store" so the data path is exercisable; enforcement is wired in when Stripe lands.
- **Seat-limit enforcement.** Pending invites counting against the seat limit (product-decisions A-2) is a business rule tied to tier; deferred to Session 4 alongside the tier cap numbers. This session's `store_invites` writes don't check a cap.
- **Owner transfer UX.** Schema supports it (Owner can `updateMemberRole(otherManager, 'owner')` then demote self to Manager — `guard_last_owner` allows this if it happens in a single transaction via the `transfer_ownership(p_member_id uuid)` RPC we ship). The Flutter UI for the transfer button is deferred; RPC ships now so a future UI PR is one screen change.
- **Bulk invite / CSV upload / directory sync** — not in roadmap.
- **Audit log of membership changes** — deferred; `created_at`/`updated_at` on `store_members` is the minimum.

## 2. Context

- Current migrations (7 files, `20260420000001` → `20260420000007`) establish the 9-table schema, owner-based RLS, three storage buckets (menu-photos / dish-images / store-logos), `handle_new_user()` trigger, anon-read-of-published extensions, templates, and `parse_runs.*_raw_response` diagnostic columns.
- The seed user `seed@menuray.com / demo1234` (fixed UUID `11111111-1111-1111-1111-111111111111`) owns one store (云间小厨 · 静安店) with one published menu. All Flutter smoke tests + customer-view e2e hit this dataset.
- ADR-017 Flutter data-layer pattern: `SupabaseClient` → `*Repository` (thin) → `*Mapper` (pure function) → `FutureProvider` / `StreamProvider`. This migration does NOT invent a new pattern; it adds `MembershipRepository` and `OrganizationRepository` shaped identically to `StoreRepository` / `MenuRepository`.
- ADR-018 §Decisions pins the shape of `store_members` / `organizations` / `store_invites` and the `auth.user_store_ids()` RLS helper. Do NOT modify those shapes; this spec translates them into executable migration + code.
- Product decisions §3 lists the **role × action matrix** (13 rows). Every write policy below maps to one row in that matrix.
- `product-decisions.md` §3 "Migration plan" lists 5 steps: additive DDL → backfill → RLS swap → deploy app → drop `owner_id` next sprint. We compress steps 1-3 into a single migration file (the DDL is additive *within* the transaction; the RLS swap + column drop run after backfill within the same txn). "Deploy app" is step 4 (normal commit + merge); "drop owner_id next sprint" becomes "drop owner_id at end of same migration" per decision-matrix row 2.
- Customer view (`frontend/customer/`) currently depends on `stores_anon_read_of_published` (migration `20260420000005`). That policy is unchanged by this migration — published menus keep their anon read path. Verified by the RLS regression script.

## 3. Decisions

### 3.1 Migration file layout

**One file, one transaction.** File: `backend/supabase/migrations/20260424000001_auth_expansion.sql`. Internal ordering:

1. `CREATE TABLE organizations`, `CREATE TABLE store_members`, `CREATE TABLE store_invites`.
2. `ALTER TABLE stores ADD COLUMN org_id`.
3. `CREATE INDEX` statements (see §4).
4. `CREATE FUNCTION auth.user_store_ids()` + `CREATE FUNCTION public.guard_last_owner()` + `CREATE TRIGGER`.
5. `CREATE FUNCTION public.mark_dish_soldout()` + `CREATE FUNCTION public.accept_invite()` + `CREATE FUNCTION public.transfer_ownership()`.
6. `DROP POLICY` each of 9 Pattern-1 owner RLS policies (tables) + 12 storage-bucket policies.
7. `CREATE POLICY` each using new template (see §3.3, §3.4).
8. **Backfill:** `INSERT INTO store_members (store_id, user_id, role, accepted_at) SELECT id, owner_id, 'owner', now() FROM stores WHERE owner_id IS NOT NULL`.
9. `CREATE OR REPLACE FUNCTION handle_new_user()` — new body (see §3.7).
10. `ALTER TABLE stores DROP CONSTRAINT stores_owner_id_key`, then `ALTER TABLE stores DROP COLUMN owner_id CASCADE`.
11. `ALTER TABLE store_members ENABLE ROW LEVEL SECURITY` + policies for `store_members`, `organizations`, `store_invites` (see §3.3).

No `BEGIN;` / `COMMIT;` needed — Supabase CLI wraps each migration file in a transaction automatically.

Rationale: a single file means (a) one `supabase db reset` re-runs it idempotently, (b) one down-revert is `DROP` of the file's artefacts, (c) integration test script applies once and asserts end state.

### 3.2 New tables

```sql
-- organizations — optional chain grouping; Growth-tier only creates rows.
CREATE TABLE organizations (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name       text NOT NULL,
  created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- store_members — source of truth for access.
CREATE TABLE store_members (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id    uuid NOT NULL REFERENCES stores(id)   ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role        text NOT NULL CHECK (role IN ('owner','manager','staff')),
  invited_by  uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  accepted_at timestamptz,                   -- NULL = invited but not accepted
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (store_id, user_id)
);

-- store_invites — pending invites with 7-day tokens.
CREATE TABLE store_invites (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id    uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  email       text,                                  -- NULL if SMS invite
  phone       text,                                  -- NULL if email invite
  role        text NOT NULL CHECK (role IN ('manager','staff')), -- cannot invite owner
  token       text NOT NULL UNIQUE DEFAULT encode(gen_random_bytes(24), 'hex'),
  invited_by  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  expires_at  timestamptz NOT NULL DEFAULT (now() + interval '7 days'),
  accepted_at timestamptz,
  accepted_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT email_or_phone CHECK ((email IS NOT NULL) <> (phone IS NOT NULL))
);

-- link stores to organizations (nullable).
ALTER TABLE stores ADD COLUMN org_id uuid REFERENCES organizations(id) ON DELETE SET NULL;

-- touch_updated_at triggers on the three new tables (mirrors existing pattern).
CREATE TRIGGER organizations_touch_updated_at BEFORE UPDATE ON organizations
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER store_members_touch_updated_at BEFORE UPDATE ON store_members
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER store_invites_touch_updated_at BEFORE UPDATE ON store_invites
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
```

Indexes:
```sql
CREATE INDEX store_members_user_accepted_idx  ON store_members(user_id) WHERE accepted_at IS NOT NULL;
CREATE INDEX store_members_store_idx          ON store_members(store_id);
CREATE INDEX store_invites_token_idx          ON store_invites(token) WHERE accepted_at IS NULL;
CREATE INDEX store_invites_store_pending_idx  ON store_invites(store_id) WHERE accepted_at IS NULL;
CREATE INDEX stores_org_idx                   ON stores(org_id) WHERE org_id IS NOT NULL;
```

### 3.3 RLS template — table policies

**Helper function** (STABLE + SECURITY DEFINER so RLS itself can call it without recursion):
```sql
CREATE FUNCTION auth.user_store_ids() RETURNS SETOF uuid
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT store_id FROM store_members
  WHERE user_id = auth.uid() AND accepted_at IS NOT NULL
$$;

CREATE FUNCTION auth.user_store_role(p_store_id uuid) RETURNS text
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT role FROM store_members
  WHERE user_id = auth.uid() AND store_id = p_store_id AND accepted_at IS NOT NULL
$$;
```

**Pattern 1a — member SELECT** (all 3 roles can read):
```sql
CREATE POLICY <table>_member_select ON <table> FOR SELECT TO authenticated
  USING (store_id IN (SELECT auth.user_store_ids()));
```
Applies to: `stores`, `menus`, `categories`, `dishes`, `dish_translations`, `category_translations`, `store_translations`, `parse_runs`, `view_logs`. (9 tables.)

**Pattern 1b — owner/manager write** (INSERT, UPDATE, DELETE) on content tables `menus`, `categories`, `dishes`, `dish_translations`, `category_translations`:
```sql
CREATE POLICY <table>_writer_rw ON <table> FOR INSERT TO authenticated
  WITH CHECK (store_id IN (SELECT auth.user_store_ids())
              AND auth.user_store_role(store_id) IN ('owner','manager'));
CREATE POLICY <table>_writer_update ON <table> FOR UPDATE TO authenticated
  USING      (store_id IN (SELECT auth.user_store_ids())
              AND auth.user_store_role(store_id) IN ('owner','manager'))
  WITH CHECK (store_id IN (SELECT auth.user_store_ids())
              AND auth.user_store_role(store_id) IN ('owner','manager'));
CREATE POLICY <table>_writer_delete ON <table> FOR DELETE TO authenticated
  USING (store_id IN (SELECT auth.user_store_ids())
         AND auth.user_store_role(store_id) IN ('owner','manager'));
```

**Pattern 1c — owner-only write** on `stores` + `store_translations`:
```sql
CREATE POLICY stores_owner_update ON stores FOR UPDATE TO authenticated
  USING      (id IN (SELECT auth.user_store_ids()) AND auth.user_store_role(id) = 'owner')
  WITH CHECK (id IN (SELECT auth.user_store_ids()) AND auth.user_store_role(id) = 'owner');
CREATE POLICY stores_owner_delete ON stores FOR DELETE TO authenticated
  USING (id IN (SELECT auth.user_store_ids()) AND auth.user_store_role(id) = 'owner');
-- No INSERT policy: stores are created only by handle_new_user() (service-role).
```

**Pattern 1d — parse_runs INSERT/UPDATE** — all roles can run a parse (per product-decisions §3 "Run OCR parse ✓ all three"):
```sql
CREATE POLICY parse_runs_member_insert ON parse_runs FOR INSERT TO authenticated
  WITH CHECK (store_id IN (SELECT auth.user_store_ids()));
CREATE POLICY parse_runs_member_update ON parse_runs FOR UPDATE TO authenticated
  USING      (store_id IN (SELECT auth.user_store_ids()))
  WITH CHECK (store_id IN (SELECT auth.user_store_ids()));
```
(`dishes.sold_out` is the one exception for Staff writes — gated via RPC, see §3.6.)

**Pattern 2 — anon SELECT on published menus + children** — UNCHANGED. Policies stay identical. Verified in the RLS regression script.

**Pattern 3 — anon INSERT on view_logs** — UNCHANGED.

**`store_members` self-policies** — users see their own memberships; owners/managers see all memberships in their stores; only owners can INSERT/UPDATE/DELETE:
```sql
CREATE POLICY store_members_self_select ON store_members FOR SELECT TO authenticated
  USING (user_id = auth.uid()
         OR store_id IN (SELECT auth.user_store_ids())); -- members see peers
CREATE POLICY store_members_owner_insert ON store_members FOR INSERT TO authenticated
  WITH CHECK (auth.user_store_role(store_id) = 'owner');
CREATE POLICY store_members_owner_update ON store_members FOR UPDATE TO authenticated
  USING      (auth.user_store_role(store_id) = 'owner')
  WITH CHECK (auth.user_store_role(store_id) = 'owner');
CREATE POLICY store_members_owner_delete ON store_members FOR DELETE TO authenticated
  USING (auth.user_store_role(store_id) = 'owner');
```
(Row inserted by `accept_invite()` SECURITY DEFINER bypasses RLS; so does the seeding code in `handle_new_user()`.)

**`store_invites`** — owners/managers can CRUD their store's invites:
```sql
CREATE POLICY store_invites_writer_rw ON store_invites FOR ALL TO authenticated
  USING      (auth.user_store_role(store_id) IN ('owner','manager'))
  WITH CHECK (auth.user_store_role(store_id) IN ('owner','manager'));
-- anon cannot touch store_invites. Invite acceptance runs via SECURITY DEFINER RPC.
```

**`organizations`** — members of any store in the org can read; only the `created_by` can update or delete:
```sql
CREATE POLICY organizations_member_select ON organizations FOR SELECT TO authenticated
  USING (id IN (SELECT DISTINCT org_id FROM stores WHERE id IN (SELECT auth.user_store_ids())));
CREATE POLICY organizations_creator_update ON organizations FOR UPDATE TO authenticated
  USING      (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());
CREATE POLICY organizations_creator_delete ON organizations FOR DELETE TO authenticated
  USING (created_by = auth.uid());
-- No INSERT policy: created only by billing edge function (service-role) in Session 4.
```

### 3.4 Storage RLS

Rewrite all 12 storage policies (4 × menu-photos + 4 × dish-images + 4 × store-logos) to gate on `auth.user_store_ids()` + role. Template:

```sql
-- menu-photos INSERT — all roles can upload parse source photos.
CREATE POLICY member_insert_menu_photos ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'menu-photos'
    AND (storage.foldername(name))[1]::uuid IN (SELECT auth.user_store_ids())
  );

-- dish-images INSERT — owner/manager only (content write).
CREATE POLICY writer_insert_dish_images ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'dish-images'
    AND (storage.foldername(name))[1]::uuid IN (SELECT auth.user_store_ids())
    AND auth.user_store_role((storage.foldername(name))[1]::uuid) IN ('owner','manager')
  );

-- store-logos INSERT — owner only (store settings).
CREATE POLICY owner_insert_store_logos ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'store-logos'
    AND (storage.foldername(name))[1]::uuid IN (SELECT auth.user_store_ids())
    AND auth.user_store_role((storage.foldername(name))[1]::uuid) = 'owner'
  );
```

UPDATE + DELETE mirror with `USING` + `WITH CHECK`. SELECT on menu-photos (private bucket) matches the member template.

### 3.5 Triggers

**`guard_last_owner`** — prevent orphaning a store:

```sql
CREATE FUNCTION guard_last_owner() RETURNS trigger
  LANGUAGE plpgsql AS $$
DECLARE
  v_affected_store uuid;
  v_owner_count    int;
BEGIN
  -- Which store is this row about? (OLD on delete/update; new owner demotions = OLD)
  v_affected_store := COALESCE(OLD.store_id, NEW.store_id);

  -- If OLD was owner AND after this op the store would have zero owners, reject.
  IF (TG_OP = 'DELETE' AND OLD.role = 'owner')
     OR (TG_OP = 'UPDATE' AND OLD.role = 'owner' AND NEW.role <> 'owner') THEN
    SELECT count(*) INTO v_owner_count
    FROM store_members
    WHERE store_id = v_affected_store
      AND role = 'owner'
      AND accepted_at IS NOT NULL
      AND id <> OLD.id;   -- exclude the row being changed
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
```

Unit tested via the PgTAP script. Note the `id <> OLD.id` filter so that counting "surviving owners" doesn't include the row being changed — critical for the UPDATE case (demoting self).

### 3.6 RPCs

**`mark_dish_soldout(p_dish_id uuid, p_sold_out boolean)`** — staff-safe single-column write:
```sql
CREATE FUNCTION mark_dish_soldout(p_dish_id uuid, p_sold_out boolean) RETURNS void
  LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_store uuid; v_role text;
BEGIN
  SELECT store_id INTO v_store FROM dishes WHERE id = p_dish_id;
  IF v_store IS NULL THEN RAISE EXCEPTION 'dish not found'; END IF;
  v_role := auth.user_store_role(v_store);
  IF v_role NOT IN ('owner','manager','staff') THEN
    RAISE EXCEPTION 'not a member of this store' USING ERRCODE = 'insufficient_privilege';
  END IF;
  UPDATE dishes SET sold_out = p_sold_out, updated_at = now() WHERE id = p_dish_id;
END $$;

REVOKE ALL ON FUNCTION mark_dish_soldout FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION mark_dish_soldout TO authenticated;
```

Flutter call: `supabase.rpc('mark_dish_soldout', params: {'p_dish_id': dishId, 'p_sold_out': value})`. Replaces the current `UPDATE dishes SET sold_out=?` path in `MenuRepository.markDishSoldOut`.

**`accept_invite(p_token text)`** — SECURITY DEFINER validator invoked from the `accept-invite` Edge Function:
```sql
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
```

**`transfer_ownership(p_target_member_id uuid)`** — promotes target to Owner and demotes caller to Manager atomically (bypasses `guard_last_owner` momentarily by running the two updates in a single statement using a CTE):
```sql
CREATE FUNCTION transfer_ownership(p_target_member_id uuid) RETURNS void
  LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_store uuid;
BEGIN
  SELECT store_id INTO v_store FROM store_members WHERE id = p_target_member_id;
  IF v_store IS NULL THEN RAISE EXCEPTION 'member not found'; END IF;
  IF auth.user_store_role(v_store) <> 'owner' THEN
    RAISE EXCEPTION 'only owner can transfer' USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- Promote target first, then demote caller — trigger allows demotion because
  -- target is already owner by the time we run the second UPDATE.
  UPDATE store_members SET role = 'owner'   WHERE id = p_target_member_id;
  UPDATE store_members SET role = 'manager' WHERE store_id = v_store AND user_id = auth.uid();
END $$;
GRANT EXECUTE ON FUNCTION transfer_ownership TO authenticated;
```
(UI defers to Session 4; RPC ships now to avoid a future migration-for-one-function.)

### 3.7 `handle_new_user()` rewrite + seed backfill

```sql
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_store_id uuid;
BEGIN
  INSERT INTO public.stores (name) VALUES ('My restaurant') RETURNING id INTO v_store_id;
  INSERT INTO public.store_members (store_id, user_id, role, accepted_at)
    VALUES (v_store_id, NEW.id, 'owner', now());
  RETURN NEW;
END $$;
```

**Backfill** (before `owner_id` is dropped, same transaction):
```sql
INSERT INTO store_members (store_id, user_id, role, accepted_at)
SELECT id, owner_id, 'owner', now() FROM stores WHERE owner_id IS NOT NULL
ON CONFLICT (store_id, user_id) DO NOTHING;
```

Then:
```sql
ALTER TABLE stores DROP CONSTRAINT IF EXISTS stores_owner_id_key;
ALTER TABLE stores DROP COLUMN IF EXISTS owner_id;
```

Existing seed.sql's line `UPDATE stores … WHERE owner_id = '11111111-…'` must be rewritten to `WHERE id IN (SELECT store_id FROM store_members WHERE user_id = '11111111-…')` — or simpler: change to `UPDATE stores SET … WHERE name = 'My restaurant'` (one store per seed apply, before other seed inserts). Spec picks the second variant for clarity.

### 3.8 Flutter: StoreContext + routing

**New state primitives** (`frontend/merchant/lib/features/store/active_store_provider.dart`):
```dart
class StoreContext {
  final String storeId;
  final String role; // 'owner'|'manager'|'staff'
  const StoreContext({required this.storeId, required this.role});
  bool get canWrite => role == 'owner' || role == 'manager';
  bool get canManageTeam => role == 'owner';
  bool get canOwnerOnly => role == 'owner';
  // JSON marshalling for SharedPreferences.
}
final activeStoreProvider = StateNotifierProvider<ActiveStoreNotifier, StoreContext?>(...);
// ActiveStoreNotifier loads/saves SharedPreferences key 'menuray.active_store_id'.
// On login event clears + re-resolves; on signOut clears.
```

**Memberships fetch** (`frontend/merchant/lib/features/store/membership_repository.dart`):
```dart
class MembershipRepository {
  MembershipRepository(this._client);
  final SupabaseClient _client;

  Future<List<Membership>> listMyMemberships() async {
    final rows = await _client.from('store_members')
      .select('id, role, accepted_at, store:stores(id, name, logo_url, source_locale)')
      .eq('user_id', _client.auth.currentUser!.id)
      .not('accepted_at', 'is', null);
    return (rows as List).cast<Map<String, dynamic>>().map(membershipFromSupabase).toList();
  }

  Future<List<StoreMember>> listStoreMembers(String storeId) async { ... }
  Future<List<StoreInvite>> listStoreInvites(String storeId) async { ... }

  Future<void> createInvite({
    required String storeId, required String email, required String role}) async { ... }
  Future<void> revokeInvite(String inviteId) async { ... }
  Future<void> updateMemberRole({required String memberId, required String role}) async { ... }
  Future<void> removeMember(String memberId) async { ... }
}
```

**Providers** (replace `currentStoreProvider`):
```dart
final membershipsProvider = FutureProvider<List<Membership>>((ref) async {
  ref.watch(authStateProvider);
  return ref.watch(membershipRepositoryProvider).listMyMemberships();
});

final activeStoreDetailProvider = FutureProvider<Store>((ref) async {
  final ctx = ref.watch(activeStoreProvider);
  if (ctx == null) throw StateError('No active store');
  return ref.watch(storeRepositoryProvider).fetchById(ctx.storeId);
});

// backwards-compat shim during migration; existing call sites redirect here:
final currentStoreProvider = activeStoreDetailProvider;
```

**Router extension** (`frontend/merchant/lib/router/app_router.dart`):
- New routes: `AppRoutes.storePicker = '/store-picker'`, `AppRoutes.teamManage = '/store/:storeId/team'`.
- Redirect logic extended:
```
if session == null           → /login  (unchanged)
if memberships.isEmpty       → /login?error=no_memberships   (dead-end with banner)
if activeStore == null && memberships.length >= 2 → /store-picker
if at /store-picker && activeStore != null        → /home
(else unchanged)
```
- Redirect uses a synchronous snapshot: `ref.read(membershipsProvider).valueOrNull` + `activeStoreProvider`. When memberships are still loading, stay put (GoRouter re-evaluates after the stream emits).

### 3.9 Flutter: new screens

**`/store-picker`** (`frontend/merchant/lib/features/store/presentation/store_picker_screen.dart`):
- Renders `AppBar` with `MenuRay` wordmark, list of `membershipsProvider` as tappable cards (store logo + name + role pill).
- Tap → `activeStoreProvider.setStore(storeId, role)` → `context.go('/')`.
- Empty state shouldn't render (redirect keeps it unreachable), but defensive: shows "Contact your admin" copy.
- Smoke test: renders 2 cards, tap picks the right one, navigates to `/`.

**`/store/:storeId/team`** (`frontend/merchant/lib/features/store/presentation/team_management_screen.dart`):
- Two tabbed lists: "Members" + "Pending invites".
- Member row: avatar, name, email, role pill, "⋯" menu (Owner sees: change role, remove, transfer ownership; others see no menu).
- Pending-invite row: email/phone, role, expiry countdown, "Revoke" button (Owner/Manager).
- FAB: "+ Invite" (Owner/Manager only — hidden for Staff) → bottom-sheet form: Email input + Role dropdown (Manager / Staff) + Send.
- All writes call `MembershipRepository`; errors (e.g., `guard_last_owner` RAISE) surface as SnackBar with i18n'd text.
- Accessed from `StoreManagementScreen`: each store card gets a trailing "Team" icon button.
- Smoke test: renders member + invite rows, FAB visible for owner.

**`RoleGate`** (`frontend/merchant/lib/shared/widgets/role_gate.dart`):
```dart
class RoleGate extends ConsumerWidget {
  final Set<String> allowed; // {'owner','manager'}
  final Widget child;
  final Widget? fallback;    // defaults to SizedBox.shrink()
  const RoleGate({required this.allowed, required this.child, this.fallback, super.key});
  @override Widget build(ctx, ref) {
    final role = ref.watch(activeStoreProvider)?.role;
    return (role != null && allowed.contains(role)) ? child : (fallback ?? const SizedBox.shrink());
  }
}
```
Used to hide write-action buttons on screens that Staff should not see full controls for (publish, edit dish price, delete menu).

### 3.10 Backend Edge Function `accept-invite`

File: `backend/supabase/functions/accept-invite/index.ts`. Deno, pattern identical to `parse-menu`.

Flow:
1. POST `/accept-invite` with `{ token: string }` and an `Authorization: Bearer <user_jwt>` header.
2. Creates a user-scoped Supabase client (`createClient(url, anon, { auth: { storageKey: 'server' }}, { global: { headers: { Authorization: authHeader }}})`).
3. Calls `supabase.rpc('accept_invite', { p_token: token })`.
4. Returns `{ storeId }` on success, `{ error: code }` on failure (`invalid_or_expired_invite`, `invite_expired`, `must_be_signed_in`).
5. No secrets needed beyond `SUPABASE_URL` + `SUPABASE_ANON_KEY` (already in env).

Deno tests: cover happy path (valid token → 200 + storeId), expired (→ 410), replay (already accepted → 400), missing auth (→ 401). Mock `fetch` against a stub PostgREST response (same pattern as OpenAI adapter tests).

### 3.11 SvelteKit `/accept-invite` page

New route: `frontend/customer/src/routes/accept-invite/+page.svelte` + `+page.server.ts`.

- URL: `https://menu.menuray.com/accept-invite?token=<token>`.
- `+page.server.ts`: if user is signed in (via Supabase cookie — **new capability** for customer app, see Risks §6), calls the `accept-invite` Edge Function and returns the result; if anonymous, passes through the token to the client for post-signup redirect.
- Three UI states: "Accepting…" (loading), "Joined <StoreName>! Open the app" (success, with deep link `menuraymerchant://open?store=<id>`), "This invite expired" / "Invalid link" (error).
- **Out of scope**: post-signup completion flow (if the invited user doesn't yet have an account, they'd sign up via the Flutter app and re-click the link). This keeps the web page simple — it's primarily a success redirect, with the heavy lifting in the Edge Function.
- No change to existing customer-view data paths — this page lives at a different URL and doesn't touch any store/menu/dish reads.

### 3.12 i18n — 22 new keys

English (`app_en.arb`):
```
teamScreenTitle                 → "Team"
teamTabMembers                  → "Members"
teamTabInvites                  → "Pending invites"
teamInviteCta                   → "Invite teammate"
teamInviteEmailHint             → "Email address"
teamInviteRoleLabel             → "Role"
teamInviteSend                  → "Send invite"
teamInviteSentSnackbar          → "Invite sent to {email}"
teamInviteRevoke                → "Revoke"
teamInviteExpiredBadge          → "Expired"
teamMemberRemove                → "Remove"
teamMemberRemoveConfirm         → "Remove {name} from {storeName}?"
teamMemberChangeRole            → "Change role"
teamMemberTransferOwnership     → "Transfer ownership"
teamMemberLastOwnerError        → "You can't remove the last owner. Transfer ownership first."
roleOwner                       → "Owner"
roleManager                     → "Manager"
roleStaff                       → "Staff"
roleOwnerDesc                   → "Full control including billing and ownership transfer."
roleManagerDesc                 → "Manage menus, publish, invite teammates."
roleStaffDesc                   → "View menus and mark dishes sold out."
storePickerTitle                → "Pick a store"
storePickerSubtitle             → "You have access to {count} stores."
authNoMembershipsBanner         → "Your account has no active store. Contact your admin."
```
Chinese (`app_zh.arb`) — matched 1:1 with same keys; copy below is the intended translation and lands verbatim in the implementation:
```
teamScreenTitle                 → "团队"
teamTabMembers                  → "成员"
teamTabInvites                  → "待接受邀请"
teamInviteCta                   → "邀请成员"
teamInviteEmailHint             → "邮箱地址"
teamInviteRoleLabel             → "角色"
teamInviteSend                  → "发送邀请"
teamInviteSentSnackbar          → "已向 {email} 发送邀请"
teamInviteRevoke                → "撤回"
teamInviteExpiredBadge          → "已过期"
teamMemberRemove                → "移除"
teamMemberRemoveConfirm         → "从 {storeName} 移除 {name}？"
teamMemberChangeRole            → "调整角色"
teamMemberTransferOwnership     → "转交所有权"
teamMemberLastOwnerError        → "不能移除最后一位所有者，请先转交所有权。"
roleOwner                       → "所有者"
roleManager                     → "管理员"
roleStaff                       → "员工"
roleOwnerDesc                   → "完整权限，包含计费与所有权转交。"
roleManagerDesc                 → "管理菜单、发布、邀请成员。"
roleStaffDesc                   → "查看菜单、标记售罄。"
storePickerTitle                → "选择门店"
storePickerSubtitle             → "你可访问 {count} 家门店。"
authNoMembershipsBanner         → "当前账号暂无活跃门店，请联系管理员。"
```

Placeholders (`{email}`, `{name}`, `{storeName}`, `{count}`) use the existing `placeholders: { X: { type: "String"|"int" } }` convention from `app_en.arb`.

### 3.13 Testing strategy

**PgTAP-style SQL regression** — single file `backend/supabase/tests/rls_auth_expansion.sql`, run with `psql` against `supabase db reset`'d local DB. Sections:

1. Seed fixtures: user_a (owner of store_x), user_b (manager of store_x), user_c (staff of store_x), user_d (owner of store_y), anon.
2. Positive: each role reads store_x content, user_a writes everything, user_b writes menus/dishes but not store, user_c writes nothing except via `mark_dish_soldout`.
3. Negative: user_d cannot read store_x; anon reads published menu_x1 but not unpublished menu_x2.
4. `guard_last_owner`: removing user_a raises; demoting user_a with a second owner succeeds.
5. Invite round-trip: user_a creates invite for `invitee@x.com`, invitee signs in + calls `accept_invite(token)`, invitee row is present with role=manager, invite row has `accepted_at IS NOT NULL`.

**Deno unit tests** — `backend/supabase/functions/accept-invite/test.ts`. Mocked `fetch` against a stub PostgREST; tests 4 branches.

**Flutter smoke tests** — new: store_picker, team_management; extend: login (verify redirect to picker for multi-membership user). Use the existing `zhMaterialApp()` + `_Fake*Repository` pattern.

**Flutter unit tests** — `test/unit/membership_mapper_test.dart` for `membershipFromSupabase`, `storeMemberFromSupabase`, `storeInviteFromSupabase`, `organizationFromSupabase` (using sample PostgREST JSON rows). `MembershipRepository` is thin wrapper — no unit test, exercised via smoke tests.

**`flutter analyze` + `flutter test` clean + `deno test` clean + `psql -f tests/rls_auth_expansion.sql` passes** are the non-negotiable gates before commit.

### 3.14 Local dev workflow

- `cd backend/supabase && supabase db reset` re-applies all migrations including the new one.
- Seed now gives user `seed@menuray.com` an Owner membership of the demo store. Login → home works identically (one membership → no picker shown).
- To exercise multi-store: `supabase db query` a second `auth.users` row + a second store + two `store_members` rows for seed — documented in the new file `backend/supabase/README-multi-store.md`.
- Invite email flow locally: Supabase CLI ships with Inbucket at `http://127.0.0.1:54324`; `supabase.auth.admin.inviteUserByEmail()` is NOT what we use (that's Supabase's own invite system). We send our own email using Supabase Auth's built-in SMTP via an RPC `send_invite_email(invite_id)` (SECURITY DEFINER, uses `auth.send_email` where available) — but to keep scope lean this session: the email body is composed in Dart and sent via `SupabaseClient.functions.invoke('send-invite-email', …)` — a second Edge Function. **Deferral note**: to avoid expanding scope, the `send-invite-email` function is NOT shipped this session; the invite token + URL are returned directly to the Flutter client after `createInvite()` and displayed in a "Copy link" modal. Email delivery wires up in a separate follow-up (tracked as `roadmap.md` entry).

Updated: invite UX this session = **"Copy invite link"** modal shown immediately after `createInvite()` succeeds. Merchant pastes the link into their own email/chat. This satisfies the product-decisions A-6 7-day TTL requirement (the link still expires), exercises the full `accept_invite()` path, and defers SMTP integration which is infra work orthogonal to RBAC. Email delivery adds a new Edge Function in a follow-up session.

## 4. Data model

### SQL (summary, see §3.2 for full DDL)

```
organizations  (id, name, created_by, created_at, updated_at)
store_members  (id, store_id, user_id, role, invited_by, accepted_at, created_at, updated_at,
                UNIQUE(store_id, user_id))
store_invites  (id, store_id, email?, phone?, role, token, invited_by, expires_at,
                accepted_at?, accepted_by?, created_at, updated_at)
stores         (… existing …, org_id FK organizations nullable)
              NO LONGER HAS: owner_id
```

### Dart (new in `frontend/merchant/lib/shared/models/`)

```dart
class Membership { // row from my-memberships query
  final String id, role;
  final Store store;
  const Membership({required this.id, required this.role, required this.store});
  bool get canWrite => role == 'owner' || role == 'manager';
}

class StoreMember {  // row from listStoreMembers(storeId)
  final String id, userId, role;
  final String? email, displayName, avatarUrl;
  final DateTime acceptedAt;
  const StoreMember({ ... });
}

class StoreInvite {
  final String id, email, role;
  final String? phone;
  final String token;     // shown only to inviter via Copy Link
  final DateTime expiresAt;
  final DateTime? acceptedAt;
  const StoreInvite({ ... });
  bool get isExpired => acceptedAt == null && expiresAt.isBefore(DateTime.now());
}

class Organization {
  final String id, name, createdBy;
  const Organization({ ... });
}

class StoreContext { // see §3.8 — stored in SharedPreferences
  final String storeId, role;
  bool get canWrite, canManageTeam, canOwnerOnly;
}
```

Mappers live in `frontend/merchant/lib/shared/models/_mappers.dart` alongside existing ones, named `membershipFromSupabase`, `storeMemberFromSupabase`, `storeInviteFromSupabase`, `organizationFromSupabase`.

### TypeScript (new in `frontend/customer/src/lib/types/`)

```ts
// src/lib/types/invite.ts (new — only used by accept-invite page)
export type AcceptInviteResult =
  | { ok: true; storeId: string; storeName: string }
  | { ok: false; code: 'invalid_or_expired_invite' | 'invite_expired' | 'must_be_signed_in' };
```

No changes to `PublishedMenu` / `Store` / etc. types — customer view's menu path is untouched.

## 5. Dependencies (none new)

- Postgres features used: `gen_random_bytes`, `pgcrypto`, SECURITY DEFINER functions, STABLE functions in RLS — all present in Supabase's default extensions.
- Flutter: no new packages. `shared_preferences` is already a transitive dep of `supabase_flutter`; if not, add it (version pinned to latest stable compatible with Flutter 3 stable).
- SvelteKit: no new packages.
- Deno: no new packages (reuses existing `supabase-js` import map).

Check `flutter pub get` after editing `pubspec.yaml` *only* if `shared_preferences` isn't transitive; the implementation plan will explicitly test this first and pin the version only if needed.

## 6. Risks & mitigations

| Risk | Mitigation |
|---|---|
| RLS rewrite misses a policy — accidental data leak | PgTAP regression script exercises every pattern before/after; CI fails if any positive or negative assertion flips |
| `auth.user_store_ids()` recursion into RLS policies | Function marked `STABLE SECURITY DEFINER` + `SET search_path = public` — bypasses its own RLS. Tested explicitly in the regression script |
| Backfill fails mid-txn leaving half-migrated DB | Entire migration is one txn; Supabase CLI wraps files automatically. Rollback on any failure |
| `guard_last_owner` blocks legitimate ownership transfer | `transfer_ownership()` RPC does two `UPDATE`s in sequence (promote target, then demote caller). Trigger allows caller demotion because target is already owner by the time second UPDATE runs. Unit-tested |
| Staff sold-out write fails under RLS (no column-level RLS) | `mark_dish_soldout()` RPC with SECURITY DEFINER + role check; Flutter `MenuRepository.markDishSoldOut` switches to RPC call |
| SvelteKit `/accept-invite` needs a signed-in Supabase session but customer view is anonymous by design | Scope the Supabase cookie handling to just this one route. If user is anon, redirect to Flutter app store link + paste-token instructions (deferred UX for P2; this session shows copy-token fallback text) |
| SharedPreferences lost between app reinstalls — user would see picker again | Acceptable; picker is cheap and correct |
| Test against an already-seeded DB produces ON CONFLICT false success | Seed wipes via `supabase db reset` before regression script runs; CI script runs `reset` first |
| `handle_new_user()` now creates two rows — longer trigger latency | `INSERT` of one row into `store_members` is ~1 ms; total signup latency impact negligible. Trigger stays `AFTER INSERT` (fires after the user row commits) |
| Seed user backfill double-inserts due to `ON CONFLICT DO NOTHING` swallowing errors | Intentional: idempotent re-apply. Verified by regression script asserting exactly one row per (store_id, user_id) |
| go_router redirect loops when memberships provider is still loading | Snapshot uses `.valueOrNull`; if null, redirect returns `null` (stay). GoRouter re-runs redirect on provider emission. Covered by smoke test that simulates slow-load |
| `store_invites.token` leaks via RLS SELECT to non-inviters | `store_invites_writer_rw` restricts reads to owner/manager of that store. Anon has no policy — cannot SELECT. Verified in regression script |

## 7. Open questions

None — decisions matrix (Session 3 intro) resolved them. Email SMTP delivery is explicitly deferred to a follow-up; all other dimensions pinned.

## 8. Success criteria

- `cd backend/supabase && supabase db reset` applies all migrations including `20260424000001_auth_expansion.sql` with zero errors.
- `psql -f backend/supabase/tests/rls_auth_expansion.sql` asserts every pattern + trigger + RPC path green.
- `deno test backend/supabase/functions/accept-invite/` all green.
- `cd frontend/merchant && flutter analyze && flutter test` clean. ≥72 existing tests still pass; new smoke + unit tests (≥6 new) all green.
- `cd frontend/customer && pnpm check && pnpm test` clean.
- Manual: log in as seed user → no picker shown (1 membership) → home renders as before. Create a second store via SQL + invite another user → log in as them → picker appears → tap → home renders with second store's content.
- Manual: as a Staff user, the FAB for "Invite" on team-management is hidden; attempting to delete a menu throws a SnackBar error; toggling sold-out succeeds.
- `grep -r 'owner_id' frontend/merchant/lib backend/supabase` returns zero hits (all references removed).
- `git grep 'currentStoreProvider'` points only to the backwards-compat shim; no call site instantiates a different path.

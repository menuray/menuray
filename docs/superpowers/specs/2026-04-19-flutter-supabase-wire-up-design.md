# Flutter Merchant App ↔ Supabase Wire-up — Design

Date: 2026-04-19
Scope: First-pass integration of the Flutter merchant app with the Supabase backend.
Audience: Whoever implements the follow-up plan.

## 1. Goal & Scope

Wire the Flutter merchant app to the Supabase backend so the **login → home** flow runs against real data instead of `MockData`.

**In scope**

- Add `supabase_flutter` dependency and initialize the client at app startup.
- Phone-OTP auth as the real login flow (`A1` login screen).
- `kDebugMode`-gated "seed user login" shortcut for local development (`signInWithPassword(seed@menuray.com, demo1234)`).
- Router-level auth guard: unauthenticated users are redirected to `/login`; authenticated users away from `/login`.
- Home screen (`A2`) reads the current user's store + its menus (with nested categories, dishes, and English dish-name translation) from Supabase.
- Loading / error / empty states on home.
- Supporting Riverpod providers and a thin repository layer.

**Out of scope (deferred)**

- `parse-menu` Edge Function calls and the `parse_runs` realtime subscription.
- Storage uploads (menu-photos / dish-images / store-logos).
- Any screen other than `login` and `home`: capture / edit / publish / manage / store / settings continue reading `MockData` unchanged.
- `Menu.viewCount`, `Store.menuCount`, `Store.weeklyVisits`, statistics — no aggregate columns yet.
- Deep-link preservation (redirect-back-to-intended-route after login).
- Integration tests that require a running `supabase start` stack.

## 2. Context

- Backend MVP schema, RLS policies, seed data, and Edge Function contract are specified in `docs/superpowers/specs/2026-04-19-supabase-backend-mvp-design.md`.
- Relevant ADRs: 010 (provider-agnostic OCR/LLM), 013 (tenancy: 1:1 stores↔users), 014 (TEXT+CHECK over ENUM; redundant `store_id`), 015 (single parse-menu function + parse_runs), 016 (storage path convention).
- Current Flutter app state: 17 screens, all reading static `MockData`. `flutter_riverpod` is listed in pubspec but no providers exist yet. `ProviderScope` is mounted in `main.dart` but unused.
- Seed user: `seed@menuray.com / demo1234` (fixed UUID `11111111-1111-1111-1111-111111111111`), owns one store `云间小厨 · 静安店` with one published menu and 5 dishes across 2 categories.

## 3. Decisions

### 3.1 Auth for local dev: phone OTP is primary; seed login is a debug affordance

Phone OTP is the production flow. Locally the Supabase stack has no SMS provider configured, and the seed user was created via email/password (no phone attached), so phone OTP cannot run end-to-end against local. A `kDebugMode`-gated button on the login screen calls `signInWithPassword(email, password)` against the seed user. In release builds the button and its handler are dead code and tree-shaken out.

Rejected alternatives:
- *Tab switch phone/email on login.* Two always-visible modes pollute the production UI.
- *Configure `auth.sms.test_otp` in local `config.toml` and add a phone to the seed user.* Would drift local config from production behavior and change seed.sql for a dev-convenience concern.

### 3.2 Config: `String.fromEnvironment` with local defaults, override via `--dart-define`

`SUPABASE_URL` and `SUPABASE_ANON_KEY` resolve at compile time via `String.fromEnvironment`. Defaults hard-code the local `supabase start` URL and the stable local anon key (supabase CLI regenerates the same key each start because the JWT secret is fixed). Android emulator debug builds substitute `10.0.2.2` for `localhost` at runtime.

Production / hosted builds pass `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`. No new runtime dependency (rejected `flutter_dotenv`).

### 3.3 Data layer: thin repositories + hand-written mappers + Riverpod providers

No codegen (Freezed, json_serializable, supabase_codegen). Mappers are pure `Map<String, dynamic>` → existing Flutter model functions, co-located in `shared/models/_mappers.dart`, so they are trivially unit-testable without a Supabase client.

Repositories wrap `SupabaseClient` and return domain models (`Menu`, `Store`, etc.). Providers are plain `FutureProvider` / `StreamProvider` — no `StateNotifier` or `AsyncNotifier` yet.

Rejected alternatives:
- *Fat providers that query + map inline.* Couples Supabase API shape to UI code; harder to test.
- *Extension-based mappers on each model file.* Spreads mapping logic across four files when one is fine.
- *Codegen.* Scope too small to justify build_runner.

### 3.4 One nested PostgREST query per menu list

`menus` select with embedded `categories → dishes → dish_translations` fetches the whole tree in one round-trip. RLS filters to the caller's store transparently. `dish_translations` rows are filtered to `locale='en'` inside the mapper (not in the query, to keep the select simple).

Child ordering (`categories.position`, `dishes.position`) is applied in the mapper because PostgREST's nested-order syntax is unstable across client versions.

## 4. Architecture

### 4.1 File layout

```
frontend/merchant/lib/
  config/
    supabase_config.dart          NEW — url + anon key resolution
  shared/
    supabase/
      supabase_client.dart        NEW — `SupabaseClient get supabase => Supabase.instance.client`
    models/
      _mappers.dart               NEW — JSON → Store/Menu/DishCategory/Dish
      (dish.dart, menu.dart, category.dart, store.dart  UNCHANGED)
    mock/mock_data.dart           UNCHANGED
  features/auth/
    auth_repository.dart          NEW
    auth_providers.dart           NEW
    presentation/login_screen.dart  MODIFIED
  features/home/
    menu_repository.dart          NEW
    store_repository.dart         NEW
    home_providers.dart           NEW
    presentation/home_screen.dart MODIFIED
  router/app_router.dart          MODIFIED (Provider-based + redirect guard)
  main.dart                       MODIFIED (Supabase.initialize)
  app.dart                        MODIFIED (ref.watch(routerProvider))
pubspec.yaml                      MODIFIED (+ supabase_flutter: ^2.5.0)
```

### 4.2 Data flow

```
main() → Supabase.initialize(url, anonKey)
       → ProviderScope → HappyMenuApp (ConsumerWidget)
       → MaterialApp.router(routerConfig: ref.watch(routerProvider))

routerProvider
  ↳ refreshListenable → authStateProvider.stream
  ↳ redirect:
      session == null + location != /login  → /login
      session != null + location == /login  → /
      else null

LoginScreen (phone OTP)
  tap 发送验证码 → authRepo.sendOtp(phone) → 60s countdown
  tap 登录       → authRepo.verifyOtp(phone, token) → Supabase fires authStateChange
  tap seed (kDebugMode) → authRepo.signInSeed() → same authStateChange
  // no explicit navigate; router guard handles it

HomeScreen (ConsumerWidget)
  currentStoreProvider  → storeRepo.currentStore()  → stores WHERE owner_id = auth.uid()
  menusProvider        → menuRepo.listMenusForStore(storeId)
                         → menus.select(nested categories.dishes.dish_translations)
                         → mapper → List<Menu>
  render .when(data/loading/error) for both; RefreshIndicator → ref.refresh(menusProvider.future)
```

## 5. Component specs

### 5.1 `SupabaseConfig`

```dart
const _envUrl  = String.fromEnvironment('SUPABASE_URL',      defaultValue: '');
const _envKey  = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

String get supabaseUrl {
  if (_envUrl.isNotEmpty) return _envUrl;
  if (!kIsWeb && Platform.isAndroid && kDebugMode) return 'http://10.0.2.2:54321';
  return 'http://localhost:54321';
}

String get supabaseAnonKey =>
    _envKey.isNotEmpty ? _envKey : '<stable local anon key from supabase status>';
```

> Implementer: run `supabase status --output env` in `backend/` and paste the `SUPABASE_ANON_KEY` value into the fallback constant. It is stable across `supabase start` invocations because the local JWT secret is fixed in `config.toml`.

### 5.2 `AuthRepository`

Methods:
- `Stream<AuthState> authStateChanges()` → `supabase.auth.onAuthStateChange`
- `Session? get currentSession`
- `Future<void> sendOtp(String phone)` → `signInWithOtp(phone:)`
- `Future<AuthResponse> verifyOtp({required String phone, required String token})` → `verifyOTP(type: OtpType.sms)`
- `Future<AuthResponse> signInSeed()` → `signInWithPassword(email: 'seed@menuray.com', password: 'demo1234')`
- `Future<void> signOut()`

### 5.3 Auth providers

```dart
final supabaseClientProvider = Provider<SupabaseClient>((_) => Supabase.instance.client);
final authRepositoryProvider = Provider<AuthRepository>((ref) =>
    AuthRepository(ref.watch(supabaseClientProvider)));
final authStateProvider = StreamProvider<AuthState>((ref) =>
    ref.watch(authRepositoryProvider).authStateChanges());
final currentSessionProvider = Provider<Session?>((ref) =>
    ref.watch(authStateProvider).valueOrNull?.session ??
    ref.watch(authRepositoryProvider).currentSession);
```

### 5.4 Login screen wiring

- Convert to `ConsumerStatefulWidget` (already needs to be stateful — owns `TextEditingController` × 2 + countdown `Timer`).
- `initState`: create controllers + timer refs. `dispose`: cancel timer + dispose controllers.
- 发送验证码 button:
  - disabled while phone invalid or countdown > 0
  - on tap: `await authRepo.sendOtp(phone)`; on success start 60s countdown; on error `SnackBar(error.message)`.
- 登录 button:
  - on tap: `await authRepo.verifyOtp(phone, otp)`; on error `SnackBar(error.message)`; on success do nothing (router guard redirects).
- `if (kDebugMode)` block at bottom: `TextButton('开发：种子账户登录', onPressed: () => authRepo.signInSeed())`. Uses `AppColors` tokens.

### 5.5 Router guard

```dart
final routerProvider = Provider<GoRouter>((ref) {
  final refreshStream = ref.watch(authStateProvider.stream);
  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: GoRouterRefreshStream(refreshStream),
    redirect: (context, state) {
      final session = ref.read(currentSessionProvider);
      final atLogin = state.matchedLocation == AppRoutes.login;
      if (session == null) return atLogin ? null : AppRoutes.login;
      if (atLogin) return AppRoutes.home;
      return null;
    },
    routes: [...existing route list, unchanged...],
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;
  @override
  void dispose() { _sub.cancel(); super.dispose(); }
}
```

### 5.6 Repositories

`StoreRepository`
- `Future<Store> currentStore()` → `stores.select().eq('owner_id', currentUserId).single()` → `storeFromSupabase(row)`.

`MenuRepository`
- `Future<List<Menu>> listMenusForStore(String storeId)` → nested select (see §3.4) → `rows.map(menuFromSupabase).toList()`.

### 5.7 Mappers (`shared/models/_mappers.dart`)

Pure functions taking `Map<String, dynamic>` and returning existing models:

```dart
Store storeFromSupabase(Map<String, dynamic> json);
Menu menuFromSupabase(Map<String, dynamic> json);
DishCategory dishCategoryFromSupabase(Map<String, dynamic> json);
Dish dishFromSupabase(Map<String, dynamic> json);
```

Detail notes:
- `Store.name` / `address` / `logoUrl`: from `name` / `address` / `logo_url` (last two nullable).
- `Store.menuCount` / `Store.weeklyVisits`: `0` this iteration.
- `Store.isCurrent`: `true` (single-store tenancy per ADR-013).
- `DishCategory.name`: from `source_name`.
- `DishCategory.dishes`: nested `dishes` sorted by `position` asc.
- `Menu.status`: schema `'draft'|'published'|'archived'`; Flutter enum has only `draft|published`. Treat `archived` as `draft` for now (out of sight on home, which shows all; archived won't show because seed only has published). Log-warn if seen.
- `Menu.timeSlot`: schema `'all_day'|'lunch'|'dinner'|'seasonal'` → `MenuTimeSlot.allDay|lunch|dinner|seasonal`.
- `Menu.updatedAt`: from `updated_at` (ISO string) → `DateTime.parse`.
- `Menu.coverImage`: `cover_image_url` (nullable).
- `Menu.viewCount`: hard-coded `0` this iteration.
- `Menu.categories`: sort by `position` asc.
- `Dish.name`: from `source_name`.
- `Dish.nameEn`: find `dish_translations` entry with `locale == 'en'`, take its `name`; null if not present.
- `Dish.price`: `(price as num).toDouble()`.
- `Dish.spice`: schema `'none'|'mild'|'medium'|'hot'` → `SpiceLevel`.
- `Dish.confidence`: schema `'high'|'low'` → `DishConfidence`.
- `Dish.allergens`: schema `text[]` → `List<String>`; cast `(json['allergens'] as List?)?.cast<String>() ?? const []`.

### 5.8 Home providers

```dart
final menuRepositoryProvider = Provider((ref) =>
    MenuRepository(ref.watch(supabaseClientProvider)));
final storeRepositoryProvider = Provider((ref) =>
    StoreRepository(ref.watch(supabaseClientProvider)));

final currentStoreProvider = FutureProvider<Store>((ref) async {
  ref.watch(authStateProvider); // invalidate on auth change
  return ref.watch(storeRepositoryProvider).currentStore();
});

final menusProvider = FutureProvider<List<Menu>>((ref) async {
  final store = await ref.watch(currentStoreProvider.future);
  return ref.watch(menuRepositoryProvider).listMenusForStore(store.id);
});
```

### 5.9 Home screen wiring

- Convert to `ConsumerWidget`.
- Top bar store name: `ref.watch(currentStoreProvider).when(...)`; loading → shimmer/placeholder label; error → `加载失败` + retry `ref.invalidate(currentStoreProvider)`.
- Menu list: `ref.watch(menusProvider).when(data: ..., loading: CircularProgressIndicator, error: retry)`. Empty list → reuse existing "还没有菜单" empty-state component.
- Wrap the list in `RefreshIndicator(onRefresh: () => ref.refresh(menusProvider.future))`.
- Keep `onTap` → `AppRoutes.menuManage` unchanged (menu management screen still reads MockData — that is out of scope).

## 6. Error handling

| Source | Surface |
|---|---|
| `sendOtp` / `verifyOtp` exception | `SnackBar(error.message)` on login screen; keep user on login |
| `signInSeed` exception | Same |
| `currentStore()` returns no row (`PostgrestException`) | error branch on home; user should already be on /login via guard, defensive only |
| `listMenusForStore` network error | error branch on home with retry button |
| Android emulator failing to reach 10.0.2.2 | documented in `backend/README.md` setup section; no in-app handling |

## 7. Testing

- **Smoke tests** (`test/smoke/`): update login + home smoke to wrap in `ProviderScope(overrides: [authRepositoryProvider.overrideWithValue(FakeAuthRepository()), menuRepositoryProvider.overrideWithValue(FakeMenuRepository()), ...])`. Assert the three states (loading / data / error) render for home.
- **Mapper unit tests** (`test/unit/mappers_test.dart`, NEW): exercise each mapper with a representative JSON sample including null cover image, missing English translation, empty allergens, and a `none` spice level.
- **Not covered this iteration**: repository integration tests against a live `supabase start` stack. Tracked as follow-up.
- `flutter analyze` and `flutter test` must pass — per CLAUDE.md.

## 8. Dependencies

Add to `pubspec.yaml`:
```yaml
  supabase_flutter: ^2.5.0
```
PR description must include the dependency justification (per CLAUDE.md).

## 9. Documentation follow-ups

- `backend/README.md`: document `supabase status --output env` to obtain the local anon key, and the Android-emulator `10.0.2.2` caveat.
- `docs/decisions.md`: add an ADR capturing the decisions in §3 of this spec (phone-OTP + debug seed login; `--dart-define` config; thin repo/mapper pattern; one nested query).
- `docs/roadmap.md`: mark `A1 login → A2 home` wired; flag `parse-menu` realtime as the next backend integration task.

## 10. Risks & follow-ups

- **Local anon key drift**: the hard-coded fallback is correct as long as `backend/supabase/config.toml` JWT secret stays fixed. Any `supabase init` reset regenerates it. Document this.
- **MockData long-tail**: other screens still read MockData. As each screen is wired to Supabase it will need its own provider + repository. No attempt to generalize until the second consumer appears.
- **Empty seed on fresh signup**: a new (non-seed) phone-OTP user auto-creates a store via the DB trigger but has no menus. Home's empty-state component needs to be visually complete — verify during implementation.
- **Menu-manage screen UUID mismatch**: tapping a real menu card navigates to `AppRoutes.menuManage`, which still reads `MockData`. The route will render MockData regardless of which real menu was tapped — a known dead-end this iteration. The next wiring pass (menu-manage) fixes it.
- **No offline / caching layer**: every home render refetches. Acceptable at this stage; revisit if the home screen becomes a primary navigation surface.

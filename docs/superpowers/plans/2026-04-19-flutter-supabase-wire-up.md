# Flutter ↔ Supabase Wire-up Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the Flutter merchant app's login and home screens to the Supabase backend, replacing static MockData with real queries for the seed user.

**Architecture:** Thin-repository + hand-written JSON-to-model mappers, behind Riverpod `FutureProvider`/`StreamProvider`. Phone-OTP is the production login; a `kDebugMode`-gated button signs in the seed user via email/password for local development. Router-level `redirect` guard enforces authentication.

**Tech Stack:** Flutter 3.11.5, Riverpod 2.6, go_router 14.6, supabase_flutter 2.5, Supabase (Postgres + Auth), Dart `String.fromEnvironment` for compile-time config.

**Spec:** [docs/superpowers/specs/2026-04-19-flutter-supabase-wire-up-design.md](../specs/2026-04-19-flutter-supabase-wire-up-design.md)

**Repo assumptions:**
- Flutter app root: `frontend/merchant/`
- Backend root: `backend/` (Supabase config + migrations + seed + functions)
- All `flutter`/`dart` commands run from `frontend/merchant/`.

---

## Task 1: Add dependency and initialize Supabase at startup

**Files:**
- Modify: `frontend/merchant/pubspec.yaml`
- Create: `frontend/merchant/lib/config/supabase_config.dart`
- Create: `frontend/merchant/lib/shared/supabase/supabase_client.dart`
- Modify: `frontend/merchant/lib/main.dart`

### Steps

- [ ] **Step 1.1: Retrieve the local Supabase anon key**

In a shell, from `backend/`, run `supabase status --output env` (prereq: `supabase start` must have been run at least once locally). Copy the `ANON_KEY` value (a ~200-char JWT).

Record the exact string; it becomes a constant in Step 1.3.

- [ ] **Step 1.2: Add `supabase_flutter` to `pubspec.yaml`**

In `frontend/merchant/pubspec.yaml`, under `dependencies:` (currently ending with `google_fonts: ^6.2.1`), add:

```yaml
  supabase_flutter: ^2.5.0
```

Then run:
```bash
cd frontend/merchant && flutter pub get
```
Expected: pub resolves successfully, no warnings about SDK mismatch.

- [ ] **Step 1.3: Create `lib/config/supabase_config.dart`**

Paste the anon key obtained in Step 1.1 in the indicated position.

```dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;

const _envUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
const _envAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

const _localAnonKey =
    // Paste the ANON_KEY from `supabase status --output env` here.
    // Stable across `supabase start` invocations because the local JWT
    // secret is fixed in backend/supabase/config.toml.
    'PASTE_LOCAL_ANON_KEY_HERE';

String get supabaseUrl {
  if (_envUrl.isNotEmpty) return _envUrl;
  if (!kIsWeb && Platform.isAndroid && kDebugMode) {
    return 'http://10.0.2.2:54321';
  }
  return 'http://localhost:54321';
}

String get supabaseAnonKey =>
    _envAnonKey.isNotEmpty ? _envAnonKey : _localAnonKey;
```

- [ ] **Step 1.4: Create `lib/shared/supabase/supabase_client.dart`**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient get supabase => Supabase.instance.client;
```

- [ ] **Step 1.5: Modify `lib/main.dart` to initialize Supabase before `runApp`**

Replace the entire file with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const ProviderScope(child: HappyMenuApp()));
}
```

- [ ] **Step 1.6: Verify analyze is clean**

```bash
cd frontend/merchant && flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 1.7: Verify the app still boots**

```bash
cd frontend/merchant && flutter test test/smoke/login_screen_smoke_test.dart
```
Expected: 1 test passes (the login screen still renders; Supabase is initialized but unused by the current screen).

- [ ] **Step 1.8: Commit**

```bash
git add frontend/merchant/pubspec.yaml frontend/merchant/pubspec.lock \
        frontend/merchant/lib/config/supabase_config.dart \
        frontend/merchant/lib/shared/supabase/supabase_client.dart \
        frontend/merchant/lib/main.dart
git commit -m "$(cat <<'EOF'
feat(merchant): add supabase_flutter + initialize client at startup

Supabase URL/anon key resolve via --dart-define with local defaults
(localhost:54321 or 10.0.2.2 for Android debug). No runtime behavior
change yet; no screen consumes the client.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Mappers (JSON → Flutter models) with unit tests

**Files:**
- Create: `frontend/merchant/lib/shared/models/_mappers.dart`
- Create: `frontend/merchant/test/unit/mappers_test.dart`

### Steps

- [ ] **Step 2.1: Write the failing mapper test**

Create `frontend/merchant/test/unit/mappers_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/shared/models/_mappers.dart';
import 'package:menuray_merchant/shared/models/category.dart';
import 'package:menuray_merchant/shared/models/dish.dart';
import 'package:menuray_merchant/shared/models/menu.dart';
import 'package:menuray_merchant/shared/models/store.dart';

void main() {
  group('storeFromSupabase', () {
    test('maps required + nullable fields', () {
      final json = {
        'id': 'store-1',
        'name': '云间小厨 · 静安店',
        'address': '上海市静安区',
        'logo_url': null,
      };
      final store = storeFromSupabase(json);
      expect(store.id, 'store-1');
      expect(store.name, '云间小厨 · 静安店');
      expect(store.address, '上海市静安区');
      expect(store.logoUrl, isNull);
      expect(store.menuCount, 0);
      expect(store.weeklyVisits, 0);
      expect(store.isCurrent, isTrue);
    });
  });

  group('dishFromSupabase', () {
    test('maps source_name → name and merges English translation', () {
      final json = {
        'id': 'd1',
        'source_name': '口水鸡',
        'source_description': null,
        'price': 38,
        'image_url': null,
        'spice_level': 'medium',
        'confidence': 'high',
        'is_signature': false,
        'is_recommended': false,
        'is_vegetarian': false,
        'sold_out': false,
        'allergens': <String>[],
        'position': 1,
        'dish_translations': [
          {'locale': 'en', 'name': 'Mouth-Watering Chicken'},
          {'locale': 'ja', 'name': 'よだれ鶏'},
        ],
      };
      final dish = dishFromSupabase(json);
      expect(dish.id, 'd1');
      expect(dish.name, '口水鸡');
      expect(dish.nameEn, 'Mouth-Watering Chicken');
      expect(dish.price, 38.0);
      expect(dish.spice, SpiceLevel.medium);
      expect(dish.confidence, DishConfidence.high);
      expect(dish.allergens, isEmpty);
    });

    test('handles missing English translation and null fields', () {
      final json = {
        'id': 'd2',
        'source_name': '川北凉粉',
        'source_description': null,
        'price': 22.5,
        'image_url': null,
        'spice_level': 'none',
        'confidence': 'low',
        'is_signature': false,
        'is_recommended': false,
        'is_vegetarian': true,
        'sold_out': false,
        'allergens': null,
        'position': 3,
        'dish_translations': null,
      };
      final dish = dishFromSupabase(json);
      expect(dish.nameEn, isNull);
      expect(dish.price, 22.5);
      expect(dish.spice, SpiceLevel.none);
      expect(dish.confidence, DishConfidence.low);
      expect(dish.isVegetarian, isTrue);
      expect(dish.allergens, isEmpty);
    });
  });

  group('dishCategoryFromSupabase', () {
    test('maps source_name and sorts dishes by position', () {
      final json = {
        'id': 'c1',
        'source_name': '热菜',
        'position': 2,
        'dishes': [
          {
            'id': 'd-b', 'source_name': 'B', 'source_description': null,
            'price': 10, 'image_url': null, 'spice_level': 'none',
            'confidence': 'high', 'is_signature': false,
            'is_recommended': false, 'is_vegetarian': false, 'sold_out': false,
            'allergens': <String>[], 'position': 2, 'dish_translations': [],
          },
          {
            'id': 'd-a', 'source_name': 'A', 'source_description': null,
            'price': 10, 'image_url': null, 'spice_level': 'none',
            'confidence': 'high', 'is_signature': false,
            'is_recommended': false, 'is_vegetarian': false, 'sold_out': false,
            'allergens': <String>[], 'position': 1, 'dish_translations': [],
          },
        ],
      };
      final cat = dishCategoryFromSupabase(json);
      expect(cat.id, 'c1');
      expect(cat.name, '热菜');
      expect(cat.dishes.map((d) => d.id).toList(), ['d-a', 'd-b']);
    });
  });

  group('menuFromSupabase', () {
    test('maps status/time_slot enums and sorts categories by position', () {
      final json = {
        'id': 'm1',
        'name': '午市套餐 2025 春',
        'status': 'published',
        'updated_at': '2026-04-16T00:00:00Z',
        'cover_image_url': null,
        'time_slot': 'lunch',
        'time_slot_description': '午市 11:00–14:00',
        'categories': [
          {
            'id': 'c-hot', 'source_name': '热菜', 'position': 2,
            'dishes': <Map<String, dynamic>>[],
          },
          {
            'id': 'c-cold', 'source_name': '凉菜', 'position': 1,
            'dishes': <Map<String, dynamic>>[],
          },
        ],
      };
      final m = menuFromSupabase(json);
      expect(m.id, 'm1');
      expect(m.name, '午市套餐 2025 春');
      expect(m.status, MenuStatus.published);
      expect(m.updatedAt, DateTime.utc(2026, 4, 16));
      expect(m.coverImage, isNull);
      expect(m.timeSlot, MenuTimeSlot.lunch);
      expect(m.timeSlotDescription, '午市 11:00–14:00');
      expect(m.categories.map((c) => c.id).toList(), ['c-cold', 'c-hot']);
      expect(m.viewCount, 0);
    });

    test('falls back to draft for archived or unknown status', () {
      final json = {
        'id': 'm2', 'name': 'x', 'status': 'archived',
        'updated_at': '2026-01-01T00:00:00Z', 'cover_image_url': null,
        'time_slot': 'all_day', 'time_slot_description': null,
        'categories': <Map<String, dynamic>>[],
      };
      final m = menuFromSupabase(json);
      expect(m.status, MenuStatus.draft);
      expect(m.timeSlot, MenuTimeSlot.allDay);
    });
  });
}
```

- [ ] **Step 2.2: Run the test — it should fail (file not found)**

```bash
cd frontend/merchant && flutter test test/unit/mappers_test.dart
```
Expected: compile error — `Target of URI doesn't exist: 'package:menuray_merchant/shared/models/_mappers.dart'`.

- [ ] **Step 2.3: Create `lib/shared/models/_mappers.dart`**

```dart
import 'dart:developer' as developer;
import 'category.dart';
import 'dish.dart';
import 'menu.dart';
import 'store.dart';

Store storeFromSupabase(Map<String, dynamic> json) => Store(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      logoUrl: json['logo_url'] as String?,
      menuCount: 0,
      weeklyVisits: 0,
      isCurrent: true,
    );

Dish dishFromSupabase(Map<String, dynamic> json) {
  final translations = (json['dish_translations'] as List?)
          ?.cast<Map<String, dynamic>>() ??
      const <Map<String, dynamic>>[];
  String? nameEn;
  for (final t in translations) {
    if (t['locale'] == 'en') {
      nameEn = t['name'] as String?;
      break;
    }
  }
  return Dish(
    id: json['id'] as String,
    name: json['source_name'] as String,
    nameEn: nameEn,
    price: (json['price'] as num).toDouble(),
    description: json['source_description'] as String?,
    imageUrl: json['image_url'] as String?,
    spice: _spiceFromString(json['spice_level'] as String?),
    isSignature: (json['is_signature'] as bool?) ?? false,
    isRecommended: (json['is_recommended'] as bool?) ?? false,
    isVegetarian: (json['is_vegetarian'] as bool?) ?? false,
    allergens: (json['allergens'] as List?)?.cast<String>() ?? const [],
    soldOut: (json['sold_out'] as bool?) ?? false,
    confidence: _confidenceFromString(json['confidence'] as String?),
  );
}

DishCategory dishCategoryFromSupabase(Map<String, dynamic> json) {
  final dishes = (json['dishes'] as List? ?? const [])
      .cast<Map<String, dynamic>>()
      .toList()
    ..sort((a, b) =>
        ((a['position'] as int?) ?? 0).compareTo((b['position'] as int?) ?? 0));
  return DishCategory(
    id: json['id'] as String,
    name: json['source_name'] as String,
    dishes: dishes.map(dishFromSupabase).toList(growable: false),
  );
}

Menu menuFromSupabase(Map<String, dynamic> json) {
  final cats = (json['categories'] as List? ?? const [])
      .cast<Map<String, dynamic>>()
      .toList()
    ..sort((a, b) =>
        ((a['position'] as int?) ?? 0).compareTo((b['position'] as int?) ?? 0));
  return Menu(
    id: json['id'] as String,
    name: json['name'] as String,
    status: _statusFromString(json['status'] as String?),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    coverImage: json['cover_image_url'] as String?,
    categories: cats.map(dishCategoryFromSupabase).toList(growable: false),
    timeSlot: _timeSlotFromString(json['time_slot'] as String?),
    timeSlotDescription: json['time_slot_description'] as String?,
  );
}

MenuStatus _statusFromString(String? v) {
  switch (v) {
    case 'published':
      return MenuStatus.published;
    case 'draft':
      return MenuStatus.draft;
    default:
      if (v != null && v != 'archived') {
        developer.log('Unknown menu.status "$v" → falling back to draft',
            name: 'mappers');
      }
      return MenuStatus.draft;
  }
}

MenuTimeSlot _timeSlotFromString(String? v) {
  switch (v) {
    case 'lunch':
      return MenuTimeSlot.lunch;
    case 'dinner':
      return MenuTimeSlot.dinner;
    case 'seasonal':
      return MenuTimeSlot.seasonal;
    case 'all_day':
    default:
      return MenuTimeSlot.allDay;
  }
}

SpiceLevel _spiceFromString(String? v) {
  switch (v) {
    case 'mild':
      return SpiceLevel.mild;
    case 'medium':
      return SpiceLevel.medium;
    case 'hot':
      return SpiceLevel.hot;
    case 'none':
    default:
      return SpiceLevel.none;
  }
}

DishConfidence _confidenceFromString(String? v) =>
    v == 'low' ? DishConfidence.low : DishConfidence.high;
```

- [ ] **Step 2.4: Run the tests — they should pass**

```bash
cd frontend/merchant && flutter test test/unit/mappers_test.dart
```
Expected: all mapper tests pass.

- [ ] **Step 2.5: Commit**

```bash
git add frontend/merchant/lib/shared/models/_mappers.dart \
        frontend/merchant/test/unit/mappers_test.dart
git commit -m "$(cat <<'EOF'
feat(shared): add Supabase JSON → model mappers with unit tests

Pure functions mapping stores/menus/categories/dishes JSON (from
nested PostgREST selects) to existing Flutter models. English name
merged from dish_translations. Categories/dishes sorted by position.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Auth repository and providers

**Files:**
- Create: `frontend/merchant/lib/features/auth/auth_repository.dart`
- Create: `frontend/merchant/lib/features/auth/auth_providers.dart`

### Steps

- [ ] **Step 3.1: Create `lib/features/auth/auth_repository.dart`**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;
  GoTrueClient get _auth => _client.auth;

  Stream<AuthState> authStateChanges() => _auth.onAuthStateChange;

  Session? get currentSession => _auth.currentSession;

  Future<void> sendOtp(String phone) =>
      _auth.signInWithOtp(phone: phone);

  Future<AuthResponse> verifyOtp({
    required String phone,
    required String token,
  }) =>
      _auth.verifyOTP(phone: phone, token: token, type: OtpType.sms);

  Future<AuthResponse> signInSeed() => _auth.signInWithPassword(
        email: 'seed@menuray.com',
        password: 'demo1234',
      );

  Future<void> signOut() => _auth.signOut();
}
```

- [ ] **Step 3.2: Create `lib/features/auth/auth_providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/supabase/supabase_client.dart';
import 'auth_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>((_) => supabase);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

final currentSessionProvider = Provider<Session?>((ref) {
  final async = ref.watch(authStateProvider);
  final sessionFromStream = async.valueOrNull?.session;
  if (sessionFromStream != null) return sessionFromStream;
  return ref.watch(authRepositoryProvider).currentSession;
});
```

- [ ] **Step 3.3: Verify analyze is clean**

```bash
cd frontend/merchant && flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 3.4: Commit**

```bash
git add frontend/merchant/lib/features/auth/auth_repository.dart \
        frontend/merchant/lib/features/auth/auth_providers.dart
git commit -m "$(cat <<'EOF'
feat(auth): add AuthRepository + Riverpod providers

Thin wrapper over Supabase auth exposing phone-OTP (sendOtp/verifyOtp),
seed email/password sign-in for local dev, and an authStateChanges
stream consumed via StreamProvider.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Router guard (Provider-based router + redirect)

**Files:**
- Modify: `frontend/merchant/lib/router/app_router.dart`
- Modify: `frontend/merchant/lib/app.dart`

### Steps

- [ ] **Step 4.1: Replace `lib/router/app_router.dart`**

Replace the entire file with:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/ai/presentation/ai_optimize_screen.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/capture/presentation/camera_screen.dart';
import '../features/capture/presentation/correct_image_screen.dart';
import '../features/capture/presentation/processing_screen.dart';
import '../features/capture/presentation/select_photos_screen.dart';
import '../features/edit/presentation/edit_dish_screen.dart';
import '../features/edit/presentation/organize_menu_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/manage/presentation/menu_management_screen.dart';
import '../features/manage/presentation/statistics_screen.dart';
import '../features/publish/presentation/custom_theme_screen.dart';
import '../features/publish/presentation/preview_menu_screen.dart';
import '../features/publish/presentation/published_screen.dart';
import '../features/publish/presentation/select_template_screen.dart';
import '../features/store/presentation/settings_screen.dart';
import '../features/store/presentation/store_management_screen.dart';

class AppRoutes {
  AppRoutes._();
  static const login = '/login';
  static const home = '/';
  static const camera = '/capture/camera';
  static const selectPhotos = '/capture/select';
  static const correctImage = '/capture/correct';
  static const processing = '/capture/processing';
  static const organize = '/edit/organize';
  static const editDish = '/edit/dish';
  static const aiOptimize = '/ai/optimize';
  static const selectTemplate = '/publish/template';
  static const customTheme = '/publish/theme';
  static const preview = '/publish/preview';
  static const published = '/publish/done';
  static const menuManage = '/manage/menu';
  static const statistics = '/manage/statistics';
  static const storeManage = '/store/list';
  static const settings = '/settings';
}

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
    routes: [
      GoRoute(path: AppRoutes.login, builder: (c, s) => const LoginScreen()),
      GoRoute(path: AppRoutes.home, builder: (c, s) => const HomeScreen()),
      GoRoute(path: AppRoutes.camera, builder: (c, s) => const CameraScreen()),
      GoRoute(path: AppRoutes.selectPhotos, builder: (c, s) => const SelectPhotosScreen()),
      GoRoute(path: AppRoutes.correctImage, builder: (c, s) => const CorrectImageScreen()),
      GoRoute(path: AppRoutes.processing, builder: (c, s) => const ProcessingScreen()),
      GoRoute(path: AppRoutes.organize, builder: (c, s) => const OrganizeMenuScreen()),
      GoRoute(path: AppRoutes.editDish, builder: (c, s) => const EditDishScreen()),
      GoRoute(path: AppRoutes.aiOptimize, builder: (c, s) => const AiOptimizeScreen()),
      GoRoute(path: AppRoutes.selectTemplate, builder: (c, s) => const SelectTemplateScreen()),
      GoRoute(path: AppRoutes.customTheme, builder: (c, s) => const CustomThemeScreen()),
      GoRoute(path: AppRoutes.preview, builder: (c, s) => const PreviewMenuScreen()),
      GoRoute(path: AppRoutes.published, builder: (c, s) => const PublishedScreen()),
      GoRoute(path: AppRoutes.menuManage, builder: (c, s) => const MenuManagementScreen()),
      GoRoute(path: AppRoutes.statistics, builder: (c, s) => const StatisticsScreen()),
      GoRoute(path: AppRoutes.storeManage, builder: (c, s) => const StoreManagementScreen()),
      GoRoute(path: AppRoutes.settings, builder: (c, s) => const SettingsScreen()),
    ],
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen(
          (_) => notifyListeners(),
          onError: (_) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 4.2: Replace `lib/app.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class HappyMenuApp extends ConsumerWidget {
  const HappyMenuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'MenuRay',
      theme: AppTheme.light,
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
    );
  }
}
```

- [ ] **Step 4.3: Verify analyze is clean**

```bash
cd frontend/merchant && flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 4.4: Commit**

```bash
git add frontend/merchant/lib/router/app_router.dart frontend/merchant/lib/app.dart
git commit -m "$(cat <<'EOF'
feat(router): Provider-based router with auth redirect guard

appRouter is now a Riverpod Provider; unauthenticated users are
redirected to /login, authenticated users away from /login. Refresh
driven by authStateProvider via a GoRouterRefreshStream adapter.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Login screen wire-up (phone OTP + debug seed button)

**Files:**
- Modify: `frontend/merchant/lib/features/auth/presentation/login_screen.dart` (full rewrite)
- Modify: `frontend/merchant/test/smoke/login_screen_smoke_test.dart`

### Steps

- [ ] **Step 5.1: Replace `lib/features/auth/presentation/login_screen.dart`**

The existing file has a purely visual `LoginScreen` with separate `_PhoneField` / `_CodeField` widgets and hardcoded 登录 that does `context.go(AppRoutes.home)`. Replace the whole file with the version below, which:

- Converts `LoginScreen` to `ConsumerStatefulWidget`.
- Owns controllers + countdown `Timer` in state.
- Wires 发送验证码 / 登录 to `AuthRepository`.
- Shows `SnackBar` on errors; displays inline error text below the OTP field when the last verify failed.
- Includes a `kDebugMode`-gated 种子账户登录 button at the bottom.
- Preserves the existing visual elements (logo, slogan, footer) unchanged.

```dart
import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/primary_button.dart';
import '../../../theme/app_colors.dart';
import '../auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  Timer? _countdownTimer;
  int _countdownSeconds = 0;
  bool _sendingOtp = false;
  bool _verifying = false;
  String? _otpError;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _countdownSeconds = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _countdownSeconds -= 1;
        if (_countdownSeconds <= 0) t.cancel();
      });
    });
  }

  Future<void> _onSendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showSnack('请输入手机号');
      return;
    }
    setState(() => _sendingOtp = true);
    try {
      await ref.read(authRepositoryProvider).sendOtp(phone);
      if (!mounted) return;
      _startCountdown();
      _showSnack('验证码已发送');
    } catch (e) {
      if (!mounted) return;
      _showSnack(_messageOf(e));
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  Future<void> _onVerifyOtp() async {
    final phone = _phoneController.text.trim();
    final token = _otpController.text.trim();
    if (phone.isEmpty || token.isEmpty) {
      setState(() => _otpError = '请输入手机号和验证码');
      return;
    }
    setState(() {
      _otpError = null;
      _verifying = true;
    });
    try {
      await ref.read(authRepositoryProvider).verifyOtp(
            phone: phone,
            token: token,
          );
      // Router guard handles redirect on auth state change.
    } catch (e) {
      if (!mounted) return;
      setState(() => _otpError = _messageOf(e));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _onSeedLogin() async {
    try {
      await ref.read(authRepositoryProvider).signInSeed();
    } catch (e) {
      if (!mounted) return;
      _showSnack(_messageOf(e));
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _messageOf(Object e) {
    final s = e.toString();
    return s.isEmpty ? '操作失败' : s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 448),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const _LogoSection(),
                        const SizedBox(height: 48),
                        _PhoneField(controller: _phoneController),
                        const SizedBox(height: 24),
                        _CodeField(
                          controller: _otpController,
                          countdownSeconds: _countdownSeconds,
                          sending: _sendingOtp,
                          errorText: _otpError,
                          onSendOtp: _onSendOtp,
                        ),
                        const SizedBox(height: 40),
                        PrimaryButton(
                          label: _verifying ? '登录中…' : '登录',
                          onPressed: _verifying ? null : _onVerifyOtp,
                        ),
                        const SizedBox(height: 24),
                        GestureDetector(
                          onTap: () {},
                          child: Text(
                            '新用户？立即注册',
                            style: TextStyle(
                              color: AppColors.primaryContainer,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (kDebugMode) ...[
                          const SizedBox(height: 24),
                          TextButton(
                            key: const ValueKey('seed-login-button'),
                            onPressed: _onSeedLogin,
                            child: const Text('开发：种子账户登录'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const _Footer(),
          ],
        ),
      ),
    );
  }
}

class _LogoSection extends StatelessWidget {
  const _LogoSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Center(child: _MenuPageIcon()),
        ),
        const SizedBox(height: 24),
        Text(
          'MenuRay',
          style: TextStyle(
            color: AppColors.primaryContainer,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '拍一张照，5 分钟生成电子菜单',
          style: TextStyle(
            color: AppColors.secondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _MenuPageIcon extends StatelessWidget {
  const _MenuPageIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: Colors.white.withAlpha(30), width: 0.5),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 16, left: 8, right: 8,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withAlpha(51),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
                Positioned(
                  top: 28, left: 8, right: 16,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withAlpha(51),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
                Positioned(
                  top: 40, left: 8, right: 8,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withAlpha(51),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -4, right: -4,
            child: Transform.rotate(
              angle: 0.21,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(25),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      style: TextStyle(color: AppColors.ink),
      decoration: InputDecoration(
        hintText: '请输入手机号',
        hintStyle: TextStyle(color: AppColors.secondary.withAlpha(153)),
        prefixIcon: Icon(Icons.smartphone, color: AppColors.secondary),
        filled: true,
        fillColor: const Color(0xFFE6E2DB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.primaryContainer, width: 1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }
}

class _CodeField extends StatelessWidget {
  const _CodeField({
    required this.controller,
    required this.countdownSeconds,
    required this.sending,
    required this.errorText,
    required this.onSendOtp,
  });

  final TextEditingController controller;
  final int countdownSeconds;
  final bool sending;
  final String? errorText;
  final VoidCallback onSendOtp;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;
    final borderColor = hasError ? AppColors.error.withAlpha(127) : Colors.transparent;
    final canTapSend = !sending && countdownSeconds == 0;
    final sendLabel = sending
        ? '发送中…'
        : countdownSeconds > 0
            ? '$countdownSeconds' 's 重发'
            : '发送验证码';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          alignment: Alignment.centerRight,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: TextStyle(color: hasError ? AppColors.error : AppColors.ink),
              decoration: InputDecoration(
                hintText: '请输入验证码',
                hintStyle:
                    TextStyle(color: AppColors.secondary.withAlpha(153)),
                prefixIcon: Icon(Icons.lock, color: AppColors.secondary),
                filled: true,
                fillColor: const Color(0xFFE6E2DB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: borderColor, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: borderColor, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: hasError ? AppColors.error : AppColors.primaryContainer,
                    width: 1,
                  ),
                ),
                contentPadding: const EdgeInsets.only(
                    top: 16, bottom: 16, left: 16, right: 128),
              ),
            ),
            Positioned(
              right: 8,
              child: OutlinedButton(
                onPressed: canTapSend ? onSendOtp : null,
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFF7F3EC),
                  foregroundColor: AppColors.primaryContainer,
                  disabledForegroundColor: AppColors.secondary.withAlpha(204),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                  minimumSize: const Size(100, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  sendLabel,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.error_outline, color: AppColors.error, size: 16),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  errorText!,
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32, top: 16),
      child: Column(
        children: [
          Text(
            '由 MenuRay 提供',
            style: TextStyle(
              color: AppColors.secondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkWell(
                onTap: () {},
                child: Text(
                  '用户协议',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.secondary.withAlpha(127),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withAlpha(127),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
              InkWell(
                onTap: () {},
                child: Text(
                  '隐私政策',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.secondary.withAlpha(127),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5.2: Update `test/smoke/login_screen_smoke_test.dart`**

The existing test pumps a plain `MaterialApp(home: LoginScreen())`. LoginScreen now reads `authRepositoryProvider`, which tries to construct a real Supabase client at build time (and fails in the test host because Supabase.initialize was not awaited). Wrap in `ProviderScope` with the repository overridden. Replace the file with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/auth/auth_providers.dart';
import 'package:menuray_merchant/features/auth/auth_repository.dart';
import 'package:menuray_merchant/features/auth/presentation/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Stream<AuthState> authStateChanges() => const Stream<AuthState>.empty();

  @override
  Session? get currentSession => null;

  @override
  Future<void> sendOtp(String phone) async {}

  @override
  Future<AuthResponse> verifyOtp({required String phone, required String token}) =>
      throw UnimplementedError();

  @override
  Future<AuthResponse> signInSeed() => throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('LoginScreen renders wordmark, form, and send-OTP button',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('MenuRay'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
    expect(find.text('拍一张照，5 分钟生成电子菜单'), findsOneWidget);
    expect(find.text('发送验证码'), findsOneWidget);
  });
}
```

- [ ] **Step 5.3: Run login smoke test**

```bash
cd frontend/merchant && flutter test test/smoke/login_screen_smoke_test.dart
```
Expected: 1 test passes.

- [ ] **Step 5.4: Verify analyze is clean**

```bash
cd frontend/merchant && flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 5.5: Commit**

```bash
git add frontend/merchant/lib/features/auth/presentation/login_screen.dart \
        frontend/merchant/test/smoke/login_screen_smoke_test.dart
git commit -m "$(cat <<'EOF'
feat(auth): wire login screen to Supabase phone OTP + debug seed login

发送验证码 button calls signInWithOtp and starts a 60s countdown; 登录
calls verifyOTP. On success, router guard redirects to home. kDebugMode
block adds a 种子账户登录 button wired to signInWithPassword against the
local seed user. Smoke test overrides the auth repository.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Store and Menu repositories

**Files:**
- Create: `frontend/merchant/lib/features/home/store_repository.dart`
- Create: `frontend/merchant/lib/features/home/menu_repository.dart`

### Steps

- [ ] **Step 6.1: Create `lib/features/home/store_repository.dart`**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/models/_mappers.dart';
import '../../shared/models/store.dart';

class StoreRepository {
  StoreRepository(this._client);

  final SupabaseClient _client;

  Future<Store> currentStore() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('No authenticated user when querying store');
    }
    final row = await _client
        .from('stores')
        .select()
        .eq('owner_id', userId)
        .single();
    return storeFromSupabase(row);
  }
}
```

- [ ] **Step 6.2: Create `lib/features/home/menu_repository.dart`**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/models/_mappers.dart';
import '../../shared/models/menu.dart';

class MenuRepository {
  MenuRepository(this._client);

  final SupabaseClient _client;

  Future<List<Menu>> listMenusForStore(String storeId) async {
    final rows = await _client
        .from('menus')
        .select('''
          id, name, status, updated_at, cover_image_url,
          time_slot, time_slot_description,
          categories(
            id, source_name, position,
            dishes(
              id, source_name, source_description, price, image_url,
              spice_level, confidence, is_signature, is_recommended,
              is_vegetarian, sold_out, allergens, position,
              dish_translations(locale, name)
            )
          )
        ''')
        .eq('store_id', storeId)
        .order('updated_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(menuFromSupabase)
        .toList(growable: false);
  }
}
```

- [ ] **Step 6.3: Verify analyze is clean**

```bash
cd frontend/merchant && flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 6.4: Commit**

```bash
git add frontend/merchant/lib/features/home/store_repository.dart \
        frontend/merchant/lib/features/home/menu_repository.dart
git commit -m "$(cat <<'EOF'
feat(home): add StoreRepository and MenuRepository

Single nested PostgREST select fetches menus with categories, dishes,
and dish_translations in one round-trip. RLS filters to the caller's
store via owner_id = auth.uid().

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Home providers

**Files:**
- Create: `frontend/merchant/lib/features/home/home_providers.dart`

### Steps

- [ ] **Step 7.1: Create `lib/features/home/home_providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/menu.dart';
import '../../shared/models/store.dart';
import '../auth/auth_providers.dart';
import 'menu_repository.dart';
import 'store_repository.dart';

final menuRepositoryProvider = Provider<MenuRepository>(
  (ref) => MenuRepository(ref.watch(supabaseClientProvider)),
);

final storeRepositoryProvider = Provider<StoreRepository>(
  (ref) => StoreRepository(ref.watch(supabaseClientProvider)),
);

final currentStoreProvider = FutureProvider<Store>((ref) async {
  ref.watch(authStateProvider); // re-evaluate on auth change
  return ref.watch(storeRepositoryProvider).currentStore();
});

final menusProvider = FutureProvider<List<Menu>>((ref) async {
  final store = await ref.watch(currentStoreProvider.future);
  return ref.watch(menuRepositoryProvider).listMenusForStore(store.id);
});
```

- [ ] **Step 7.2: Verify analyze is clean**

```bash
cd frontend/merchant && flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 7.3: Commit**

```bash
git add frontend/merchant/lib/features/home/home_providers.dart
git commit -m "$(cat <<'EOF'
feat(home): add currentStoreProvider and menusProvider

FutureProviders that re-evaluate when auth state changes. menusProvider
depends on currentStoreProvider to fetch the store_id before querying
menus.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Home screen wire-up

**Files:**
- Modify: `frontend/merchant/lib/features/home/presentation/home_screen.dart` (full rewrite)
- Modify: `frontend/merchant/test/smoke/home_screen_smoke_test.dart`

### Steps

- [ ] **Step 8.1: Replace `lib/features/home/presentation/home_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../shared/models/menu.dart';
import '../../../shared/models/store.dart';
import '../../../shared/widgets/menu_card.dart';
import '../../../shared/widgets/merchant_bottom_nav.dart';
import '../../../shared/widgets/search_input.dart';
import '../../../theme/app_colors.dart';
import '../home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeAsync = ref.watch(currentStoreProvider);
    final menusAsync = ref.watch(menusProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: _TopBar(storeAsync: storeAsync),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentStoreProvider);
          await ref.read(menusProvider.future);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SearchInput(hintText: 'Search menus, items, or status...'),
              const SizedBox(height: 32),
              _SectionHeader(
                title: 'Curated Menus',
                total: menusAsync.maybeWhen(
                  data: (list) => '${list.length} Total',
                  orElse: () => '— Total',
                ),
              ),
              const SizedBox(height: 16),
              _MenuList(menusAsync: menusAsync),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.camera),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          '新建菜单',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      bottomNavigationBar: MerchantBottomNav(
        current: MerchantTab.menus,
        onTap: (tab) {
          switch (tab) {
            case MerchantTab.menus:
              break;
            case MerchantTab.data:
              context.go(AppRoutes.statistics);
            case MerchantTab.mine:
              context.go(AppRoutes.settings);
          }
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  const _TopBar({required this.storeAsync});

  final AsyncValue<Store> storeAsync;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final name = storeAsync.maybeWhen(
      data: (s) => s.name,
      orElse: () => '加载中…',
    );
    return Container(
      color: AppColors.surface.withAlpha(204),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.search, color: AppColors.primaryDark),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const Spacer(),
              const _StoreAvatar(),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreAvatar extends StatelessWidget {
  const _StoreAvatar();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.divider,
        child: ClipOval(
          child: Image.asset(
            'assets/sample/store_avatar.png',
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => Icon(
              Icons.store,
              color: AppColors.primaryDark,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.total});

  final String title;
  final String total;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const Spacer(),
        Text(
          total,
          style: TextStyle(
            color: AppColors.accent,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _MenuList extends ConsumerWidget {
  const _MenuList({required this.menusAsync});

  final AsyncValue<List<Menu>> menusAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return menusAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => _ErrorBlock(
        message: '加载失败：$err',
        onRetry: () => ref.invalidate(menusProvider),
      ),
      data: (menus) {
        if (menus.isEmpty) return const _EmptyBlock();
        return Column(
          children: menus
              .map(
                (menu) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: MenuCard(
                    menu: menu,
                    onTap: () => context.go(AppRoutes.menuManage),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 32),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.ink, fontSize: 14)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.menu_book, color: AppColors.secondary, size: 40),
          const SizedBox(height: 12),
          Text('还没有菜单，点右下角"新建菜单"开始',
              style: TextStyle(color: AppColors.secondary, fontSize: 14)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 8.2: Update `test/smoke/home_screen_smoke_test.dart`**

Replace the entire file with a smoke test that overrides the repository providers and asserts loading + data states:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/auth/auth_providers.dart';
import 'package:menuray_merchant/features/auth/auth_repository.dart';
import 'package:menuray_merchant/features/home/home_providers.dart';
import 'package:menuray_merchant/features/home/menu_repository.dart';
import 'package:menuray_merchant/features/home/presentation/home_screen.dart';
import 'package:menuray_merchant/features/home/store_repository.dart';
import 'package:menuray_merchant/shared/models/category.dart';
import 'package:menuray_merchant/shared/models/menu.dart';
import 'package:menuray_merchant/shared/models/store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Stream<AuthState> authStateChanges() => const Stream<AuthState>.empty();
  @override
  Session? get currentSession => null;
  @override
  Future<void> sendOtp(String phone) async {}
  @override
  Future<AuthResponse> verifyOtp({required String phone, required String token}) =>
      throw UnimplementedError();
  @override
  Future<AuthResponse> signInSeed() => throw UnimplementedError();
  @override
  Future<void> signOut() async {}
}

class _FakeStoreRepository implements StoreRepository {
  @override
  Future<Store> currentStore() async => const Store(
        id: 'store-seed',
        name: '云间小厨',
        address: '上海市静安区',
        isCurrent: true,
      );
}

class _FakeMenuRepository implements MenuRepository {
  @override
  Future<List<Menu>> listMenusForStore(String storeId) async => [
        Menu(
          id: 'm1',
          name: '午市套餐 2025 春',
          status: MenuStatus.published,
          updatedAt: DateTime(2026, 4, 16),
          timeSlot: MenuTimeSlot.lunch,
          timeSlotDescription: '午市 11:00–14:00',
          categories: const <DishCategory>[],
        ),
      ];
}

void main() {
  testWidgets('HomeScreen renders store name and seed menu from providers',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          storeRepositoryProvider.overrideWithValue(_FakeStoreRepository()),
          menuRepositoryProvider.overrideWithValue(_FakeMenuRepository()),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('云间小厨'), findsOneWidget);
    expect(find.text('Curated Menus'), findsOneWidget);
    expect(find.text('1 Total'), findsOneWidget);
    expect(find.text('午市套餐 2025 春'), findsOneWidget);
    expect(find.text('新建菜单'), findsOneWidget);
  });
}
```

- [ ] **Step 8.3: Run home smoke test**

```bash
cd frontend/merchant && flutter test test/smoke/home_screen_smoke_test.dart
```
Expected: 1 test passes.

- [ ] **Step 8.4: Verify analyze is clean**

```bash
cd frontend/merchant && flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 8.5: Commit**

```bash
git add frontend/merchant/lib/features/home/presentation/home_screen.dart \
        frontend/merchant/test/smoke/home_screen_smoke_test.dart
git commit -m "$(cat <<'EOF'
feat(home): wire home screen to Supabase store + menus providers

Top bar store name and section-header menu count now read live data.
Menu list uses AsyncValue.when for loading/error/empty states.
RefreshIndicator re-invalidates both providers. Smoke test overrides
both repositories with fake data.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Full test suite + analyze sweep

**Files:** none modified in this task (unless regressions surface)

### Steps

- [ ] **Step 9.1: Run full analyze**

```bash
cd frontend/merchant && flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 9.2: Run full test suite**

```bash
cd frontend/merchant && flutter test
```
Expected: all tests pass (previously 27; now 27 + new mapper tests). If any pre-existing smoke test fails because its screen indirectly imports the new auth/home providers and didn't exist before, fix by wrapping that test in `ProviderScope` with appropriate overrides (no screen outside login/home should need overrides, but verify).

- [ ] **Step 9.3: If any fixes were needed, commit them**

```bash
git add -A
git commit -m "$(cat <<'EOF'
chore(merchant): fix analyze/test regressions after Supabase wire-up

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

(Skip this step if Step 9.1 + 9.2 were already clean.)

---

## Task 10: End-to-end manual verification against local Supabase

This task is manual and does not produce a commit. Record the verification outcome in the PR description / task log.

### Steps

- [ ] **Step 10.1: Start the local Supabase stack**

```bash
cd backend && supabase start
```
Wait for `API URL: http://localhost:54321` to print. Confirm seed data was applied (`supabase status` shows DB URL; if the stack was freshly created, `supabase db reset` re-applies migrations + seed).

- [ ] **Step 10.2: Confirm the anon key matches**

```bash
cd backend && supabase status --output env
```
Compare `ANON_KEY` to the value pasted into `frontend/merchant/lib/config/supabase_config.dart` in Task 1. If they differ, update the constant and re-run Task 1 Step 1.6–1.8 (analyze, smoke, commit).

- [ ] **Step 10.3: Launch the Flutter app**

```bash
cd frontend/merchant && flutter run -d chrome
```
(Use `-d chrome` for web, or `-d macos`/`-d linux` for desktop, whichever is available. Android emulator requires no flag but relies on the `10.0.2.2` substitution from SupabaseConfig.)

- [ ] **Step 10.4: Verify the login-guard redirect**

Expected: App opens at `/login` (not `/`), because `currentSessionProvider` returns null.

- [ ] **Step 10.5: Tap the 种子账户登录 button**

Expected:
- SnackBar does NOT appear (no error).
- Router redirects to `/` within ~500 ms.
- Top bar shows `云间小厨 · 静安店` (or whatever seed.sql named the store).
- Section header shows `1 Total`.
- Menu card shows `午市套餐 2025 春`.

- [ ] **Step 10.6: Pull-to-refresh**

Expected: RefreshIndicator spins; same data re-renders; no error.

- [ ] **Step 10.7: Hot-restart the app**

Expected: App opens directly at `/` (session persisted in Supabase local storage). Menu list re-loads.

- [ ] **Step 10.8: Sign out via the debug console**

In the running app's debug console, run:
```dart
// via the Flutter DevTools REPL, or temporarily add a logout button
Supabase.instance.client.auth.signOut();
```
Expected: Router redirects back to `/login` within one frame.

- [ ] **Step 10.9: Record the verification in the PR description**

Note whether all expected behaviors were observed and any deviations.

---

## Task 11: Docs updates

**Files:**
- Modify: `backend/README.md`
- Modify: `docs/decisions.md`
- Modify: `docs/roadmap.md`

### Steps

- [ ] **Step 11.1: Update `backend/README.md`**

Find the existing local-dev setup section. Append a new subsection:

```markdown
## Getting the local anon key for the Flutter app

The Flutter merchant app embeds the local Supabase anon key as a constant in
`frontend/merchant/lib/config/supabase_config.dart`. To retrieve the current
value:

```bash
cd backend && supabase status --output env | grep ANON_KEY
```

The value is stable across `supabase start` invocations because the JWT
secret in `backend/supabase/config.toml` is fixed. Running `supabase init`
from scratch regenerates it — update the constant if that happens.

### Android emulator note

`http://localhost:54321` points at the emulator itself, not the host. The
Flutter app automatically substitutes `http://10.0.2.2:54321` in Android
debug builds. On a physical device connected by USB, override at build time:

```bash
flutter run --dart-define=SUPABASE_URL=http://<host-lan-ip>:54321 \
            --dart-define=SUPABASE_ANON_KEY=<key>
```
```

- [ ] **Step 11.2: Add an ADR to `docs/decisions.md`**

At the bottom of the ADR list (after ADR-016), append:

```markdown
## ADR-017: Flutter client — auth pattern & data layer for login/home

**Date:** 2026-04-19
**Status:** Accepted

### Context

The Flutter merchant app needed its first real backend connection. Phone
OTP is the intended production login, but the seed user is email/password
and the local Supabase stack has no SMS provider.

### Decision

1. **Phone OTP as primary auth; debug-only seed login button.** Login UI
   stays identical between dev and prod. A `kDebugMode`-gated button calls
   `signInWithPassword(seed@menuray.com, demo1234)` so local dev works
   without SMS infrastructure. Release builds tree-shake the button.
2. **Config via `String.fromEnvironment` + `--dart-define`.** No new
   runtime dependency; anon key hard-coded as the local default (stable
   across `supabase start`).
3. **Thin repositories + hand-written mappers behind Riverpod
   `FutureProvider`.** No codegen. Mappers are pure functions and unit-
   testable without Supabase. Repositories wrap `SupabaseClient` and
   return domain models.
4. **One nested PostgREST select per menu list.** `menus(categories
   (dishes(dish_translations)))` in a single round-trip; child ordering
   applied in the mapper for cross-version stability.

### Consequences

- New dep: `supabase_flutter ^2.5`.
- The debug seed login is the sole path for local functional testing
  until phone OTP can be exercised with `auth.sms.test_otp` or a real
  SMS provider.
- Other screens (capture/edit/publish/manage/store/settings) still read
  `MockData`. Menu-manage and store-management are the next targets; a
  tapped menu card currently dead-ends into MockData content.

### References

- Spec: `docs/superpowers/specs/2026-04-19-flutter-supabase-wire-up-design.md`
- Plan: `docs/superpowers/plans/2026-04-19-flutter-supabase-wire-up.md`
```

- [ ] **Step 11.3: Update `docs/roadmap.md`**

Find the row / bullet tracking "merchant app wired to Supabase". Mark
login + home as done; keep `parse-menu` realtime, menu-manage, and the
remaining screens listed as upcoming.

If there is no such row yet, add one under the current active-work
section:

```markdown
- [x] Merchant app: login + home wired to Supabase (seed user)
- [ ] Merchant app: menu-manage screen wired to Supabase
- [ ] Merchant app: parse-menu realtime subscription
- [ ] Merchant app: remaining screens (capture/edit/publish/store/settings)
```

- [ ] **Step 11.4: Commit docs**

```bash
git add backend/README.md docs/decisions.md docs/roadmap.md
git commit -m "$(cat <<'EOF'
docs: ADR-017 + README + roadmap for Flutter↔Supabase wire-up

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-review (post-plan)

- **Spec coverage:**
  - §1 in-scope items → covered by Tasks 1–8 (dep, init, phone OTP, seed button, router guard, home providers/screen, loading/error/empty).
  - §3.1 decision (phone OTP + debug seed) → Task 5.
  - §3.2 (compile-time config) → Task 1.
  - §3.3 (thin repos + mappers) → Tasks 2, 6, 7.
  - §3.4 (one nested query) → Task 6.2.
  - §5.1–5.9 component specs → Tasks 1, 3, 4, 5, 6, 7, 8.
  - §6 error handling → Task 5 (snackbar/inline), Task 8 (error retry).
  - §7 testing → Task 2 (mappers unit), Task 5 (login smoke), Task 8 (home smoke), Task 9 (full sweep).
  - §8 dependency → Task 1.2.
  - §9 docs → Task 11.
- **Placeholder scan:** only `PASTE_LOCAL_ANON_KEY_HERE` in Step 1.3 is intentional — the plan tells the implementer exactly what to paste there in Step 1.1. No other TBDs.
- **Type consistency:** `authStateProvider` / `currentSessionProvider` / `authRepositoryProvider` referenced identically across Tasks 3, 4, 5, 7. `menusProvider` / `currentStoreProvider` / `menuRepositoryProvider` / `storeRepositoryProvider` consistent between Tasks 6, 7, 8. Mapper function names (`storeFromSupabase`, `menuFromSupabase`, `dishCategoryFromSupabase`, `dishFromSupabase`) match across Tasks 2, 6. `AuthRepository` / `StoreRepository` / `MenuRepository` interfaces match their fake implementations in smoke tests.

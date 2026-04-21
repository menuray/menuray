# Merchant Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close merchant-app polish gaps surfaced during sub-batches 1 and 2 — real logout, working register link, explicit `shouldCreateUser`, pure validator helpers wired into three forms, two shared L/E widgets replacing ad-hoc duplication, two missing empty states, and supporting docs. Spec: `docs/superpowers/specs/2026-04-20-merchant-polish-design.md`.

**Architecture:** All changes are merchant-Flutter-only. Pure-function validators land at `lib/shared/validation.dart` (unit-tested). Two shared widgets land at `lib/shared/widgets/{loading_view,error_view}.dart` and replace per-screen `_LoadingBody` / `_ErrorBody` across 4 screens using `AsyncValue.when`. Three screens (login, edit_dish, store_management) become `Form` + `TextFormField` + `validator:` users. Logout flows through `AuthRepository.signOut()` before redirect. 15 new en/zh i18n keys cover all user-visible strings.

**Tech Stack:** Flutter 3 stable, Riverpod, go_router, supabase_flutter, Flutter built-in Form / TextFormField / validator. No new dependencies.

---

## File structure

**New:**
```
frontend/merchant/lib/shared/validation.dart
frontend/merchant/lib/shared/widgets/loading_view.dart
frontend/merchant/lib/shared/widgets/error_view.dart
frontend/merchant/test/unit/validation_test.dart
frontend/merchant/test/widgets/loading_view_widget_test.dart
frontend/merchant/test/widgets/error_view_widget_test.dart
```

**Modified:**
```
frontend/merchant/lib/l10n/app_en.arb
frontend/merchant/lib/l10n/app_zh.arb
frontend/merchant/lib/features/auth/data/auth_repository.dart             (sendOtp explicit shouldCreateUser; verify signOut exists)
frontend/merchant/lib/features/auth/presentation/login_screen.dart        (register onTap + Form + TextFormField)
frontend/merchant/lib/features/store/presentation/settings_screen.dart    (logout actually signs out)
frontend/merchant/lib/features/store/presentation/store_management_screen.dart  (Form + TextFormField on name)
frontend/merchant/lib/features/edit/presentation/edit_dish_screen.dart    (Form + TextFormField on name + price; L/E refactor)
frontend/merchant/lib/features/manage/presentation/menu_management_screen.dart  (L/E refactor)
frontend/merchant/lib/features/edit/presentation/organize_menu_screen.dart      (L/E refactor + empty state)
frontend/merchant/lib/features/templates/presentation/select_template_screen.dart (L/E refactor)
frontend/merchant/lib/features/home/presentation/home_screen.dart         (empty state when no menus)
frontend/merchant/test/smoke/login_screen_smoke_test.dart                 (extend)
frontend/merchant/test/smoke/edit_dish_screen_smoke_test.dart             (extend)
frontend/merchant/test/smoke/settings_screen_smoke_test.dart              (new or extend; see Task 3)
docs/architecture.md                                                      (shared widgets paragraph)
CLAUDE.md                                                                 (Active work cell)
```

---

## Task 1: Add 15 new i18n keys (en + zh) + regenerate localizations

**Files:**
- Modify: `frontend/merchant/lib/l10n/app_en.arb`
- Modify: `frontend/merchant/lib/l10n/app_zh.arb`

- [ ] **Step 1: Read existing arb format**

Run: `head -30 /home/coder/workspaces/menuray/frontend/merchant/lib/l10n/app_en.arb` — note the format (JSON with `@key` descriptor blocks, placeholder syntax for `{name}` args requires a sibling `@key: { "placeholders": { "name": { "type": "String" } } }` entry).

- [ ] **Step 2: Add en keys**

Open `frontend/merchant/lib/l10n/app_en.arb`. Before the closing `}`, insert (comma-separate cleanly with the existing last entry):

```json
  "validationRequired": "Required",
  "@validationRequired": { "description": "Generic 'required field' error" },

  "validationRequiredFieldNamed": "{field} is required",
  "@validationRequiredFieldNamed": {
    "description": "Named required field error",
    "placeholders": { "field": { "type": "String" } }
  },

  "validationPhoneInvalid": "Enter a valid phone (11-digit China mobile or +country number)",
  "validationPriceInvalid": "Enter a number",
  "validationPriceNegative": "Price cannot be negative",
  "validationPriceTooPrecise": "At most 2 decimal places",

  "validationMaxLength": "At most {max} characters",
  "@validationMaxLength": {
    "description": "Max length validator error",
    "placeholders": { "max": { "type": "int" } }
  },

  "logoutFailedSnackbar": "Logout failed, but we sent you back to login.",
  "registerHintSnackbar": "New users: enter your phone — we'll send a code and create your account automatically.",

  "emptyOrganizeCategoriesMessage": "This menu has no categories yet",
  "emptyOrganizeCategoriesAction": "Add category",
  "emptyHomeMenusMessage": "No menus yet",
  "emptyHomeMenusAction": "Take a photo of a menu",

  "errorGenericMessage": "Something went wrong",
  "errorRetry": "Retry",

  "loadingDefault": "Loading…"
```

- [ ] **Step 3: Add zh keys**

Open `frontend/merchant/lib/l10n/app_zh.arb`. Before the closing `}`, insert:

```json
  "validationRequired": "必填",
  "validationRequiredFieldNamed": "{field}必填",
  "@validationRequiredFieldNamed": {
    "placeholders": { "field": { "type": "String" } }
  },

  "validationPhoneInvalid": "请输入有效手机号（11位中国手机号或 +国际号码）",
  "validationPriceInvalid": "请输入数字",
  "validationPriceNegative": "价格不能为负",
  "validationPriceTooPrecise": "最多保留 2 位小数",

  "validationMaxLength": "最多{max}个字符",
  "@validationMaxLength": {
    "placeholders": { "max": { "type": "int" } }
  },

  "logoutFailedSnackbar": "退出登录出错，但已返回登录页。",
  "registerHintSnackbar": "新用户直接输入手机号，我们会发送验证码并自动创建账号。",

  "emptyOrganizeCategoriesMessage": "此菜单还没有分类",
  "emptyOrganizeCategoriesAction": "新增分类",
  "emptyHomeMenusMessage": "还没有菜单",
  "emptyHomeMenusAction": "拍一张菜单照片",

  "errorGenericMessage": "出错了",
  "errorRetry": "重试",

  "loadingDefault": "加载中…"
```

Note: `zh.arb` only duplicates the `@key` descriptor blocks when placeholders need explicit typing; other `@key` descriptions can stay in en-only.

- [ ] **Step 4: Regenerate localizations**

Run: `cd /home/coder/workspaces/menuray/frontend/merchant && /home/coder/flutter/bin/flutter gen-l10n`
Expected: no errors; `lib/l10n/app_localizations*.dart` updated in place with the new getter methods.

- [ ] **Step 5: Analyze to verify the new keys parse**

Run: `/home/coder/flutter/bin/flutter analyze`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add frontend/merchant/lib/l10n/
git commit -m "i18n(merchant): add 15 keys for polish (validators + L/E/E + logout/register)

Placeholders use Flutter's gen_l10n format: validationMaxLength({max})
and validationRequiredFieldNamed({field}). No dart change outside
generated localizations.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Validator helpers + unit tests (TDD)

**Files:**
- Create: `frontend/merchant/lib/shared/validation.dart`
- Create: `frontend/merchant/test/unit/validation_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `frontend/merchant/test/unit/validation_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:menuray/l10n/app_localizations.dart';
import 'package:menuray/shared/validation.dart';

/// Loads an AppLocalizations instance for a given locale so we can pass it to
/// validators without spinning up a full widget tree.
Future<AppLocalizations> loadL10n(Locale locale) async {
  // AppLocalizations.delegate.load() is async and resolves localized strings.
  return AppLocalizations.delegate.load(locale);
}

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    l = await loadL10n(const Locale('en'));
  });

  group('validateRequired', () {
    test('null → error', () => expect(validateRequired(null, l), isNotNull));
    test('empty → error', () => expect(validateRequired('', l), isNotNull));
    test('whitespace → error', () => expect(validateRequired('   ', l), isNotNull));
    test('non-empty → null', () => expect(validateRequired('hi', l), isNull));
    test('fieldLabel produces named error',
        () => expect(validateRequired('', l, fieldLabel: 'Phone'), contains('Phone')));
  });

  group('validatePhoneOrChineseMobile', () {
    test('empty → error', () => expect(validatePhoneOrChineseMobile('', l), isNotNull));
    test('11-digit China mobile → ok',
        () => expect(validatePhoneOrChineseMobile('13800001234', l), isNull));
    test('+86 China mobile → ok',
        () => expect(validatePhoneOrChineseMobile('+8613800001234', l), isNull));
    test('+1 US → ok', () => expect(validatePhoneOrChineseMobile('+14155551234', l), isNull));
    test('9-digit unprefixed → error',
        () => expect(validatePhoneOrChineseMobile('123456789', l), isNotNull));
    test('letters → error',
        () => expect(validatePhoneOrChineseMobile('+1415ABC1234', l), isNotNull));
    test('12-digit CN (wrong leading) → error',
        () => expect(validatePhoneOrChineseMobile('23800001234', l), isNotNull));
    test('whitespace-wrapped 11-digit → ok',
        () => expect(validatePhoneOrChineseMobile('  13800001234  ', l), isNull));
  });

  group('normalizePhone', () {
    test('11-digit CN → +86 prefix', () => expect(normalizePhone('13800001234'), '+8613800001234'));
    test('+ prefix kept', () => expect(normalizePhone('+14155551234'), '+14155551234'));
    test('trims whitespace', () => expect(normalizePhone('  13800001234  '), '+8613800001234'));
  });

  group('validatePriceNonNegative', () {
    test('empty → error', () => expect(validatePriceNonNegative('', l), isNotNull));
    test('zero → ok', () => expect(validatePriceNonNegative('0', l), isNull));
    test('10.99 → ok', () => expect(validatePriceNonNegative('10.99', l), isNull));
    test('negative → error', () => expect(validatePriceNonNegative('-1', l), isNotNull));
    test('letters → error', () => expect(validatePriceNonNegative('abc', l), isNotNull));
    test('3 decimals → error', () => expect(validatePriceNonNegative('10.999', l), isNotNull));
    test('1 decimal → ok', () => expect(validatePriceNonNegative('10.9', l), isNull));
  });

  group('validateMaxLength', () {
    test('null → ok', () => expect(validateMaxLength(null, l, max: 10), isNull));
    test('exactly max → ok',
        () => expect(validateMaxLength('a' * 10, l, max: 10), isNull));
    test('over max → error',
        () => expect(validateMaxLength('a' * 11, l, max: 10), isNotNull));
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /home/coder/workspaces/menuray/frontend/merchant && /home/coder/flutter/bin/flutter test test/unit/validation_test.dart`
Expected: compilation error — `package:menuray/shared/validation.dart` not found.

- [ ] **Step 3: Implement `lib/shared/validation.dart`**

```dart
import 'package:menuray/l10n/app_localizations.dart';

/// Returns null if non-empty (after trim); else localized error.
/// If [fieldLabel] is provided, returns "{fieldLabel} is required".
String? validateRequired(String? value, AppLocalizations l, {String? fieldLabel}) {
  if (value == null || value.trim().isEmpty) {
    return fieldLabel != null
        ? l.validationRequiredFieldNamed(fieldLabel)
        : l.validationRequired;
  }
  return null;
}

/// Accepts either an 11-digit Chinese mobile starting with 1, or a full E.164
/// number (+ followed by 7-15 digits, first digit 1-9). Returns localized error
/// otherwise. Empty input is treated as required.
String? validatePhoneOrChineseMobile(String? raw, AppLocalizations l) {
  if (raw == null || raw.trim().isEmpty) return l.validationRequired;
  final v = raw.trim();
  if (RegExp(r'^1\d{10}$').hasMatch(v)) return null;
  if (RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(v)) return null;
  return l.validationPhoneInvalid;
}

/// Canonicalizes the user input into E.164 form. 11-digit CN → '+86…';
/// anything else trimmed and returned as-is. Callers pass this to
/// Supabase signInWithOtp.
String normalizePhone(String raw) {
  final v = raw.trim();
  if (RegExp(r'^1\d{10}$').hasMatch(v)) return '+86$v';
  return v;
}

/// Returns null for a non-negative decimal with at most 2 fractional digits.
String? validatePriceNonNegative(String? raw, AppLocalizations l) {
  if (raw == null || raw.trim().isEmpty) return l.validationRequired;
  final t = raw.trim();
  final d = double.tryParse(t);
  if (d == null) return l.validationPriceInvalid;
  if (d < 0) return l.validationPriceNegative;
  final parts = t.split('.');
  if (parts.length == 2 && parts[1].length > 2) return l.validationPriceTooPrecise;
  return null;
}

/// Returns null if [raw] is null or within [max] characters; else localized error.
/// Required-ness should be checked separately via [validateRequired].
String? validateMaxLength(String? raw, AppLocalizations l, {required int max}) {
  if (raw == null) return null;
  if (raw.length > max) return l.validationMaxLength(max);
  return null;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `/home/coder/flutter/bin/flutter test test/unit/validation_test.dart`
Expected: all tests pass (≥20 assertions).

- [ ] **Step 5: Analyze**

Run: `/home/coder/flutter/bin/flutter analyze`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add frontend/merchant/lib/shared/validation.dart frontend/merchant/test/unit/
git commit -m "feat(shared): validation helpers — required / phone / price / maxLength

Four pure functions + normalizePhone(). All localized via
AppLocalizations passed by the caller. TDD'd; 20+ unit tests.
Chinese 11-digit mobiles auto-prefix to +86 in normalizePhone.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: AuthRepository.sendOtp explicit + logout fix

**Files:**
- Modify: `frontend/merchant/lib/features/auth/data/auth_repository.dart`
- Modify: `frontend/merchant/lib/features/store/presentation/settings_screen.dart`
- Create or extend: `frontend/merchant/test/smoke/settings_screen_smoke_test.dart`

- [ ] **Step 1: Inspect existing `AuthRepository`**

Read `frontend/merchant/lib/features/auth/data/auth_repository.dart`. Verify a `signOut` method exists. If it does, note its signature. If it does NOT, you'll add one (see Step 3).

- [ ] **Step 2: Make `sendOtp` explicit about `shouldCreateUser`**

Find the `sendOtp` method. Replace:

```dart
Future<void> sendOtp(String phone) =>
    _auth.signInWithOtp(phone: phone);
```

With:

```dart
Future<void> sendOtp(String phone) =>
    _auth.signInWithOtp(phone: phone, shouldCreateUser: true);
```

- [ ] **Step 3: Ensure `signOut` exists**

If the class already has a `signOut` method, skip. Otherwise add near the other methods:

```dart
Future<void> signOut() => _auth.signOut();
```

(Where `_auth` is whatever the field is named — match the class's existing convention.)

- [ ] **Step 4: Read `settings_screen.dart`**

Open `frontend/merchant/lib/features/store/presentation/settings_screen.dart`. Locate the `_LogoutButton(onTap: () => context.go(AppRoutes.login))` call (around lines 95–97 per prior exploration). Note whether the parent widget is a `ConsumerWidget` or `ConsumerStatefulWidget` — needed to use `ref`.

- [ ] **Step 5: Fix the logout**

If the parent widget is `ConsumerWidget`, the fix slots in-place. If it's `StatelessWidget`, wrap the specific logout-invoking widget in a `Consumer` so you can read `ref` without converting the whole screen. Typical shape:

```dart
_LogoutButton(
  onTap: () async {
    final l = AppLocalizations.of(context)!;
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.logoutFailedSnackbar)),
        );
      }
    }
    if (context.mounted) context.go(AppRoutes.login);
  },
),
```

If the screen is a `StatelessWidget` that doesn't have `ref`, the smallest viable change is to wrap JUST that `_LogoutButton` in a `Consumer(builder: (context, ref, _) => _LogoutButton(onTap: async { … }))`. Don't refactor the whole screen.

Add the `AppLocalizations` import if absent:

```dart
import 'package:menuray/l10n/app_localizations.dart';
```

- [ ] **Step 6: Write/extend settings smoke test**

Check for an existing `frontend/merchant/test/smoke/settings_screen_smoke_test.dart`. If absent, create:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:menuray/features/auth/data/auth_repository.dart';
import 'package:menuray/features/store/presentation/settings_screen.dart';
import 'package:menuray/l10n/app_localizations.dart';

class _FakeAuthRepository implements AuthRepository {
  int signOutCalls = 0;

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }

  // Implement other AuthRepository members as unreachable noops so the fake
  // satisfies the interface. Adapt to the actual class members — mirror
  // whatever other tests' fakes look like.
  @override
  Future<void> sendOtp(String phone) async {}

  @override
  Future<void> verifyOtp(String phone, String otp) async {}
}

Widget _harness({required GoRouter router, required AuthRepository auth}) =>
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
      child: MaterialApp.router(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: router,
      ),
    );

void main() {
  testWidgets('logout taps signOut and navigates to login', (tester) async {
    final auth = _FakeAuthRepository();
    // Minimal GoRouter with settings + login.
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('LOGIN_MARKER'))),
      ],
    );

    await tester.pumpWidget(_harness(router: router, auth: auth));
    await tester.pumpAndSettle();

    // Tap the logout button. Its label (zh) is "退出登录" — find by text.
    await tester.tap(find.text('退出登录'));
    await tester.pumpAndSettle();

    expect(auth.signOutCalls, 1);
    expect(find.text('LOGIN_MARKER'), findsOneWidget);
  });
}
```

Adapt the fake's implemented members to match the actual `AuthRepository` interface (Step 1 told you what's there).

If the path `/settings` or `/login` already live in `AppRoutes`, reference them instead of string literals.

- [ ] **Step 7: Analyze + run tests**

```bash
/home/coder/flutter/bin/flutter analyze
/home/coder/flutter/bin/flutter test
```

Expected: both clean. Test count goes up by at least 1 vs previous 36.

If the smoke test fails because the `_LogoutButton`'s label isn't the plain string `退出登录` (it might be via `l.someKey`), update the finder to `find.text(AppLocalizations.of(...).whateverKey)` by pumping the widget tree + reading the localization. Simpler: finder `find.byType(_LogoutButton)` (if the widget is public) or `find.ancestor(of: find.text('LOGOUT_LABEL'), matching: find.byType(GestureDetector))`.

- [ ] **Step 8: Commit**

```bash
git add frontend/merchant/lib/features/auth/data/auth_repository.dart \
        frontend/merchant/lib/features/store/presentation/settings_screen.dart \
        frontend/merchant/test/smoke/settings_screen_smoke_test.dart
git commit -m "fix(auth): logout actually signs out; sendOtp explicit shouldCreateUser

- settings_screen: _LogoutButton.onTap awaits authRepo.signOut() then
  goes to login; snackbar on failure but still navigates
- auth_repository: sendOtp passes shouldCreateUser: true explicitly
- smoke test asserts signOut is called and login is reached

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: LoadingView + ErrorView shared widgets + widget tests

**Files:**
- Create: `frontend/merchant/lib/shared/widgets/loading_view.dart`
- Create: `frontend/merchant/lib/shared/widgets/error_view.dart`
- Create: `frontend/merchant/test/widgets/loading_view_widget_test.dart`
- Create: `frontend/merchant/test/widgets/error_view_widget_test.dart`

- [ ] **Step 1: `loading_view.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:menuray/theme/app_colors.dart';

/// Centered progress indicator with an optional label below.
/// Use inside AsyncValue.when's loading branch for consistency.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          if (label != null) ...[
            const SizedBox(height: 16),
            Text(
              label!,
              style: const TextStyle(color: AppColors.secondary),
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: `error_view.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:menuray/shared/widgets/primary_button.dart';
import 'package:menuray/theme/app_colors.dart';

/// Centered error icon, message, and optional retry button.
/// Visual style matches EmptyState (padding 32, icon 96, 16px gaps).
/// Callers pass localized strings — widget imports no AppLocalizations.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel,
  });

  final String message;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 96, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 16, color: AppColors.secondary),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              PrimaryButton(
                label: retryLabel ?? 'Retry',
                onPressed: onRetry!,
                fullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

If the `AppColors.error` constant doesn't exist, use `Colors.red.shade700` instead and note it in the report; adjust the spec's reference later.

- [ ] **Step 3: LoadingView widget test**

```dart
// frontend/merchant/test/widgets/loading_view_widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray/shared/widgets/loading_view.dart';

void main() {
  testWidgets('renders a CircularProgressIndicator', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoadingView()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('renders label when provided', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoadingView(label: 'Loading…')),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading…'), findsOneWidget);
  });
}
```

- [ ] **Step 4: ErrorView widget test**

```dart
// frontend/merchant/test/widgets/error_view_widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray/shared/widgets/error_view.dart';

void main() {
  testWidgets('renders message + error icon, no button when onRetry absent',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ErrorView(message: 'Boom')),
    );
    expect(find.text('Boom'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    // No PrimaryButton: one-line way is no 'Retry' / no ElevatedButton.
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('renders button when onRetry provided; tapping invokes it',
      (tester) async {
    int calls = 0;
    await tester.pumpWidget(MaterialApp(
      home: ErrorView(
        message: 'Boom',
        retryLabel: 'Try again',
        onRetry: () => calls++,
      ),
    ));
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(calls, 1);
  });
}
```

- [ ] **Step 5: Analyze + run tests**

```bash
/home/coder/flutter/bin/flutter analyze
/home/coder/flutter/bin/flutter test test/widgets/
```

Expected: no issues; widget tests pass (4 total).

- [ ] **Step 6: Commit**

```bash
git add frontend/merchant/lib/shared/widgets/loading_view.dart \
        frontend/merchant/lib/shared/widgets/error_view.dart \
        frontend/merchant/test/widgets/
git commit -m "feat(shared): LoadingView + ErrorView widgets

Match EmptyState's visual style (32px padding, 96px icon, 16px
gaps). Callers pass localized strings; widgets import no
AppLocalizations to keep shared/ lookup-free.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Refactor 4 screens to use LoadingView + ErrorView

**Files:**
- Modify: `frontend/merchant/lib/features/manage/presentation/menu_management_screen.dart`
- Modify: `frontend/merchant/lib/features/edit/presentation/organize_menu_screen.dart`
- Modify: `frontend/merchant/lib/features/edit/presentation/edit_dish_screen.dart`
- Modify: `frontend/merchant/lib/features/templates/presentation/select_template_screen.dart`

For each file, apply the following pattern.

- [ ] **Step 1: `menu_management_screen.dart` L/E refactor**

Find the `AsyncValue<Menu>.when(...)` block (around lines 66–73). Replace:

```dart
loading: () => const _LoadingBody(),      // or Center(child: CircularProgressIndicator())
error: (err, _) => const _ErrorBody(),
```

with:

```dart
loading: () => LoadingView(label: AppLocalizations.of(context)!.loadingDefault),
error: (e, _) => ErrorView(
  message: AppLocalizations.of(context)!.errorGenericMessage,
  retryLabel: AppLocalizations.of(context)!.errorRetry,
  onRetry: () => ref.invalidate(menuByIdProvider(widget.menuId)),  // adjust provider name
),
```

Replace the provider name to match what this file reads (e.g. `menuByIdProvider(widget.menuId)` — check the file). Add imports at the top:

```dart
import 'package:menuray/shared/widgets/loading_view.dart';
import 'package:menuray/shared/widgets/error_view.dart';
```

Delete the private `_LoadingBody` and `_ErrorBody` widget classes at the bottom of the file (if present). Before deleting, `grep` inside the file to confirm no other call sites.

- [ ] **Step 2: `organize_menu_screen.dart` L/E refactor**

Same pattern as Step 1. Identify the provider name from the file (likely `menuByIdProvider` or `organizeMenuProvider`). Keep the data branch untouched for now (empty-state work lands in Task 8).

- [ ] **Step 3: `edit_dish_screen.dart` L/E refactor**

Same pattern. Provider likely `dishByIdProvider` or similar.

- [ ] **Step 4: `select_template_screen.dart` L/E refactor**

Same pattern. Replace the existing inline `loading: () => const Center(child: CircularProgressIndicator())` and `error: (e, _) => Center(child: Text(l.appearanceSaveFailed))` blocks with `LoadingView(label: …)` / `ErrorView(message: l.errorGenericMessage, …)`. The provider is `templateListProvider`.

Note: `select_template_screen` has its own `_loadInitial()` try/catch for the DB-fetched template/color state. That's independent and untouched.

- [ ] **Step 5: Verify no private `_LoadingBody` / `_ErrorBody` left in the 4 files**

Run: `grep -n "_LoadingBody\|_ErrorBody" frontend/merchant/lib/features/{manage,edit,templates}/presentation/*.dart`
Expected: no matches.

- [ ] **Step 6: Analyze + test**

```bash
/home/coder/flutter/bin/flutter analyze
/home/coder/flutter/bin/flutter test
```

Expected: clean; all existing tests still pass.

- [ ] **Step 7: Commit**

```bash
git add frontend/merchant/lib/features/manage/presentation/menu_management_screen.dart \
        frontend/merchant/lib/features/edit/presentation/organize_menu_screen.dart \
        frontend/merchant/lib/features/edit/presentation/edit_dish_screen.dart \
        frontend/merchant/lib/features/templates/presentation/select_template_screen.dart
git commit -m "refactor(merchant): 4 screens use shared LoadingView + ErrorView

Deletes private _LoadingBody / _ErrorBody duplication. Each
ErrorView's onRetry invalidates the relevant provider so the user
can re-fetch.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Login screen — register link wire + phone TextFormField

**Files:**
- Modify: `frontend/merchant/lib/features/auth/presentation/login_screen.dart`
- Modify: `frontend/merchant/test/smoke/login_screen_smoke_test.dart`

- [ ] **Step 1: Read the current login_screen.dart**

Read the file. Note:
- Whether it's already a `ConsumerStatefulWidget`.
- Existing `_phoneController` name.
- Existing submit handler.
- The current `_LoginButton` or `ElevatedButton` that triggers `sendOtp`.

- [ ] **Step 2: Add a `FocusNode` + `GlobalKey<FormState>` to the state class**

In `_LoginScreenState` (or create that state class if the widget is currently stateless — CLAUDE.md requires StatefulWidget for anything owning controllers/focus nodes), add fields:

```dart
final _phoneFocusNode = FocusNode();
final _formKey = GlobalKey<FormState>();
```

Initialize + dispose properly:

```dart
@override
void dispose() {
  _phoneFocusNode.dispose();
  // keep existing controller dispose(s)
  super.dispose();
}
```

- [ ] **Step 3: Wrap the phone input in a `Form` and change `TextField` → `TextFormField`**

Find the existing phone `TextField`. Replace the enclosing structure so it looks like:

```dart
Form(
  key: _formKey,
  child: TextFormField(
    controller: _phoneController,
    focusNode: _phoneFocusNode,
    keyboardType: TextInputType.phone,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    validator: (v) => validatePhoneOrChineseMobile(v, AppLocalizations.of(context)!),
    decoration: const InputDecoration(
      // keep whatever decoration the original TextField had; just copy the
      // hintText / labelText / prefix from the old widget.
    ),
  ),
),
```

Add imports if missing:

```dart
import 'package:menuray/shared/validation.dart';
import 'package:menuray/l10n/app_localizations.dart';  // likely already imported
```

- [ ] **Step 4: Wire the register link onTap**

Find `GestureDetector(onTap: () {}, child: Text(l.authRegisterHint))` (around line 152). Replace:

```dart
GestureDetector(
  onTap: () {
    final l = AppLocalizations.of(context)!;
    _phoneFocusNode.requestFocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.registerHintSnackbar),
        duration: const Duration(seconds: 3),
      ),
    );
  },
  child: Text(
    AppLocalizations.of(context)!.authRegisterHint,
    // keep existing style
  ),
),
```

- [ ] **Step 5: Gate the submit handler on form validation**

Find the button/handler that calls `sendOtp`. Wrap the submission in:

```dart
Future<void> _submit() async {
  if (_formKey.currentState?.validate() != true) return;
  final phone = normalizePhone(_phoneController.text);
  await ref.read(authRepositoryProvider).sendOtp(phone);
  // existing navigation / UI state transition continues here
}
```

Attach `_submit` to the button's `onPressed`.

- [ ] **Step 6: Extend the smoke test**

Read `frontend/merchant/test/smoke/login_screen_smoke_test.dart`. Add three scenarios (append new `testWidgets` blocks, don't remove existing ones):

```dart
testWidgets('empty phone → submit shows validator error', (tester) async {
  // Reuse whatever harness the existing test uses.
  await tester.pumpWidget(/* existing harness around LoginScreen */);
  await tester.pumpAndSettle();

  // Tap submit without filling phone.
  await tester.tap(find.byType(ElevatedButton));  // or whatever submit widget type
  await tester.pump();

  // Generic 'required' or 'invalid phone' text must be visible (ZH locale).
  final hasRequired = find.text('必填').evaluate().isNotEmpty;
  final hasInvalid = find.textContaining('手机号').evaluate().isNotEmpty;
  expect(hasRequired || hasInvalid, isTrue);
});

testWidgets('register link → snackbar visible + phone focused', (tester) async {
  await tester.pumpWidget(/* existing harness */);
  await tester.pumpAndSettle();

  // Find + tap the register hint.
  await tester.tap(find.textContaining('新用户'));
  await tester.pump();

  expect(find.textContaining('新用户直接输入手机号'), findsOneWidget);
});

testWidgets('valid CN mobile → sendOtp called with +86 prefix', (tester) async {
  // This assumes the existing test's _FakeAuthRepository records sendOtp calls.
  // If it doesn't, extend the fake to record the last arg.
  final fake = /* _FakeAuthRepository with `String? lastPhone` field */;
  await tester.pumpWidget(/* harness with that fake */);
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextFormField), '13800001234');
  await tester.tap(find.byType(ElevatedButton));  // or whichever submit widget
  await tester.pumpAndSettle();

  expect(fake.lastPhone, '+8613800001234');
});
```

Adapt to the existing test file's conventions. If the existing `_FakeAuthRepository` doesn't expose `lastPhone`, extend the fake inside the smoke test file to add that field:

```dart
class _FakeAuthRepository implements AuthRepository {
  String? lastPhone;
  @override
  Future<void> sendOtp(String phone) async { lastPhone = phone; }
  // other members: no-op per existing fake
}
```

- [ ] **Step 7: Analyze + test**

```bash
/home/coder/flutter/bin/flutter analyze
/home/coder/flutter/bin/flutter test
```

Expected: clean; existing tests + 3 new login smoke tests pass.

- [ ] **Step 8: Commit**

```bash
git add frontend/merchant/lib/features/auth/presentation/login_screen.dart \
        frontend/merchant/test/smoke/login_screen_smoke_test.dart
git commit -m "feat(auth): login register link onTap + phone form validation

- Register hint now requests focus on the phone input and shows a
  snackbar explaining the OTP-auto-register flow.
- Phone input becomes a TextFormField inside a Form with
  validatePhoneOrChineseMobile. Submit gated on validator success.
- sendOtp receives normalizePhone() output so 11-digit CN numbers
  are auto-prefixed with +86.
- 3 new smoke assertions cover the validator, the register link,
  and the phone normalization.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: edit_dish + store_management form validation

**Files:**
- Modify: `frontend/merchant/lib/features/edit/presentation/edit_dish_screen.dart`
- Modify: `frontend/merchant/lib/features/store/presentation/store_management_screen.dart`
- Modify: `frontend/merchant/test/smoke/edit_dish_screen_smoke_test.dart`

- [ ] **Step 1: edit_dish_screen — Form + validators**

Read the file. Identify the name and price inputs (they're currently `TextField`s per prior context). Add a `GlobalKey<FormState> _formKey = GlobalKey()` field on the state class.

Wrap the two inputs in a `Form(key: _formKey, child: Column(children: [...]))`. Convert each `TextField` to a `TextFormField`:

```dart
TextFormField(
  controller: _nameController,
  autovalidateMode: AutovalidateMode.onUserInteraction,
  validator: (v) {
    final l = AppLocalizations.of(context)!;
    return validateRequired(v, l, fieldLabel: l.dishName)
        ?? validateMaxLength(v, l, max: 80);
  },
  decoration: /* keep existing decoration */,
),

TextFormField(
  controller: _priceController,
  keyboardType: const TextInputType.numberWithOptions(decimal: true),
  autovalidateMode: AutovalidateMode.onUserInteraction,
  validator: (v) => validatePriceNonNegative(v, AppLocalizations.of(context)!),
  decoration: /* keep existing decoration */,
),
```

If `l.dishName` doesn't exist, use the literal `'Name'` or add a key. Alternatively, pass `fieldLabel: null` to get the generic "Required" message — adjust if the dishName key is absent.

Gate the save handler:

```dart
Future<void> _save() async {
  if (_formKey.currentState?.validate() != true) return;
  // existing save logic unchanged
}
```

Add imports:

```dart
import 'package:menuray/shared/validation.dart';
```

- [ ] **Step 2: store_management_screen — Form + validator**

Read the file. Find the name input. Convert to `TextFormField` inside a `Form(key: _formKey, ...)`. Validator:

```dart
validator: (v) {
  final l = AppLocalizations.of(context)!;
  return validateRequired(v, l, fieldLabel: l.storeName)
      ?? validateMaxLength(v, l, max: 60);
},
```

If `l.storeName` doesn't exist, drop `fieldLabel` or use a literal. Gate the save handler on `_formKey.currentState?.validate() == true` before calling `updateStore`.

- [ ] **Step 3: Extend edit_dish smoke test**

Read `frontend/merchant/test/smoke/edit_dish_screen_smoke_test.dart`. Add two scenarios:

```dart
testWidgets('empty name → save shows required error', (tester) async {
  await tester.pumpWidget(/* existing harness */);
  await tester.pumpAndSettle();

  // Clear the name field, tap save.
  await tester.enterText(find.byType(TextFormField).first, '');
  await tester.tap(find.text('保存'));  // or whatever save label is in zh
  await tester.pump();

  expect(find.textContaining('必填'), findsWidgets);
});

testWidgets('negative price → save shows negative-price error', (tester) async {
  await tester.pumpWidget(/* existing harness */);
  await tester.pumpAndSettle();

  // Fill price with -1.
  final fields = find.byType(TextFormField);
  // Assumes price is the 2nd TextFormField in the column. Adjust if different.
  await tester.enterText(fields.at(1), '-1');
  await tester.tap(find.text('保存'));
  await tester.pump();

  expect(find.textContaining('不能为负'), findsOneWidget);
});
```

If the finder indices for which `TextFormField` is which are brittle, attach `Key('dish-name-field')` and `Key('dish-price-field')` in the screen and use them. Add the keys in `edit_dish_screen.dart` as part of Step 1 if needed.

- [ ] **Step 4: Analyze + test**

```bash
/home/coder/flutter/bin/flutter analyze
/home/coder/flutter/bin/flutter test
```

Expected: clean; all tests pass (+2 new edit_dish smoke assertions).

- [ ] **Step 5: Commit**

```bash
git add frontend/merchant/lib/features/edit/presentation/edit_dish_screen.dart \
        frontend/merchant/lib/features/store/presentation/store_management_screen.dart \
        frontend/merchant/test/smoke/edit_dish_screen_smoke_test.dart
git commit -m "feat(forms): validation on edit_dish + store_management

- edit_dish: Form with TextFormField on name (required + maxLen 80)
  and price (non-negative + ≤2 decimals). Save gated.
- store_management: Form with TextFormField on name (required +
  maxLen 60). Save gated.
- 2 new smoke assertions on edit_dish validator behaviour.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Empty states — organize_menu + home_screen

**Files:**
- Modify: `frontend/merchant/lib/features/edit/presentation/organize_menu_screen.dart`
- Modify: `frontend/merchant/lib/features/home/presentation/home_screen.dart`

- [ ] **Step 1: organize_menu empty state**

Read the file. Find the `data:` branch of the `AsyncValue.when` (Task 5 left this branch alone). Inside `data`, before building the regular category list, add:

```dart
if (menu.categories.isEmpty) {
  final l = AppLocalizations.of(context)!;
  return EmptyState(
    icon: Icons.category_outlined,
    message: l.emptyOrganizeCategoriesMessage,
    actionLabel: l.emptyOrganizeCategoriesAction,
    onAction: _addCategory,  // or existing equivalent
  );
}
```

If `_addCategory` doesn't exist in the file, add a stub:

```dart
void _addCategory() {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('暂未实现')),
  );
}
```

The stub is intentional — wiring real "Add category" is a larger feature that belongs to content-edit work, not polish. The empty-state affordance is visible; the button gives a minimal "we heard you" response.

Add import if absent:

```dart
import 'package:menuray/shared/widgets/empty_state.dart';
```

- [ ] **Step 2: home_screen empty state**

Read `frontend/merchant/lib/features/home/presentation/home_screen.dart`. Find the block that renders the menu list. Currently it likely renders a list even if empty. Add a guard:

```dart
if (menus.isEmpty) {
  final l = AppLocalizations.of(context)!;
  return EmptyState(
    icon: Icons.restaurant_menu,
    message: l.emptyHomeMenusMessage,
    actionLabel: l.emptyHomeMenusAction,
    onAction: () => context.push(AppRoutes.capture),  // adjust: actual "take photo" route
  );
}
```

Where `AppRoutes.capture` is whatever route the existing "take a photo" / main capture entry uses. Grep `AppRoutes` constants to pick the right one — it's likely `AppRoutes.camera` or `AppRoutes.home` (capture FAB).

If `home_screen` uses `AsyncValue` too, this check goes inside the `data:` branch. If it uses direct provider reads, it goes in the build method.

Add imports:

```dart
import 'package:go_router/go_router.dart';
import 'package:menuray/router/app_router.dart';
import 'package:menuray/shared/widgets/empty_state.dart';
```

- [ ] **Step 3: Analyze + test**

```bash
/home/coder/flutter/bin/flutter analyze
/home/coder/flutter/bin/flutter test
```

Expected: clean; existing tests pass.

If a smoke test for home_screen currently stubs a store with menus and now fails because the empty path is taken for an unrelated reason, inspect what the test provides. Adjust the test if it actually meant to test the populated path but the provider now returns empty — set up the stub correctly.

- [ ] **Step 4: Commit**

```bash
git add frontend/merchant/lib/features/edit/presentation/organize_menu_screen.dart \
        frontend/merchant/lib/features/home/presentation/home_screen.dart
git commit -m "feat(ux): empty states for organize_menu + home_screen

- organize_menu: EmptyState when menu has no categories (stub
  onAction until real add-category lands).
- home_screen: EmptyState when store has no menus; action goes to
  the camera/capture entry.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: Docs + CLAUDE.md + final verification

**Files:**
- Modify: `docs/architecture.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update `docs/architecture.md`**

Append (or extend) a short "Shared widgets" paragraph. Match the file's heading style. Content:

```md
### Shared merchant widgets

Canonical trio under `frontend/merchant/lib/shared/widgets/`:

- **`EmptyState`** — icon + message + action button. Use when a data fetch succeeds but returns zero rows (e.g. a menu with no categories).
- **`LoadingView`** — centered progress spinner with optional label. Use inside `AsyncValue.when`'s loading branch.
- **`ErrorView`** — icon + message + optional retry button. Use inside `AsyncValue.when`'s error branch; caller passes `onRetry` that invalidates the relevant provider.

All three take localized strings from the caller and import no `AppLocalizations` themselves, which keeps `lib/shared/` free of feature-level dependencies.
```

- [ ] **Step 2: Update `CLAUDE.md` Active work cell**

Append to the ✅ Done cell:

> Merchant polish shipped: real logout (signOut + redirect), register link wired (snackbar + focus), `shouldCreateUser: true` explicit, 4 validator helpers + 3 form-wired screens (login / edit_dish / store_management), `LoadingView` + `ErrorView` shared widgets replacing per-screen duplication in 4 async screens, empty states for organize_menu + home_screen.

In the 🔄 Next cell, remove sub-batch 3 mentions. Session 1 is complete — the cell should now describe what's next session-wise (OCR/LLM provider, auth migration, billing, analytics, additional templates — see roadmap).

- [ ] **Step 3: Run full verification**

```bash
cd /home/coder/workspaces/menuray/frontend/merchant
/home/coder/flutter/bin/flutter analyze
/home/coder/flutter/bin/flutter test

# Also make sure sub-batches 1+2 still green:
cd /home/coder/workspaces/menuray/frontend/customer
pnpm check
pnpm test
pnpm test:e2e
```

All five commands must pass.

Paste the last ~3 lines of each output into the report.

- [ ] **Step 4: Commit**

```bash
git add docs/architecture.md CLAUDE.md
git commit -m "docs: merchant polish shipped (sub-batch 3)

- docs/architecture.md: Shared widgets paragraph (EmptyState +
  LoadingView + ErrorView canonical trio).
- CLAUDE.md: Active work reflects sub-batch 3 completion; 🔄 Next
  cell updated to point at future sessions.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Self-review notes

Every spec section has a task:

| Spec § | Task |
|---|---|
| §1 Logout fix | Task 3 |
| §1 Register link wire | Task 6 |
| §1 `shouldCreateUser` explicit | Task 3 |
| §1 Form validation (3 forms) | Task 6 (login) + Task 7 (edit_dish + store_management) |
| §1 LoadingView + ErrorView + 4 screens refactor | Task 4 (widgets) + Task 5 (refactor) |
| §1 Empty states | Task 8 |
| §1 i18n keys | Task 1 |
| §1 validation.dart | Task 2 |
| §1 Tests | All tasks include test updates |
| §1 Docs update | Task 9 |
| §3.1 Logout call-site code | Task 3 Step 5 |
| §3.2 Register onTap code | Task 6 Step 4 |
| §3.3 sendOtp explicit | Task 3 Step 2 |
| §3.4 Validators | Task 2 |
| §3.5 Form wiring (3 screens) | Task 6 + Task 7 |
| §3.6 LoadingView + ErrorView code | Task 4 |
| §3.7 Refactor pattern per screen | Task 5 |
| §3.8 Empty states | Task 8 |
| §3.9 Testing strategy | Tasks 2/3/4/6/7 |
| §3.10 Migration note (none) | N/A |

No placeholders detected. Type names consistent: `validateRequired` / `validatePhoneOrChineseMobile` / `validatePriceNonNegative` / `validateMaxLength` / `normalizePhone` used identically across Tasks 2, 6, 7. Widget names `LoadingView` / `ErrorView` consistent across Tasks 4 and 5.

Known adaptive judgment calls (flagged in tasks):
- Task 3 — `AuthRepository.signOut` may or may not exist today; task handles both.
- Task 6 — smoke test finders for TextFormField may need `Key`s if positional indices prove brittle.
- Task 7 — `l.dishName` / `l.storeName` keys may not exist; plan tells implementer to drop fieldLabel or use literals if so.
- Task 8 — `home_screen.dart`'s menu-list path may be inside a Futureprovider; plan handles both branches.

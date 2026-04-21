# Merchant Polish — Design

Date: 2026-04-20
Scope: Close real merchant-app gaps discovered while shipping sub-batches 1 and 2: logout silently leaves the session alive, the "新用户？立即注册" link is a no-op, `shouldCreateUser` is left to SDK default, no form validation anywhere, and loading/error states are duplicated per screen. This sub-batch fixes all of those and introduces two shared widgets (`LoadingView` + `ErrorView`) so future screens get consistent UX.
Audience: whoever implements the follow-up plan. Scoped to sub-batch 3 of this session.

## 1. Goal & Scope

After this sub-batch:

1. Tapping "退出登录" actually signs the user out of Supabase, then navigates to login.
2. Tapping "新用户？立即注册" shows a localized snackbar explaining that the same phone-OTP flow handles registration, and focuses the phone input. No separate register screen.
3. `AuthRepository.sendOtp` explicitly passes `shouldCreateUser: true` so the auto-register behaviour is stable across Supabase SDK upgrades.
4. Three high-value forms validate before submit: login phone (E.164 or 11-digit CN auto-prefixed `+86`), edit-dish price (non-negative, ≤2 decimals, required), store-management name (required, max length).
5. Two new shared widgets `LoadingView` + `ErrorView` replace ad-hoc inline `CircularProgressIndicator` and per-screen `_ErrorBody` duplication across four screens already using `AsyncValue.when` (menu_management, organize_menu, edit_dish, select_template).
6. Two missing empty states surfaced: `organize_menu` with zero categories, `home_screen` with zero menus.

**In scope**

- `lib/features/auth/data/auth_repository.dart`: `sendOtp(phone)` call gains `shouldCreateUser: true`.
- `lib/features/auth/presentation/login_screen.dart`: wire "新用户？立即注册" onTap → snackbar + focus phone input. `TextFormField` replaces the current phone `TextField`, validator via new helper.
- `lib/features/store/presentation/settings_screen.dart`: `_LogoutButton.onTap` becomes `async` — calls `authRepositoryProvider.signOut()`, then `context.go(login)` regardless of success. Snackbar on failure.
- `lib/features/edit/presentation/edit_dish_screen.dart`: wrap name + price in `TextFormField`s with validators.
- `lib/features/store/presentation/store_management_screen.dart`: wrap name field in `TextFormField` with required validator.
- New `lib/shared/validation.dart` — 4 pure validator functions with unit tests: `validateRequired(value, {String? fieldName})`, `validatePhoneOrChineseMobile(value)`, `validatePriceNonNegative(value)`, `validateMaxLength(value, {required int max})`. Each returns `null` on success or a localized error message via a passed `AppLocalizations`.
- New `lib/shared/widgets/loading_view.dart` — `LoadingView` widget: centered `CircularProgressIndicator` plus optional `label` text below.
- New `lib/shared/widgets/error_view.dart` — `ErrorView` widget: centered brand-error icon, `message`, optional `onRetry` → button. Matches `EmptyState` visual style (32px padding, 16px icon→text gap).
- Refactor 4 screens (`menu_management`, `organize_menu`, `edit_dish`, `select_template`) to use `LoadingView()` + `ErrorView(message: …, onRetry: () => ref.invalidate(…))` inside their existing `AsyncValue.when` blocks. Delete the private `_LoadingBody` / `_ErrorBody` widgets that are now redundant.
- `organize_menu_screen.dart`: if fetched menu has zero categories, render `EmptyState(message: '此菜单还没有分类', actionLabel: '新增分类', onAction: _addCategory)` instead of an empty ListView. (Use existing `EmptyState`.)
- `home_screen.dart`: if `currentStore`'s menu list is empty, render `EmptyState(message: '还没有菜单', actionLabel: '拍一张菜单照片', onAction: _goCapture)`.
- New i18n keys for snackbars, validator messages, and empty-state strings (en + zh).
- Tests:
  - Unit tests for all 4 validators in `test/unit/validation_test.dart`.
  - Smoke tests: extend `login_screen_smoke_test.dart` (tap register link → snackbar visible; submit empty phone → validator error). Extend `settings_screen_smoke_test.dart` if exists, else new: tap logout → fake `signOut` called + `context.go(login)` invoked (use a navigator observer). Extend `edit_dish_screen_smoke_test.dart`: submit with negative price → validator error.
  - Widget tests: `loading_view_widget_test.dart` + `error_view_widget_test.dart` assert props render + `onRetry` invoked.
- Docs: `docs/architecture.md` gains a "Shared widgets" paragraph listing LoadingView + ErrorView + EmptyState as the canonical trio. No new ADR — this is an existing-pattern polish.

**Out of scope (deferred)**

- **Capture-flow screens** (`camera`, `correct_image`, `processing`, `select_photos`): they're imperative state machines, not `AsyncValue.when`-driven. Their error UX needs its own think — not a polish pass.
- **ai_optimize, preview_menu, published, custom_theme** screens' L/E/E: lower-priority placeholders. Revisit when their data flows solidify (Session 2 or later).
- **Network retry / offline support**: `onRetry` in `ErrorView` just re-invalidates the provider — no exponential backoff, no offline queue.
- **Full form-validation coverage** across all 17 screens: this sub-batch only wires login / edit_dish / store_management. Other screens get a follow-up pass in P1.
- **Field-level live validation** (as-you-type): we rely on `TextFormField`'s `autovalidateMode: onUserInteraction` — good enough; no debounce / custom live feedback.
- **Localized validator messages in exotic locales**: only en + zh this sub-batch (matching existing i18n scope).
- **Password / email auth flow**: phone OTP is the only path; no email reset / password reset work here.
- **Account deletion**: out of scope — pricing decisions §4 (user data) calls this out as Session 4 work.
- **Rate-limiting / abuse on OTP**: server-side via Supabase defaults; no additional client throttle.
- **Re-architecting `_ErrorBody` across all 17 screens** — only the 4 with `AsyncValue.when` get the treatment.

## 2. Context

- Merchant app is Flutter + Riverpod + go_router. 17 screens shipped (see sub-batch 2 context gathering for the list).
- Auth: `AuthRepository.sendOtp(phone)` + `AuthRepository.verifyOtp(phone, otp)` (Supabase phone OTP). Session is persisted by `supabase_flutter` in secure storage. Signing out requires calling `supabase.auth.signOut()`.
- `AuthRepository.signOut()` already exists (per the repo's convention — verify during implementation). If it doesn't, add a one-liner.
- Current logout bug: `settings_screen.dart:95-97` renders `_LogoutButton(onTap: () => context.go(AppRoutes.login))`. Session stays live; next app launch auto-logs in the previous user.
- Current register bug: `login_screen.dart:152` — `GestureDetector(onTap: () {}, child: Text(l.authRegisterHint))`.
- OTP auto-create: Supabase's `signInWithOtp` defaults `shouldCreateUser: true`, but explicit is better — the SDK has flipped defaults before.
- Four screens use `AsyncValue.when`: `menu_management_screen.dart`, `organize_menu_screen.dart`, `edit_dish_screen.dart`, `select_template_screen.dart` (new in sub-batch 2). Each currently has a private `_LoadingBody` or inline `Center(child: CircularProgressIndicator())`, plus a private `_ErrorBody`. This duplication is the core L/E/E cleanup target.
- `EmptyState` widget (`lib/shared/widgets/empty_state.dart`) already exists and is reused by several screens. Its API: `EmptyState(message, actionLabel, onAction, icon?)`. New LoadingView + ErrorView follow its style (Padding 32, Column mainAxisAlignment.center, icon 96px top, 16px gaps, AppColors.secondary text).
- No `form_validator` package in pubspec.yaml; all current validation is imperative. Using `TextFormField` + `validator:` is idiomatic Flutter and keeps zero deps.
- Chinese mobile numbers (11 digits starting with `1`) are the majority real-world input for the target market. Accepting them without requiring users to type `+86` is a small but meaningful UX win.
- `autovalidateMode: AutovalidateMode.onUserInteraction` is the standard Flutter choice — validators run after the field loses focus or a submit is attempted, not on every keystroke.

## 3. Decisions

### 3.1 Logout fix (settings_screen.dart)

`_LogoutButton` becomes a `Consumer` (or the parent screen becomes `ConsumerStatefulWidget` if it isn't already — check first). On tap:

```dart
Future<void> _onLogoutTap() async {
  final l = AppLocalizations.of(context)!;
  try {
    await ref.read(authRepositoryProvider).signOut();
  } catch (_) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.logoutFailedSnackbar)),
      );
    }
    // Intentional: continue to login regardless. User's mental model is "I clicked logout".
  }
  if (!mounted) return;
  context.go(AppRoutes.login);
}
```

Rationale for continuing to login on failure: the user tapped "退出登录"; their expectation is the login screen. A stuck session on a failed signOut is better than leaving the user in the settings UI with an unclear state.

### 3.2 Register link (login_screen.dart)

The existing `GestureDetector` keeps its position. New behaviour:

```dart
onTap: () {
  _phoneFocusNode.requestFocus();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(l.registerHintSnackbar),
      duration: const Duration(seconds: 3),
    ),
  );
}
```

A `_phoneFocusNode` is added as a `FocusNode` field on the state class (initialize in `initState`, dispose in `dispose` — matches CLAUDE.md's controller rule). The existing phone input becomes a `TextFormField` (see §3.3); attach `focusNode: _phoneFocusNode`.

Snackbar strings (en / zh):
- EN: `registerHintSnackbar`: "New users: enter your phone — we'll send a code and create your account automatically."
- ZH: `registerHintSnackbar`: "新用户直接输入手机号，我们会发送验证码并自动创建账号。"

### 3.3 OTP `shouldCreateUser` explicit

`auth_repository.dart`:

```dart
Future<void> sendOtp(String phone) =>
    _auth.signInWithOtp(phone: phone, shouldCreateUser: true);
```

One-parameter addition; behaviour unchanged (default is already `true` but this is forward-compatible).

### 3.4 Validators (`lib/shared/validation.dart`)

All validators are pure top-level functions taking the value + an `AppLocalizations` instance and returning `String?` (null = valid, else the localized error text). This avoids import loops and lets every `TextFormField` write `validator: (v) => validateRequired(v, l)` without ceremony.

```dart
import 'package:menuray/l10n/app_localizations.dart';

String? validateRequired(String? value, AppLocalizations l, {String? fieldLabel}) {
  if (value == null || value.trim().isEmpty) {
    return fieldLabel != null
        ? l.validationRequiredFieldNamed(fieldLabel)
        : l.validationRequired;
  }
  return null;
}

String? validatePhoneOrChineseMobile(String? raw, AppLocalizations l) {
  if (raw == null || raw.trim().isEmpty) return l.validationRequired;
  final v = raw.trim();
  // Chinese mobile shortcut: 11 digits starting with 1.
  if (RegExp(r'^1\d{10}$').hasMatch(v)) return null;
  // E.164: + followed by 7-15 digits (ITU-T E.164 max 15).
  if (RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(v)) return null;
  return l.validationPhoneInvalid;
}

/// Returns the caller-ready E.164 form. Example: '13800001234' → '+8613800001234'.
/// Defined here so login_screen's submit handler has one code path.
String normalizePhone(String raw) {
  final v = raw.trim();
  if (RegExp(r'^1\d{10}$').hasMatch(v)) return '+86$v';
  return v;
}

String? validatePriceNonNegative(String? raw, AppLocalizations l) {
  if (raw == null || raw.trim().isEmpty) return l.validationRequired;
  final d = double.tryParse(raw.trim());
  if (d == null) return l.validationPriceInvalid;
  if (d < 0) return l.validationPriceNegative;
  // Max 2 decimals: reject '12.345' to avoid surprise rounding.
  final parts = raw.trim().split('.');
  if (parts.length == 2 && parts[1].length > 2) return l.validationPriceTooPrecise;
  return null;
}

String? validateMaxLength(String? raw, AppLocalizations l, {required int max}) {
  if (raw == null) return null;  // required-ness checked separately
  if (raw.length > max) return l.validationMaxLength(max);
  return null;
}
```

New i18n keys:

| Key | EN | ZH |
|---|---|---|
| `validationRequired` | "Required" | "必填" |
| `validationRequiredFieldNamed` | "{field} is required" | "{field}必填" |
| `validationPhoneInvalid` | "Enter a valid phone (11-digit China mobile or +country number)" | "请输入有效手机号（11位中国手机号或 +国际号码）" |
| `validationPriceInvalid` | "Enter a number" | "请输入数字" |
| `validationPriceNegative` | "Price cannot be negative" | "价格不能为负" |
| `validationPriceTooPrecise` | "At most 2 decimal places" | "最多保留 2 位小数" |
| `validationMaxLength` | "At most {max} characters" | "最多{max}个字符" |
| `logoutFailedSnackbar` | "Logout failed, but we sent you back to login." | "退出登录出错，但已返回登录页。" |
| `registerHintSnackbar` | "New users: enter your phone — we'll send a code and create your account automatically." | "新用户直接输入手机号，我们会发送验证码并自动创建账号。" |
| `emptyOrganizeCategoriesMessage` | "This menu has no categories yet" | "此菜单还没有分类" |
| `emptyOrganizeCategoriesAction` | "Add category" | "新增分类" |
| `emptyHomeMenusMessage` | "No menus yet" | "还没有菜单" |
| `emptyHomeMenusAction` | "Take a photo of a menu" | "拍一张菜单照片" |
| `errorGenericMessage` | "Something went wrong" | "出错了" |
| `errorRetry` | "Retry" | "重试" |
| `loadingDefault` | "Loading…" | "加载中…" |

### 3.5 Form validation wiring

**login_screen.dart**:
- Convert the phone `TextField` to `TextFormField` inside a new `Form` widget with a `GlobalKey<FormState>`.
- `validator: (v) => validatePhoneOrChineseMobile(v, l)`.
- `autovalidateMode: AutovalidateMode.onUserInteraction`.
- Submit handler: `if (_formKey.currentState?.validate() != true) return;` before calling `sendOtp(normalizePhone(_phoneController.text))`.

**edit_dish_screen.dart**:
- Wrap the existing name + price inputs in a `Form`.
- Name `TextFormField`: `validator: (v) => validateRequired(v, l, fieldLabel: l.dishName) ?? validateMaxLength(v, l, max: 80)`.
- Price `TextFormField`: `validator: (v) => validatePriceNonNegative(v, l)`.
- Save button disabled unless `_formKey.currentState?.validate()` returns true.

**store_management_screen.dart**:
- Wrap name input in a `Form`.
- Validator: `validateRequired(v, l, fieldLabel: l.storeName) ?? validateMaxLength(v, l, max: 60)`.

The validators always return `null` or a localized string — `TextFormField.validator`'s contract — so no unwrapping gymnastics.

### 3.6 Shared LoadingView + ErrorView

**`lib/shared/widgets/loading_view.dart`**:

```dart
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

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
            Text(label!, style: const TextStyle(color: AppColors.secondary)),
          ],
        ],
      ),
    );
  }
}
```

**`lib/shared/widgets/error_view.dart`**:

```dart
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'primary_button.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry, this.retryLabel});
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
                label: retryLabel ?? 'Retry',  // callers pass localized
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

Callers are responsible for passing localized strings — the widget doesn't import `AppLocalizations` because it lives in `lib/shared/` which stays lookup-free (matches the existing EmptyState style).

### 3.7 AsyncValue.when refactor (4 screens)

For each of `menu_management_screen.dart`, `organize_menu_screen.dart`, `edit_dish_screen.dart`, `select_template_screen.dart`:

1. Replace `loading: () => _LoadingBody()` (or inline spinner) with `loading: () => LoadingView(label: l.loadingDefault)`.
2. Replace `error: (e, _) => _ErrorBody()` with:
   ```dart
   error: (e, _) => ErrorView(
     message: l.errorGenericMessage,
     retryLabel: l.errorRetry,
     onRetry: () => ref.invalidate(thisScreensProvider),
   ),
   ```
3. Delete the now-unused private `_LoadingBody` / `_ErrorBody` classes.
4. Add the import for the new shared widgets.

`select_template_screen.dart`'s current error body reads `l.appearanceSaveFailed` which is a save-failure label, not a fetch-failure label — retain that semantic in the new call by using `l.errorGenericMessage` (a better fit for a fetch failure) unless the code specifically handles save failure at this spot. Decision: use `l.errorGenericMessage` for the fetch-error path.

### 3.8 Empty states

**organize_menu_screen.dart**: In `AsyncValue.when`'s `data:` handler, after the menu loads, check `menu.categories.isEmpty`. If so, return:

```dart
EmptyState(
  message: l.emptyOrganizeCategoriesMessage,
  actionLabel: l.emptyOrganizeCategoriesAction,
  icon: Icons.category_outlined,
  onAction: _addCategory,
)
```

Where `_addCategory` is either the existing handler or a new stub that shows a snackbar "Not yet implemented" if the feature isn't wired (check the existing file — if adding categories isn't yet a thing, fallback to `SnackBar(content: Text('暂不支持'))`).

**home_screen.dart**: In the data branch that currently renders the menu list, add a `menus.isEmpty` check → `EmptyState(message: l.emptyHomeMenusMessage, actionLabel: l.emptyHomeMenusAction, icon: Icons.restaurant_menu, onAction: () => context.push(AppRoutes.capture))`.

### 3.9 Testing

**Unit tests** (`test/unit/validation_test.dart`):
- `validateRequired`: null / empty / whitespace / valid.
- `validatePhoneOrChineseMobile`: Chinese 11-digit pass; `+86138...` pass; `+1...` pass; 9-digit fail; letters fail; empty fail.
- `normalizePhone`: `13800001234` → `+8613800001234`; `+44...` → unchanged.
- `validatePriceNonNegative`: `0` pass; `10.99` pass; `-1` fail; `abc` fail; `10.999` fail (too precise); empty fail.
- `validateMaxLength`: `'a' * max` pass; `'a' * (max+1)` fail; null pass.

**Widget tests**:
- `loading_view_widget_test.dart`: renders `CircularProgressIndicator`; when label given, renders Text.
- `error_view_widget_test.dart`: renders message; when `onRetry` present, button visible and tapping calls it; when absent, no button.

**Smoke tests (extend or add)**:
- `login_screen_smoke_test.dart`: (a) submit with empty phone → validator error visible. (b) tap register link → snackbar visible. (c) submit with `13800001234` → `sendOtp` called with `+8613800001234`.
- `settings_screen_smoke_test.dart`: (new if absent) tap logout → fake `AuthRepository.signOut()` called; navigator observer records push of login route.
- `edit_dish_screen_smoke_test.dart`: submit with empty name → required error. Submit with `-1` price → negative error.

### 3.10 Migration / rollout

No schema change, no migration. Pure Flutter. Deploy alongside any next merchant build; existing sessions auto-migrate (they just start seeing real logout behaviour + validators next time they interact).

## 4. Risks & mitigations

| Risk | Mitigation |
|---|---|
| `signOut()` call blocks for network timeout (slow Supabase ping) and logout UX feels stuck | Wrap in try/catch — any exception falls through to `context.go(login)`. No `await` timeout budget this sub-batch (KISS); can add later if telemetry shows it |
| Chinese mobile regex collides with legitimate `1XXXXXXXXXX` numbers in other E.164 regions | `+` is required for non-CN numbers via validator; inputs without `+` are only accepted as 11-digit CN mobile. Any other unprefixed input fails — explicit is safer than guessing |
| Switching from `TextField` to `TextFormField` breaks the existing smoke tests (they search by widget type) | Smoke tests use text/label finders predominantly; `TextFormField` is a superset that still accepts `controller`. Re-run existing tests and patch any type-specific finders |
| `_ErrorBody` deletion in one of the 4 screens is referenced elsewhere (e.g. tests) | Before deleting, `grep _ErrorBody` / `grep _LoadingBody` across `lib/` + `test/`. Delete only if no other callers |
| `validateMaxLength` + `validateRequired` nested via `??` is unreadable | Pattern is idiomatic enough in Flutter forms; document via a brief comment on first use |
| `select_template_screen.dart`'s `_loadInitial()` already has its own try/catch for test environments (per sub-batch 2 Task 10) — interacts with the new ErrorView refactor | The `_loadInitial` path is separate from the `templateListProvider` AsyncValue. The refactor touches the AsyncValue.when block only. No collision |
| Shared widgets create import noise (`import 'package:menuray/shared/widgets/loading_view.dart'`) repeated across 4 screens | Acceptable; re-export from a barrel file `shared/widgets/widgets.dart` only if the pattern recurs — YAGNI for now |

## 5. Success criteria

- `flutter analyze` clean.
- `flutter test` passes: existing 36 tests + new validator unit tests (≥15) + 2 widget tests + 3 smoke assertions extending existing files = roughly 55–60 total.
- Manual check (dev build): logout from settings → login screen renders, and next app launch shows login (session no longer persists).
- Manual check: tap "立即注册" → snackbar visible, phone input focused. Enter `13800001234` → submit → OTP sent.
- Manual check: edit_dish — enter `-1` price → submit disabled / shows error. Enter `10.999` → "At most 2 decimal places".
- Manual check: organize_menu with a menu that has zero categories → EmptyState visible.
- No duplicated `_LoadingBody` / `_ErrorBody` private widgets left in the 4 screens — `grep '_LoadingBody\|_ErrorBody' lib/` returns empty (excluding file history).
- Docs: `docs/architecture.md` "Shared widgets" paragraph reflects LoadingView/ErrorView/EmptyState as the canonical trio.

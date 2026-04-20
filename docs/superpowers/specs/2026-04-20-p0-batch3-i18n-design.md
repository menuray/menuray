# P0 Batch 3 — i18n migration — Design

Date: 2026-04-20
Scope: migrate all UI-chrome strings across the 17 merchant screens to Flutter's ARB-based localisation, establish English as the default locale, and ship a complete zh-CN bundle preserving current Chinese copy.
Audience: whoever implements the follow-up plan.

## 1. Goal & Scope

Turn every hardcoded Chinese string in the merchant app into an ARB-keyed lookup so that:

- An English-speaking user running `flutter run` sees a complete English UI.
- A zh-CN user (OS locale OR in-app picker) sees the current Chinese copy unchanged.
- Contributors who add a new string can only do so by adding it to `app_en.arb` first.

**In scope**

- `flutter_localizations` + `intl` dependencies.
- `l10n.yaml` at `frontend/merchant/` pointing Flutter's built-in `gen-l10n` tool at `lib/l10n/`.
- Two ARB files: `lib/l10n/app_en.arb` (template / source of truth) and `lib/l10n/app_zh.arb` (Chinese translation).
- Generated `AppLocalizations` via `flutter gen-l10n` — wired into `MaterialApp.router` with `supportedLocales: [en, zh]` and `localizationsDelegates: [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate, GlobalWidgetsLocalizations.delegate]`.
- Every visible UI-chrome string (~200-300 unique after dedup) extracted from all 17 screens + shared widgets.
- Every call site updated: `Text('保存')` → `Text(AppLocalizations.of(context)!.commonSave)`.
- Smoke tests get a `TestHarness.withLocale(locale: Locale('zh'))` wrapper so their Chinese assertions keep passing. Existing 33 tests remain 33 — no net count change.
- `docs/i18n.md` updated: correct the "dot.notation" example to match Flutter's required Dart-identifier key style (camelCase with feature prefix).

**Out of scope (deferred)**

- Runtime in-app language picker — roadmap bullet; we wire supportedLocales but no UI toggle this batch. OS locale is honoured.
- Translation of sample data (`云间小厨·静安店`, `午市套餐 2025 春`, `宫保鸡丁`) — per `docs/i18n.md` §"What we will not do", these are seed data, not UI chrome, and stay in the source locale of the store / menu.
- Menu-content `dish_translations` — dynamic data, already plumbed via schema; translator UI is a separate spec.
- `MenuRay` brand name — `docs/i18n.md`: brand names not translated.
- Customer view locale negotiation — lives in the SvelteKit package (not yet started).
- Right-to-left audit — roadmap item, no RTL locale added this batch.
- Date / number / currency formatters with locale-aware output — current display has no date/number-heavy widgets; retrofit as screens that need it surface.
- Additional locales (Japanese, Spanish, etc.) — easy to add after this batch; not in scope.

## 2. Context

- Flutter SDK: 3.11.5. Native `flutter_localizations` + `intl` (0.19.0) + `gen-l10n` supported.
- `pubspec.yaml` has `flutter.generate: true` set? **No** — Task 0 adds it.
- App wiring: `lib/app.dart` is a lean `MaterialApp.router` call. Task 0 expands it to add `supportedLocales` + `localizationsDelegates`.
- Smoke tests: currently all assert Chinese strings directly (`'编辑菜品'`, `'下一步'`, `'保存'`). Reality: after migration, the default locale is EN and Chinese text no longer renders unless the widget tree is under a `Localizations` with `Locale('zh')`. Task 0's test-helper `withZhLocale(...)` patches every test with a one-line wrap.
- Key naming: `docs/i18n.md` currently proposes `dot.notation` (`auth.login.title`). Flutter's `gen-l10n` generates a Dart method per key — keys MUST be valid Dart identifiers (no dots). We switch to camelCase with a short feature prefix: `authLoginTitle`, `commonSave`, `editDishSaveButton`. `docs/i18n.md` is updated in this batch to reflect this.

## 3. Decisions

### 3.1 Flutter built-in `gen-l10n` over `flutter_intl` / `slang` / `easy_localization`

`gen-l10n` ships with Flutter, requires zero extra deps, supports placeholders + plurals + `@@metadata`, and has no IDE-specific code generator. All three alternatives add a third-party maintenance surface for marginal ergonomics.

Rejected:
- `flutter_intl` (Jetbrains IDE plugin): couples developer workflow to an IDE. Discussed in `docs/i18n.md` — we reverse that earlier preference in favour of the CLI-native path.
- `easy_localization`: runtime loading of JSON at app start; nice for asset-light apps but ship-path overhead we don't need.
- `slang`: Dart-only, type-safe, but requires adopting a second build-runner.

### 3.2 Key naming: `{feature}{Screen}{Element}` camelCase

Flutter's `gen-l10n` codegen emits one Dart method per key. Method names must be valid identifiers; dots break codegen. Examples:

| Domain | Key | English | Chinese |
|---|---|---|---|
| common | `commonSave` | Save | 保存 |
| common | `commonCancel` | Cancel | 取消 |
| common | `commonNext` | Next | 下一步 |
| common | `commonRetry` | Retry | 重试 |
| auth | `authLoginTitle` | Welcome | 登录 |
| auth | `authLoginPhoneHint` | Phone number | 手机号 |
| home | `homeFabNewMenu` | New menu | 新建菜单 |
| menuManage | `menuManageSoldOutSection` | Sold-out items | 售罄管理 |
| editDish | `editDishTitle` | Edit dish | 编辑菜品 |
| editDish | `editDishSpiceNone` | No spice | 不辣 |

Rules:
- Prefix = feature directory name in camelCase (`auth`, `home`, `menuManage`, `editDish`, `organize`, `preview`, `published`, `settings`, `storeManage`, `camera`, `selectPhotos`, `correctImage`, `processing`, `aiOptimize`, `selectTemplate`, `customTheme`, `statistics`) OR `common` for generic tokens reused across ≥3 screens.
- Screen name = optional second hump when the feature has multiple screens.
- Element name = final hump — button label, title, hint, section header, tooltip.
- Placeholders: arb entries use `{placeholder}` syntax; matching `@key: {placeholders: {count: {type: int}}}` block.

Rejected: dot notation (breaks gen-l10n). snake_case (idiomatic for ARB key style but dart methods would be `snake_case` — against `lint_prefer_camel_case_methods`).

`docs/i18n.md` will be updated with this convention in Task 8.

### 3.3 Seed data stays in its source language; UI chrome translates

Per existing `docs/i18n.md`, rule honoured:

- `_FakeStoreRepository().currentStore()` returning `'云间小厨·静安店'`, `menu.name` = `'午市套餐 2025 春'`, dish `'宫保鸡丁'` → **not** translated. These represent merchant-supplied data and the per-dish translation system handles them at the data layer.
- Button `'保存'`, AppBar title `'编辑菜品'`, section header `'售罄管理'`, FAB label `'新建菜单'` → **translated**. These are UI chrome shipped with the app.

Strings that sit in a placeholder / empty-state (`'暂无分类'`, `'未选择照片'`) are UI chrome and translate.

Brand names (`'MenuRay'`) are not translated (per i18n.md).

### 3.4 Default locale = English; current copy moves to `app_zh.arb`

`MaterialApp.supportedLocales: [Locale('en'), Locale('zh')]`. No `locale:` override — the framework matches OS locale against `supportedLocales` and falls back to the first entry (English).

A user on an OS set to `zh-CN` still gets Chinese; users on anything else get English. This matches `docs/i18n.md` §1.

### 3.5 Smoke tests pinned to `zh` locale (one test helper)

New helper `test/support/test_harness.dart`:

```dart
Widget withZhLocale(Widget child) => Localizations(
      locale: const Locale('zh'),
      delegates: AppLocalizations.localizationsDelegates,
      child: child,
    );
```

Every smoke test wraps its `home:` widget with `withZhLocale(...)`. No other change to test assertions. Alternative (translate every assert to English) doubles the diff on 17 tests without improving coverage.

### 3.6 One consolidated ARB per locale (no file-per-feature fragmentation)

Single `app_en.arb` + `app_zh.arb`. The 200-300 keys are readable as long as we group them via comments (`// === Common ===`, `// === Auth ===`, etc.). Fragmenting across `en_common.arb`, `en_auth.arb`, ... is not supported by `gen-l10n` without the (undocumented) `synthetic-package` stitching and breaks contributor flow.

## 4. Files touched

New:
- `frontend/merchant/l10n.yaml`
- `frontend/merchant/lib/l10n/app_en.arb`
- `frontend/merchant/lib/l10n/app_zh.arb`
- `frontend/merchant/test/support/test_harness.dart`

Modified (a lot):
- `frontend/merchant/pubspec.yaml` — deps + `generate: true`.
- `frontend/merchant/lib/app.dart` — supportedLocales + delegates.
- **Every** `lib/features/**/presentation/*_screen.dart` with Chinese strings (~15 files).
- Shared widgets with Chinese text (`shared/widgets/*.dart`) — ~3 files.
- **Every** `test/smoke/*_test.dart` wraps home: in `withZhLocale(...)` (~17 files).

Generated (not committed by dev but built at `flutter pub get`):
- `.dart_tool/flutter_gen/gen_l10n/app_localizations*.dart` — excluded from VCS.

## 5. Error handling

- Missing key at compile time: `AppLocalizations.of(context)!.someKey` fails if key absent in `app_en.arb` → caught by `flutter analyze`.
- Missing key in zh translation but present in en: `gen-l10n` warns; the framework falls back to the en value. Acceptable.
- Extra key in zh but not in en: `gen-l10n` warns and strips it. Acceptable.

## 6. Testing

- `flutter analyze` — clean.
- `flutter test` — **33/33** (identical count, rewrites only).
- `flutter build web --profile` — succeeds (no platform-specific l10n concerns).
- Manual E2E: boot with `--dart-define=SHOW_SEED_LOGIN=true` and OS set to `zh-CN` → unchanged visual output. Set OS to `en-US` → every label is English. (Web: browser language setting governs.)

## 7. Dependencies

```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: ^0.19.0
```

## 8. Risks

1. **Codegen in `.dart_tool/flutter_gen/`**: older Flutter versions placed generated files in `lib/l10n/` directly. Flutter 3.11 uses `.dart_tool/flutter_gen/` by default. Analyze pipeline picks it up via synthetic package import. No-op for our setup but flagged.
2. **ARB-file edit discipline**: a sloppy edit (missing comma, duplicate key) breaks codegen and `flutter analyze`. Task 0 adds a tiny CI-style check: `flutter gen-l10n` must succeed before every screen-extraction commit.
3. **Smoke-test coverage gap**: because we force `Locale('zh')` in tests, the English bundle never loads in CI. A broken English key only surfaces at `flutter build web`. Mitigation: add one "render with en locale" golden-ish smoke test at the end — assert the login title renders `'Welcome'` under `en`. Cheap insurance.
4. **Three months from now, someone adds a Chinese string in code without an ARB entry**: can't prevent with lint rules alone. Mitigation: add a note to `CONTRIBUTING.md` + a comment in every new screen file. Out of scope for the batch itself.

## 9. Follow-ups

- Runtime in-app language picker: `roadmap.md` already lists it as a P0 bullet. This batch leaves it unchecked.
- Translation completeness checker (CI gate): future tooling.
- A few screens (ai_optimize, select_template, custom_theme, statistics) use mock data and won't be wired to Supabase in P0 but still have Chinese UI chrome — they translate here.

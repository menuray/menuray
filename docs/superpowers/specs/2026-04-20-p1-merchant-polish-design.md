# P1 Merchant Polish — Design

Date: 2026-04-20
Scope: Three P1 follow-ups wrapped into a single batch — in-app language picker with `SharedPreferences` persistence, self-drawn rotate+crop UI for `correct_image`, and a bottom-sheet source picker on the home FAB.
Audience: whoever implements the follow-up plan.

## 1. Goal & Scope

**In scope**

- Settings screen gains a "Language" tile that opens a modal bottom sheet with three options (`Follow system` / `中文` / `English`). Selection persists to `SharedPreferences` under key `app_locale`, values `"system" | "zh" | "en"`.
- New `localeNotifierProvider` (Riverpod `StateNotifier<Locale?>`) loads from prefs at app start and feeds `MaterialApp.locale`. `null` = follow system.
- `correct_image_screen` replaces the animated placeholder with a functional editor over `photos.first`: rotate 90° CW button + a 4-corner-handle crop rectangle. On "Apply" the bytes are re-encoded via `package:image` and a new `XFile` replaces the first entry in the list carried to `processing`.
- Home FAB (`New menu`) `onTap` opens a modal bottom sheet with two `ListTile`s (`Take photo` → `/capture/camera`, `Choose from album` → `/capture/select`). No dependency added.
- Two new packages: `shared_preferences ^2.2` (persistence), `image ^4.2` (pure-Dart byte crop + rotate, web-compatible).
- Smoke-test updates for `settings`, `home`, `correct_image` per changed surface area. Test count stays at **34/34** (rewrites, not additions).
- `docs/roadmap.md` entries checked: "In-app language picker", "correct_image crop / rotate / perspective UI" (perspective part deferred, note it), "Home 相册 entry point".

**Out of scope**

- Perspective / skew correction (deferred until real OCR behaviour informs the ergonomics).
- Multi-photo editing inside `correct_image` (edit the first `XFile` only this iteration; others pass through unchanged — noted in the UI with a grey "only photo 1 is editable this release" hint, OR by simply showing only the first image). Multi-step prev/next deferred to P2.
- iOS/Android native crop UI — we stay cross-platform with the self-drawn editor.
- Saving corrected photos back to Supabase Storage mid-correct_image — the correction happens in memory before `processing` uploads. Re-upload / re-run loop is a future feature.
- Server-side image processing (rotation metadata, EXIF preservation).
- Per-field language packs (English AppLocalizations for the merchant **data** — that's per-dish translations, covered by separate feature).
- Dark mode / theme switching — same settings surface but a separate spec.

## 2. Decisions

### 2.1 Self-drawn cropper instead of `image_cropper`

The `image_cropper` package wraps native Android / iOS crop activities and a Flutter-based fallback via `image_cropper_for_web`. The web path is a second federated plugin whose build-system integration is exactly the kind of web-compile hazard we dodged for `camera` in Batch 2. Since we only need rotate-by-90° plus an axis-aligned crop rectangle, a pure-Dart implementation using `CustomPainter` + `GestureDetector` + `package:image` for the byte-level re-encode is ~300 lines and keeps the web bundle lean.

**Rejected:**
- `image_cropper` + conditional import — same platform-split ceremony as `camera_launcher`. Two shims is the threshold to promote into an ADR; three would be unpleasant. We dodge the precedent by staying DIY.
- `crop_your_image` / `crop_image` / other community packages — less-maintained, same web fragility.

### 2.2 `shared_preferences` over Riverpod-persistence middleware

Single-setting persistence — `SharedPreferences.getInstance()` read on startup, `setString` on change. No need for a reactive-persistence library. The `localeNotifierProvider` owns the single read during app bootstrap (a brief `CircularProgressIndicator` splash until the prefs hydrate, or — simpler — render MaterialApp with a placeholder locale and reconcile when prefs land; we pick the latter).

**Rejected:**
- `riverpod_annotation` + generator — overkill for one string.
- Hydrate via `ref.listen` inside every consumer — needless complexity.

### 2.3 `Locale?`-as-source-of-truth

`null` means "follow the OS locale" (MaterialApp's default behaviour). Non-null pins it. This is the stock Material behaviour — no wrapper types. The three UI options map to:

| UI | Stored | `localeNotifierProvider` value |
|---|---|---|
| Follow system | `"system"` | `null` |
| 中文 | `"zh"` | `Locale('zh')` |
| English | `"en"` | `Locale('en')` |

### 2.4 Home FAB becomes a source picker, not a SpeedDial

`showModalBottomSheet` with two `ListTile`s is a stock Material idiom for "choose source" — it's the same pattern iOS uses natively for Photos. A SpeedDial (FAB that expands to mini-FABs) would require a new package or self-drawn animation and adds motion complexity for two options.

**Rejected:**
- `flutter_speed_dial` package — new dep.
- Two separate FABs at opposite corners — awkward layout.
- Two buttons inside a Row replacing the FAB — loses the single-hand ergonomic.

### 2.5 Edit first photo only in this iteration

Most merchants photograph a single-page menu — one XFile is the common path. Editing multiple images inside `correct_image` requires prev/next navigation, cumulative state, undo/redo, and a richer spec. We crop/rotate `photos.first`, leave any additional images untouched, and move on. If merchants flag this as a gap, we spec multi-image editing in its own follow-up.

## 3. Architecture

### 3.1 `localeNotifierProvider`

`lib/features/settings/locale_provider.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier() : super(null) { _hydrate(); }

  static const _prefKey = 'app_locale';

  Future<void> _hydrate() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_prefKey) ?? 'system';
    state = _fromString(raw);
  }

  Future<void> set(Locale? locale) async {
    state = locale;
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefKey, locale == null ? 'system' : locale.languageCode);
  }

  static Locale? _fromString(String raw) =>
      raw == 'zh' ? const Locale('zh') : raw == 'en' ? const Locale('en') : null;
}

final localeNotifierProvider =
    StateNotifierProvider<LocaleNotifier, Locale?>((ref) => LocaleNotifier());
```

`lib/app.dart` gains `locale: ref.watch(localeNotifierProvider)` on the `MaterialApp.router`.

### 3.2 Language picker UI

New widget `_LanguagePickerSheet` inside `settings_screen.dart`. The `Language` tile replaces (or sits alongside — to decide in implementation) the current `Notification settings` row. Tile trailing shows the current selection text (`Follow system` / `中文` / `English`). Tap → `showModalBottomSheet<void>` with three `RadioListTile<String>` rows — tapping one dismisses the sheet and calls `ref.read(localeNotifierProvider.notifier).set(...)`.

### 3.3 Cropper — self-drawn over `CustomPainter`

`lib/features/capture/presentation/_image_editor.dart` (new, private to the feature):

- State: `_rotationTurns: int` (0..3), `_cropRect: Rect` in image-pixel coords normalised to `[0..1]`.
- Layout: `LayoutBuilder` gives the display size. Image painted via `Transform.rotate(angle: _rotationTurns * pi/2, child: Image.memory(bytes))`.
- Overlay: 4 corner `Positioned` widgets each wrapping a `GestureDetector(onPanUpdate: (d) => _updateCorner(...))`.
- Rectangle stroke + shaded outside area via a `CustomPaint` behind the handles.
- "Rotate 90°" button increments `_rotationTurns` mod 4 and resets `_cropRect` to full image.
- "Apply" button: decodes bytes with `img.decodeImage`, applies `img.copyRotate(times: _rotationTurns * 90)`, computes integer crop rect from normalised values, `img.copyCrop`, `img.encodeJpg(quality: 90)` → `XFile.fromData(Uint8List.fromList(result))`. The calling screen replaces `photos[0]` with this new `XFile`.

The editor returns a `Future<XFile?>` from a single `show(BuildContext, XFile)` entry point, similar to `showDialog`.

### 3.4 Home FAB source picker

In `home_screen.dart`, change FAB `onPressed` from a direct `context.go(AppRoutes.camera)` to an async helper that awaits `showModalBottomSheet<_Source>` with two `ListTile`s. Result dispatches to the appropriate route.

### 3.5 Touched files

**New:**
- `frontend/merchant/lib/features/settings/locale_provider.dart`
- `frontend/merchant/lib/features/capture/presentation/_image_editor.dart` (or a file under `capture/widgets/` — implementer's call)

**Modified:**
- `frontend/merchant/pubspec.yaml` (2 deps)
- `frontend/merchant/lib/app.dart` (locale wiring)
- `frontend/merchant/lib/features/store/presentation/settings_screen.dart` (Language tile + sheet)
- `frontend/merchant/lib/features/home/presentation/home_screen.dart` (FAB sheet)
- `frontend/merchant/lib/features/capture/presentation/correct_image_screen.dart` (replace placeholder w/ editor, wire Apply)
- `frontend/merchant/lib/l10n/app_en.arb` + `app_zh.arb` (a handful of new keys)
- Smoke tests: `settings_screen_smoke_test.dart`, `home_screen_smoke_test.dart`, `correct_image_screen_smoke_test.dart`
- `docs/roadmap.md` (check off)

## 4. Error handling

| Failure | UI |
|---|---|
| `SharedPreferences` unavailable (impossible on supported platforms; still defensive) | Fall back to `null` locale (follow system). |
| Cropper `decodeImage` returns null (unsupported format) | SnackBar `'无法处理该图片'` / `'Unable to process image'`; editor stays open so the user can tap "Back" and return without corrupting state. |
| Cropper byte-level crop takes >2s | Visual: button shows `CircularProgressIndicator` during the decode+crop+encode; button disabled. No cancellation this iteration. |
| User taps Apply without adjusting the rect → identity crop | Accepted. Produces a re-encoded copy of the original. No special case. |
| Home bottom sheet dismissed by swipe-down | No-op. |

## 5. Testing

- **settings smoke**: existing assertion + verify `Language` tile visible (`find.text('Language')` under EN / `'语言'` under zh). Do NOT actually tap and show the sheet — simulating the modal chain is shaky in widget tests.
- **home smoke**: existing `Menus / Data / Mine` assertions + verify FAB still renders. Don't simulate the bottom sheet.
- **correct_image smoke**: pass `photos: const []` → existing empty-state assertions hold (editor renders placeholder). Testing the cropper's byte path requires a real decodable image — skip in smoke; covered by manual E2E.
- Target: 34/34 unchanged.

## 6. Dependencies

```yaml
dependencies:
  shared_preferences: ^2.2.2
  image: ^4.2.0
```

Reasoning in PR:
- `shared_preferences`: stable, maintained by Flutter team, only way to persist the language selection without writing our own storage abstraction.
- `image`: pure-Dart image decode/encode/crop/rotate. Works on web (no native plugins). Mature, battle-tested.

## 7. Risks

1. **Web `XFile.fromData` + `Blob` lifecycle**: web XFile's `path` is a blob URL; when we pass the cropped XFile through `GoRouter.extra` and `processing_screen` reads it, the blob must still be alive. Mitigation: the blob belongs to the same page session; GoRouter navigation is same-SPA — no risk of revocation.
2. **Cropper byte operations on a 10 MB image on mobile web**: may take 500-1500ms and block the UI thread. Acceptable; we show a spinner. A second-release optimisation would be `compute()` isolation.
3. **Locale change mid-session**: `MaterialApp` rebuilds when locale changes, which re-localizes every widget. Some widgets that cache `AppLocalizations.of(context)` in `initState` (an anti-pattern we should not have) would miss the change. We scanned — the current codebase reads in `build()`, safe.
4. **Cropper on landscape vs portrait orientations**: aspect-ratio math needs care. Implementer must test both.
5. **`shared_preferences` on first launch**: returns null → we fall back to system. No splash needed.

## 8. Follow-ups

- `docs/roadmap.md` — check off:
  - In-app language picker
  - Home 相册 entry point
  - Rewrite the correct_image line: "P1 correct_image crop + rotate" done; "perspective correction" remains deferred.
- Future P2: multi-photo stepping inside correct_image, perspective correction, compute-isolated byte processing.

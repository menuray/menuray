# P1 Merchant Polish — Implementation Plan

> **For agentic workers:** one sequential subagent runs this plan. Tasks 0–2 are the foundation + 2 simpler screens (parallelisable if we wanted, but kept sequential for tidiness); Task 3 is the cropper and carries defer risk; Task 4 sweeps docs + tests.

**Goal:** Ship the P1 polish batch — language picker + Home FAB source sheet + correct_image rotate/crop.

**Architecture:** extends the existing Riverpod / ARB / GoRouter setup with one `StateNotifierProvider<Locale?>`, one self-drawn cropper widget, and two bottom-sheet entry points. No new repositories. Two new packages.

**Spec:** `docs/superpowers/specs/2026-04-20-p1-merchant-polish-design.md`

**Repo:** Flutter 3.11 app at `frontend/merchant/`. Branch `main`. Base: `bc8e08c`. Test count before: 34. Target: 34.

---

## Task 0: Add `shared_preferences` + `image` + `localeNotifierProvider` + app.dart wiring

**Files:**
- Modify: `frontend/merchant/pubspec.yaml`
- Create: `frontend/merchant/lib/features/settings/locale_provider.dart`
- Modify: `frontend/merchant/lib/app.dart`

### Steps

- [ ] **Step 0.1:** `pubspec.yaml` — add under `dependencies:` (after `intl`):
  ```yaml
    shared_preferences: ^2.2.2
    image: ^4.2.0
  ```
  Run `flutter pub get`.

- [ ] **Step 0.2:** Create `locale_provider.dart` with the `LocaleNotifier` + `localeNotifierProvider` from spec §3.1. Verbatim.

- [ ] **Step 0.3:** In `app.dart`, wire the locale:
  ```dart
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  // ...
  import 'features/settings/locale_provider.dart';
  // inside build:
  return MaterialApp.router(
    title: 'MenuRay',
    theme: AppTheme.light,
    routerConfig: ref.watch(routerProvider),
    debugShowCheckedModeBanner: false,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    locale: ref.watch(localeNotifierProvider),
  );
  ```

- [ ] **Step 0.4:** `flutter analyze` clean + `flutter test` 34/34 pass (no UI affected yet — just an unused provider + nullable locale that defaults to `null`).

- [ ] **Step 0.5:** Commit:
  ```
  feat(settings): add shared_preferences + image deps + localeNotifierProvider

  shared_preferences persists the user's language choice; image enables
  the correct_image cropper's pure-Dart byte rotate/crop. locale_provider
  loads from prefs at app start; null means follow-system.

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  ```

---

## Task 1: Language picker in settings

**Files:**
- Modify: `frontend/merchant/lib/features/store/presentation/settings_screen.dart`
- Modify: `frontend/merchant/lib/l10n/app_en.arb` + `app_zh.arb` (3 new keys)
- Modify: `frontend/merchant/test/smoke/settings_screen_smoke_test.dart`

### Steps

- [ ] **Step 1.1:** Add ARB keys:
  - `settingsLanguage` EN: "Language" / zh: "语言"
  - `settingsLanguageFollowSystem` EN: "Follow system" / zh: "跟随系统"
  - `settingsLanguageChinese` EN: "中文" / zh: "中文"  (Chinese name in both locales)
  - `settingsLanguageEnglish` EN: "English" / zh: "English"  (English name in both locales)

Regenerate with `flutter gen-l10n`.

- [ ] **Step 1.2:** Convert `SettingsScreen` to `ConsumerWidget` if not already (it is — Batch 1).

- [ ] **Step 1.3:** Add a `_SettingsTile` entry for Language under a reasonable group (alongside 通知设置 / Notifications). Trailing text reads the current selection via `ref.watch(localeNotifierProvider)` → `'Follow system'` if null, else `'中文'` / `'English'`.

- [ ] **Step 1.4:** `onTap` calls `_showLanguageSheet(context, ref)`:

```dart
Future<void> _showLanguageSheet(BuildContext context, WidgetRef ref) async {
  final current = ref.read(localeNotifierProvider);
  final l = AppLocalizations.of(context)!;
  await showModalBottomSheet<void>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<String?>(
            value: null, groupValue: current?.languageCode,
            title: Text(l.settingsLanguageFollowSystem),
            onChanged: (_) {
              ref.read(localeNotifierProvider.notifier).set(null);
              Navigator.pop(c);
            },
          ),
          RadioListTile<String?>(
            value: 'zh', groupValue: current?.languageCode,
            title: Text(l.settingsLanguageChinese),
            onChanged: (_) {
              ref.read(localeNotifierProvider.notifier).set(const Locale('zh'));
              Navigator.pop(c);
            },
          ),
          RadioListTile<String?>(
            value: 'en', groupValue: current?.languageCode,
            title: Text(l.settingsLanguageEnglish),
            onChanged: (_) {
              ref.read(localeNotifierProvider.notifier).set(const Locale('en'));
              Navigator.pop(c);
            },
          ),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 1.5:** Smoke test — add a single assertion: `expect(find.text('语言'), findsOneWidget);` (test runs under `zhMaterialApp`).

- [ ] **Step 1.6:** `flutter analyze` clean + settings smoke passes.

- [ ] **Step 1.7:** Commit:
  ```
  feat(settings): in-app language picker (Follow system / 中文 / English)

  New Language tile opens a modal bottom sheet; selection drives
  localeNotifierProvider and persists via shared_preferences.
  MaterialApp.locale is already wired — picking a value re-renders
  the app in that locale immediately.

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  ```

---

## Task 2: Home FAB source picker

**Files:**
- Modify: `frontend/merchant/lib/features/home/presentation/home_screen.dart`
- Modify: `frontend/merchant/lib/l10n/app_en.arb` + `app_zh.arb` (2 new keys)
- Modify: `frontend/merchant/test/smoke/home_screen_smoke_test.dart` (if needed — probably not)

### Steps

- [ ] **Step 2.1:** ARB keys:
  - `homeSourceSheetTitle` EN: "Add a menu" / zh: "新建菜单"
  - `homeSourceCamera` EN: "Take photo" / zh: "拍照"
  - `homeSourceGallery` EN: "Choose from album" / zh: "从相册选择"

- [ ] **Step 2.2:** In `home_screen.dart`, replace the FAB `onPressed`:

  ```dart
  floatingActionButton: FloatingActionButton.extended(
    onPressed: () => _showSourceSheet(context),
    ...
  ),

  Future<void> _showSourceSheet(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(l.homeSourceSheetTitle,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l.homeSourceCamera),
              onTap: () { Navigator.pop(c); context.go(AppRoutes.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l.homeSourceGallery),
              onTap: () { Navigator.pop(c); context.go(AppRoutes.selectPhotos); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
  ```

- [ ] **Step 2.3:** Existing home smoke test asserts the 'New menu' label — that still renders, no change needed. If it asserts the direct route navigation (it doesn't), that test would need adjustment.

- [ ] **Step 2.4:** Analyze + test clean.

- [ ] **Step 2.5:** Commit:
  ```
  feat(home): FAB bottom-sheet picker for photo source

  'New menu' FAB now opens a two-tile sheet (Take photo / Choose
  from album) and routes to /capture/camera or /capture/select
  respectively, closing the home 相册 entry UX gap carried over
  from Batch 2.

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  ```

---

## Task 3: correct_image — rotate + crop editor

Biggest task; defer-eligible if byte-path complexity blows up.

**Files:**
- Create: `frontend/merchant/lib/features/capture/presentation/_image_editor.dart` (or put it at the top of `correct_image_screen.dart` if the implementer prefers file locality)
- Modify: `frontend/merchant/lib/features/capture/presentation/correct_image_screen.dart`
- Modify: `frontend/merchant/lib/l10n/app_en.arb` + `app_zh.arb` (4 new keys)
- Modify: `frontend/merchant/test/smoke/correct_image_screen_smoke_test.dart` (keep empty-photo path, assertions unchanged)

### Steps

- [ ] **Step 3.1:** ARB keys:
  - `correctImageRotate` EN: "Rotate" / zh: "旋转"  — (replaces current static label if present)
  - `correctImageApply` EN: "Apply" / zh: "应用"
  - `correctImageDecodeFailed` EN: "Unable to process image" / zh: "无法处理该图片"
  - `correctImageProcessing` EN: "Processing…" / zh: "处理中…"

- [ ] **Step 3.2:** Implement the editor (`_image_editor.dart`):

```dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart' show XFile;

import '../../../l10n/app_localizations.dart';

class ImageEditor extends StatefulWidget {
  const ImageEditor({super.key, required this.photo, required this.onApply});
  final XFile photo;
  final void Function(XFile edited) onApply;
  @override State<ImageEditor> createState() => _ImageEditorState();
}

class _ImageEditorState extends State<ImageEditor> {
  Uint8List? _bytes;
  ui.Image? _uiImage;
  int _rotationTurns = 0;
  // Normalised (0..1) in the currently-displayed (possibly rotated) image space.
  Rect _cropNorm = const Rect.fromLTRB(0.05, 0.05, 0.95, 0.95);
  bool _processing = false;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final b = await widget.photo.readAsBytes();
    final codec = await ui.instantiateImageCodec(b);
    final frame = await codec.getNextFrame();
    if (!mounted) return;
    setState(() { _bytes = b; _uiImage = frame.image; });
  }

  void _rotate() => setState(() {
    _rotationTurns = (_rotationTurns + 1) % 4;
    _cropNorm = const Rect.fromLTRB(0.05, 0.05, 0.95, 0.95);
  });

  Future<void> _apply() async {
    if (_bytes == null) return;
    setState(() { _processing = true; _error = null; });
    try {
      final decoded = img.decodeImage(_bytes!);
      if (decoded == null) {
        setState(() { _error = AppLocalizations.of(context)!.correctImageDecodeFailed; _processing = false; });
        return;
      }
      var rotated = decoded;
      if (_rotationTurns != 0) {
        rotated = img.copyRotate(decoded, angle: _rotationTurns * 90);
      }
      final w = rotated.width, h = rotated.height;
      final left = (_cropNorm.left * w).round().clamp(0, w - 1);
      final top = (_cropNorm.top * h).round().clamp(0, h - 1);
      final right = (_cropNorm.right * w).round().clamp(left + 1, w);
      final bottom = (_cropNorm.bottom * h).round().clamp(top + 1, h);
      final cropped = img.copyCrop(rotated, x: left, y: top, width: right - left, height: bottom - top);
      final out = Uint8List.fromList(img.encodeJpg(cropped, quality: 90));
      final edited = XFile.fromData(out, mimeType: 'image/jpeg', name: 'edited.jpg');
      if (!mounted) return;
      widget.onApply(edited);
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _processing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (_uiImage == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return LayoutBuilder(builder: (ctx, cons) {
      final size = cons.biggest;
      return Stack(children: [
        Positioned.fill(child: Transform.rotate(
          angle: _rotationTurns * math.pi / 2,
          child: RawImage(image: _uiImage, fit: BoxFit.contain),
        )),
        // Crop rectangle painter + draggable corner handles:
        Positioned.fill(child: CustomPaint(painter: _CropOverlay(_cropNorm))),
        ..._buildHandles(size),
        // Toolbar:
        Positioned(
          bottom: 16, left: 16, right: 16,
          child: Row(children: [
            OutlinedButton.icon(
              onPressed: _processing ? null : _rotate,
              icon: const Icon(Icons.rotate_90_degrees_cw),
              label: Text(l.correctImageRotate),
            ),
            const Spacer(),
            if (_error != null) Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
            ElevatedButton(
              onPressed: _processing ? null : _apply,
              child: _processing
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 8),
                      Text(l.correctImageProcessing),
                    ])
                  : Text(l.correctImageApply),
            ),
          ]),
        ),
      ]);
    });
  }

  Iterable<Widget> _buildHandles(Size size) sync* {
    Widget handle(Alignment at, void Function(Offset) onDrag) {
      // Convert normalised to pixel, render a 32×32 draggable dot.
      const hs = 32.0;
      double dx, dy;
      switch (at) {
        case Alignment.topLeft: dx = _cropNorm.left * size.width; dy = _cropNorm.top * size.height;
        case Alignment.topRight: dx = _cropNorm.right * size.width; dy = _cropNorm.top * size.height;
        case Alignment.bottomLeft: dx = _cropNorm.left * size.width; dy = _cropNorm.bottom * size.height;
        case Alignment.bottomRight: dx = _cropNorm.right * size.width; dy = _cropNorm.bottom * size.height;
        default: dx = 0; dy = 0;
      }
      return Positioned(
        left: dx - hs / 2, top: dy - hs / 2,
        child: GestureDetector(
          onPanUpdate: (d) {
            final nx = (d.globalPosition.dx - Offset(0, 0).dx) / size.width;
            final ny = (d.globalPosition.dy - Offset(0, 0).dy) / size.height;
            onDrag(Offset(nx.clamp(0.0, 1.0), ny.clamp(0.0, 1.0)));
          },
          child: Container(
            width: hs, height: hs,
            decoration: BoxDecoration(
              color: Colors.white, shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 2),
            ),
          ),
        ),
      );
    }
    yield handle(Alignment.topLeft, (p) => setState(() {
      _cropNorm = Rect.fromLTRB(math.min(p.dx, _cropNorm.right - 0.1), math.min(p.dy, _cropNorm.bottom - 0.1), _cropNorm.right, _cropNorm.bottom);
    }));
    yield handle(Alignment.topRight, (p) => setState(() {
      _cropNorm = Rect.fromLTRB(_cropNorm.left, math.min(p.dy, _cropNorm.bottom - 0.1), math.max(p.dx, _cropNorm.left + 0.1), _cropNorm.bottom);
    }));
    yield handle(Alignment.bottomLeft, (p) => setState(() {
      _cropNorm = Rect.fromLTRB(math.min(p.dx, _cropNorm.right - 0.1), _cropNorm.top, _cropNorm.right, math.max(p.dy, _cropNorm.top + 0.1));
    }));
    yield handle(Alignment.bottomRight, (p) => setState(() {
      _cropNorm = Rect.fromLTRB(_cropNorm.left, _cropNorm.top, math.max(p.dx, _cropNorm.left + 0.1), math.max(p.dy, _cropNorm.top + 0.1));
    }));
  }
}

class _CropOverlay extends CustomPainter {
  _CropOverlay(this.rect);
  final Rect rect;
  @override
  void paint(Canvas canvas, Size size) {
    final shade = Paint()..color = const Color(0x99000000);
    final r = Rect.fromLTRB(rect.left * size.width, rect.top * size.height, rect.right * size.width, rect.bottom * size.height);
    // 4 rectangles outside crop:
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, r.top), shade);
    canvas.drawRect(Rect.fromLTRB(0, r.bottom, size.width, size.height), shade);
    canvas.drawRect(Rect.fromLTRB(0, r.top, r.left, r.bottom), shade);
    canvas.drawRect(Rect.fromLTRB(r.right, r.top, size.width, r.bottom), shade);
    final stroke = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawRect(r, stroke);
  }
  @override bool shouldRepaint(covariant _CropOverlay old) => old.rect != rect;
}
```

> **Implementer note:** the handle-drag math above uses `d.globalPosition` — that's fragile if the widget isn't at (0,0). Use `d.localPosition` via a `Builder` that captures a `GlobalKey` for the Stack, OR just pass `d.delta` and accumulate. Simplest robust approach: each handle's `onPanUpdate` uses `d.delta / size` additive updates against the current corner. Implementer picks — target is correct drag behaviour.

- [ ] **Step 3.3:** In `correct_image_screen.dart`, replace the `_ImageEditArea` widget's body:
  - If `widget.photos.isEmpty`: keep current placeholder.
  - Else: render `ImageEditor(photo: widget.photos.first, onApply: (edited) { ... })`.
- When `onApply` fires: replace `photos[0]` with the edited XFile via a local `_editedPhotos` state list, then advance to `processing` via the existing "下一步" button (Note: the existing button navigates to `/capture/processing` with extra=photos; pass `_editedPhotos ?? widget.photos` instead). OR auto-advance on Apply — implementer picks, but auto-advance is cleaner.

Recommend: on `onApply`, the editor is dismissed (or the screen updates local `_editedPhotos = [edited, ...widget.photos.skip(1)]`) and the existing "下一步" button passes `_editedPhotos`. This separates "edit" from "confirm the overall set".

- [ ] **Step 3.4:** If `package:image` decode or encode fails on the test platform (happens when pumping with a 0-byte mock), the smoke test must NOT trigger the editor's `_load()`. Keep the test's `photos: const []` empty-path assertion — that renders the placeholder only.

- [ ] **Step 3.5:** Analyze + tests pass.

- [ ] **Step 3.6:** Commit:
  ```
  feat(capture): correct_image — rotate 90° + rectangle crop editor

  Replaces the animated-handles placeholder on the first photo with
  a self-drawn editor backed by package:image for byte-level rotate +
  crop. Re-encoded XFile replaces photos[0]; other photos (rare)
  pass through. Perspective correction remains deferred.

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  ```

- [ ] **Step 3.7 (defer fallback):** If during implementation any of the following happens:
  - Web build fails because `image` pkg pulls in a platform-specific native plugin.
  - `XFile.fromData` blob lifecycle blocks reading in `processing_screen`.
  - Handle-drag math takes more than 30 min to stabilise and the UI is still janky.

  Then abandon Task 3, discard the work-in-progress files (do NOT commit the broken editor), revert any ARB keys added in Step 3.1, and skip to Task 4. Update Task 4's commit to note "cropper deferred — see spec §3.3 for technical reasons encountered".

---

## Task 4: Sweep + docs + roadmap + final commit

### Steps

- [ ] **Step 4.1:** `flutter analyze` clean.
- [ ] **Step 4.2:** `flutter test` 34/34 pass.
- [ ] **Step 4.3:** `flutter build web --profile --dart-define=SUPABASE_URL=http://127.0.0.1:54321` succeeds.
- [ ] **Step 4.4:** `docs/roadmap.md`:
  - Check `[x]` on `P0 In-app language picker`.
  - Check `[x]` on `P0 Home 相册 entry point`.
  - Replace `P1 correct_image crop / rotate / perspective UI` with:
    - `[x] **M** correct_image rotate + axis-aligned crop (perspective deferred)` — OR keep it unchecked if Task 3 was deferred, and add a bullet noting what landed vs not.
- [ ] **Step 4.5:** Commit (if anything changed):
  ```
  docs: P1 merchant-polish batch follow-ups

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  ```

---

## Self-review (post-plan)

- **Spec coverage:** §2.1 self-drawn cropper → Task 3. §2.2 shared_prefs persistence → Task 0. §2.3 Locale? source of truth → Task 0. §2.4 bottom-sheet source picker → Task 2. §2.5 first-photo-only → Task 3.
- **Type consistency:** `localeNotifierProvider` → `StateNotifierProvider<LocaleNotifier, Locale?>` referenced in Task 0, 1 identically. `XFile.fromData` is `image_picker` 1.x API — verified available since Task 0 already depended on `image_picker 1.2`.
- **Defer path documented:** Step 3.7 gives the controller a clean exit if the cropper blows up.
- **Test count delta:** 0.

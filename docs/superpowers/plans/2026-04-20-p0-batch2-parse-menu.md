# P0 Batch 2 — Parse-menu Flow & Real Camera Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Tasks 0–3 are the foundation (sequential); Tasks 4–7 are per-screen and parallelisable once foundation lands; Tasks 8–10 sweep the result.

**Goal:** Land `docs/superpowers/specs/2026-04-20-p0-batch2-parse-menu-design.md` — merchant can photograph a paper menu (native camera on mobile, file-picker on web) or pick from the gallery, and the app runs the real upload → parse_runs → /parse-menu → realtime stream → navigate-to-organize pipeline.

**Architecture:** ADR-017 unchanged; adds `CaptureRepository`, conditional-import `camera_launcher`, and a `StreamProvider.family` for parse_runs status.

**Tech stack:** Flutter 3.11.5 / Riverpod 2.6 / go_router 14.6 / supabase_flutter 2.12 / `image_picker ^1.1` / `camera ^0.11`.

**Spec:** `docs/superpowers/specs/2026-04-20-p0-batch2-parse-menu-design.md`

**Repo assumptions:**
- Flutter app root: `frontend/merchant/`. Flutter SDK: `/home/coder/flutter/bin/flutter`.
- Branch: `main`. Base commit: the Batch 2 spec commit (`4c5aac2` on current HEAD).
- Existing test count: **33**; target after this plan: **33** (rewrites, not additions).
- Backend: `supabase start` + `supabase db reset` produce the seed. Edge Function `parse-menu` already deployed locally.

---

## Task 0: Add packages + conditional-import scaffold

Foundation. Introduces `image_picker`, `camera`, and the platform-split `camera_launcher` shim.

**Files:**
- Modify: `frontend/merchant/pubspec.yaml`
- Create: `frontend/merchant/lib/features/capture/platform/camera_launcher.dart`
- Create: `frontend/merchant/lib/features/capture/platform/camera_launcher_io.dart`
- Create: `frontend/merchant/lib/features/capture/platform/camera_launcher_web.dart`

### Steps

- [ ] **Step 0.1:** In `pubspec.yaml`, under `dependencies:` (after `supabase_flutter`), add:

```yaml
  image_picker: ^1.1.2
  camera: ^0.11.0
```

- [ ] **Step 0.2:** Run `flutter pub get` from `frontend/merchant/`.

- [ ] **Step 0.3:** Create `platform/camera_launcher.dart` — conditional export:

```dart
// Platform-split entry point. Pulls the mobile impl on dart:io targets and the
// web impl on browser targets. Public interface is the free function below
// plus the exported ImagePicker XFile re-export from each impl.
export 'camera_launcher_stub.dart'
    if (dart.library.io) 'camera_launcher_io.dart'
    if (dart.library.html) 'camera_launcher_web.dart';
```

Also create `camera_launcher_stub.dart` with the public declarations and `UnsupportedError` bodies so `flutter analyze` can type-check without resolving the split.

```dart
// camera_launcher_stub.dart
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart' show XFile;
export 'package:image_picker/image_picker.dart' show XFile;

/// Builds the camera-preview surface for the current platform. [onCaptured]
/// is invoked once per shot; callers accumulate into their own List.
Widget buildCameraPreview({
  required void Function(XFile shot) onCaptured,
  required VoidCallback onPermissionDenied,
}) =>
    throw UnsupportedError('camera_launcher: no platform impl');
```

- [ ] **Step 0.4:** `camera_launcher_io.dart`:

```dart
import 'package:camera/camera.dart' as cam;
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart' show XFile;
export 'package:image_picker/image_picker.dart' show XFile;

class _CameraBody extends StatefulWidget {
  const _CameraBody({required this.onCaptured, required this.onDenied});
  final void Function(XFile) onCaptured;
  final VoidCallback onDenied;

  @override
  State<_CameraBody> createState() => _CameraBodyState();
}

class _CameraBodyState extends State<_CameraBody> {
  cam.CameraController? _controller;
  bool _initFailed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cams = await cam.availableCameras();
      if (cams.isEmpty) { setState(() => _initFailed = true); widget.onDenied(); return; }
      final ctrl = cam.CameraController(cams.first, cam.ResolutionPreset.high,
          enableAudio: false);
      await ctrl.initialize();
      if (!mounted) { await ctrl.dispose(); return; }
      setState(() => _controller = ctrl);
    } catch (_) {
      if (mounted) setState(() => _initFailed = true);
      widget.onDenied();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _shoot() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || c.value.isTakingPicture) return;
    final file = await c.takePicture(); // returns an XFile (camera pkg)
    widget.onCaptured(XFile(file.path));
  }

  @override
  Widget build(BuildContext context) {
    if (_initFailed) {
      return const Center(child: Text('相机不可用', style: TextStyle(color: Color(0xFFFFFFFF))));
    }
    final c = _controller;
    if (c == null) return const ColoredBox(color: Color(0xFF000000));
    return Stack(fit: StackFit.expand, children: [
      cam.CameraPreview(c),
      Align(
        alignment: const Alignment(0, 0.85),
        child: GestureDetector(
          onTap: _shoot,
          child: Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(color: Color(0xFFFFFFFF), shape: BoxShape.circle),
          ),
        ),
      ),
    ]);
  }
}

Widget buildCameraPreview({
  required void Function(XFile shot) onCaptured,
  required VoidCallback onPermissionDenied,
}) =>
    _CameraBody(onCaptured: onCaptured, onDenied: onPermissionDenied);
```

- [ ] **Step 0.5:** `camera_launcher_web.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
export 'package:image_picker/image_picker.dart' show XFile;

/// On web, `camera_screen`'s "shutter" actually opens the browser file picker
/// with camera hint. We render a full-bleed surface that dispatches the shot
/// on tap. Multi-shot accumulation happens in the calling screen.
Widget buildCameraPreview({
  required void Function(XFile shot) onCaptured,
  required VoidCallback onPermissionDenied,
}) {
  return _WebCaptureSurface(onCaptured: onCaptured);
}

class _WebCaptureSurface extends StatelessWidget {
  const _WebCaptureSurface({required this.onCaptured});
  final void Function(XFile) onCaptured;

  Future<void> _pick() async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
    if (x != null) onCaptured(x);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: _pick,
        child: Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_alt, size: 80, color: Colors.white),
              SizedBox(height: 16),
              Text('点击开始拍摄', style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
        ),
      );
}
```

- [ ] **Step 0.6:** Verify `flutter analyze` clean AND `flutter build web --profile --dart-define=SUPABASE_URL=http://127.0.0.1:54321` succeeds. If web build pulls the `camera` package and errors, add a `dependency_overrides` / `platforms:` block documented in a follow-up concern — **but don't change the solution**; escalate to the controller.

- [ ] **Step 0.7:** Commit:

```
chore(capture): add image_picker + camera + platform-split camera_launcher

Introduces the conditional-import shim that lets the web bundle avoid
the camera plugin while mobile gets a real CameraPreview. No screen
consumes these yet — Tasks 2–5 wire them in.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

---

## Task 1: `CaptureRepository` + providers

**Files:**
- Create: `frontend/merchant/lib/features/capture/capture_repository.dart`
- Create: `frontend/merchant/lib/features/capture/capture_providers.dart`

### Steps

- [ ] **Step 1.1:** `capture_repository.dart`:

```dart
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart' show XFile;
import 'package:supabase_flutter/supabase_flutter.dart';

enum ParseRunStatus { pending, ocr, structuring, succeeded, failed }

ParseRunStatus _statusFrom(String? v) => switch (v) {
      'ocr' => ParseRunStatus.ocr,
      'structuring' => ParseRunStatus.structuring,
      'succeeded' => ParseRunStatus.succeeded,
      'failed' => ParseRunStatus.failed,
      _ => ParseRunStatus.pending,
    };

class ParseRunSnapshot {
  final String id;
  final ParseRunStatus status;
  final String? menuId;
  final String? errorStage;
  final String? errorMessage;
  const ParseRunSnapshot({
    required this.id, required this.status,
    this.menuId, this.errorStage, this.errorMessage,
  });
  factory ParseRunSnapshot.fromRow(Map<String, dynamic> row) => ParseRunSnapshot(
        id: row['id'] as String,
        status: _statusFrom(row['status'] as String?),
        menuId: row['menu_id'] as String?,
        errorStage: row['error_stage'] as String?,
        errorMessage: row['error_message'] as String?,
      );
}

class CaptureRepository {
  CaptureRepository(this._client);
  final SupabaseClient _client;

  Future<String> uploadPhoto({
    required XFile file,
    required String storeId,
    required String runId,
    required int index,
  }) async {
    final path = '$storeId/$runId/$index.jpg';
    final bytes = await file.readAsBytes();
    await _client.storage
        .from('menu-photos')
        .uploadBinary(path, Uint8List.fromList(bytes),
            fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'));
    return path;
  }

  Future<void> createParseRun({
    required String id,
    required String storeId,
    required List<String> paths,
  }) async {
    await _client.from('parse_runs').insert({
      'id': id,
      'store_id': storeId,
      'source_photo_paths': paths,
      'status': 'pending',
    });
  }

  Future<ParseRunStatus> invokeParseMenu({required String runId}) async {
    final res = await _client.functions.invoke('parse-menu', body: {'run_id': runId});
    final status = (res.data as Map?)?['status'] as String?;
    return _statusFrom(status);
  }

  Stream<ParseRunSnapshot> streamParseRun({required String runId}) {
    return _client
        .from('parse_runs')
        .stream(primaryKey: ['id'])
        .eq('id', runId)
        .map((rows) {
      if (rows.isEmpty) {
        return ParseRunSnapshot(id: runId, status: ParseRunStatus.pending);
      }
      return ParseRunSnapshot.fromRow(rows.first);
    });
  }
}
```

- [ ] **Step 1.2:** `capture_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'capture_repository.dart';

final captureRepositoryProvider = Provider<CaptureRepository>(
  (ref) => CaptureRepository(ref.watch(supabaseClientProvider)),
);

final parseRunStreamProvider =
    StreamProvider.family<ParseRunSnapshot, String>((ref, runId) {
  ref.watch(authStateProvider);
  return ref.watch(captureRepositoryProvider).streamParseRun(runId: runId);
});
```

- [ ] **Step 1.3:** `flutter analyze` clean.

- [ ] **Step 1.4:** Commit:

```
feat(capture): add CaptureRepository + parseRunStreamProvider

Upload + parse_runs insert + edge-function invoke + realtime
stream for run status. Consumed by processing_screen in Task 5.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

---

## Task 2: `camera_screen` full rewrite

**Files:**
- Modify: `frontend/merchant/lib/features/capture/presentation/camera_screen.dart` (full rewrite)
- Modify: `frontend/merchant/test/smoke/camera_screen_smoke_test.dart`

### Steps

- [ ] **Step 2.1:** Replace `camera_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../theme/app_colors.dart';
import '../platform/camera_launcher.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});
  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  final List<XFile> _shots = [];

  void _onCaptured(XFile x) => setState(() => _shots.add(x));

  void _onDenied() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('相机不可用或权限被拒绝')),
    );
  }

  void _finish() {
    if (_shots.isEmpty) return;
    context.go(AppRoutes.correctImage, extra: List<XFile>.unmodifiable(_shots));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(children: [
          Positioned.fill(
            child: buildCameraPreview(
              onCaptured: _onCaptured,
              onPermissionDenied: _onDenied,
            ),
          ),
          Positioned(
            top: 8, left: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => context.go(AppRoutes.home),
            ),
          ),
          Positioned(
            bottom: 24, right: 16,
            child: ElevatedButton(
              onPressed: _shots.isEmpty ? null : _finish,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              child: Text('完成 (${_shots.length})'),
            ),
          ),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 2.2:** Smoke test rewrite — assert renders without throwing + the close button icon finds. Don't actually initialise a camera. Keep to 1 assertion.

- [ ] **Step 2.3:** Analyze clean + smoke passes.

- [ ] **Step 2.4:** Commit:

```
feat(capture): real camera_screen with platform-split preview

Mobile uses CameraController (via camera_launcher_io); web uses
browser file-picker (camera hint). Captured XFiles accumulate
locally; 完成 forwards the list to /capture/correct via extra.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

---

## Task 3: `select_photos` rewrite

**Files:**
- Modify: `frontend/merchant/lib/features/capture/presentation/select_photos_screen.dart` (full rewrite)
- Modify: `frontend/merchant/test/smoke/select_photos_screen_smoke_test.dart`

### Steps

- [ ] **Step 3.1:** Replace the screen. Instead of a hardcoded 4-column asset grid, it calls `ImagePicker().pickMultiImage()` on first build and renders the returned XFiles in the existing grid shape:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../router/app_router.dart';
import '../../../theme/app_colors.dart';

class SelectPhotosScreen extends StatefulWidget {
  const SelectPhotosScreen({super.key});
  @override
  State<SelectPhotosScreen> createState() => _SelectPhotosScreenState();
}

class _SelectPhotosScreenState extends State<SelectPhotosScreen> {
  List<XFile> _picked = const [];
  bool _pickerOpened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_pickerOpened) {
      _pickerOpened = true;
      Future.microtask(_openPicker);
    }
  }

  Future<void> _openPicker() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (!mounted) return;
    if (picked.isEmpty) {
      context.go(AppRoutes.home);
    } else {
      setState(() => _picked = picked);
    }
  }

  void _next() {
    if (_picked.isEmpty) return;
    context.go(AppRoutes.correctImage, extra: _picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        leading: TextButton(
          onPressed: () => context.go(AppRoutes.home),
          child: const Text('取消',
              style: TextStyle(color: Colors.black54, fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        leadingWidth: 72,
        title: const Text('选择菜单图片',
            style: TextStyle(color: AppColors.primaryDark, fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _picked.isEmpty ? null : _next,
            style: TextButton.styleFrom(
              backgroundColor: AppColors.primary, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: const StadiumBorder(),
            ),
            child: Text('下一步 (${_picked.length})'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _picked.isEmpty
          ? const Center(child: Text('未选择照片', style: TextStyle(color: Colors.black54)))
          : GridView.builder(
              padding: const EdgeInsets.all(4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, mainAxisSpacing: 4, crossAxisSpacing: 4,
              ),
              itemCount: _picked.length,
              itemBuilder: (ctx, i) => ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(_picked[i].path, fit: BoxFit.cover),
              ),
            ),
    );
  }
}
```

> **Web caveat:** `Image.network(xfile.path)` works because `pickMultiImage` returns blob URLs on web. On mobile it'd be file-path — use `Image.file(File(xfile.path))`. Simpler cross-platform: use `Image.memory(await xfile.readAsBytes())` via `FutureBuilder`, OR wrap in a helper. For this batch, use `FutureBuilder<Uint8List>` reading `readAsBytes()`.

Revised tile implementation:

```dart
Image _tile(XFile x) => ...  // replaced with:
FutureBuilder<Uint8List>(
  future: x.readAsBytes(),
  builder: (c, s) => s.hasData
      ? Image.memory(s.data!, fit: BoxFit.cover)
      : const ColoredBox(color: Color(0xFFE6E2DB)),
),
```

- [ ] **Step 3.2:** Smoke test — assert the title `选择菜单图片` renders. No picker launched (`pickMultiImage` only fires in a non-test harness; in test it will simply return an empty list and the didChangeDependencies guard prevents a re-open loop).

- [ ] **Step 3.3:** Analyze clean + smoke passes.

- [ ] **Step 3.4:** Commit:

```
feat(capture): real select_photos via ImagePicker.pickMultiImage

Opens the native gallery picker on mount; returned XFiles render in
the existing grid (readAsBytes + Image.memory for cross-platform).
下一步 forwards the list via GoRouter.extra.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

---

## Task 4: `correct_image` pass-through

**Files:**
- Modify: `frontend/merchant/lib/features/capture/presentation/correct_image_screen.dart` (targeted edits)
- Modify: `frontend/merchant/test/smoke/correct_image_screen_smoke_test.dart`

### Steps

- [ ] **Step 4.1:** Accept `List<XFile>` via constructor:

```dart
class CorrectImageScreen extends StatefulWidget {
  const CorrectImageScreen({super.key, this.photos = const []});
  final List<XFile> photos;
  ...
}
```

- [ ] **Step 4.2:** Router: add an `extra` read for the route:

```dart
GoRoute(
  path: AppRoutes.correctImage,
  builder: (c, s) => CorrectImageScreen(
    photos: (s.extra as List?)?.cast<XFile>() ?? const [],
  ),
),
```

(Modification in `app_router.dart`.)

- [ ] **Step 4.3:** In the screen body, swap the animated preview stub with the first XFile via `FutureBuilder<Uint8List>` from `widget.photos.first.readAsBytes()` when `photos.isNotEmpty`; fall back to the existing placeholder otherwise. The spinning `AnimationController` stays; it provides rotation handles UI that we can leave as cosmetic placeholders since crop/rotate is deferred.

- [ ] **Step 4.4:** Next button: `context.go(AppRoutes.processing, extra: widget.photos)`.

- [ ] **Step 4.5:** Smoke test passes a 0-item list; existing single-assertion bar holds.

- [ ] **Step 4.6:** Analyze clean + smoke passes.

- [ ] **Step 4.7:** Commit:

```
feat(capture): correct_image pass-through XFile list (crop/rotate deferred)

Screen accepts a List<XFile> constructor param carried from
camera_screen / select_photos; renders the first photo under the
existing rotation-handles visuals. 下一步 forwards to /capture/processing.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

---

## Task 5: `processing_screen` — upload + parse_runs + realtime

The orchestrator. Biggest task in the batch.

**Files:**
- Modify: `frontend/merchant/lib/features/capture/presentation/processing_screen.dart` (full rewrite)
- Modify: `frontend/merchant/test/smoke/processing_screen_smoke_test.dart`

### Steps

- [ ] **Step 5.1:** Full rewrite. Key elements:

```dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../../router/app_router.dart';
import '../../../theme/app_colors.dart';
import '../../home/home_providers.dart';
import '../capture_providers.dart';
import '../capture_repository.dart';

class ProcessingScreen extends ConsumerStatefulWidget {
  const ProcessingScreen({super.key, this.photos = const []});
  final List<XFile> photos;
  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

enum _LocalPhase { uploading, waiting, terminal }

class _ProcessingScreenState extends ConsumerState<ProcessingScreen> {
  _LocalPhase _phase = _LocalPhase.uploading;
  String? _runId;
  String? _error;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (widget.photos.isEmpty) {
      setState(() {
        _phase = _LocalPhase.terminal;
        _error = '未选择照片';
      });
      return;
    }
    try {
      final repo = ref.read(captureRepositoryProvider);
      final store = await ref.read(currentStoreProvider.future);
      final runId = _uuidV4();
      final paths = <String>[];
      for (var i = 0; i < widget.photos.length; i++) {
        paths.add(await repo.uploadPhoto(
          file: widget.photos[i], storeId: store.id, runId: runId, index: i,
        ));
      }
      await repo.createParseRun(id: runId, storeId: store.id, paths: paths);
      setState(() { _runId = runId; _phase = _LocalPhase.waiting; });
      // Fire-and-forget; realtime is the source of truth.
      unawaited(repo.invokeParseMenu(runId: runId));
    } catch (e) {
      if (mounted) setState(() { _phase = _LocalPhase.terminal; _error = '$e'; });
    }
  }

  Future<void> _retry() async {
    if (_runId == null) return;
    setState(() { _phase = _LocalPhase.waiting; _error = null; });
    try {
      await ref.read(captureRepositoryProvider).invokeParseMenu(runId: _runId!);
    } catch (e) {
      if (mounted) setState(() { _phase = _LocalPhase.terminal; _error = '$e'; });
    }
  }

  String _uuidV4() {
    // Minimal v4 generator — avoids adding the uuid package for one call-site.
    final r = Random.secure();
    String hex(int n) => r.nextInt(1 << 32).toRadixString(16).padLeft(8, '0').substring(0, n);
    return '${hex(8)}-${hex(4)}-4${hex(3)}-${(8 + r.nextInt(4)).toRadixString(16)}${hex(3)}-${hex(8)}${hex(4)}';
  }

  @override
  Widget build(BuildContext context) {
    // During "uploading" we can't watch the stream yet.
    if (_phase == _LocalPhase.uploading) {
      return _shell(child: const _Busy(label: '正在上传图片…'));
    }
    if (_phase == _LocalPhase.terminal && _runId == null) {
      return _shell(child: _Failed(message: _error ?? '未知错误', onRetry: _start));
    }
    final runId = _runId!;
    final asyncSnap = ref.watch(parseRunStreamProvider(runId));
    return asyncSnap.when(
      loading: () => _shell(child: const _Busy(label: '等待服务器响应…')),
      error: (e, _) => _shell(child: _Failed(message: '$e', onRetry: _retry)),
      data: (snap) {
        if (snap.status == ParseRunStatus.succeeded && snap.menuId != null && !_navigated) {
          _navigated = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go(AppRoutes.organizeFor(snap.menuId!));
          });
          return _shell(child: const _Busy(label: '跳转中…'));
        }
        if (snap.status == ParseRunStatus.failed) {
          return _shell(child: _Failed(
            message: snap.errorMessage ?? '解析失败',
            onRetry: _retry,
          ));
        }
        final label = switch (snap.status) {
          ParseRunStatus.ocr => '识别中…',
          ParseRunStatus.structuring => '整理菜单…',
          _ => '排队中…',
        };
        return _shell(child: _Busy(label: label));
      },
    );
  }

  Widget _shell({required Widget child}) => Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface, elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.primaryDark),
            onPressed: () => context.go(AppRoutes.home),
          ),
          title: const Text('导入菜单',
              style: TextStyle(color: AppColors.primaryDark, fontSize: 18, fontWeight: FontWeight.w600)),
        ),
        body: Center(child: child),
      );
}

class _Busy extends StatelessWidget { /* progress circle + label */ }
class _Failed extends StatelessWidget { /* icon + msg + retry button */ }
```

(`unawaited` requires `import 'dart:async';`.)

- [ ] **Step 5.2:** Update the router builder to pass `extra`:

```dart
GoRoute(
  path: AppRoutes.processing,
  builder: (c, s) => ProcessingScreen(
    photos: (s.extra as List?)?.cast<XFile>() ?? const [],
  ),
),
```

- [ ] **Step 5.3:** Smoke test rewrite: override `captureRepositoryProvider` with a `_FakeCaptureRepository` whose `streamParseRun` emits `[ParseRunSnapshot(pending), ParseRunSnapshot(succeeded, menuId: 'm1')]` via a `StreamController`. Pump frames until the "跳转中…" label shows OR the busy indicator renders — either is fine as the one assertion. The fake should also return a dummy store from the overridden `currentStoreProvider` (same `_FakeStoreRepository` pattern used in Batch 1).

- [ ] **Step 5.4:** Analyze clean + smoke passes.

- [ ] **Step 5.5:** Commit:

```
feat(capture): processing_screen runs real upload + parse_runs + realtime

Uploads each XFile to menu-photos, inserts parse_runs, fires the
parse-menu Edge Function, subscribes to realtime status updates via
parseRunStreamProvider. On succeeded → go /edit/organize/:menu_id;
on failed → inline banner with retry (idempotent re-invoke).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

---

## Task 6: Home entry points

**Files:**
- Modify: `frontend/merchant/lib/features/home/presentation/home_screen.dart` (two hunks)

### Steps

- [ ] **Step 6.1:** Locate the two capture-entry buttons (likely `_SnapPromo` or `_ActionChip` style widgets — `grep` for `拍照` and `相册` or for route constants). Wire their `onTap`/`onPressed` to:

```dart
() => context.go(AppRoutes.camera)     // 拍照
() => context.go(AppRoutes.selectPhotos) // 相册
```

If they already point at these routes (Batch 1 might have done this), Task 6 is a no-op — skip to Step 6.3.

- [ ] **Step 6.2:** Smoke test for home should still pass; if the button tap assertion breaks, update the smoke test accordingly (still one assertion).

- [ ] **Step 6.3:** Commit (if anything changed):

```
fix(nav): home 拍照/相册 entry points to capture flow
```

---

## Task 7: Full analyze + test sweep

### Steps

- [ ] **Step 7.1:** `flutter analyze` — clean.

- [ ] **Step 7.2:** `flutter test` — all 33 pass.

- [ ] **Step 7.3:** `flutter build web --profile --dart-define=SUPABASE_URL=http://127.0.0.1:54321` — **must succeed**. This is the critical check for Task 0's conditional import.

- [ ] **Step 7.4:** Any regression: fix + commit with message `chore(capture): fix analyze/test/build regressions after Batch 2`.

---

## Task 8: Docs update

**Files:**
- Modify: `docs/roadmap.md`
- Modify: `docs/architecture.md`

### Steps

- [ ] **Step 8.1:** In `roadmap.md`, check off these bullets under `### Merchant app — connect to real backend`:

```
- [x] **M** `parse-menu` realtime subscription from the capture/processing flow
- [x] **S** Real camera integration (`image_picker` / `camera`)
- [x] **M** Batch 2 (capture / correct_image / processing / select_photos) wired to Supabase + parse-menu realtime
```

Add a new follow-up under P1:

```
### P1 follow-ups carried from P0 Batch 2
- [ ] **S** iOS Info.plist + Android Manifest permission strings for camera + photo library
- [ ] **M** correct_image crop / rotate / perspective UI
```

- [ ] **Step 8.2:** In `architecture.md`: bump wired-screen count 9 → 13; document the `camera_launcher` conditional-import pattern under Merchant app.

- [ ] **Step 8.3:** Commit:

```
docs: mark P0 Batch 2 wire-up done (13/17 screens)
```

---

## Task 9: End-to-end manual verification

Manual — no commit.

### Steps

- [ ] **Step 9.1:** `supabase status` — API up at 54321. `supabase db reset` if the parse_runs table has stale rows.

- [ ] **Step 9.2:** Start the edge-function host: `supabase functions serve parse-menu --env-file ./supabase/.env` (in a separate terminal). Expect it to log requests per invocation.

- [ ] **Step 9.3:** Re-apply the `SHOW_SEED_LOGIN` patch (login_screen.dart:158). Build the web app:

```
flutter build web --profile \
  --dart-define=SUPABASE_URL=https://54321--main--apang--kuaifan.coder.dootask.com \
  --dart-define=SHOW_SEED_LOGIN=true
```

- [ ] **Step 9.4:** Serve `build/web` on port 8080; open the tunnel URL `https://8080--main--apang--kuaifan.coder.dootask.com/`.

- [ ] **Step 9.5:** Seed login → home. Tap 拍照 → camera screen. Take 1 shot (web: file picker opens). Tap 完成.

- [ ] **Step 9.6:** correct_image shows the captured photo → 下一步 → processing.

- [ ] **Step 9.7:** Watch processing: "正在上传图片…" → "识别中…" → "整理菜单…" → auto-navigate to `/edit/organize/<new_menu_id>`.

- [ ] **Step 9.8:** Verify the new menu exists in Supabase Studio (`menus` table, status draft, created_at just now; `parse_runs` row with status `succeeded` and `menu_id` populated).

- [ ] **Step 9.9:** Back to home → 相册 → pick 2-3 photos → repeat the flow end-to-end.

- [ ] **Step 9.10:** Error-path: stop `supabase functions serve`, retry the capture. Expect "解析失败" banner with 重试; restart the function host, tap 重试 → succeeds.

- [ ] **Step 9.11:** Revert the SHOW_SEED_LOGIN patch; confirm clean worktree.

- [ ] **Step 9.12:** Record in PR description.

---

## Self-review (post-plan)

- **Spec coverage:**
  - §1 in-scope → Tasks 0–6.
  - §3.1 conditional import → Task 0.
  - §3.2 XFile via extra → Task 5.2 + Task 4.2 (router builders).
  - §3.3 parse_runs lifecycle → Task 5.1.
  - §3.4 correct_image pass-through → Task 4.
  - §5 packages → Task 0.1.
  - §6 error handling → Task 3 empty-picker, Task 5 terminal branches.
  - §7 testing → Tasks 2.2, 3.2, 4.5, 5.3 + full sweep in Task 7.
  - §9 follow-ups → Task 8.
- **Placeholder scan:** `_Busy` / `_Failed` widget bodies are marked `/* progress circle + label */` and `/* icon + msg + retry button */` — trivial StatelessWidget implementations for the implementer; no ambiguity. `_uuidV4()` uses `dart:math` only — intentional (avoids a `uuid` package dep for one use-site).
- **Type consistency:** `ParseRunSnapshot` / `ParseRunStatus` signatures identical between Tasks 1.1 (definition) and 5.1 (usage). `CaptureRepository.*` method signatures identical between Tasks 1.1 and 5.1. `List<XFile>` type carried consistently across Tasks 2.1, 3.1, 4.1, 4.2, 5.1, 5.2.
- **Parallelisability:** Tasks 0, 1 sequential (foundation). Tasks 2, 3, 4, 5 parallelisable after Task 1 lands (they each own disjoint files). Task 6 last (depends on home screen unchanged between Batches 1 and 2; trivial). Tasks 7–9 sequential sweep.
- **Out-of-scope reaffirmation:** no permissions plist/manifest, no real OCR, no correct_image UI, no resume-upload, no cancel.

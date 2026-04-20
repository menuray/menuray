# P0 Batch 2 — Parse-menu Flow & Real Camera — Design

Date: 2026-04-20
Scope: Wire the merchant app's four capture-flow screens (camera / select_photos / correct_image / processing) to real device photo capture, Supabase Storage upload, the existing `parse-menu` Edge Function, and Postgres realtime — so a restaurant can actually photograph a paper menu and land on the editable draft within the app.
Audience: whoever implements the follow-up plan.

## 1. Goal & Scope

Merchant's capture loop becomes:

```
home ┬─ 拍照 → camera_screen   (native preview + shutter OR web file picker)
     └─ 相册 → select_photos   (gallery multi-pick)
                    │
                    ▼
          correct_image        (pass-through this batch)
                    │
                    ▼
          processing           (upload → parse_runs row → POST /parse-menu
                                → stream parse_runs.status → on succeeded
                                → go /edit/organize/:menu_id)
                    │
                    ▼
          organize_menu        (already wired in Batch 1)
```

**In scope**

- Real `image_picker` integration on every screen that currently renders asset-mock images.
- Real `camera` package on iOS / Android (live preview + shutter, multi-shot).
- Conditional-import shim so the `camera` package is never compiled into the web bundle.
- `CaptureRepository` (new): photo upload to `menu-photos/{storeId}/{runId}/{i}.jpg`, `parse_runs` row insert, `parse-menu` Edge Function invoke, and a realtime `Stream<ParseRunStatus>` for the currently-running row.
- `parseRunStreamProvider(runId)` — Riverpod `StreamProvider.family` wrapping the realtime channel.
- `processing_screen` becomes the orchestrator: takes `List<XFile>` via `go_router` `extra`, uploads, creates the run, triggers the function, subscribes to status, and navigates on success. Error paths show an inline error + retry.
- `correct_image` accepts and forwards `List<XFile>` through `extra` without UI changes.
- `select_photos` replaces its 12-asset mock grid with real `pickMultiImage` results.
- `camera_screen` full rewrite: native camera preview + shutter on mobile, file-picker (with `capture=environment` hint) on web.
- Smoke tests for all four screens; Fake `CaptureRepository` emits a canned status progression.
- Two new packages: `image_picker: ^1.x`, `camera: ^0.11.x`.

**Out of scope (deferred)**

- OCR / LLM provider wiring — `parse-menu` still runs with `MENURAY_*_PROVIDER=mock` (roadmap P0 AI services track).
- correct_image crop / rotate / perspective UI — P1 ergonomics pass; we forward the raw XFile through for Batch 2.
- Post-capture photo editing (markup, redaction, re-order within the grid).
- Retake / delete individual shots inside the `select_photos` grid — minimum viable is "re-open picker" if the user wants to change the selection.
- iOS `Info.plist` / Android `AndroidManifest.xml` permission strings — **listed as follow-up TODOs**; merchant currently runs via `flutter build web` in the dev loop so mobile permissions are not blocking this batch.
- Progress bar or per-photo upload UI — we render a single indeterminate spinner during the `processing` state transitions.
- Retry / resume of a partially-uploaded run.
- Cancel mid-processing (back-button behaviour during `processing` is a hard-navigation to home + orphan run is tolerated; status-cleanup is a future Edge Function cron).

## 2. Context

- `parse-menu` Edge Function contract (`backend/supabase/functions/parse-menu/README.md`): POST `{run_id}` with Bearer JWT → returns `{run_id, status}`. Idempotent on terminal states.
- `parse_runs` schema: `status text` with check-in `('pending','ocr','structuring','succeeded','failed')`; `source_photo_paths text[]`; `menu_id uuid` (nullable, set by the edge function).
- Storage: `menu-photos` bucket is **private**, file-size limit 10 MiB, MIME allow list `image/jpeg,image/png`. RLS (`20260420000003_storage_buckets.sql`) requires the first path segment to be a `store_id` the caller owns. We lay paths out as `{storeId}/{runId}/{index}.jpg`. RLS on `parse_runs` similarly filters by owned `store_id`.
- Realtime: supabase_flutter 2.5+ supports `.stream(primaryKey: ['id']).eq('id', runId)` returning `Stream<List<Map<String, dynamic>>>`. Single-row filter; we map to `ParseRunStatus` via an enum parser.
- ADR-017 pattern unchanged — repository + mapper + Riverpod. No new ADR required; we do document the conditional-import trick in `docs/architecture.md`.

## 3. Decisions

### 3.1 Conditional import for native camera on mobile

Dart's `if (dart.library.html)` export switch lets the web compiler pick an image-picker-only implementation while mobile gets the `camera` package. File layout:

```
lib/features/capture/platform/
├── camera_launcher.dart           // only re-exports, selected by dart.library.html
├── camera_launcher_io.dart        // uses package:camera
└── camera_launcher_web.dart       // uses package:image_picker
```

Public interface both files expose:

```dart
/// Returns a ready-to-use widget that owns camera-preview lifecycle and calls
/// [onCaptured] with each newly-taken XFile. On unsupported platforms, shows
/// the appropriate fallback UI.
Widget buildCameraPreview({required void Function(XFile shot) onCaptured});
```

The calling screen accumulates `XFile`s into a local `List<XFile>` and owns the "下一步" / "重拍" / "完成" buttons. This keeps platform-specific state contained in one shared interface and lets `camera_screen.dart` itself stay platform-agnostic.

Rejected:
- `kIsWeb ? pickerBody : cameraBody` at runtime — the `camera` import would still fail to compile on web because web-missing `dart:ui` calls inside the `camera` plugin break Dart Sound Null Safety on JS targets.
- Federated plugin approach where `camera_web` handles the web codepath: `camera_web` exists but has weaker browser support (no file-picker fallback on desktop) and requires HTTPS in all browsers — unfavourable for the coder-tunnel dev URL.

### 3.2 XFile list traverses the flow via `GoRouter.extra`

`context.go(AppRoutes.correctImage, extra: xfiles)` (and similar). Screens read `GoRouterState.of(context).extra as List<XFile>`. We **do not** persist the list to Riverpod — it's an in-flight, in-memory handoff and survives only the active navigation session. A hard refresh loses the pending shots, which is fine because the pipeline hasn't persisted anything yet.

Rejected:
- Riverpod `capturedPhotosProvider = StateProvider<List<XFile>>`: persists across the flow but encourages callers to trust it after the upload is done, which invites dangling references to now-invalid temp files.
- URL-encoded file paths: XFiles are in-memory on web; there's no shareable URI.

### 3.3 `parse_runs` lifecycle owned by the client, realtime for status

Sequence in `processing_screen`:

1. `pickedFiles = state.extra as List<XFile>` (empty list → kick back with SnackBar).
2. `storeId = await currentStoreProvider.future`.
3. For each `(xfile, index)`: upload bytes to `menu-photos/{storeId}/{runId}/{index}.jpg` via `StorageApi.uploadBinary`. `runId` is generated client-side as a UUID v4 using `dart:math` (there's no server-side insert-and-return because path needs the id upfront).
4. `INSERT INTO parse_runs (id, store_id, source_photo_paths, status) VALUES (?, ?, ?, 'pending')` via PostgREST.
5. POST `/functions/v1/parse-menu` with `{run_id}`.
6. `ref.watch(parseRunStreamProvider(runId))` — realtime subscription on `parse_runs.id = runId`.
7. On `succeeded`: read `run.menu_id` from the last realtime frame, `context.go(AppRoutes.organizeFor(menu_id))`.
8. On `failed`: show `error_message` inline with a 重试 button that **re-POSTs** the function (idempotent); does not re-upload.

Rejected:
- Server-side `INSERT + trigger parse-menu` chain — fewer round trips but requires a new trigger, cross-schema privileges, and couples upload failure to parse_runs creation.
- Polling instead of realtime — simple but adds a poll loop and 1-3s delay to a <30s pipeline. Realtime is already used nowhere else; landing it here sets up Batch 3 / future screens.

### 3.4 `correct_image` as pass-through

Constructor accepts `final List<XFile> photos`; body renders the first image full-bleed with next / back buttons. No crop, no rotate, no perspective handles. Rationale: correcting a paper-menu photo is a UX investment (edges detection, undo stack, zoom gestures) worth its own spec; the parse-menu mock + real providers both cope with un-corrected photos, so pass-through unblocks the E2E loop.

Rejected:
- Removing the screen from the flow: leaves four route constants orphaned and forces a spec update to `app_router.dart` that we'd have to re-do when the real correct UI lands.

## 4. Architecture

### 4.1 New repository

`lib/features/capture/capture_repository.dart`:

```dart
enum ParseRunStatus { pending, ocr, structuring, succeeded, failed }

class ParseRunSnapshot {
  final String id;
  final ParseRunStatus status;
  final String? menuId;
  final String? errorStage;     // 'ocr' | 'structure' | null
  final String? errorMessage;
  /* ... */
}

class CaptureRepository {
  CaptureRepository(this._client);
  final SupabaseClient _client;

  /// Returns the storage path on success.
  Future<String> uploadPhoto({
    required XFile file,
    required String storeId,
    required String runId,
    required int index,
  });

  Future<void> createParseRun({
    required String id,
    required String storeId,
    required List<String> paths,
  });

  /// Fire the edge function. Returns the terminal or in-flight status the
  /// function itself echoed back — the UI relies on the realtime stream for
  /// intermediate states.
  Future<ParseRunStatus> invokeParseMenu({required String runId});

  Stream<ParseRunSnapshot> streamParseRun({required String runId});
}
```

### 4.2 Providers

`lib/features/capture/capture_providers.dart`:

```dart
final captureRepositoryProvider = Provider<CaptureRepository>(
  (ref) => CaptureRepository(ref.watch(supabaseClientProvider)),
);

final parseRunStreamProvider =
    StreamProvider.family<ParseRunSnapshot, String>((ref, runId) {
  ref.watch(authStateProvider);
  return ref.watch(captureRepositoryProvider).streamParseRun(runId: runId);
});
```

### 4.3 Screen-by-screen

| Screen | Class | Consumes | Produces | Extras in/out |
|---|---|---|---|---|
| `camera_screen` | `ConsumerStatefulWidget` (uses `buildCameraPreview`) | — | `List<XFile>` | out via `go(correctImage, extra: list)` |
| `select_photos` | `ConsumerStatefulWidget` (calls `pickMultiImage` onInit) | — | `List<XFile>` | same |
| `correct_image` | `StatelessWidget` (stateless pass-through) | — | forwards | in from extra, out to `processing` |
| `processing` | `ConsumerStatefulWidget` | `captureRepositoryProvider`, `currentStoreProvider`, `parseRunStreamProvider` | runs pipeline | in from extra |

`processing_screen` state machine local to the widget:

```
Idle → Uploading → Pending → Ocr → Structuring → Succeeded → (navigate)
                                              ↘
                                             Failed → (retry button)
```

"Uploading" is the local client phase; after `createParseRun` returns, the screen moves into watching the realtime stream and local state mirrors the server's `ParseRunStatus`.

### 4.4 Route changes

Four routes keep their current paths (no id, matches today's constants). The four `GoRoute` builders change to read `List<XFile>?` from `state.extra`:

```dart
GoRoute(
  path: AppRoutes.correctImage,
  builder: (c, s) => CorrectImageScreen(
    photos: (s.extra as List?)?.cast<XFile>() ?? const [],
  ),
),
```

Same shape for `processing`. `camera_screen` + `select_photos` take no extra in but populate on exit.

### 4.5 Home entry points

`home_screen` top "snap" area currently has two affordances (拍照, 相册). Already wired in Batch 1? No — they're placeholders. This batch binds them:

- 拍照 → `context.go(AppRoutes.camera)`.
- 相册 → `context.go(AppRoutes.selectPhotos)`.

## 5. Dependencies (new packages)

```yaml
dependencies:
  image_picker: ^1.1.2   # both platforms
  camera: ^0.11.0        # mobile only — never imported on web path
```

`camera` gets past web compile because conditional-import hides its symbols from the web compilation unit. Confirmed with a dummy-build check in the plan.

## 6. Error handling

| Failure | UI |
|---|---|
| `pickMultiImage` cancelled / returns empty | Stay on current screen; toast "未选择照片". |
| Camera permission denied (mobile) | Fallback body with `'需要相机权限'` text + a 打开设置 button (calls `camera`'s default error-path; no `permission_handler` dep this batch). |
| Upload fails on photo N | Abort, roll back uploads 0..N-1, show banner + 重试 button. |
| `invokeParseMenu` fails (network / 5xx) | Retain run row, show banner + 重试. |
| `parse_runs.status = failed` | Show `error_message` + 重试; pressing 重试 invokes `invokeParseMenu` again (idempotent). |
| Realtime disconnect | Stream auto-reconnects via `supabase_flutter`; no UI signal. |

## 7. Testing

- **Smoke tests (4 screens):** `ProviderScope` overrides with a `_FakeCaptureRepository`. For `processing`, the fake returns a canned in-memory controller that emits `pending → ocr → succeeded` (with `menuId: 'm1'`) and asserts the screen would call `context.go(...)` — we assert via finder once the succeeded-state body renders.
- **No integration test** on realtime / supabase — out of scope; manual E2E with a live stack.
- `flutter analyze` clean; `flutter test` holds at **33 + 0 net** (rewrites only).
- Existing smoke tests for camera / select_photos / correct_image / processing are all one-liners (render title); rewrites keep the one-assertion bar.

## 8. Risks / open questions

1. **`camera` plugin web compile**: historically `camera` has been a `package:camera` + `package:camera_web` federated setup; if the web target still tries to pull `camera_web` via the package's Flutter plugin metadata, the conditional-import trick is not enough. Mitigation: explicitly declare `camera` in `pubspec.yaml` under a mobile-only `platforms:` block if `flutter pub get` still emits web glue. Plan's Task 0 verifies with `flutter build web`.
2. **XFile from `image_picker` on web is a blob URL**, not a file path. `SupabaseClient.storage.from().uploadBinary(path, await xfile.readAsBytes())` bypasses this — Task 1 uses `readAsBytes` universally.
3. **Realtime with RLS**: Supabase realtime honours RLS on Postgres changes. Our `parse_runs` owner policy is `store_id IN (SELECT ... WHERE owner_id = auth.uid())` — subscription will receive updates for the caller's runs only. No extra channel-auth needed.
4. **Edge Function runtime**: the local `supabase functions serve` host is separate from the JavaScript bundle on the tunnel. Dev test must hit `http://127.0.0.1:54321/functions/v1/parse-menu` from the Flutter client, which means the dart-define `SUPABASE_URL` must resolve to localhost (not the tunnel URL) when verifying locally, OR use the tunnel URL throughout. Plan's Task 9 uses the tunnel URL end-to-end.
5. **Mobile permission strings**: iOS/Android permission keys are a follow-up — Batch 2 targets the web dev loop and mobile sanity requires permission plumbing that isn't wired in this batch. Flagged in the roadmap update.

## 9. Follow-ups

- `docs/roadmap.md`: check off `parse-menu realtime subscription from the capture/processing flow` + `Real camera integration (image_picker / camera)`.
- `docs/architecture.md`: bump wired-screen count from 9 → 13, document the `camera_launcher` conditional-import pattern.
- New ADR? **No** — the conditional-import pattern is documented in architecture.md. If we adopt it in a second place, promote to ADR-018.

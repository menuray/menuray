# Session 6 — QR Generation + Customer Dispatcher Refactor — Implementation Plan

> **For agentic workers:** Use `superpowers:subagent-driven-development` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax. Spec: `docs/superpowers/specs/2026-04-25-qr-and-dispatcher-design.md`.

**Goal:** Ship Session 6 — replace the placeholder QR painter on `PublishedScreen` with a real `qr_flutter`-driven QR encoding the live customer URL; add a brand-styled "share QR PNG" flow + copy-link affordance; refactor the customer-view template dispatcher from `if/else` to a `Record<TemplateId, ComponentType>` registry so designer-delivered Bistro / Izakaya / Street drop in as one file each.

**Architecture:** Single screen on the merchant app gains real-QR rendering + an off-screen `RepaintBoundary` that captures a brand-styled card to PNG via `boundary.toImage().toByteData(format: png)`, written to `path_provider`'s temp dir, shared via `SharePlus.instance.share`. Customer host pulled out into compile-time `String.fromEnvironment('MENURAY_CUSTOMER_HOST', defaultValue: 'menu.menuray.com')` so dev can override. Customer dispatcher becomes a registry — five template ids map to two real layouts plus three Minimal fallbacks, swap-in-place when designer ships.

**Tech Stack:** Flutter 3 stable + Riverpod + `qr_flutter ^4.1.0` (new) + `share_plus` (already) + `path_provider` (already) + Material 3; SvelteKit 2 + Svelte 5 runes (existing).

---

## File structure

**New (merchant flutter):**

```
frontend/merchant/lib/config/app_config.dart
frontend/merchant/lib/features/publish/data/qr_export_service.dart
frontend/merchant/test/unit/app_config_test.dart
frontend/merchant/test/unit/qr_export_service_test.dart
frontend/merchant/test/smoke/published_screen_test.dart        (new — none today)
```

**New (customer sveltekit):**

```
frontend/customer/tests/unit/templateRegistry.test.ts
```

**Modified (merchant flutter):**

```
frontend/merchant/pubspec.yaml                                  (+ qr_flutter ^4.1.0)
frontend/merchant/lib/features/publish/presentation/published_screen.dart   (full rewrite of QR card + buttons)
frontend/merchant/lib/features/store/presentation/team_management_screen.dart  (use AppConfig)
frontend/merchant/lib/l10n/app_en.arb                           (+ 6 keys)
frontend/merchant/lib/l10n/app_zh.arb                           (+ 6 keys)
```

**Modified (customer sveltekit):**

```
frontend/customer/src/routes/[slug]/+page.svelte               (registry dispatcher)
```

**Modified (docs):**

```
docs/decisions.md                                               (+ ADR-022)
docs/architecture.md                                            (+ small paragraph)
docs/roadmap.md                                                 (flip QR row, reframe templates row)
CLAUDE.md                                                       (Active work, Session 6 block)
```

Total: 6 new + 9 modified.

---

## Phase 1 — Foundations: pubspec, AppConfig, i18n keys

> **Subagent profile:** haiku — mechanical edits.

- [ ] **Task 1.1** — Add `qr_flutter: ^4.1.0` to `frontend/merchant/pubspec.yaml` under `dependencies:` (alphabetical order with the existing block). Run `flutter pub get` from `frontend/merchant/`. Verify the lockfile updates and no dep conflicts surface.
- [ ] **Task 1.2** — Create `frontend/merchant/lib/config/app_config.dart`:
  ```dart
  class AppConfig {
    const AppConfig._();
    static const String customerHost = String.fromEnvironment(
      'MENURAY_CUSTOMER_HOST',
      defaultValue: 'menu.menuray.com',
    );
    static String customerMenuUrl(String slug) => 'https://$customerHost/$slug';
    static String customerInviteUrl(String token) => 'https://$customerHost/accept-invite?token=$token';
  }
  ```
  Add a one-line doc comment explaining `String.fromEnvironment` is compile-time and overrides are passed via `--dart-define=MENURAY_CUSTOMER_HOST=…` at build/run.
- [ ] **Task 1.3** — Add 6 keys to `frontend/merchant/lib/l10n/app_en.arb`:
  - `publishedShareQr` → "Share QR image"
  - `publishedShareQrSubject` → "My MenuRay menu — {storeName}" (with `placeholders: {storeName: {type: String}}`)
  - `publishedCopyLink` → "Copy link"
  - `publishedLinkCopied` → "Link copied to clipboard"
  - `publishedScanCaption` → "Scan to view menu"
  - `publishedDone` → "Done"
- [ ] **Task 1.4** — Mirror the 6 keys in `frontend/merchant/lib/l10n/app_zh.arb` with the zh translations from spec §4.8.
- [ ] **Task 1.5** — Run `flutter gen-l10n` from `frontend/merchant/` (or rely on the build_runner / auto-gen) — verify `lib/l10n/app_localizations.dart` regenerates with the 6 new accessors. If the project doesn't auto-gen, no manual edit needed (the build hook runs on next `flutter test`/`flutter run`).
- [ ] **Task 1.6** — `flutter analyze` clean. No tests yet — these are foundations.

**Acceptance:** `flutter pub get` succeeds; `flutter analyze` clean; `app_en.arb` + `app_zh.arb` parseable JSON with 6 new keys each.

---

## Phase 2 — Real QR widget on PublishedScreen

> **Subagent profile:** sonnet — judgment around layout / state.

- [ ] **Task 2.1** — In `frontend/merchant/lib/features/publish/presentation/published_screen.dart`:
  - Import `package:qr_flutter/qr_flutter.dart`.
  - Import `package:menuray_merchant/config/app_config.dart`.
  - Replace `_QrCard`'s body — delete the `CustomPaint(painter: _QrPainter(...))` block and the entire `_QrPainter` class at the bottom of the file. Replace with `QrImageView`:
    ```dart
    QrImageView(
      data: AppConfig.customerMenuUrl(menu.slug),
      version: QrVersions.auto,
      size: 220,
      backgroundColor: Colors.white,
      errorCorrectionLevel: QrErrorCorrectLevel.H,
      embeddedImage: store.logoUrl != null && store.logoUrl!.isNotEmpty
          ? NetworkImage(store.logoUrl!)
          : null,
      embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(48, 48)),
    )
    ```
  - Keep the existing brand frame (rounded card, beige bg, sticker-style header) around the new `QrImageView`.
  - Update the URL footer text under the QR (the line that previously displayed the hardcoded URL) to use `AppConfig.customerMenuUrl(menu.slug)`.
- [ ] **Task 2.2** — `_QrCard` accepts `(menu, store, isDraft)`. Confirm the parent widget passes `store` (likely from a Riverpod `activeStoreProvider` or a passed `Store` model). If today's signature only passes `(url, isDraft)`, refactor the call site to pass `menu` + `store` (or fetch them inside via `ref.watch(...)`). Search for `_QrCard(` in the file and adjust.
- [ ] **Task 2.3** — `flutter analyze` clean. The screen now compiles with the real QR.

**Acceptance:** `flutter analyze` passes; `flutter run` of the merchant app reaches PublishedScreen and the QR is a black-and-white pattern (real, scannable) instead of grey noise. Manual scan with iOS Camera opens the customer URL.

---

## Phase 3 — QR PNG export + share + copy-link

> **Subagent profile:** sonnet — RepaintBoundary + share_plus orchestration is judgment-heavy.

- [ ] **Task 3.1** — Create `frontend/merchant/lib/features/publish/data/qr_export_service.dart`:
  ```dart
  import 'dart:io';
  import 'dart:typed_data';
  import 'dart:ui' as ui;
  import 'package:flutter/rendering.dart';
  import 'package:flutter/widgets.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:path_provider/path_provider.dart';

  class QrExportService {
    Future<File> renderToPng({
      required GlobalKey boundaryKey,
      required String menuId,
      double pixelRatio = 3.0,
    }) async {
      final ctx = boundaryKey.currentContext;
      if (ctx == null) {
        throw StateError('QR boundary not mounted yet');
      }
      final boundary = ctx.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('toByteData returned null');
      }
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/menuray-$menuId-qr.png');
      await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
      return file;
    }
  }

  final qrExportServiceProvider = Provider<QrExportService>((_) => QrExportService());
  ```
- [ ] **Task 3.2** — In `published_screen.dart`, add an `Offstage(offstage: true, child: RepaintBoundary(key: _shareKey, child: _QrShareCard(...)))` to the widget tree, OUTSIDE the visible body but inside the same `Scaffold` body Column (so it lays out + paints). `_QrShareCard` is a private widget defined at the bottom of the file. Visual structure per spec §4.4.
  - `_QrShareCard` parameters: `Store store`, `Menu menu`, `BuildContext context` (for AppLocalizations).
  - Use `SizedBox(width: 600)` to fix the capture width regardless of screen size.
  - Wrap content in a `Container` with the brand `surface` background and 24 px rounded corners.
  - Use a `QrImageView` 460×460 (no embedded logo here — the share artifact has the logo above the QR as a clear avatar, which scans more reliably).
  - `Inter` font is loaded via `google_fonts` in the existing theme; `Theme.of(context).textTheme` styles already match.
- [ ] **Task 3.3** — Add a state field `final GlobalKey _shareKey = GlobalKey()` to the StatefulWidget hosting PublishedScreen body. If the screen is currently a `StatelessWidget` or `ConsumerWidget`, convert to `ConsumerStatefulWidget` per the CLAUDE.md StatefulWidget rule (we now own a `GlobalKey` — qualifies as state).
- [ ] **Task 3.4** — Add a `_handleShareQr` method that calls `qrExportServiceProvider`'s `renderToPng`, then `await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: t.publishedShareQrSubject(store.name)))`. Wrap in try/catch — on error, show `SnackBar` with a generic localized "share failed" (reuse existing key or add one — keep it simple, log to console).
- [ ] **Task 3.5** — Add a `_handleCopyLink` method that calls `Clipboard.setData(ClipboardData(text: AppConfig.customerMenuUrl(menu.slug)))` then `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.publishedLinkCopied)))`.
- [ ] **Task 3.6** — Replace the existing single bottom-bar CTA with a stacked button group:
  ```dart
  Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _handleShareQr,
              icon: const Icon(Icons.ios_share),
              label: Text(t.publishedShareQr),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _handleCopyLink,
              icon: const Icon(Icons.link),
              label: Text(t.publishedCopyLink),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => context.go(AppRoutes.home),
            child: Text(t.publishedDone),
          ),
        ],
      ),
    ),
  )
  ```
  (Keep using existing AppRoutes for the home destination — search the file for the current "Done" CTA's `context.go(...)` target.)
- [ ] **Task 3.7** — `flutter analyze` clean.

**Acceptance:** `flutter analyze` clean; manual run shows three buttons; "Copy link" shows a snackbar and the URL ends up in the clipboard; "Share QR image" opens the system share sheet with a PNG attachment showing the brand-frame card.

---

## Phase 4 — invite-link refactor + customer dispatcher registry

> **Subagent profile:** haiku for invite-link (mechanical), sonnet for dispatcher (judgment).

- [ ] **Task 4.1** — In `frontend/merchant/lib/features/store/presentation/team_management_screen.dart`, find the hardcoded `https://menu.menuray.com/...` invite-link construction and replace with `AppConfig.customerInviteUrl(token)`. Add the import. `flutter analyze` clean.
- [ ] **Task 4.2** — Refactor `frontend/customer/src/routes/[slug]/+page.svelte` per spec §4.7:
  ```svelte
  <script lang="ts">
    import type { ComponentType } from 'svelte';
    import MinimalLayout from '$lib/templates/minimal/MenuPage.svelte';
    import GridLayout from '$lib/templates/grid/MenuPage.svelte';
    import type { TemplateId } from '$lib/types/menu';

    const TEMPLATES: Record<TemplateId, ComponentType> = {
      minimal: MinimalLayout,
      grid: GridLayout,
      bistro: MinimalLayout,
      izakaya: MinimalLayout,
      street: MinimalLayout,
    };

    let { data } = $props();
    const Template = $derived(TEMPLATES[data.menu.templateId] ?? MinimalLayout);
  </script>

  <Template {data} />
  ```
  Keep any existing `<svelte:head>` / `<style>` / JSON-LD blocks above or below this script intact — only the in-script `<script>` body and the visible `{#if .. /:else}` block change.
- [ ] **Task 4.3** — Run `pnpm check` from `frontend/customer/`. Resolve any svelte-check errors.

**Acceptance:** `pnpm check` clean from `frontend/customer/`; `flutter analyze` clean from `frontend/merchant/`.

---

## Phase 5 — Tests

> **Subagent profile:** sonnet — test design.

- [ ] **Task 5.1** — `frontend/merchant/test/unit/app_config_test.dart`:
  ```dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:menuray_merchant/config/app_config.dart';

  void main() {
    test('customerMenuUrl uses default host', () {
      expect(
        AppConfig.customerMenuUrl('foo-bar'),
        'https://menu.menuray.com/foo-bar',
      );
    });
    test('customerInviteUrl includes token', () {
      expect(
        AppConfig.customerInviteUrl('abc123'),
        'https://menu.menuray.com/accept-invite?token=abc123',
      );
    });
  }
  ```
  Note: cannot test the override path without rebuilding with `--dart-define`; the default-value test is sufficient regression coverage.
- [ ] **Task 5.2** — `frontend/merchant/test/unit/qr_export_service_test.dart`: use `WidgetTester` to pump a small `RepaintBoundary` with a known size, call `renderToPng`, assert (a) returned `File.existsSync()` is true, (b) `lengthSync() > 0`, (c) first 8 bytes match the PNG signature `[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]`.
- [ ] **Task 5.3** — `frontend/merchant/test/smoke/published_screen_test.dart`: pump `PublishedScreen` with a mocked `menuByIdProvider` + `activeStoreProvider`, assert (a) `find.byType(QrImageView)`, (b) the three buttons render (FilledButton with localized share label, OutlinedButton with copy label, TextButton with done label), (c) tap the copy button → check `Clipboard.getData` returns the expected URL via the test channel mock.
  - To mock the clipboard channel: `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, ...)`. Capture writes from `Clipboard.setData`.
- [ ] **Task 5.4** — `frontend/customer/tests/unit/templateRegistry.test.ts`: import the same registry shape from `[slug]/+page.svelte` (extract to a `$lib/templates/registry.ts` if necessary to make it testable; otherwise inline-test the resolver logic). Assert `bistro`, `izakaya`, `street`, and an unknown id all resolve to MinimalLayout. Assert `minimal` and `grid` resolve to their respective components.
  - **If extracting:** Move the `TEMPLATES` constant to `frontend/customer/src/lib/templates/registry.ts`:
    ```ts
    import type { ComponentType } from 'svelte';
    import MinimalLayout from './minimal/MenuPage.svelte';
    import GridLayout from './grid/MenuPage.svelte';
    import type { TemplateId } from '$lib/types/menu';

    export const TEMPLATES: Record<TemplateId, ComponentType> = {
      minimal: MinimalLayout,
      grid: GridLayout,
      bistro: MinimalLayout,
      izakaya: MinimalLayout,
      street: MinimalLayout,
    };

    export function resolveTemplate(id: string): ComponentType {
      return (TEMPLATES as Record<string, ComponentType>)[id] ?? MinimalLayout;
    }
    ```
    Update `[slug]/+page.svelte` to `import { resolveTemplate } from '$lib/templates/registry'` and `const Template = $derived(resolveTemplate(data.menu.templateId))`.
  - The unit test imports `resolveTemplate` and `TEMPLATES` and asserts referential equality.
- [ ] **Task 5.5** — Run `cd frontend/merchant && flutter test`. All pass.
- [ ] **Task 5.6** — Run `cd frontend/customer && pnpm test` (Vitest). All pass.

**Acceptance:** All Flutter tests pass (108 = 106 existing + 3 new files; smoke replaces or adds 1, unit adds 2). All Vitest tests pass (19 = 18 existing + 1 new).

---

## Phase 6 — Docs

> **Subagent profile:** haiku — straight prose updates.

- [ ] **Task 6.1** — Add ADR-022 to `docs/decisions.md`:
  - Title: "ADR-022: Real QR via `qr_flutter`; customer host configurable; template dispatch via registry"
  - Status: Accepted (2026-04-25)
  - Context: slogan promises QR but PublishedScreen rendered a placeholder; dispatcher was hardcoded if/else; designer assets for Bistro/Izakaya/Street still pending.
  - Decision: ship `qr_flutter` with embedded logo + brand-frame share PNG; pull the customer host into compile-time `String.fromEnvironment` (default unchanged); dispatcher becomes `Record<TemplateId, ComponentType>` registry with Minimal fallback for unimplemented templates.
  - Consequences: scannable QR closes the slogan loop; share path opens marketing surface; designer can drop in three new templates as one file each + one registry line; compile-time-only host override means dev must rebuild to point at localhost (acceptable trade-off for the simplicity of `--dart-define`).
- [ ] **Task 6.2** — Update `docs/architecture.md`: under "Customer view" add a sentence noting the dispatcher registry; under "Merchant app" note the `AppConfig.customerHost` indirection + `qr_flutter` for QR rendering.
- [ ] **Task 6.3** — Update `docs/roadmap.md`:
  - Flip the `[ ] **S** QR generation` row in P0 → `[x] **S** QR generation — `qr_flutter` + share PNG (Session 6)`.
  - Replace the `[ ] **M** Templates Bistro / Izakaya / Street — designer-delivered` Session 6 row with: Session 6 reframed to QR + dispatcher infra (file-by-file shipped); the three designer-pending templates remain on the post-S6 list with the registry pattern called out as the integration mechanism — adding a new template = one new directory under `$lib/templates/` + one entry in `$lib/templates/registry.ts` + flipping `is_launch=true` in the templates seed.
- [ ] **Task 6.4** — Update `CLAUDE.md` "Active work" — add a Session 6 block summarising what shipped (mirror the format of the S5 block: counts, file references, key commits).

**Acceptance:** `git diff --stat docs/ CLAUDE.md` shows 4 files modified; rendered MD has no broken links; ADR-022 reads coherent.

---

## Phase 7 — Full verification

- [ ] **Task 7.1** — `cd frontend/merchant && flutter analyze`. Must be clean. (Spec §7 success criterion.)
- [ ] **Task 7.2** — `cd frontend/merchant && flutter test`. Must be all green. Capture the test count and paste into the commit body.
- [ ] **Task 7.3** — `cd frontend/customer && pnpm check`. Must be clean.
- [ ] **Task 7.4** — `cd frontend/customer && pnpm test`. Must be all green.
- [ ] **Task 7.5** — `cd frontend/customer && pnpm test:e2e`. Must be all green (re-runs the existing 8 Playwright tests; new dispatcher must not regress them).
- [ ] **Task 7.6** — Smoke check: `git status` clean except for the explicit S6 changes. Stage + commit each phase as a separate logical commit using conventional-commit format with co-author trailer.

**Acceptance:** All checks green; commits land on `main` (no remote — single-branch policy holds); CLAUDE.md reflects post-S6 state.

---

## Commit plan (one logical change per commit)

1. `chore(deps): qr_flutter for real QR rendering`
2. `feat(config): AppConfig.customerHost compile-time env`
3. `feat(i18n): 6 published-screen QR + share + copy keys (en + zh)`
4. `feat(publish): real QR via qr_flutter on PublishedScreen`
5. `feat(publish): QrExportService — branded PNG share`
6. `feat(publish): copy-link + share-QR + done bottom bar`
7. `refactor(rbac): team-management invite link uses AppConfig`
8. `refactor(customer): template dispatcher registry`
9. `test(merchant): AppConfig + QrExportService unit + PublishedScreen smoke`
10. `test(customer): templateRegistry unit`
11. `docs: ADR-022 + architecture + roadmap`
12. `docs: session 6 QR + dispatcher shipped` (CLAUDE.md update)

12 commits expected. Each gates on `flutter analyze` + relevant tests being green.

---

## Risks (cross-reference spec §6)

Mitigations for each are in the spec — see §6. Highlights:

- `RepaintBoundary` must be painted at least once → `Offstage(offstage: true)` keeps it laid out + painted (verified Flutter contract); smoke test covers regression.
- `qr_flutter` `embeddedImage` with `NetworkImage` may not load before the first paint → mitigated by `precacheImage` on `didChangeDependencies` of the parent. If pre-cache fails, the QR still renders without the embedded logo (graceful degradation).
- Compile-time `--dart-define` doesn't hot-reload → documented in `app_config.dart` doc comment; default unchanged so prod builds need no flag.

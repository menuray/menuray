# Session 6 — QR Generation + Customer Dispatcher Refactor — Design

Date: 2026-04-25
Scope: Replace the placeholder QR painter on the merchant `PublishedScreen` with a real `qr_flutter` widget that encodes the live customer URL, ship a "share branded QR PNG" flow, and refactor the customer-view template dispatcher from a hard-coded `if/else` to an extensible registry so new templates (Bistro / Izakaya / Street, post-designer) can drop in as one file each.
Audience: whoever implements the follow-up plan. Replaces the original "Session 6 = three new templates" framing because the designer has not delivered Bistro / Izakaya / Street assets — see decision matrix in §1.

## 1. Why we deviated from the original Session 6 brief

The original brief in `CLAUDE.md` and `docs/roadmap.md` framed Session 6 as "Templates Bistro / Izakaya / Street — designer-delivered; flip `is_launch=true`, implement 3 new `MenuPage.svelte`". As of 2026-04-25 the designer has **not** delivered visual assets for these three templates — `frontend/design/` contains only merchant-screen Stitch designs (1–11), and `docs/product-decisions.md §5` explicitly states "launch MVP with 2 (Minimal + Grid), 3 more after designer".

Letting an AI improvise the three template aesthetics is high-risk for brand fidelity and would almost certainly need a rewrite once the designer ships. Better to use Session 6 to (a) ship infrastructure that makes the eventual designer drop-in trivial (the dispatcher refactor), and (b) close the most glaring P0 product gap that remains.

The most glaring P0 gap: **QR generation**. MenuRay's slogan — "snap a photo of any paper menu, get a shareable digital menu in minutes" — depends on a QR code the merchant can print or share. Today the published-menu screen renders a deterministic-pixel-noise painter, not a real scannable QR. Without QR generation the slogan is unmet and the loop merchant→QR→customer is broken at the last step.

Session 6 therefore ships:
1. **Real QR generation** on the merchant published screen, with a branded PNG share flow.
2. **Customer dispatcher refactor** from `if/else` to a registry, so dropping in a new template later is one file + one map entry.

The three placeholder templates (`bistro`, `izakaya`, `street`) stay seeded with `is_launch=false` and remain "Coming soon" in the merchant template picker. When the designer delivers, a future micro-session flips the flags and adds the three `MenuPage.svelte` files — no further infra work needed.

## 2. Goal & Scope

After Session 6 ships:

1. A merchant who completes publish lands on `PublishedScreen` and sees a **scannable** QR encoding `https://menu.menuray.com/<slug>` (or the configured host).
2. Tapping "Share QR image" generates a brand-styled PNG (QR + store name + logo + "Scan to view menu" caption + small "menuray.com" wordmark) and opens the system share sheet via `share_plus`.
3. Tapping "Copy link" copies the customer URL to the clipboard with a snackbar confirmation.
4. The customer host is configurable at compile-time via `--dart-define=MENURAY_CUSTOMER_HOST=…` so a developer pointing at a local SvelteKit instance can scan their own QR. Default `menu.menuray.com` (matches the hard-coded values today).
5. Customer dispatcher in `[slug]/+page.svelte` reads `data.menu.templateId`, looks up a registry, and renders the matching `MenuPage.svelte`. Adding `bistro` / `izakaya` / `street` later = one file per template + one line in the registry.

**In scope**

- **Merchant Flutter**:
  - Add `qr_flutter ^4.1.0` to `frontend/merchant/pubspec.yaml`.
  - New file `frontend/merchant/lib/config/app_config.dart` exposing `AppConfig.customerHost` (compile-time-configurable, default `menu.menuray.com`) and `AppConfig.customerMenuUrl(slug)`. Refactor the two existing call sites (`published_screen.dart`, `team_management_screen.dart`) to use it.
  - Replace the fake-QR `_QrCard` painter in `published_screen.dart` with a real `QrImageView` from `qr_flutter`. Keep the embedded-logo center disc when `store.logoUrl` is non-null (load via `Image.network` → `MemoryImage` adapter). Keep the brand frame around the QR.
  - Add "Share QR image" + "Copy link" buttons to the published screen. Wire them to (a) a small QR-export helper that captures a `RepaintBoundary` containing the QR + store name + caption to `Image.toByteData(format: png)` → writes to a temp file in `path_provider`'s temp dir → invokes `SharePlus.instance.share(ShareParams(files: [XFile(file.path)]))`, (b) `Clipboard.setData` + `ScaffoldMessenger` snackbar.
  - Add 5 new i18n keys for the new UI affordances (en + zh).
- **Customer SvelteKit**:
  - Refactor `frontend/customer/src/routes/[slug]/+page.svelte` to use a `Record<TemplateId, ComponentType>` registry. Use Svelte 5 `$derived` for the lookup. Defensive fallback to `MinimalLayout` for any unknown id (covers Bistro/Izakaya/Street + DB tampering).
  - No change to `[slug]/[dishId]/+page.svelte` (already template-agnostic).
- **Tests**:
  - Merchant: extend / replace `test/smoke/published_screen_test.dart` (if it exists; otherwise create) to assert a `QrImageView` widget renders, the two new buttons render, and tapping "Copy link" calls the clipboard.
  - Merchant: unit test the QR-PNG export helper in isolation (write to a known path, assert file exists, header bytes are PNG signature `89 50 4E 47`).
  - Merchant: unit test `AppConfig.customerMenuUrl('foo-bar')` returns the right URL with the default host AND with an overridden host (set via `String.fromEnvironment` mock).
  - Customer: existing `tests/e2e/templates.spec.ts` keeps passing (selectors are layout-class-based, not dispatcher-shape-based — see explore report). No new e2e tests needed for the dispatcher itself.
  - Customer: one `vitest` unit test for the registry — assert that `TEMPLATES[id]` returns the right component for each known id and falls back to Minimal for `bistro` / `izakaya` / `street` / unknown.
- **Docs**:
  - New ADR-022 in `docs/decisions.md`: "Real QR via `qr_flutter`; customer host configurable via compile-time env; template dispatch via registry to ease future drop-in".
  - `CLAUDE.md` "Active work" Session 6 block updated.
  - `docs/roadmap.md` — flip QR generation P0 row to ✅; add a new explicit "Designer-delivered Bistro / Izakaya / Street templates" row called out as deferred until designer ships, with the registry pattern documented as the integration mechanism.
  - `docs/architecture.md` — short paragraph on QR + dispatcher pattern.

**Out of scope (deferred)**

- **PDF table-tent generator** — adding `pdf` + `printing` to the dependency tree is non-trivial (printing fonts, Material → PDF rendering). Share-as-PNG covers the print use case (merchant prints from Photos.app). Defer to P1.
- **Save-to-gallery (`image_gallery_saver`)** — the share sheet exposes "Save Image" on iOS and "Save to Photos" on Android, so the user already has gallery access via the share path. A dedicated button doubles UI without adding functionality. Defer.
- **Tier-gating the "MenuRay" wordmark on the QR PNG** — `docs/product-decisions.md §2` says "Custom branding on QR page" is Pro+. Session 4 already gates the customer-page footer badge by tier. The QR PNG is a merchant artifact; we keep a tasteful "menuray.com" wordmark in the bottom margin for all tiers. Removing the wordmark for Pro+ is a P1 polish item.
- **Bistro / Izakaya / Street template implementations** — blocked on designer (per §1).
- **Real device pass on iOS + Android** for the QR share flow — relies on platform-specific share-sheet behaviors. Acknowledged as a launch-readiness manual-QA item; not blocked on Session 6 code.
- **QR view tracking surfacing** — Session 4 already counts QR views on the customer side and surfaces them in Statistics (Session 5). No additional analytics work for this session.

## 3. Context

- `frontend/merchant/lib/features/publish/presentation/published_screen.dart` — the current PublishedScreen renders a fake QR via `_QrPainter` (lines 312–385) seeded with a deterministic RNG. URL is hardcoded as `https://menu.menuray.com/${menu.slug}` at line 49. Bottom CTA returns to home (line 112). Brand frame: a beige card with rounded corners and a sticker-style header.
- `frontend/merchant/lib/features/store/presentation/team_management_screen.dart` — the invite-link generator uses the same hardcoded host. Refactoring both to read `AppConfig.customerHost` keeps them in sync.
- `frontend/merchant/lib/features/manage/presentation/statistics_screen.dart:395` (Session 5) — sets the precedent for `share_plus` usage: write to a real temp file with `path_provider.getTemporaryDirectory()`, then `SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: …))`. Reuse this pattern for the QR PNG.
- `frontend/customer/src/routes/[slug]/+page.svelte:27–33` — the current dispatcher is a 7-line `if/else` between `MinimalLayout` and `GridLayout`. `[slug]/[dishId]/+page.svelte` is already template-agnostic (one fixed component) and stays that way.
- `frontend/customer/tests/e2e/templates.spec.ts:28` — selectors used: `page.locator('main div[class*="grid-cols"]')` (layout class) and `page.evaluate()` for CSS variable read. **Not dispatcher-shape-dependent**; refactor is safe.
- `qr_flutter ^4.1.0` is the canonical Flutter QR library (5k stars, MIT, supports `embeddedImage`, `eyeStyle`, `dataModuleStyle`, `errorCorrectionLevel`). Vector-rendered, scales without aliasing.
- Svelte 5 runes mode (verified in `[slug]/+page.svelte` already using `$props()`) supports `$derived` for reactive lookups: `let Template = $derived(TEMPLATES[id] ?? MinimalLayout)` then `<Template {data} />` (capitalized variable name → component). No `<svelte:component>` needed in Svelte 5; the capitalized-variable form is the idiomatic dynamic component pattern. SSR-safe because all imports are static at build time — the registry is just a runtime lookup over compile-time-resolved modules.

## 4. Decisions

### 4.1 `qr_flutter` over alternatives

Two real options: `qr_flutter` (4k+ stars, last release Q1 2026, supports embedded image + custom corner styles + CustomPainter exports) vs. `pretty_qr_code` (smaller, fancier built-in styling, but heavier API). `qr_flutter` is more conservative and the embed-logo API matches the current visual.

### 4.2 Customer host via `String.fromEnvironment`

```dart
// lib/config/app_config.dart
class AppConfig {
  static const String customerHost = String.fromEnvironment(
    'MENURAY_CUSTOMER_HOST',
    defaultValue: 'menu.menuray.com',
  );
  static String customerMenuUrl(String slug) => 'https://$customerHost/$slug';
}
```

Compile-time `String.fromEnvironment` (not `Platform.environment`) so the value is baked into the build artifact. Dev workflow: `flutter run --dart-define=MENURAY_CUSTOMER_HOST=localhost:5173` and the merchant app generates QRs pointing at the local SvelteKit dev server.

Both `published_screen.dart` and `team_management_screen.dart` import this and call `AppConfig.customerMenuUrl(menu.slug)` / `AppConfig.customerHost`.

### 4.3 QR rendering in `_QrCard`

Replace the `CustomPaint(painter: _QrPainter(seed))` with:

```dart
QrImageView(
  data: AppConfig.customerMenuUrl(menu.slug),
  version: QrVersions.auto,
  size: 220,
  backgroundColor: Colors.white,
  errorCorrectionLevel: QrErrorCorrectLevel.H,  // H=30%, lets us embed a logo
  embeddedImage: store.logoUrl != null
      ? NetworkImage(store.logoUrl!)
      : null,
  embeddedImageStyle: QrEmbeddedImageStyle(
    size: const Size(48, 48),
  ),
)
```

`H` error-correction level allows the embedded logo without breaking decode reliability. The widget renders a vector QR — clean at any scale. Store-logo network image is best-effort; if it fails to load, `qr_flutter` silently renders without it.

`QrImageView` accepts a `Color` for `dataModuleStyle.color` to match brand if we want — kept default black for maximum scan reliability.

### 4.4 Branded QR PNG export

Architecture: a hidden `RepaintBoundary` wraps a `Column` containing store logo (top), store name, the `QrImageView`, the "Scan to view menu" caption, and the menuray.com wordmark. The exporter captures it via `boundary.toImage(pixelRatio: 3.0).toByteData(format: png)`, writes to `${tempDir}/menuray-${menuId}-qr.png`, and shares.

```dart
// lib/features/publish/data/qr_export_service.dart
class QrExportService {
  Future<File> renderToPng({
    required GlobalKey boundaryKey,
    required String menuId,
  }) async {
    final boundary = boundaryKey.currentContext!.findRenderObject()
        as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/menuray-$menuId-qr.png');
    await file.writeAsBytes(byteData!.buffer.asUint8List());
    return file;
  }
}
```

Provider: `qrExportServiceProvider = Provider((_) => QrExportService())`. Inject in `PublishedScreen` via `ref.read`.

The capture target is rendered off-screen at **600 logical px wide**, height intrinsic, with `pixelRatio: 3.0` → final PNG ~1800 px wide. Wrapped in a brand-styled card so the share artifact looks intentional, not a screenshot. Visual structure (top → bottom, all centered):

1. 32 px outer padding (uniform).
2. Store logo (if present): 64×64 circular avatar.
3. 12 px gap.
4. Store name: `Inter 600 24sp ink`.
5. 24 px gap.
6. `QrImageView` 460×460 inside a white card with 20 px inner padding, brand stroke 2 px primary, rounded 24.
7. 16 px gap.
8. "Scan to view menu" / "扫码查看菜单" caption: `Inter 500 16sp ink`.
9. 12 px gap.
10. `menuray.com` wordmark: `Inter 400 13sp ink-secondary`.
11. 32 px outer padding.

Keep this in a separate widget `_QrShareCard` colocated with `_QrCard`, gated by an `Offstage(offstage: true, child: ...)` so it does not affect layout but the `RepaintBoundary` still has a render pass to capture.

`Offstage` + `RepaintBoundary` is a standard idiom. Verified pattern: the boundary's `toImage` works as long as the subtree has been laid out and painted at least once, which `Offstage(offstage: true)` does (it lays out and paints, just doesn't display).

### 4.5 Copy-link

```dart
await Clipboard.setData(ClipboardData(text: AppConfig.customerMenuUrl(menu.slug)));
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text(t.publishedLinkCopied)),
);
```

Snackbar duration: default 4 sec. No tier gating.

### 4.6 Sticky bottom bar — button layout

Currently the published screen has one full-width "返回" button. Change to a 3-button row (or 2-row stack on narrow screens):

- Primary: "Share QR image" (icon: `Icons.ios_share`, FilledButton, full-width on narrow / wider on `≥360`).
- Secondary: "Copy link" (icon: `Icons.link`, OutlinedButton).
- Tertiary text button: "Done" (returns to home; replaces current CTA).

Stacked vertically inside a `SafeArea` + `Padding` block. Keeps the existing back-arrow in the AppBar so "Done" is redundant only as a clearer affordance.

### 4.7 Customer dispatcher registry

Replace the `if/else` block in `frontend/customer/src/routes/[slug]/+page.svelte`:

```svelte
<script lang="ts">
  import type { ComponentType } from 'svelte';
  import MinimalLayout from '$lib/templates/minimal/MenuPage.svelte';
  import GridLayout from '$lib/templates/grid/MenuPage.svelte';
  import type { TemplateId } from '$lib/types/menu';

  // Registry: every TemplateId maps to a layout component. Bistro/Izakaya/Street
  // fall back to Minimal until the designer delivers them; once the new
  // MenuPage.svelte files exist, swap the import here and flip is_launch=true
  // in the templates table.
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

Notes:
- `$derived` returns a reactive value; `let Template = $derived(...)` is the runes idiom (must be `let`, not `const` — `$derived` is mutable-by-runtime even though the *expression* is pure).
- Capitalized variable `Template` → Svelte 5 renders it as a component without `<svelte:component>`.
- Defensive `?? MinimalLayout` covers DB tampering with a non-enum value (the `TemplateId` type is enforced at the Supabase mapper boundary, but defence-in-depth is cheap).
- All five entries import statically — Vite bundles each at build time. No SSR import-resolution issues.

### 4.8 i18n keys (en + zh)

| Key | en | zh |
|---|---|---|
| `publishedShareQr` | Share QR image | 分享 QR 图片 |
| `publishedShareQrSubject` | My MenuRay menu — {storeName} | 我的 MenuRay 菜单 — {storeName} |
| `publishedCopyLink` | Copy link | 复制链接 |
| `publishedLinkCopied` | Link copied to clipboard | 已复制链接 |
| `publishedScanCaption` | Scan to view menu | 扫码查看菜单 |
| `publishedDone` | Done | 完成 |

Six keys total. The subject string takes a `{storeName}` placeholder.

### 4.9 Test plan

| Layer | Test | Target |
|---|---|---|
| Merchant unit | `test/unit/app_config_test.dart` | `AppConfig.customerMenuUrl('foo-bar')` returns `https://menu.menuray.com/foo-bar` (default) |
| Merchant unit | `test/unit/qr_export_service_test.dart` | Renders a tiny `RepaintBoundary` to PNG; assert returned `File` exists, size > 0, first 4 bytes are PNG signature |
| Merchant smoke | `test/smoke/published_screen_test.dart` (replace any existing fake-QR assertion) | Renders without throwing; asserts a `QrImageView` widget is in the tree; asserts "Share QR image" + "Copy link" buttons render; tapping copy-link populates clipboard and shows snackbar |
| Customer unit | `tests/unit/templateRegistry.test.ts` (new) | Registry returns the right component for each known id; falls back to Minimal for `bistro` / `izakaya` / `street` / unknown |
| Customer e2e | existing `tests/e2e/templates.spec.ts` | Still green — selectors don't depend on dispatcher shape |

Total target: 4 new tests + 1 existing-test stability check = 5 changes. Keeps Session 6 around the **M** budget.

## 5. File tree

```
frontend/merchant/
├── lib/
│   ├── config/
│   │   └── app_config.dart                                                  (new)
│   ├── features/
│   │   ├── publish/
│   │   │   ├── data/
│   │   │   │   └── qr_export_service.dart                                   (new)
│   │   │   └── presentation/
│   │   │       └── published_screen.dart                                    (modified — real QR + share + copy)
│   │   └── store/
│   │       └── presentation/
│   │           └── team_management_screen.dart                              (modified — use AppConfig)
│   └── l10n/
│       ├── app_en.arb                                                       (modified — 6 keys)
│       └── app_zh.arb                                                       (modified — 6 keys)
├── pubspec.yaml                                                             (modified — qr_flutter)
└── test/
    ├── unit/
    │   ├── app_config_test.dart                                             (new)
    │   └── qr_export_service_test.dart                                      (new)
    └── smoke/
        └── published_screen_test.dart                                       (new or modified)

frontend/customer/
├── src/routes/[slug]/+page.svelte                                           (modified — registry dispatcher)
└── tests/unit/templateRegistry.test.ts                                      (new)

docs/
├── decisions.md                                                             (modified — new ADR-022)
├── architecture.md                                                          (modified — small paragraph)
└── roadmap.md                                                               (modified — flip QR row, add deferred templates row)

CLAUDE.md                                                                    (modified — Active work)
```

Total: 9 new files + 6 modifications.

## 6. Risks & mitigations

| Risk | Mitigation |
|---|---|
| `qr_flutter` `embeddedImage` with `NetworkImage` may flash or fail to load on first render → captured PNG misses logo | Pre-load via `precacheImage` in `didChangeDependencies` of `_PublishedBody`; gate the share button or fall back to no-logo capture if precache rejected |
| `RepaintBoundary.toImage` requires the subtree to have been painted at least once. `Offstage(offstage: true)` keeps it in the layout tree but doesn't paint to screen — verify it still paints to the layer tree | Standard Flutter answer: `Offstage` lays out and paints; only `Visibility(visible: false)` skips painting. Confirmed by the Flutter source. Smoke test verifies. |
| iOS share sheet treats unknown extensions weirdly → some apps reject the PNG | Use `.png` extension and rely on share_plus's MIME inference. The repo's CSV export (Session 5) already proves the pattern works in iOS Simulator. |
| `--dart-define` for `MENURAY_CUSTOMER_HOST` may surprise CI / production builds if not set | Default value `menu.menuray.com` matches the previously-hardcoded value, so unconfigured builds behave identically to today. Add a section in `docs/development.md` covering the override. |
| `String.fromEnvironment` evaluated at compile-time means a hot-reload of an env-change requires a full rebuild | Document in `app_config.dart` doc comment. Rebuild is a one-command operation. |
| Svelte 5 `$derived` with capitalized component variable may behave unexpectedly under SSR if any template module is heavy | All templates are static imports → bundled and tree-shaken at build. Worst case is unused-import bytes. The customer view has no SSR hydration ambiguity here because `<Template/>` resolves the same on server and client. |
| The "MenuRay" wordmark on the share PNG is a visible brand artifact for free-tier users — could provoke "I paid, why is it still there?" complaints from Pro+ | Acknowledged as P1 polish; documented in §2 out-of-scope. Wordmark sized small and tasteful. |
| `pubspec.yaml` add of `qr_flutter` may pull in transitive deps that bloat APK | `qr_flutter` is pure-Dart with zero platform plugins → adds <50 KB. Verify post-install with `flutter build apk --analyze-size` if curiosity strikes; not gating. |

## 7. Success criteria

- `cd frontend/merchant && flutter pub get && flutter analyze` → clean.
- `cd frontend/merchant && flutter test` → all tests pass, including the 4 new ones (`app_config_test`, `qr_export_service_test`, `published_screen_test`, plus any pre-existing tests staying green).
- Manual: run merchant app, complete a publish flow on the seed menu, assert the QR on PublishedScreen scans correctly with iOS Camera (or any QR reader app) and opens `https://menu.menuray.com/<slug>` (or whatever was set via `--dart-define`).
- Manual: tap "Share QR image" → system share sheet appears → "Save Image" puts a usable PNG with the brand frame in Photos.app.
- Manual: tap "Copy link" → snackbar shows; paste into another app reveals the URL.
- `cd frontend/customer && pnpm check && pnpm test && pnpm test:e2e` → all clean. New `templateRegistry.test.ts` runs as part of `pnpm test`.
- `docs/decisions.md` has a new ADR-022 entry.
- `CLAUDE.md` "Active work" Session 6 block describes what shipped (with file refs).
- `docs/roadmap.md` QR-generation P0 row flipped to ✅; the deferred Bistro/Izakaya/Street row reframed.

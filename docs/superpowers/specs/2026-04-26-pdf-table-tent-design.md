# Session 9 — PDF Table-Tent Generator — Design

Date: 2026-04-26
Scope: Wire the previously-hidden `publishedExportPdf` button on `PublishedScreen` to a real PDF generator. The PDF is a print-ready single A4 page with the QR + store name + caption + URL, suitable for cutting and folding into a table tent. Replaces the S6 deferral.

## 1. Goal & Scope

After Session 9 ships:

1. A merchant taps "Export PDF" on `PublishedScreen` and the system share sheet opens with a PDF attachment.
2. The PDF is a single A4 page, portrait, with two table-tent panels (each contains store name + QR code + scan caption + URL + cut/fold guide marks) so two diners' tables can be served from one print.
3. The PDF respects the existing tier-aware wordmark gating (Pro+ omits `menuray.com`).

**In scope**

- **Dependency**: `pdf: ^3.11.0` (pure-Dart; no platform plugins). The `printing` package is **not** added — share-via-share-sheet is sufficient and avoids native build complexity.
- **`PdfExportService`** at `lib/features/publish/data/pdf_export_service.dart`. One method `renderToPdf({menuId, storeName, customerUrl, scanCaption, showWordmark})` that builds the document via `pw.Document()` + `pw.Page(pageFormat: PdfPageFormat.a4)`, writes to a temp file via `path_provider`, returns the `File`.
- **QR encoding**: the `pdf` package ships a built-in QR widget (`pw.BarcodeWidget(barcode: pw.Barcode.qrCode(...))`). Reuses the same URL passed in.
- **Page layout**: portrait A4, two table-tent panels stacked vertically. Each panel renders inside a 50%-height `pw.Container` with a dashed-line cut guide and a fold-line marker between halves — diners read the QR + name on the front; back stays blank for hand-folding. Uniform 24pt outer padding.
- **`_QrShareCard` parent in `published_screen.dart`** gains a `_handleSharePdf` that calls `PdfExportService.renderToPdf` (re-using `storeName` + `_url` + tier flag from existing state) → `share_plus`.
- **Wire `_ExportActions`** to surface the PDF button: re-add a third column for the PDF button (currently hidden after S6) so the export row reads "Save QR" / "Export PDF" / "Share". The `onSavePdf` handler uses the new service.
- **i18n**: 1 new key `publishedExportPdfFailed` for snackbar errors. The existing `publishedExportPdf` label ("Export PDF" / "导出 PDF") is reused.
- **Tests**:
  - Flutter unit: `test/unit/pdf_export_service_test.dart` builds a PDF in a temp dir, asserts file exists, size > 0, first 4 bytes are PDF signature `25 50 44 46` (`%PDF`).
  - Flutter smoke: extend `test/smoke/published_screen_smoke_test.dart` to assert the "导出 PDF" button is back. (Tap-and-render is too slow for smoke; covered by the unit test.)
- **Docs**: ADR-026; CLAUDE.md S9 block; roadmap row for PDF table-tent flipped to ✅.

**Out of scope (deferred)**

- **Rich custom fonts** — the `pdf` package's default Helvetica is fine for ASCII + most CJK rendering on iOS / Android. CJK rendering on Linux without bundled fonts may show tofu boxes; document as a known limitation. Bundling Noto Sans CJK is a P1 polish item if needed.
- **Multi-page PDFs / N tents per page across multiple pages** — single A4 with two panels fits the common use case (one small restaurant, two tables).
- **Cover image / logo embedded in the PDF panel** — the PDF carries the QR + text. If the merchant wants the logo, they'll generate a print version with their printer's tools.
- **Custom paper sizes** (Letter, A5) — A4 is the global default; alternate sizes are a P2 customisation.
- **Print directly via `printing` package** — deferred; share-sheet → AirPrint / Google Cloud Print works on every platform we target.
- **Pro+ removes wordmark from PDF** — same gating logic as S8 share PNG. **Actually IN scope** because `_QrShareCard` already takes `showWordmark`; we mirror the gate in the PDF builder.

## 2. Decisions

### 2.1 `pdf` package only (no `printing`)

The `printing` package brings native code (CUPS on Linux, Android print framework, iOS UIKit print). It works but adds platform-channel surface area + iOS Info.plist edits. The `pdf` package is pure Dart and produces bytes; `share_plus` already moves bytes around the system. Net change is minimal.

### 2.2 PDF file naming convention

`menuray-<menuId>-tent.pdf` in `path_provider.getTemporaryDirectory()`. Mirrors the S6 PNG naming (`menuray-<menuId>-qr.png`).

### 2.3 Two-panel layout vs single large QR

A single QR fills A4 = wasteful and hard to fold. Two-panel = the standard table-tent footprint a small-restaurant printer-paper-cutter setup yields. Cut along the dashed guide → fold along the solid line → upright tent.

### 2.4 Default Helvetica + CJK fallback warning

`pdf` ships only Helvetica/Times/Courier. CJK text uses the runtime's font fallback (works on iOS/Android; may be tofu on Linux/Web). For the merchant's typical share path (iOS/Android share sheet → Photos / Files), this is fine. We document the Linux/Web caveat in the README. Bundling NotoSansCJK adds ~5MB to the bundle — defer.

### 2.5 Reuse the same share PNG showWordmark flag

The PDF carries the same wordmark/no-wordmark distinction as the share PNG. `_PublishedBodyState.build` reads tier once and passes the boolean down to BOTH `_QrShareCard.showWordmark` and the new PDF service call.

### 2.6 Keep the share PNG path; PDF is a sibling action

We don't replace "Save QR" with "Export PDF". A merchant's instinct is "save the QR as an image to AirDrop to my phone" vs "print it on table tents". Both are valid; both buttons sit side-by-side.

## 3. File tree

**New (merchant flutter):**
```
frontend/merchant/lib/features/publish/data/pdf_export_service.dart
frontend/merchant/test/unit/pdf_export_service_test.dart
```

**Modified (merchant flutter):**
```
frontend/merchant/pubspec.yaml                            (+ pdf ^3.11.0)
frontend/merchant/lib/features/publish/presentation/published_screen.dart  (Export PDF wire)
frontend/merchant/lib/l10n/app_en.arb                     (+ 1 key)
frontend/merchant/lib/l10n/app_zh.arb                     (+ 1 key)
frontend/merchant/test/smoke/published_screen_smoke_test.dart  (assert PDF button)
```

**Modified (docs):**
```
docs/decisions.md          (+ ADR-026)
docs/architecture.md       (small note in merchant section)
docs/roadmap.md            (PDF row flipped)
CLAUDE.md                  (S9 block + test totals)
```

Total: 2 new files + 7 modifications.

## 4. Risks & mitigations

| Risk | Mitigation |
|---|---|
| `pdf` package's CJK fallback shows tofu on Linux | Documented in README + ADR. Mobile share path unaffected. |
| `pw.BarcodeWidget` may render at suboptimal pixel density | The widget vector-renders the QR; PDF readers + printers rasterise at print DPI. Should be crisp. |
| File-not-found if share_plus is invoked before write completes | `await file.writeAsBytes(..., flush: true)` blocks until the bytes hit disk. |
| Adding `pdf` increases APK size | ~600 KB. Acceptable given the value to merchants. |
| Tier-gating drift: wordmark removed from PDF but not PNG (or vice versa) | Single source of truth in `_PublishedBodyState.build` passes the same `showWordmark` to both. Smoke test covers both paths. |

## 5. Success criteria

- `flutter pub get` + `flutter analyze` + `flutter test` all clean.
- Manual: tap Export PDF → share sheet opens → save / mail PDF → opens with two visible panels in any standard PDF reader.
- Manual on Pro user: PDF lacks the `menuray.com` wordmark.

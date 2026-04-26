# Session 9 — PDF Table-Tent Generator — Implementation Plan

> Spec: `docs/superpowers/specs/2026-04-26-pdf-table-tent-design.md`. Single feature, three phases.

## Phase 1 — pubspec + PdfExportService

- [ ] Add `pdf: ^3.11.0` to `frontend/merchant/pubspec.yaml`. Run `flutter pub get`.
- [ ] Create `frontend/merchant/lib/features/publish/data/pdf_export_service.dart` exposing
      ```dart
      class PdfExportService {
        Future<File> renderToPdf({
          required String menuId,
          required String storeName,
          required String customerUrl,
          required String scanCaption,
          required bool showWordmark,
        });
      }
      ```
      and a Riverpod `Provider<PdfExportService>`.
- [ ] Implementation: `pw.Document()` → one `pw.Page(pageFormat: pw.PdfPageFormat.a4)` → outer 24pt padding → two stacked panels with a horizontal dashed cut line between. Each panel is a `pw.Container` with rounded border, store name (Inter-equivalent / default Helvetica), `pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: customerUrl, width: 200, height: 200)`, scan caption, URL monospaced, and (only when `showWordmark`) the `menuray.com` wordmark below.
- [ ] Use `pdf.save()` to get bytes, write to `${tempDir.path}/menuray-$menuId-tent.pdf`.

## Phase 2 — Wire the Export PDF button

- [ ] In `published_screen.dart`:
  - Re-introduce the third button in `_ExportActions` (`onExportPdf` parameter — currently 2 buttons after S6).
  - Add `_handleExportPdf` method on `_PublishedBodyState`. Mirrors `_handleShareQrPng`: reads the PDF service from Riverpod, calls `renderToPdf`, hands off to `SharePlus.instance.share` with subject `publishedShareQrSubject(storeName)`. On error: snackbar with the new key.
  - Pass `showWordmark: showWordmark` into the call (same flag used for the PNG card).
- [ ] Add 1 i18n key in en + zh: `publishedExportPdfFailed` ("Could not generate PDF — please try again" / "PDF 生成失败 — 请重试"). Reuse `publishedExportPdf` for the button label.

## Phase 3 — Tests + docs

- [ ] `test/unit/pdf_export_service_test.dart`: build a small PDF in a temp dir, assert (a) file exists, (b) size > 0, (c) bytes start with `%PDF` (`0x25 0x50 0x44 0x46`).
- [ ] Extend `test/smoke/published_screen_smoke_test.dart` with: pump → assert "导出 PDF" button is visible.
- [ ] `flutter analyze` clean; `flutter test` green.
- [ ] ADR-026 added; CLAUDE.md S9 block; roadmap PDF row flipped.

## Commit plan

1. `chore(deps): pdf for table-tent generator`
2. `feat(publish): PdfExportService — A4 two-panel table tent with QR + tier-aware wordmark`
3. `feat(publish): wire Export PDF button on PublishedScreen + new i18n key`
4. `test: PdfExportService unit + PublishedScreen smoke for PDF button`
5. `docs: ADR-026 + roadmap + CLAUDE.md for S9`

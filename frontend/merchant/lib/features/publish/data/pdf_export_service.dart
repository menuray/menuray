import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Generates a single-A4 two-panel table-tent PDF for a published menu.
/// The merchant prints, cuts along the dashed guide, folds along the solid
/// fold line → upright tent suitable for a small-restaurant table.
class PdfExportService {
  const PdfExportService();

  Future<File> renderToPdf({
    required String menuId,
    required String storeName,
    required String customerUrl,
    required String scanCaption,
    required bool showWordmark,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => pw.Column(
          children: [
            pw.Expanded(
              child: _panel(
                storeName: storeName,
                customerUrl: customerUrl,
                scanCaption: scanCaption,
                showWordmark: showWordmark,
              ),
            ),
            // Cut guide between the two panels.
            pw.Container(
              height: 18,
              alignment: pw.Alignment.center,
              child: pw.Text(
                '— — — — — — — cut — — — — — — —',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                  letterSpacing: 4,
                ),
              ),
            ),
            pw.Expanded(
              child: _panel(
                storeName: storeName,
                customerUrl: customerUrl,
                scanCaption: scanCaption,
                showWordmark: showWordmark,
              ),
            ),
          ],
        ),
      ),
    );

    final bytes = await doc.save();
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/menuray-$menuId-tent.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  pw.Widget _panel({
    required String storeName,
    required String customerUrl,
    required String scanCaption,
    required bool showWordmark,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      padding: const pw.EdgeInsets.all(20),
      child: pw.Center(
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            if (storeName.isNotEmpty) ...[
              pw.Text(
                storeName,
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey900,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 12),
            ],
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey800, width: 1),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: customerUrl,
                width: 180,
                height: 180,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              scanCaption,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              customerUrl,
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey600,
              ),
              textAlign: pw.TextAlign.center,
            ),
            if (showWordmark) ...[
              pw.SizedBox(height: 8),
              pw.Text(
                'menuray.com',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey500,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final pdfExportServiceProvider =
    Provider<PdfExportService>((_) => const PdfExportService());

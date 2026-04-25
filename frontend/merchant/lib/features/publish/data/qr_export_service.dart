import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Captures a `RepaintBoundary` to a PNG file in the system temp dir so the
/// merchant can share a brand-styled QR artifact via the system share sheet.
class QrExportService {
  const QrExportService();

  Future<File> renderToPng({
    required GlobalKey boundaryKey,
    required String menuId,
    double pixelRatio = 3.0,
  }) async {
    final ctx = boundaryKey.currentContext;
    if (ctx == null) {
      throw StateError('QR boundary is not mounted yet');
    }
    final boundary = ctx.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('toByteData returned null');
      }
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/menuray-$menuId-qr.png');
      await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
      return file;
    } finally {
      image.dispose();
    }
  }
}

final qrExportServiceProvider =
    Provider<QrExportService>((_) => const QrExportService());

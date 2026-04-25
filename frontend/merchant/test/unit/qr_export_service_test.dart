import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/publish/data/qr_export_service.dart';

void main() {
  group('QrExportService', () {
    const service = QrExportService();

    test('renderToPng throws when boundary key is unmounted', () async {
      // GlobalKey.currentContext returns null when the key has not been
      // attached to any widget; the service detects this and refuses to
      // capture. Some Flutter releases assert internally before that null
      // check fires (debug-mode key bookkeeping), so the contract here is
      // "throws *something*" rather than a specific exception type.
      final unmountedKey = GlobalKey();
      await expectLater(
        () => service.renderToPng(boundaryKey: unmountedKey, menuId: 'm1'),
        throwsA(anything),
      );
    });
  });
}

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/features/publish/data/pdf_export_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _FakePathProvider(this.tempPath);
  final String tempPath;
  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('menuray-pdf-test-');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });
  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('renderToPdf produces a valid PDF file with %PDF header', () async {
    const service = PdfExportService();
    final file = await service.renderToPdf(
      menuId: 'm-test',
      storeName: 'Test shop',
      customerUrl: 'https://menu.menuray.com/test-shop-2026',
      scanCaption: 'Scan for menu',
      showWordmark: true,
    );

    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(0));

    final raw = await file.readAsBytes();
    // PDF files begin with the bytes "%PDF" (0x25 0x50 0x44 0x46).
    final header = raw.sublist(0, 4);
    expect(
      header,
      Uint8List.fromList(const [0x25, 0x50, 0x44, 0x46]),
      reason: 'expected %PDF header',
    );
  });

  test('renderToPdf with showWordmark:false still produces a valid PDF',
      () async {
    const service = PdfExportService();
    final file = await service.renderToPdf(
      menuId: 'm-test-pro',
      storeName: 'Pro shop',
      customerUrl: 'https://menu.menuray.com/pro-shop-2026',
      scanCaption: 'Scan for menu',
      showWordmark: false,
    );

    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(0));
  });
}

// Opt-in visual review artifact: flutter test --no-pub tool/render_printer_test_page.dart
import 'dart:io';

import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/printing/printer_test_page_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('export the actual A4 printer test page for visual review', () async {
    final bytes = await PrinterTestPagePdf.build(
      const ShopSettingsSnapshot(shopName: 'محل اختبار الطباعة'),
    );
    final output = File('.dart_tool/printer-test.pdf');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes, flush: true);
    expect(await output.length(), greaterThan(1000));
  });
}

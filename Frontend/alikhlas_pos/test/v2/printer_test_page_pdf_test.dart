import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/printing/printer_test_page_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'printer test page builds an Arabic PDF from the current shop details',
    () async {
      final pdf = await PrinterTestPagePdf.build(
        const ShopSettingsSnapshot(shopName: 'محل اختبار الطباعة'),
      );

      expect(pdf.length, greaterThan(1000));
      expect(String.fromCharCodes(pdf.take(4)), '%PDF');
    },
  );
}

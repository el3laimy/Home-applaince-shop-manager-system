import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../application/v2_use_cases.dart';
import 'pdf_fonts.dart';

class PrinterTestPagePdf {
  const PrinterTestPagePdf._();

  static Future<bool> printTestPage(ShopSettingsSnapshot settings) async {
    final bytes = await build(settings);
    return Printing.layoutPdf(
      name: 'alikhlas-printer-test',
      format: PdfPageFormat.a4,
      dynamicLayout: false,
      onLayout: (_) async => bytes,
    );
  }

  static Future<Uint8List> build(ShopSettingsSnapshot settings) async {
    final fonts = await PdfFonts.loadCairo();
    final theme = pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold);
    final document = pw.Document(theme: theme);

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (_) => pw.Center(
          child: pw.Container(
            width: 420,
            padding: const pw.EdgeInsets.all(28),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey500, width: 1),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  settings.shopName,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: fonts.bold, fontSize: 24),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'اختبار طباعة إخلاص POS',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: fonts.bold, fontSize: 18),
                ),
                pw.Divider(),
                pw.SizedBox(height: 12),
                pw.Text(
                  'تأكد من وضوح الحروف العربية وترتيب الأرقام: 0123456789',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: fonts.regular, fontSize: 13),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'هذه صفحة اختبار A4. جرّب إيصالًا وملصق باركود بالحجم الفعلي قبل بدء العمل.',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: fonts.regular, fontSize: 11),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  'يمكنك إغلاق نافذة الطباعة دون تسجيل أي عملية في المحل.',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: fonts.regular, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return document.save();
  }
}

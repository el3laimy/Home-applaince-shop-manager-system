import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../application/v2_use_cases.dart';
import '../core/money.dart';
import 'pdf_fonts.dart';

class ReportSummaryPdf {
  const ReportSummaryPdf._();

  static Future<void> printReport({
    required PeriodReportSnapshot report,
    required ShopSettingsSnapshot settings,
  }) async {
    final bytes = await build(report: report, settings: settings);
    await Printing.layoutPdf(
      name: 'alikhlas-report-${_dateKey(report.start)}-${_dateKey(report.end)}',
      onLayout: (_) async => bytes,
    );
  }

  static Future<Uint8List> build({
    required PeriodReportSnapshot report,
    required ShopSettingsSnapshot settings,
  }) async {
    final fonts = await PdfFonts.loadCairo();
    final regular = fonts.regular;
    final bold = fonts.bold;
    final theme = pw.ThemeData.withFont(base: regular, bold: bold);
    final doc = pw.Document(theme: theme);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              settings.shopName,
              style: pw.TextStyle(font: bold, fontSize: 22),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'تقرير مختصر من ${_date(report.start)} إلى ${_date(report.end)}',
              style: pw.TextStyle(font: regular, fontSize: 11),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 18),
            _amountGrid(report, bold, regular),
            pw.SizedBox(height: 20),
            _countsTable(report, bold, regular),
            pw.Spacer(),
            pw.Divider(),
            pw.Text(
              'كل الأرقام مشتقة من قيود الدفتر في ALIkhlasPOS v2.',
              style: pw.TextStyle(font: regular, fontSize: 9),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }

  static pw.Widget _amountGrid(
    PeriodReportSnapshot report,
    pw.Font bold,
    pw.Font regular,
  ) {
    final rows = [
      ('المبيعات', report.salesMinor),
      ('تكلفة البضاعة', report.cogsMinor),
      ('المصروفات', report.expensesMinor),
      ('الفوائد', report.interestMinor),
      ('الربح', report.profitMinor),
      ('صافي الكاش', report.cashNetMinor),
      ('صافي المحفظة', report.walletNetMinor),
      ('المشتريات', report.purchaseMinor),
    ];

    return pw.Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final row in rows)
          pw.Container(
            width: 170,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  row.$1,
                  style: pw.TextStyle(font: regular, fontSize: 9),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  Money(row.$2).formatPlain(),
                  style: pw.TextStyle(font: bold, fontSize: 13),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static pw.Widget _countsTable(
    PeriodReportSnapshot report,
    pw.Font bold,
    pw.Font regular,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [_cell('المؤشر', bold), _cell('القيمة', bold)],
        ),
        _countRow('عدد فواتير البيع', report.saleCount, regular),
        _countRow('عدد فواتير الشراء', report.purchaseCount, regular),
        _countRow('عدد المرتجعات', report.returnCount, regular),
      ],
    );
  }

  static pw.TableRow _countRow(String label, int count, pw.Font font) {
    return pw.TableRow(
      children: [_cell(label, font), _cell(count.toString(), font)],
    );
  }

  static pw.Widget _cell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 10),
        textAlign: pw.TextAlign.right,
      ),
    );
  }

  static String _date(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  static String _dateKey(DateTime value) {
    return '${value.year}${value.month.toString().padLeft(2, '0')}${value.day.toString().padLeft(2, '0')}';
  }
}

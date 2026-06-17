import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/receipt_service.dart';
import '../services/api_service.dart';

/// Generates a full A4 PDF sales report that can be printed or saved.
class ReportPdfService {
  static Future<void> exportSalesReport({
    required DateTime from,
    required DateTime to,
    required Map<String, dynamic> salesMetrics,
    required List<dynamic> topProducts,
    required Map<String, dynamic> inventoryMetrics,
  }) async {
    final settings = await ReceiptService.getShopSettings();
    final pdf = await _buildReportPdf(
      settings: settings,
      from: from,
      to: to,
      salesMetrics: salesMetrics,
      topProducts: topProducts,
      inventoryMetrics: inventoryMetrics,
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf,
      name: 'تقرير المبيعات — ${_fmt(from)} إلى ${_fmt(to)}',
    );
  }

  static Future<Uint8List> _buildReportPdf({
    required ShopSettingsModel settings,
    required DateTime from,
    required DateTime to,
    required Map<String, dynamic> salesMetrics,
    required List<dynamic> topProducts,
    required Map<String, dynamic> inventoryMetrics,
  }) async {
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBoldFont = await PdfGoogleFonts.cairoBold();

    final doc = pw.Document();

    final totalRevenue = (salesMetrics['totalRevenue'] as num?)?.toDouble() ?? 0;
    final totalCost = (salesMetrics['totalCost'] as num?)?.toDouble() ?? 0;
    final netProfit = (salesMetrics['netProfit'] as num?)?.toDouble() ?? 0;
    final totalRefunds = (salesMetrics['totalRefunds'] as num?)?.toDouble() ?? 0;
    final totalExpenses = (salesMetrics['totalExpenses'] as num?)?.toDouble() ?? 0;

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      header: (ctx) => _buildHeader(settings, arabicBoldFont, arabicFont, from, to),
      footer: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}', style: pw.TextStyle(font: arabicFont, fontSize: 9, color: PdfColors.grey600)),
          pw.Text(settings.shopName, style: pw.TextStyle(font: arabicFont, fontSize: 9, color: PdfColors.grey600)),
        ]),
      ),
      build: (ctx) => [
        // ── KPI Cards Row ──────────────────────────────────────────────────
        pw.Row(children: [
          _kpiCard('الإيرادات', _money(totalRevenue), PdfColors.blue700, arabicBoldFont, arabicFont),
          _kpiCard('التكلفة', _money(totalCost), PdfColors.orange700, arabicBoldFont, arabicFont),
          _kpiCard('المرتجعات', _money(totalRefunds), PdfColors.red700, arabicBoldFont, arabicFont),
          _kpiCard('المصروفات', _money(totalExpenses), PdfColors.purple700, arabicBoldFont, arabicFont),
          _kpiCard('صافي الربح', _money(netProfit), netProfit >= 0 ? PdfColors.green700 : PdfColors.red700, arabicBoldFont, arabicFont),
        ]),

        pw.SizedBox(height: 24),

        // ── Top Products Table ─────────────────────────────────────────────
        pw.Text('أكثر المنتجات مبيعاً', style: pw.TextStyle(font: arabicBoldFont, fontSize: 14)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(4),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: ['#', 'اسم المنتج', 'الكمية المباعة', 'الإيرادات']
                  .map((h) => _tCell(h, arabicBoldFont, isHeader: true))
                  .toList(),
            ),
            ...topProducts.asMap().entries.map((e) {
              final item = e.value as Map<String, dynamic>;
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: e.key.isEven ? PdfColors.white : const PdfColor(0.97, 0.97, 0.97),
                ),
                children: [
                  _tCell('${e.key + 1}', arabicFont),
                  _tCell(item['productName'] as String? ?? '', arabicFont),
                  _tCell('${item['quantitySold']}', arabicFont),
                  _tCell(_money((item['totalRevenue'] as num?)?.toDouble() ?? 0), arabicFont),
                ],
              );
            }),
          ],
        ),

        pw.SizedBox(height: 24),

        // ── Inventory Summary ───────────────────────────────────────────────
        pw.Text('ملخص المخزون', style: pw.TextStyle(font: arabicBoldFont, fontSize: 14)),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          _kpiCard('التكلفة الإجمالية للمخزون',
              _money((inventoryMetrics['TotalCostValue'] as num?)?.toDouble() ?? 0),
              PdfColors.orange700, arabicBoldFont, arabicFont),
          _kpiCard('القيمة البيعية المتوقعة',
              _money((inventoryMetrics['TotalRetailValue'] as num?)?.toDouble() ?? 0),
              PdfColors.blue700, arabicBoldFont, arabicFont),
          _kpiCard('الربح المتوقع',
              _money((inventoryMetrics['ExpectedProfit'] as num?)?.toDouble() ?? 0),
              PdfColors.green700, arabicBoldFont, arabicFont),
        ]),
      ],
    ));

    return doc.save();
  }

  static pw.Widget _buildHeader(
    ShopSettingsModel settings,
    pw.Font boldFont,
    pw.Font regularFont,
    DateTime from,
    DateTime to,
  ) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(settings.shopName, style: pw.TextStyle(font: boldFont, fontSize: 18)),
          if (settings.address != null)
            pw.Text(settings.address!, style: pw.TextStyle(font: regularFont, fontSize: 10, color: PdfColors.grey700)),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('تقرير المبيعات', style: pw.TextStyle(font: boldFont, fontSize: 16, color: PdfColors.indigo700)),
          pw.Text('${_fmt(from)} — ${_fmt(to)}', style: pw.TextStyle(font: regularFont, fontSize: 10, color: PdfColors.grey600)),
        ]),
      ]),
      pw.Divider(thickness: 1.5, color: PdfColors.indigo700),
      pw.SizedBox(height: 8),
    ]);
  }

  static pw.Widget _kpiCard(String label, String value, PdfColor color, pw.Font boldFont, pw.Font regularFont) {
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.all(4),
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: color, width: 1.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          pw.Text(value, style: pw.TextStyle(font: boldFont, fontSize: 14, color: color), textDirection: pw.TextDirection.rtl),
          pw.SizedBox(height: 4),
          pw.Text(label, style: pw.TextStyle(font: regularFont, fontSize: 9, color: PdfColors.grey700), textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.center),
        ]),
      ),
    );
  }

  static pw.Widget _tCell(String text, pw.Font font, {bool isHeader = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
    child: pw.Text(text,
      style: pw.TextStyle(font: font, fontSize: isHeader ? 10 : 9, fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal),
      textDirection: pw.TextDirection.rtl),
  );

  static String _money(double v) => '${v.toStringAsFixed(2)} ج.م';
  static String _fmt(DateTime dt) => '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
}

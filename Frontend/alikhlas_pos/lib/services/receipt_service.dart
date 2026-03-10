import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/invoice_model.dart';
import '../services/api_service.dart';
import '../core/utils/toast_service.dart';

/// ShopSettings model (matched to backend ShopSettings entity)
class ShopSettingsModel {
  final String shopName;
  final String? address;
  final String? phone;
  final String? receiptFooter;
  final bool vatEnabled;
  final double defaultVatRate;
  final String currencySymbol;

  const ShopSettingsModel({
    required this.shopName,
    this.address,
    this.phone,
    this.receiptFooter,
    this.vatEnabled = false,
    this.defaultVatRate = 14,
    this.currencySymbol = 'ج.م',
  });

  factory ShopSettingsModel.fromJson(Map<String, dynamic> j) => ShopSettingsModel(
        shopName: j['shopName'] as String? ?? 'إخلاص POS',
        address: j['address'] as String?,
        phone: j['phone'] as String?,
        receiptFooter: j['receiptFooter'] as String?,
        vatEnabled: j['vatEnabled'] as bool? ?? false,
        defaultVatRate: (j['defaultVatRate'] as num? ?? 14).toDouble(),
        currencySymbol: j['currencySymbol'] as String? ?? 'ج.م',
      );

  static ShopSettingsModel get defaults => const ShopSettingsModel(shopName: 'إخلاص POS');
}

/// Service for generating and printing thermal receipts (80mm).
class ReceiptService {
  static ShopSettingsModel? _cachedSettings;

  // ── Load shop settings (cached) ──────────────────────────────────────────

  static Future<ShopSettingsModel> getShopSettings() async {
    if (_cachedSettings != null) return _cachedSettings!;
    try {
      final data = await ApiService.get('shopsettings');
      _cachedSettings = ShopSettingsModel.fromJson(data);
      return _cachedSettings!;
    } catch (_) {
      return ShopSettingsModel.defaults;
    }
  }

  static void clearCache() => _cachedSettings = null;

  // ── Build and print receipt ────────────────────────────────────────────────

  static Future<void> printReceipt({
    required String invoiceNo,
    required DateTime date,
    required List<CartItemModel> items,
    required double subTotal,
    required double discountAmount,
    required double vatAmount,
    required double totalAmount,
    required double paidAmount,
    required double remaining,
    required String paymentType,
    String? customerName,
    String? cashierName,
    String? notes,
  }) async {
    final settings = await getShopSettings();
    final doc = await _buildPdf(
      settings: settings,
      invoiceNo: invoiceNo,
      date: date,
      items: items,
      subTotal: subTotal,
      discountAmount: discountAmount,
      vatAmount: vatAmount,
      totalAmount: totalAmount,
      paidAmount: paidAmount,
      remaining: remaining,
      paymentType: paymentType,
      customerName: customerName,
      cashierName: cashierName,
      notes: notes,
    );

    await _sendToPrinter(doc, 'إيصال $invoiceNo', 'receipt_printer');
  }

  /// Print a test page to verify printer setup
  static Future<void> printTestPage() async {
    final settings = await getShopSettings();
    final doc = pw.Document();

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.roll80.copyWith(marginTop: 0, marginBottom: 0, marginLeft: 2 * PdfPageFormat.mm, marginRight: 2 * PdfPageFormat.mm),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(settings.shopName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('صفحة اختبار الطباعة', style: const pw.TextStyle(fontSize: 14)),
          pw.Divider(),
          pw.Text('الطابعة تعمل بشكل صحيح ✓', style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 8),
          pw.Text(DateTime.now().toString()),
          pw.SizedBox(height: 20),
          pw.Text('--- نهاية الاختبار ---', style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    ));

    await _sendToPrinter(await doc.save(), 'اختبار الطباعة', 'receipt_printer');
  }

  static Future<void> _sendToPrinter(Uint8List docBytes, String jobName, String prefsKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final targetPrinterName = prefs.getString(prefsKey) ?? 'Default';

      final printers = await Printing.listPrinters();
      final printer = printers.firstWhere(
        (p) => p.name == targetPrinterName, 
        orElse: () => printers.firstWhere((p) => p.isDefault, orElse: () => printers.first)
      );

      final success = await Printing.directPrintPdf(
        printer: printer,
        onLayout: (format) async => docBytes,
        name: jobName,
      );

      if (!success) {
        ToastService.showError('تعذر الإرسال لطابعة الفواتير. يرجى التأكد من توصيلها وتشغيلها.');
      }
    } catch (e) {
      ToastService.showError('عفواً، يبدو أن طابعة الفواتير غير متصلة أو لا يوجد بها ورق. يرجى التحقق وإعادة المحاولة.');
    }
  }

  // ── Internal: Build PDF document ──────────────────────────────────────────

  static Future<Uint8List> _buildPdf({
    required ShopSettingsModel settings,
    required String invoiceNo,
    required DateTime date,
    required List<CartItemModel> items,
    required double subTotal,
    required double discountAmount,
    required double vatAmount,
    required double totalAmount,
    required double paidAmount,
    required double remaining,
    required String paymentType,
    String? customerName,
    String? cashierName,
    String? notes,
  }) async {
    // Load Arabic font for correct RTL rendering
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBoldFont = await PdfGoogleFonts.cairoBold();

    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        textDirection: pw.TextDirection.rtl,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ── Header ────────────────────────────────────────
            pw.Center(
              child: pw.Text(
                settings.shopName,
                style: pw.TextStyle(font: arabicBoldFont, fontSize: 16),
                textDirection: pw.TextDirection.rtl,
              ),
            ),
            if (settings.address != null)
              pw.Center(child: pw.Text(settings.address!, style: pw.TextStyle(font: arabicFont, fontSize: 9), textDirection: pw.TextDirection.rtl)),
            if (settings.phone != null)
              pw.Center(child: pw.Text('هاتف: ${settings.phone}', style: pw.TextStyle(font: arabicFont, fontSize: 9))),

            pw.Divider(thickness: 0.5),

            // ── Invoice Info ──────────────────────────────────
            _infoRow('رقم الفاتورة:', invoiceNo, arabicFont),
            _infoRow('التاريخ:', '${date.year}/${date.month.toString().padLeft(2,'0')}/${date.day.toString().padLeft(2,'0')}', arabicFont),
            if (customerName != null) _infoRow('العميل:', customerName, arabicFont),
            if (cashierName != null) _infoRow('الكاشير:', cashierName, arabicFont),

            pw.Divider(thickness: 0.5),

            // ── Items Table ───────────────────────────────────
            pw.Table(
              border: pw.TableBorder(horizontalInside: const pw.BorderSide(width: 0.3)),
              columnWidths: {
                0: const pw.FlexColumnWidth(4), // name
                1: const pw.FlexColumnWidth(1), // qty
                2: const pw.FlexColumnWidth(2), // price
                3: const pw.FlexColumnWidth(2), // total
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _cell('الصنف', arabicBoldFont, isHeader: true),
                    _cell('كمية', arabicBoldFont, isHeader: true),
                    _cell('سعر', arabicBoldFont, isHeader: true),
                    _cell('إجمالي', arabicBoldFont, isHeader: true),
                  ],
                ),
                // Data rows
                for (final item in items)
                  pw.TableRow(children: [
                    _cell(item.productName, arabicFont),
                    _cell('${item.quantity}', arabicFont),
                    _cell(_fmt(item.unitPrice), arabicFont),
                    _cell(_fmt(item.totalPrice), arabicFont),
                  ]),
              ],
            ),

            pw.Divider(thickness: 0.5),

            // ── Totals ────────────────────────────────────────
            if (discountAmount > 0) _totalRow('المجموع:', _fmt(subTotal), arabicFont),
            if (discountAmount > 0) _totalRow('الخصم:', '- ${_fmt(discountAmount)}', arabicFont),
            if (vatAmount > 0) _totalRow('ضريبة:', _fmt(vatAmount), arabicFont),
            _totalRow('الإجمالي:', _fmt(totalAmount), arabicBoldFont, bold: true),
            _totalRow('المدفوع:', _fmt(paidAmount), arabicFont),
            if (remaining > 0.001) _totalRow('المتبقي:', _fmt(remaining), arabicFont, warning: true),
            _totalRow('طريقة الدفع:', _paymentLabel(paymentType), arabicFont),

            if (notes != null && notes.isNotEmpty) ...[
              pw.SizedBox(height: 6),
              pw.Text('ملاحظة: $notes', style: pw.TextStyle(font: arabicFont, fontSize: 9), textDirection: pw.TextDirection.rtl),
            ],

            pw.Divider(thickness: 0.5),

            // ── Footer ────────────────────────────────────────
            pw.Center(
              child: pw.Text(
                settings.receiptFooter ?? 'شكراً لزيارتكم 🌟',
                style: pw.TextStyle(font: arabicFont, fontSize: 10),
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }

  // ── PDF helpers ──────────────────────────────────────────────────────────

  static pw.Widget _infoRow(String label, String value, pw.Font font) =>
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(value, style: pw.TextStyle(font: font, fontSize: 9)),
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: 9)),
      ]);

  static pw.Widget _totalRow(String label, String value, pw.Font font, {bool bold = false, bool warning = false}) =>
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(value, style: pw.TextStyle(font: font, fontSize: bold ? 12 : 10, color: warning ? PdfColors.red : null)),
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: bold ? 12 : 10)),
      ]);

  static pw.Widget _cell(String text, pw.Font font, {bool isHeader = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
        child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 9, fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal), textDirection: pw.TextDirection.rtl),
      );

  static String _fmt(double v) => v.toStringAsFixed(2);

  static String _paymentLabel(String type) => switch (type.toLowerCase()) {
        'cash' || '0' => 'نقدي',
        'card' || '1' => 'بطاقة',
        'installment' || '2' => 'أقساط',
        _ => type,
      };
}

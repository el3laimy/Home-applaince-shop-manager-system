import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_model.dart';
import '../core/utils/toast_service.dart';

/// Label size configurations
class LabelSize {
  final String name;
  final double widthMm;
  final double heightMm;
  final double barcodeFontSize;
  final double nameFontSize;
  final double priceFontSize;
  final double barcodeWidth;
  final double barcodeHeight;

  const LabelSize({
    required this.name,
    required this.widthMm,
    required this.heightMm,
    this.barcodeFontSize = 7,
    this.nameFontSize = 8,
    this.priceFontSize = 7,
    this.barcodeWidth = 120,
    this.barcodeHeight = 35,
  });

  PdfPageFormat get pageFormat =>
      PdfPageFormat(widthMm * PdfPageFormat.mm, heightMm * PdfPageFormat.mm, marginAll: 0);

  static const LabelSize size50x25 = LabelSize(
    name: '50x25',
    widthMm: 50,
    heightMm: 25,
    barcodeFontSize: 7,
    nameFontSize: 8,
    priceFontSize: 7,
    barcodeWidth: 120,
    barcodeHeight: 35,
  );

  static const LabelSize size50x30 = LabelSize(
    name: '50x30',
    widthMm: 50,
    heightMm: 30,
    barcodeFontSize: 8,
    nameFontSize: 9,
    priceFontSize: 8,
    barcodeWidth: 125,
    barcodeHeight: 40,
  );

  static const LabelSize size40x20 = LabelSize(
    name: '40x20',
    widthMm: 40,
    heightMm: 20,
    barcodeFontSize: 6,
    nameFontSize: 7,
    priceFontSize: 6,
    barcodeWidth: 95,
    barcodeHeight: 28,
  );

  static const List<LabelSize> all = [size50x25, size50x30, size40x20];

  static LabelSize fromName(String name) =>
      all.firstWhere((s) => s.name == name, orElse: () => size50x25);
}

class BarcodePrintService {
  /// Generate a PDF label for a product with configurable label size
  static Future<void> printProductLabel(
    ProductModel product,
    int quantity, {
    LabelSize labelSize = LabelSize.size50x25,
  }) async {
    final barcodeData = product.globalBarcode.isNotEmpty
        ? product.globalBarcode
        : product.internalBarcode ?? '';
    if (barcodeData.isEmpty) {
      ToastService.showError('المنتج ليس له باركود للطباعة');
      return;
    }

    final doc = pw.Document();

    for (var i = 0; i < quantity; i++) {
      doc.addPage(_buildLabelPage(
        name: product.name,
        barcodeData: barcodeData,
        price: product.price,
        labelSize: labelSize,
      ));
    }

    await _sendToPrinter(doc, 'Barcode_${product.name}', 'label_printer');
  }

  /// Generate a single PDF with labels for multiple products (batch print)
  static Future<void> printBatchLabels(
    List<ProductModel> products,
    Map<String, int> quantities, {
    LabelSize labelSize = LabelSize.size50x25,
  }) async {
    final doc = pw.Document();
    int totalLabels = 0;

    for (final product in products) {
      final barcodeData = product.globalBarcode.isNotEmpty
          ? product.globalBarcode
          : product.internalBarcode ?? '';
      if (barcodeData.isEmpty) continue;

      final qty = quantities[product.id] ?? 1;
      for (var i = 0; i < qty; i++) {
        doc.addPage(_buildLabelPage(
          name: product.name,
          barcodeData: barcodeData,
          price: product.price,
          labelSize: labelSize,
        ));
        totalLabels++;
      }
    }

    if (totalLabels == 0) {
      ToastService.showError('لا توجد منتجات بها باركود للطباعة');
      return;
    }

    await _sendToPrinter(doc, 'Batch_Labels_${products.length}', 'label_printer');
    ToastService.showSuccess('تم إرسال $totalLabels ملصق للطباعة ✓');
  }

  /// Builds a single label page with configurable dimensions
  static pw.Page _buildLabelPage({
    required String name,
    required String barcodeData,
    required double price,
    required LabelSize labelSize,
  }) {
    return pw.Page(
      pageFormat: labelSize.pageFormat,
      build: (pw.Context context) {
        return pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                child: pw.Text(
                  name,
                  style: pw.TextStyle(
                    fontSize: labelSize.nameFontSize,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 2),
              // Quiet Zone: horizontal padding ensures scanner readability
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8),
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(), // Vector-based drawing
                  data: barcodeData,
                  width: labelSize.barcodeWidth,
                  height: labelSize.barcodeHeight,
                  drawText: true,
                  textStyle: pw.TextStyle(fontSize: labelSize.barcodeFontSize),
                ),
              ),
              pw.SizedBox(height: 1),
              pw.Text(
                'السعر: ${price.toStringAsFixed(2)} ج.م',
                style: pw.TextStyle(fontSize: labelSize.priceFontSize),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Prints a calibration label with configurable size
  static Future<void> printCalibrationLabel({
    LabelSize labelSize = LabelSize.size50x25,
  }) async {
    final doc = pw.Document();

    doc.addPage(pw.Page(
      pageFormat: labelSize.pageFormat,
      build: (ctx) => pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 1),
        ),
        child: pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('CALIBRATION TEST',
                  style: pw.TextStyle(
                    fontSize: labelSize.nameFontSize,
                    fontWeight: pw.FontWeight.bold,
                  )),
              pw.SizedBox(height: 2),
              pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: 'TEST-12345',
                width: labelSize.barcodeWidth - 20,
                height: labelSize.barcodeHeight - 5,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '${labelSize.widthMm.toInt()}x${labelSize.heightMm.toInt()}mm — Border = label edges',
                style: pw.TextStyle(fontSize: labelSize.priceFontSize - 1),
              ),
            ],
          ),
        ),
      ),
    ));

    await _sendToPrinter(doc, 'Calibration_${labelSize.name}', 'label_printer');
  }

  /// Send the PDF document to the configured label printer
  static Future<void> _sendToPrinter(
    pw.Document doc,
    String jobName,
    String prefsKey,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final targetPrinterName = prefs.getString(prefsKey) ?? 'Default';

      // Proactive check: list printers and find the match
      final printers = await Printing.listPrinters();
      if (printers.isEmpty) {
        ToastService.showError('لم يتم العثور على أي طابعة متصلة.');
        return;
      }

      final printer = printers.firstWhere(
        (p) => p.name == targetPrinterName,
        orElse: () => printers.firstWhere(
          (p) => p.isDefault,
          orElse: () => printers.first,
        ),
      );

      // Direct silent print
      final success = await Printing.directPrintPdf(
        printer: printer,
        onLayout: (format) async => doc.save(),
        name: jobName,
      );

      if (!success) {
        ToastService.showError(
          'تعذر الإرسال للطابعة. تأكد من توصيل الكابل وتشغيل الطابعة.',
        );
      }
    } catch (e) {
      ToastService.showError(
        'خطأ في الطباعة: عفواً، يبدو أن الطابعة غير متصلة أو لا يوجد بها ورق.',
      );
    }
  }
}

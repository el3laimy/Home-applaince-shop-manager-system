import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_model.dart';
import '../core/utils/toast_service.dart';

class BarcodePrintService {
  /// Generate a PDF label for a product (e.g. 50mm x 25mm barcode label)
  static Future<void> printProductLabel(ProductModel product, int quantity) async {
    // 50mm x 25mm is approx 141 x 70 in standard PDF points (1 mm = 2.83 pt)
    // marginAll: 0 is CRITICAL to prevent Windows printer auto-scaling
    final format = PdfPageFormat(50 * PdfPageFormat.mm, 25 * PdfPageFormat.mm, marginAll: 0);
    
    final doc = pw.Document();
    
    final barcodeData = product.globalBarcode.isNotEmpty ? product.globalBarcode : product.internalBarcode ?? '';
    if (barcodeData.isEmpty) return; // Cannot print label without barcode
    
    // Create a page for each label requested
    for (var i = 0; i < quantity; i++) {
        doc.addPage(
          pw.Page(
            pageFormat: format,
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                      child: pw.Text(
                        product.name,
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
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
                        width: 120,
                        height: 35,
                        drawText: true,
                        textStyle: pw.TextStyle(fontSize: 7),
                      ),
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      'Price: ${product.price.toStringAsFixed(2)} EGP',
                      style: const pw.TextStyle(fontSize: 7),
                    ),
                  ],
                )
              );
            }
          )
        );
    }
    
    await _sendToPrinter(doc, 'Barcode_${product.name}', 'label_printer');
  }

  /// Prints a boundary box and sample barcode to help user calibrate paper size
  static Future<void> printCalibrationLabel() async {
    final format = PdfPageFormat(50 * PdfPageFormat.mm, 25 * PdfPageFormat.mm, marginAll: 0);
    final doc = pw.Document();

    doc.addPage(pw.Page(
      pageFormat: format,
      build: (ctx) => pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1)),
        child: pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('CALIBRATION TEST', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: 'TEST-12345',
                width: 100,
                height: 30,
              ),
              pw.SizedBox(height: 2),
              pw.Text('Border should align with label edges', style: const pw.TextStyle(fontSize: 5)),
            ],
          ),
        ),
      ),
    ));

    await _sendToPrinter(doc, 'Calibration_Label', 'label_printer');
  }

  static Future<void> _sendToPrinter(pw.Document doc, String jobName, String prefsKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final targetPrinterName = prefs.getString(prefsKey) ?? 'Default';

      // Proactive check: list printers and find the match
      final printers = await Printing.listPrinters();
      final printer = printers.firstWhere((p) => p.name == targetPrinterName, orElse: () => printers.firstWhere((p) => p.isDefault, orElse: () => printers.first));

      if (targetPrinterName != 'Default' && targetPrinterName != printer.name) {
          // If a specific printer was wanted but not found, we can warn but usually Printing handles it
      }

      // Direct silent print
      final success = await Printing.directPrintPdf(
        printer: printer,
        onLayout: (format) async => doc.save(),
        name: jobName,
      );

      if (!success) {
        ToastService.showError('تعذر الإرسال للطابعة. تأكد من توصيل الكابل وتشغيل الطابعة.');
      }
    } catch (e) {
      ToastService.showError('خطأ في الطباعة: عفواً، يبدو أن الطابعة غير متصلة أو لا يوجد بها ورق.');
    }
  }
}

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/product_model.dart';

class BarcodePrintService {
  /// Generate a PDF label for a product (e.g. 50mm x 25mm barcode label)
  static Future<void> printProductLabel(ProductModel product, int quantity) async {
    // 50mm x 25mm is approx 141 x 70 in standard PDF points (1 mm = 2.83 pt)
    final format = PdfPageFormat(50 * PdfPageFormat.mm, 25 * PdfPageFormat.mm, marginAll: 2 * PdfPageFormat.mm);
    
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
                    pw.Text(
                      product.name,
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                      maxLines: 1,
                      overflow: pw.TextOverflow.clip,
                    ),
                    pw.SizedBox(height: 2),
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.code128(), // Code128 supports alphanumeric
                      data: barcodeData,
                      width: 100,
                      height: 30,
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
    
    // Display the print dialog natively 
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat printFormat) async => doc.save(),
      name: 'Barcode_${product.name}',
    );
  }
}

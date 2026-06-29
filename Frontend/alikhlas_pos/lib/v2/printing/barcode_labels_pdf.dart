import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'pdf_fonts.dart';

class BarcodeLabelItem {
  const BarcodeLabelItem({
    required this.productName,
    required this.barcode,
    required this.quantity,
  });

  final String productName;
  final String? barcode;
  final int quantity;

  bool get canPrint => barcode?.trim().isNotEmpty == true && quantity > 0;
}

class BarcodeLabelsPdf {
  const BarcodeLabelsPdf._();

  static final defaultLabelFormat = labelFormat(widthMm: 40, heightMm: 30);

  static PdfPageFormat labelFormat({
    required int widthMm,
    required int heightMm,
  }) {
    return PdfPageFormat(
      widthMm * PdfPageFormat.mm,
      heightMm * PdfPageFormat.mm,
      marginAll: 2 * PdfPageFormat.mm,
    );
  }

  static final label40x30 = PdfPageFormat(
    40 * PdfPageFormat.mm,
    30 * PdfPageFormat.mm,
    marginAll: 2 * PdfPageFormat.mm,
  );

  static List<BarcodeLabelItem> printableItems(List<BarcodeLabelItem> items) {
    return [
      for (final labelItem in items)
        if (labelItem.canPrint)
          BarcodeLabelItem(
            productName: labelItem.productName.trim(),
            barcode: labelItem.barcode!.trim(),
            quantity: labelItem.quantity,
          ),
    ];
  }

  static int printableCount(List<BarcodeLabelItem> items) {
    return printableItems(
      items,
    ).fold<int>(0, (sum, labelItem) => sum + labelItem.quantity);
  }

  static Future<void> printLabels(
    List<BarcodeLabelItem> items, {
    PdfPageFormat? pageFormat,
  }) async {
    final bytes = await build(items, pageFormat: pageFormat);
    await Printing.layoutPdf(
      name: 'barcode-labels',
      onLayout: (_) async => bytes,
    );
  }

  static Future<Uint8List> build(
    List<BarcodeLabelItem> items, {
    PdfPageFormat? pageFormat,
  }) async {
    final labels = printableItems(items);
    if (labels.isEmpty) {
      throw ArgumentError('لا توجد ملصقات باركود صالحة للطباعة');
    }

    final fonts = await PdfFonts.loadCairo();
    final regular = fonts.regular;
    final bold = fonts.bold;
    final theme = pw.ThemeData.withFont(base: regular, bold: bold);
    final doc = pw.Document(theme: theme);
    final barcode = Barcode.code128();

    for (final labelItem in labels) {
      for (var copy = 0; copy < labelItem.quantity; copy++) {
        doc.addPage(
          pw.Page(
            pageFormat: pageFormat ?? defaultLabelFormat,
            textDirection: pw.TextDirection.rtl,
            build: (context) => _label(labelItem, barcode, regular, bold),
          ),
        );
      }
    }

    return doc.save();
  }

  static pw.Widget _label(
    BarcodeLabelItem labelItem,
    Barcode barcode,
    pw.Font regular,
    pw.Font bold,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.SizedBox(
          height: 8 * PdfPageFormat.mm,
          child: pw.Center(
            child: pw.Text(
              labelItem.productName,
              maxLines: 2,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: bold, fontSize: 8),
            ),
          ),
        ),
        pw.Expanded(
          child: pw.BarcodeWidget(
            barcode: barcode,
            data: labelItem.barcode!,
            drawText: false,
            color: PdfColors.black,
            backgroundColor: PdfColors.white,
            padding: const pw.EdgeInsets.symmetric(horizontal: 1),
          ),
        ),
        pw.SizedBox(height: 1.5 * PdfPageFormat.mm),
        pw.Center(
          child: pw.Text(
            labelItem.barcode!,
            textDirection: pw.TextDirection.ltr,
            style: pw.TextStyle(font: regular, fontSize: 7),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfCairoFonts {
  const PdfCairoFonts({required this.regular, required this.bold});

  final pw.Font regular;
  final pw.Font bold;
}

class PdfFonts {
  const PdfFonts._();

  static Future<PdfCairoFonts> loadCairo() async {
    final regularData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    return PdfCairoFonts(
      regular: pw.Font.ttf(regularData),
      bold: pw.Font.ttf(boldData),
    );
  }
}

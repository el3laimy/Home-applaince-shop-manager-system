import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../application/v2_use_cases.dart';
import '../core/money.dart';

class SaleReceiptPdf {
  const SaleReceiptPdf._();

  static Future<void> printReceipt(SaleReceiptSnapshot receipt) async {
    final bytes = await build(receipt);
    await Printing.layoutPdf(
      name: receipt.invoice.invoiceNo,
      onLayout: (_) async => bytes,
    );
  }

  static Future<Uint8List> build(SaleReceiptSnapshot receipt) async {
    final regular = await PdfGoogleFonts.cairoRegular();
    final bold = await PdfGoogleFonts.cairoBold();
    final theme = pw.ThemeData.withFont(base: regular, bold: bold);
    final doc = pw.Document(theme: theme);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80.copyWith(
          marginLeft: 4 * PdfPageFormat.mm,
          marginRight: 4 * PdfPageFormat.mm,
          marginTop: 6 * PdfPageFormat.mm,
          marginBottom: 6 * PdfPageFormat.mm,
        ),
        textDirection: pw.TextDirection.rtl,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              child: pw.Text(
                receipt.shopSettings.shopName,
                style: pw.TextStyle(font: bold, fontSize: 15),
              ),
            ),
            if (receipt.shopSettings.phone != null)
              pw.Center(
                child: pw.Text(
                  receipt.shopSettings.phone!,
                  style: pw.TextStyle(font: regular, fontSize: 9),
                ),
              ),
            if (receipt.shopSettings.address != null)
              pw.Center(
                child: pw.Text(
                  receipt.shopSettings.address!,
                  style: pw.TextStyle(font: regular, fontSize: 9),
                ),
              ),
            pw.SizedBox(height: 2),
            pw.Center(
              child: pw.Text(
                'فاتورة بيع',
                style: pw.TextStyle(font: regular, fontSize: 10),
              ),
            ),
            pw.Divider(),
            _info('رقم الفاتورة', receipt.invoice.invoiceNo, bold, regular),
            _info(
              'التاريخ',
              _dateTime(receipt.invoice.createdAt),
              bold,
              regular,
            ),
            _info('العميل', receipt.customerName ?? 'نقدي', bold, regular),
            pw.Divider(),
            _table(receipt, bold, regular),
            pw.Divider(),
            _amount('الإجمالي', receipt.invoice.subtotalMinor, bold, regular),
            if (receipt.invoice.discountMinor > 0)
              _amount('الخصم', receipt.invoice.discountMinor, bold, regular),
            if (receipt.invoice.interestMinor > 0)
              _amount(
                'فائدة التقسيط',
                receipt.invoice.interestMinor,
                bold,
                regular,
              ),
            _amount('المطلوب', receipt.invoice.totalMinor, bold, regular),
            _amount('المدفوع', receipt.invoice.paidMinor, bold, regular),
            if (receipt.invoice.remainingMinor > 0)
              _amount('المتبقي', receipt.invoice.remainingMinor, bold, regular),
            if (receipt.payments.isNotEmpty) ...[
              pw.SizedBox(height: 6),
              pw.Text(
                'المدفوعات',
                style: pw.TextStyle(font: bold, fontSize: 10),
              ),
              for (final payment in receipt.payments)
                _amount(
                  _paymentMethodLabel(payment.method),
                  payment.amountMinor,
                  bold,
                  regular,
                ),
            ],
            pw.SizedBox(height: 10),
            if (receipt.shopSettings.receiptFooter != null)
              pw.Center(
                child: pw.Text(
                  receipt.shopSettings.receiptFooter!,
                  style: pw.TextStyle(font: regular, fontSize: 9),
                ),
              ),
          ],
        ),
      ),
    );

    return doc.save();
  }

  static pw.Widget _table(
    SaleReceiptSnapshot receipt,
    pw.Font bold,
    pw.Font regular,
  ) {
    return pw.Table(
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.4),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.5),
        1: pw.FlexColumnWidth(0.7),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _cell('الصنف', bold),
            _cell('كمية', bold),
            _cell('سعر', bold),
            _cell('إجمالي', bold),
          ],
        ),
        for (final line in receipt.lines)
          pw.TableRow(
            children: [
              _cell(line.productName, regular),
              _cell(line.qty.toString(), regular),
              _cell(Money(line.unitPriceMinor).format(), regular),
              _cell(Money(line.lineTotalMinor).format(), regular),
            ],
          ),
      ],
    );
  }

  static pw.Widget _cell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 8),
        textAlign: pw.TextAlign.right,
      ),
    );
  }

  static pw.Widget _info(
    String label,
    String value,
    pw.Font bold,
    pw.Font regular,
  ) {
    return pw.Row(
      children: [
        pw.Text('$label: ', style: pw.TextStyle(font: bold, fontSize: 9)),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(font: regular, fontSize: 9),
          ),
        ),
      ],
    );
  }

  static pw.Widget _amount(
    String label,
    int amountMinor,
    pw.Font bold,
    pw.Font regular,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 9)),
        pw.Text(
          Money(amountMinor).format(),
          style: pw.TextStyle(font: regular, fontSize: 9),
        ),
      ],
    );
  }

  static String _paymentMethodLabel(PaymentMethod method) {
    return switch (method) {
      PaymentMethod.cash => 'كاش',
      PaymentMethod.wallet => 'محفظة',
      PaymentMethod.installment => 'تقسيط',
    };
  }

  static String _dateTime(DateTime value) {
    final date =
        '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    final time =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}

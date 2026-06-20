import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../application/v2_use_cases.dart';
import '../core/money.dart';

class PartyStatementPdf {
  const PartyStatementPdf._();

  static Future<void> printStatement({
    required PartyBalance party,
    required List<PartyStatementLine> statement,
    required ShopSettingsSnapshot settings,
  }) async {
    final bytes = await build(
      party: party,
      statement: statement,
      settings: settings,
    );
    await Printing.layoutPdf(
      name: 'alikhlas-${party.type}-${party.id}-statement',
      onLayout: (_) async => bytes,
    );
  }

  static Future<Uint8List> build({
    required PartyBalance party,
    required List<PartyStatementLine> statement,
    required ShopSettingsSnapshot settings,
  }) async {
    final regular = await PdfGoogleFonts.cairoRegular();
    final bold = await PdfGoogleFonts.cairoBold();
    final theme = pw.ThemeData.withFont(base: regular, bold: bold);
    final doc = pw.Document(theme: theme);
    final debit = statement.fold<int>(0, (sum, line) => sum + line.debitMinor);
    final credit = statement.fold<int>(
      0,
      (sum, line) => sum + line.creditMinor,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (context) => [
          pw.Text(
            settings.shopName,
            style: pw.TextStyle(font: bold, fontSize: 22),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'كشف حساب ${party.type == 'supplier' ? 'مورد' : 'عميل'}: ${party.name}',
            style: pw.TextStyle(font: bold, fontSize: 15),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 16),
          _summaryGrid(
            party,
            (movementCount: statement.length, debit: debit, credit: credit),
            bold,
            regular,
          ),
          pw.SizedBox(height: 16),
          _statementTable(statement, bold, regular),
          pw.SizedBox(height: 18),
          _invoiceDetailsSection(statement, bold, regular),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _summaryGrid(
    PartyBalance party,
    ({int movementCount, int debit, int credit}) totals,
    pw.Font bold,
    pw.Font regular,
  ) {
    final rows = [
      ('الحركات', totals.movementCount.toString()),
      ('مدين', Money(totals.debit).format()),
      ('دائن', Money(totals.credit).format()),
      ('الرصيد الحالي', Money(party.balanceMinor).format()),
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
                pw.Text(row.$2, style: pw.TextStyle(font: bold, fontSize: 12)),
              ],
            ),
          ),
      ],
    );
  }

  static pw.Widget _statementTable(
    List<PartyStatementLine> statement,
    pw.Font bold,
    pw.Font regular,
  ) {
    if (statement.isEmpty) {
      return pw.Center(
        child: pw.Text('لا توجد حركات', style: pw.TextStyle(font: regular)),
      );
    }
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.2),
        1: pw.FlexColumnWidth(1.2),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.2),
        4: pw.FlexColumnWidth(1.2),
        5: pw.FlexColumnWidth(1.5),
        6: pw.FlexColumnWidth(2.2),
        7: pw.FlexColumnWidth(1.4),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _cell('الرصيد', bold),
            _cell('المتبقي', bold),
            _cell('المدفوع', bold),
            _cell('الإجمالي', bold),
            _cell('الحركة', bold),
            _cell('الرقم', bold),
            _cell('البيان', bold),
            _cell('التاريخ', bold),
          ],
        ),
        for (final line in statement)
          pw.TableRow(
            children: [
              _cell(Money(line.balanceMinor).format(), regular),
              _cell(
                _invoiceMoney(line.invoiceDetails?.remainingMinor),
                regular,
              ),
              _cell(_invoiceMoney(line.invoiceDetails?.paidMinor), regular),
              _cell(_invoiceMoney(line.invoiceDetails?.totalMinor), regular),
              _cell(_movementAmount(line), regular),
              _cell(line.invoiceDetails?.invoiceNo ?? '-', regular),
              _cell(line.entry.description, regular),
              _cell(_date(line.entry.createdAt), regular),
            ],
          ),
      ],
    );
  }

  static pw.Widget _invoiceDetailsSection(
    List<PartyStatementLine> statement,
    pw.Font bold,
    pw.Font regular,
  ) {
    final invoices = <String, StatementInvoiceDetails>{};
    for (final line in statement) {
      final details = line.invoiceDetails;
      if (details != null) invoices[details.invoiceNo] = details;
    }
    if (invoices.isEmpty) return pw.SizedBox.shrink();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          'تفاصيل الفواتير',
          style: pw.TextStyle(font: bold, fontSize: 14),
        ),
        pw.SizedBox(height: 8),
        for (final details in invoices.values) ...[
          _invoiceBlock(details, bold, regular),
          pw.SizedBox(height: 10),
        ],
      ],
    );
  }

  static pw.Widget _invoiceBlock(
    StatementInvoiceDetails details,
    pw.Font bold,
    pw.Font regular,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            '${details.type == 'purchase' ? 'فاتورة شراء' : 'فاتورة بيع'} ${details.invoiceNo} · الإجمالي ${Money(details.totalMinor).format()} · المدفوع ${Money(details.paidMinor).format()} · المتبقي ${Money(details.remainingMinor).format()}',
            style: pw.TextStyle(font: bold, fontSize: 10),
            textAlign: pw.TextAlign.right,
          ),
          pw.SizedBox(height: 6),
          _invoiceItemsTable(details.items, bold, regular),
          if (details.payments.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text('المدفوعات', style: pw.TextStyle(font: bold, fontSize: 9)),
            for (final payment in details.payments)
              pw.Text(
                '${_paymentLabel(payment.method)} · ${Money(payment.amountMinor).format()} · ${_date(payment.createdAt)}',
                style: pw.TextStyle(font: regular, fontSize: 8),
                textAlign: pw.TextAlign.right,
              ),
          ],
          if (details.installments.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text('الأقساط', style: pw.TextStyle(font: bold, fontSize: 9)),
            for (final installment in details.installments)
              pw.Text(
                '${_date(installment.dueDate)} · ${Money(installment.amountMinor).format()} · ${installment.status == 'paid' ? 'مدفوع' : 'مستحق'}',
                style: pw.TextStyle(font: regular, fontSize: 8),
                textAlign: pw.TextAlign.right,
              ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _invoiceItemsTable(
    List<StatementInvoiceItem> items,
    pw.Font bold,
    pw.Font regular,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.2),
        1: pw.FlexColumnWidth(1.2),
        2: pw.FlexColumnWidth(0.8),
        3: pw.FlexColumnWidth(2.4),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _cell('الإجمالي', bold),
            _cell('السعر', bold),
            _cell('كمية', bold),
            _cell('الصنف', bold),
          ],
        ),
        for (final item in items)
          pw.TableRow(
            children: [
              _cell(Money(item.lineTotalMinor).format(), regular),
              _cell(Money(item.unitMinor).format(), regular),
              _cell(item.qty.toString(), regular),
              _cell(item.productName, regular),
            ],
          ),
      ],
    );
  }

  static pw.Widget _cell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(7),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 9),
        textAlign: pw.TextAlign.right,
      ),
    );
  }

  static String _date(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  static String _invoiceMoney(int? amountMinor) {
    return amountMinor == null ? '-' : Money(amountMinor).format();
  }

  static String _movementAmount(PartyStatementLine line) {
    final amount = line.debitMinor > 0 ? line.debitMinor : line.creditMinor;
    return Money(amount).format();
  }

  static String _paymentLabel(PaymentMethod method) {
    return switch (method) {
      PaymentMethod.cash => 'كاش',
      PaymentMethod.wallet => 'محفظة',
      PaymentMethod.installment => 'تقسيط',
    };
  }
}

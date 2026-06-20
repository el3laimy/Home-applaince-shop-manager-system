import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../application/v2_use_cases.dart';
import '../core/money.dart';
import 'pdf_fonts.dart';

class PartyStatementPdf {
  const PartyStatementPdf._();

  static Future<void> printStatement({
    required PartyBalance party,
    required List<PartyStatementLine> statement,
    required ShopSettingsSnapshot settings,
  }) async {
    await Printing.layoutPdf(
      name: 'alikhlas-${party.type}-${party.id}-statement',
      onLayout: (format) => build(
        party: party,
        statement: statement,
        settings: settings,
        pageFormat: format,
      ),
    );
  }

  static Future<Uint8List> build({
    required PartyBalance party,
    required List<PartyStatementLine> statement,
    required ShopSettingsSnapshot settings,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) async {
    final fonts = await PdfFonts.loadCairo();
    final regular = fonts.regular;
    final bold = fonts.bold;
    final theme = pw.ThemeData.withFont(base: regular, bold: bold);
    final doc = pw.Document(theme: theme);
    final debit = statement.fold<int>(0, (sum, line) => sum + line.debitMinor);
    final credit = statement.fold<int>(
      0,
      (sum, line) => sum + line.creditMinor,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(18),
        textDirection: pw.TextDirection.rtl,
        build: (context) => [
          _header(party, settings, bold, regular),
          pw.SizedBox(height: 12),
          _summaryGrid(
            party,
            (movementCount: statement.length, debit: debit, credit: credit),
            bold,
            regular,
          ),
          pw.SizedBox(height: 14),
          _sectionTitle('حركات الحساب', bold),
          pw.SizedBox(height: 8),
          _movementCards(statement, bold, regular),
          pw.SizedBox(height: 16),
          _invoiceDetailsSection(statement, bold, regular),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _header(
    PartyBalance party,
    ShopSettingsSnapshot settings,
    pw.Font bold,
    pw.Font regular,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            settings.shopName,
            style: pw.TextStyle(font: bold, fontSize: 18),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'كشف حساب ${party.type == 'supplier' ? 'مورد' : 'عميل'}',
            style: pw.TextStyle(font: bold, fontSize: 13),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 6),
          _infoLine('الاسم', party.name, bold, regular),
          if (party.phone != null)
            _infoLine('الهاتف', party.phone!, bold, regular),
        ],
      ),
    );
  }

  static pw.Widget _summaryGrid(
    PartyBalance party,
    ({int movementCount, int debit, int credit}) totals,
    pw.Font bold,
    pw.Font regular,
  ) {
    final rows = [
      ('عدد الحركات', totals.movementCount.toString()),
      ('إجمالي مدين', _money(totals.debit)),
      ('إجمالي دائن', _money(totals.credit)),
      ('الرصيد الحالي', _money(party.balanceMinor)),
    ];
    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final row in rows)
          _metricBox(
            row.$1,
            row.$2,
            bold,
            regular,
            strong: row.$1 == 'الرصيد الحالي',
          ),
      ],
    );
  }

  static pw.Widget _movementCards(
    List<PartyStatementLine> statement,
    pw.Font bold,
    pw.Font regular,
  ) {
    if (statement.isEmpty) {
      return pw.Center(
        child: pw.Text('لا توجد حركات', style: pw.TextStyle(font: regular)),
      );
    }
    return pw.Column(
      children: [
        for (final line in statement) ...[
          _movementCard(line, bold, regular),
          pw.SizedBox(height: 8),
        ],
      ],
    );
  }

  static pw.Widget _movementCard(
    PartyStatementLine line,
    pw.Font bold,
    pw.Font regular,
  ) {
    final details = line.invoiceDetails;
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(7),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Text(
                  details == null
                      ? line.entry.description
                      : '${_invoiceType(details)} ${details.invoiceNo}',
                  style: pw.TextStyle(font: bold, fontSize: 10.5),
                  textAlign: pw.TextAlign.right,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                _date(line.entry.createdAt),
                style: pw.TextStyle(font: regular, fontSize: 8.5),
              ),
            ],
          ),
          if (details != null) ...[
            pw.SizedBox(height: 6),
            pw.Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _metricBox(
                  'صافي الفاتورة',
                  _money(details.totalMinor),
                  bold,
                  regular,
                ),
                _metricBox('المدفوع', _money(details.paidMinor), bold, regular),
                _metricBox(
                  'المتبقي',
                  _money(details.remainingMinor),
                  bold,
                  regular,
                ),
                _metricBox(
                  'الرصيد بعد الحركة',
                  _money(line.balanceMinor),
                  bold,
                  regular,
                  strong: true,
                ),
              ],
            ),
          ] else ...[
            pw.SizedBox(height: 6),
            pw.Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _metricBox('قيمة الحركة', _movementAmount(line), bold, regular),
                _metricBox(
                  'الرصيد بعد الحركة',
                  _money(line.balanceMinor),
                  bold,
                  regular,
                  strong: true,
                ),
              ],
            ),
          ],
        ],
      ),
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
        _sectionTitle('تفاصيل الفواتير', bold),
        pw.SizedBox(height: 8),
        for (final details in invoices.values) ...[
          _invoiceBlock(details, bold, regular),
          pw.SizedBox(height: 12),
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
        border: pw.Border.all(color: PdfColors.grey400, width: 0.55),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            '${_invoiceType(details)} ${details.invoiceNo} - ${_date(details.createdAt)}',
            style: pw.TextStyle(font: bold, fontSize: 11.5),
            textAlign: pw.TextAlign.right,
          ),
          pw.SizedBox(height: 8),
          _invoiceItemsTable(details.items, bold, regular),
          pw.SizedBox(height: 8),
          _invoiceTotals(details, bold, regular),
          if (details.payments.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            _sectionTitle('المدفوعات', bold, fontSize: 10),
            pw.SizedBox(height: 4),
            for (final payment in details.payments)
              _plainLine(
                '${_paymentLabel(payment.method)} - ${_money(payment.amountMinor)} - ${_date(payment.createdAt)}',
                regular,
              ),
          ],
          if (details.installments.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            _sectionTitle('الأقساط', bold, fontSize: 10),
            pw.SizedBox(height: 4),
            for (final installment in details.installments)
              _plainLine(
                'استحقاق ${_date(installment.dueDate)} - ${_money(installment.amountMinor)} - ${installment.status == 'paid' ? 'مدفوع' : 'مستحق'}',
                regular,
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
        0: pw.FlexColumnWidth(1.25),
        1: pw.FlexColumnWidth(1.25),
        2: pw.FlexColumnWidth(0.75),
        3: pw.FlexColumnWidth(2.8),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _cell('إجمالي السطر', bold),
            _cell('سعر الوحدة', bold),
            _cell('الكمية', bold),
            _cell('الصنف', bold),
          ],
        ),
        for (final item in items)
          pw.TableRow(
            children: [
              _cell(_money(item.lineTotalMinor), regular),
              _cell(_money(item.unitMinor), regular),
              _cell(item.qty.toString(), regular),
              _cell(item.productName, regular),
            ],
          ),
      ],
    );
  }

  static pw.Widget _invoiceTotals(
    StatementInvoiceDetails details,
    pw.Font bold,
    pw.Font regular,
  ) {
    final itemsTotal = details.subtotalMinor ?? _itemsTotal(details.items);
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          _amountLine('إجمالي الأصناف قبل الخصم', itemsTotal, bold, regular),
          if (details.discountMinor > 0)
            _amountLine('خصم الفاتورة', -details.discountMinor, bold, regular),
          if (details.interestMinor > 0)
            _amountLine('فائدة التقسيط', details.interestMinor, bold, regular),
          pw.Divider(color: PdfColors.grey400, height: 8),
          _amountLine('صافي الفاتورة', details.totalMinor, bold, bold),
          _amountLine('المدفوع', details.paidMinor, bold, regular),
          _amountLine('المتبقي', details.remainingMinor, bold, bold),
        ],
      ),
    );
  }

  static pw.Widget _metricBox(
    String label,
    String value,
    pw.Font bold,
    pw.Font regular, {
    bool strong = false,
  }) {
    return pw.Container(
      width: 128,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: pw.BoxDecoration(
        color: strong ? PdfColors.grey200 : PdfColors.white,
        border: pw.Border.all(color: PdfColors.grey300, width: 0.4),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(font: regular, fontSize: 7.5),
            textAlign: pw.TextAlign.right,
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(font: strong ? bold : regular, fontSize: 9),
            textAlign: pw.TextAlign.right,
          ),
        ],
      ),
    );
  }

  static pw.Widget _amountLine(
    String label,
    int amountMinor,
    pw.Font labelFont,
    pw.Font valueFont,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: labelFont, fontSize: 9)),
          pw.Text(
            _money(amountMinor),
            style: pw.TextStyle(font: valueFont, fontSize: 9),
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoLine(
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
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }

  static pw.Widget _sectionTitle(
    String title,
    pw.Font bold, {
    double fontSize = 12,
  }) {
    return pw.Text(
      title,
      style: pw.TextStyle(font: bold, fontSize: fontSize),
      textAlign: pw.TextAlign.right,
    );
  }

  static pw.Widget _plainLine(String text, pw.Font regular) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: regular, fontSize: 8.5),
        textAlign: pw.TextAlign.right,
      ),
    );
  }

  static pw.Widget _cell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 8.3),
        textAlign: pw.TextAlign.right,
      ),
    );
  }

  static int _itemsTotal(List<StatementInvoiceItem> items) {
    return items.fold<int>(0, (sum, item) => sum + item.lineTotalMinor);
  }

  static String _invoiceType(StatementInvoiceDetails details) {
    return details.type == 'purchase' ? 'فاتورة شراء' : 'فاتورة بيع';
  }

  static String _date(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  static String _money(int amountMinor) {
    return Money(amountMinor).formatPlain();
  }

  static String _movementAmount(PartyStatementLine line) {
    final amount = line.debitMinor > 0 ? line.debitMinor : line.creditMinor;
    return _money(amount);
  }

  static String _paymentLabel(PaymentMethod method) {
    return switch (method) {
      PaymentMethod.cash => 'كاش',
      PaymentMethod.wallet => 'محفظة',
      PaymentMethod.installment => 'تقسيط',
    };
  }
}

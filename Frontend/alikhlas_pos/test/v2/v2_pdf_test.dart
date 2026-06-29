import 'dart:io';

import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:alikhlas_pos/v2/printing/barcode_labels_pdf.dart';
import 'package:alikhlas_pos/v2/printing/party_statement_pdf.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pdf printing uses bundled Cairo font assets', () {
    final printingSource = _readTree(Directory('lib/v2/printing'));

    expect(printingSource, isNot(contains('PdfGoogleFonts.cairoRegular')));
    expect(printingSource, isNot(contains('PdfGoogleFonts.cairoBold')));
    expect(printingSource, contains('assets/fonts/Cairo-Regular.ttf'));
    expect(printingSource, contains('assets/fonts/Cairo-Bold.ttf'));
  });

  test('barcode labels pdf builds printable incoming-stock labels', () async {
    final labels = [
      const BarcodeLabelItem(
        productName: 'غسالة باركود',
        barcode: 'AK-2026-00001',
        quantity: 3,
      ),
      const BarcodeLabelItem(
        productName: 'منتج بدون باركود',
        barcode: null,
        quantity: 5,
      ),
    ];

    expect(BarcodeLabelsPdf.printableCount(labels), 3);
    expect(BarcodeLabelsPdf.printableItems(labels), hasLength(1));

    final pdf = await BarcodeLabelsPdf.build(labels);

    expect(pdf.length, greaterThan(1000));
    expect(
      File('lib/v2/printing/barcode_labels_pdf.dart').readAsStringSync(),
      contains('Barcode.code128()'),
    );
  });

  test(
    'party statement pdf builds with invoice details for both parties',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final useCases = V2UseCases(db);
      await useCases.bootstrap();

      final customerId = await db
          .into(db.customers)
          .insert(CustomersCompanion.insert(name: 'عميل PDF'));
      final supplierId = await db
          .into(db.suppliers)
          .insert(SuppliersCompanion.insert(name: 'مورد PDF'));
      final saleProduct = await successOf(
        useCases.createProduct(
          name: 'شاشة PDF',
          salePriceMinor: 8000,
          openingQty: 2,
          openingCostMinor: 7000,
        ),
      );
      final purchaseProduct = await successOf(
        useCases.createProduct(
          name: 'ثلاجة PDF',
          salePriceMinor: 20000,
          openingQty: 0,
          openingCostMinor: 0,
        ),
      );

      await successOf(useCases.openShift(0));
      final saleId = await successOf(
        useCases.createSale(
          customerId: customerId,
          items: [
            SaleLineInput(
              productId: saleProduct.id,
              qty: 2,
              unitPriceMinor: 8000,
            ),
          ],
          payments: const [PaymentInput(PaymentMethod.cash, 5000)],
          discountMinor: 1000,
          installmentTerms: InstallmentTerms(
            partyId: customerId,
            count: 4,
            firstDueDate: DateTime(2026, 7),
          ),
        ),
      );
      final plan = await (db.select(
        db.installmentPlans,
      )..where((row) => row.ownerType.equals('sale'))).getSingle();
      await successOf(
        useCases.collectInstallment(
          planId: plan.id,
          amountMinor: 1500,
          method: PaymentMethod.cash,
        ),
      );
      final saleItem = await (db.select(
        db.saleItems,
      )..where((row) => row.saleId.equals(saleId))).getSingle();
      await successOf(
        useCases.createSaleReturn(
          saleId: saleId,
          saleItemQuantities: {saleItem.id: 1},
          refundMethod: PaymentMethod.installment,
        ),
      );
      await successOf(
        useCases.createPurchase(
          supplierId: supplierId,
          items: [
            PurchaseLineInput(
              productId: purchaseProduct.id,
              qty: 2,
              unitCostMinor: 8000,
            ),
          ],
          payments: const [],
        ),
      );

      final workbench = await useCases.workbenchSnapshot();
      final settings = await useCases.shopSettings();
      final customer = workbench.customerBalances.singleWhere(
        (party) => party.id == customerId,
      );
      final supplier = workbench.supplierBalances.singleWhere(
        (party) => party.id == supplierId,
      );
      final customerStatement = await useCases.partyStatement(
        partyType: 'customer',
        partyId: customerId,
      );
      final supplierStatement = await useCases.partyStatement(
        partyType: 'supplier',
        partyId: supplierId,
      );

      final customerDetails = customerStatement.last.invoiceDetails!;
      expect(customerDetails.invoiceNo, startsWith('S-'));
      expect(customerDetails.items.single.productName, 'شاشة PDF');
      expect(customerDetails.subtotalMinor, 16000);
      expect(customerDetails.discountMinor, 1000);
      expect(customerDetails.items.single.lineTotalMinor, 16000);
      expect(customerDetails.totalMinor, 15000);
      expect(customerDetails.returnedMinor, 7500);
      expect(customerDetails.paidMinor, 6500);
      expect(customerDetails.remainingMinor, 1000);
      expect(customerDetails.payments.map((payment) => payment.amountMinor), [
        5000,
        1500,
      ]);
      expect(
        customerDetails.installments.fold<int>(
          0,
          (sum, installment) => sum + installment.paidMinor,
        ),
        1500,
      );
      expect(
        customerDetails.installments.fold<int>(
          0,
          (sum, installment) => sum + installment.remainingMinor,
        ),
        1000,
      );
      expect(
        customerDetails.installments.any(
          (installment) => installment.status == 'partial',
        ),
        isTrue,
      );
      expect(
        supplierStatement.single.invoiceDetails?.invoiceNo,
        startsWith('P-'),
      );
      expect(
        supplierStatement.single.invoiceDetails?.items.single.productName,
        'ثلاجة PDF',
      );
      expect(supplierStatement.single.invoiceDetails?.totalMinor, 16000);
      expect(supplierStatement.single.invoiceDetails?.paidMinor, 0);
      expect(supplierStatement.single.invoiceDetails?.remainingMinor, 16000);

      final customerPdf = await PartyStatementPdf.build(
        party: customer,
        statement: customerStatement,
        settings: settings,
      );
      final supplierPdf = await PartyStatementPdf.build(
        party: supplier,
        statement: supplierStatement,
        settings: settings,
      );

      expect(customerPdf.length, greaterThan(1000));
      expect(supplierPdf.length, greaterThan(1000));
    },
  );
}

Future<T> successOf<T>(Future<AppResult<T>> future) async {
  final result = await future;
  if (result case AppSuccess<T>(:final value)) return value;
  fail('Expected AppSuccess<$T>, got $result');
}

String _readTree(Directory directory) {
  final buffer = StringBuffer();
  for (final entity in directory.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    buffer.writeln(entity.readAsStringSync());
  }
  return buffer.toString();
}

import 'dart:io';

import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
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
      await successOf(
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

      expect(
        customerStatement.single.invoiceDetails?.invoiceNo,
        startsWith('S-'),
      );
      expect(
        customerStatement.single.invoiceDetails?.items.single.productName,
        'شاشة PDF',
      );
      expect(customerStatement.single.invoiceDetails?.subtotalMinor, 16000);
      expect(customerStatement.single.invoiceDetails?.discountMinor, 1000);
      expect(
        customerStatement.single.invoiceDetails?.items.single.lineTotalMinor,
        16000,
      );
      expect(customerStatement.single.invoiceDetails?.totalMinor, 15000);
      expect(customerStatement.single.invoiceDetails?.paidMinor, 5000);
      expect(customerStatement.single.invoiceDetails?.remainingMinor, 10000);
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

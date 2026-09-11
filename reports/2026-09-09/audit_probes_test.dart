import 'dart:io';
import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// Audit probes assert observed defects, not desired product behavior.
void main() {
  test('audit: full discounted return refunds more than invoice net', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final uc = V2UseCases(db);
    final product =
        (await uc.createProduct(
                  name: 'audit',
                  salePriceMinor: 10000,
                  openingQty: 3,
                  openingCostMinor: 5000,
                )
                as AppSuccess<Product>)
            .value;
    final sale =
        (await uc.createSale(
                  items: [
                    SaleLineInput(
                      productId: product.id,
                      qty: 3,
                      unitPriceMinor: 10000,
                    ),
                  ],
                  payments: [const PaymentInput(PaymentMethod.wallet, 29999)],
                  discountMinor: 1,
                )
                as AppSuccess<int>)
            .value;
    final item = await db.select(db.saleItems).getSingle();
    expect(
      await uc.createSaleReturn(
        saleId: sale,
        saleItemQuantities: {item.id: 3},
        refundMethod: PaymentMethod.wallet,
        allowNegativeBalance: true,
      ),
      isA<AppSuccess<int>>(),
    );
    expect((await db.select(db.saleReturns).getSingle()).refundMinor, 30000);
    expect((await db.select(db.saleInvoices).getSingle()).totalMinor, 29999);
  });
  test(
    'audit: repeated partial payments leave a settled row partial',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final uc = V2UseCases(db);
      final customer = await db
          .into(db.customers)
          .insert(CustomersCompanion.insert(name: 'audit'));
      final product =
          (await uc.createProduct(
                    name: 'audit',
                    salePriceMinor: 20000,
                    openingQty: 2,
                    openingCostMinor: 5000,
                  )
                  as AppSuccess<Product>)
              .value;
      expect(
        await uc.createSale(
          customerId: customer,
          items: [
            SaleLineInput(productId: product.id, qty: 1, unitPriceMinor: 20000),
          ],
          payments: [],
          installmentTerms: InstallmentTerms(
            partyId: customer,
            count: 2,
            firstDueDate: DateTime(2026, 1, 1),
            interestMinor: 0,
          ),
        ),
        isA<AppSuccess<int>>(),
      );
      final plan = await db.select(db.installmentPlans).getSingle();
      for (final amount in [4000, 6000]) {
        expect(
          await uc.collectInstallment(
            planId: plan.id,
            amountMinor: amount,
            method: PaymentMethod.wallet,
          ),
          isA<AppSuccess<int>>(),
        );
      }
      final rows = await db.select(db.installmentPayments).get();
      expect(rows.first.status, 'partial');
      final snapshot = await uc.workbenchSnapshot();
      expect(
        snapshot.dueInstallments.any((due) => due.payment.id == rows.first.id),
        isTrue,
      );
      expect(
        (await db.select(db.installmentPlans).getSingle()).paidMinor,
        10000,
      );
    },
  );

  test('audit: duplicate sale lines lose a stock decrement', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final uc = V2UseCases(db);
    final product =
        (await uc.createProduct(
                  name: 'audit',
                  salePriceMinor: 10000,
                  openingQty: 5,
                  openingCostMinor: 5000,
                )
                as AppSuccess<Product>)
            .value;
    expect(
      await uc.createSale(
        items: [
          for (var i = 0; i < 2; i++)
            SaleLineInput(productId: product.id, qty: 3, unitPriceMinor: 10000),
        ],
        payments: [const PaymentInput(PaymentMethod.wallet, 60000)],
      ),
      isA<AppSuccess<int>>(),
    );
    expect((await db.select(db.products).getSingle()).stockQty, 2);
    expect(
      (await db.select(db.saleItems).get()).fold<int>(
        0,
        (sum, row) => sum + row.qty,
      ),
      6,
    );
  });

  test(
    'audit: invalid backup overwrites database and removes rollback',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'alikhlas-audit-restore-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final live = File('${dir.path}/live.db');
      final db = AppDatabase(NativeDatabase(live));
      final uc = V2UseCases(db);
      await db.select(db.users).get();
      final bad = File('${dir.path}/bad.db');
      await bad.writeAsString('not a SQLite database');
      await uc.restoreFromBackup(bad);
      expect(await live.readAsString(), 'not a SQLite database');
      expect(await dir.list().where((f) => f.path.endsWith('.bak')).length, 0);
    },
  );

  test('audit: inaccessible backup directory fails bootstrap', () async {
    final dir = await Directory.systemTemp.createTemp(
      'alikhlas-audit-startup-',
    );
    addTearDown(() => dir.delete(recursive: true));
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final uc = V2UseCases(db);
    await uc.bootstrap();
    final file = File('${dir.path}/regular-file');
    await file.writeAsString('audit');
    await uc.setBackupDirectory('${file.path}/backups');
    await expectLater(uc.bootstrap(), throwsA(isA<FileSystemException>()));
  });
}

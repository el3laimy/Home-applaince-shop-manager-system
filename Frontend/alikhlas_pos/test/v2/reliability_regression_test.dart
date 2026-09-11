import 'dart:io';
import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

// Regression tests for the first reliability implementation batch.
void main() {
  test('partial payments settle the schedule cumulatively', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final uc = V2UseCases(db);
    final customer = await db
        .into(db.customers)
        .insert(CustomersCompanion.insert(name: 'audit'));
    final product =
        (await uc.createProduct(
                  operationKey: uc.newOpeningStockOperationKey(),
                  name: 'audit',
                  salePriceMinor: 20000,
                  openingQty: 2,
                  openingCostMinor: 5000,
                )
                as AppSuccess<Product>)
            .value;
    expect(
      await uc.createSale(
        operationKey: uc.newSaleOperationKey(),
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
          operationKey: uc.newInstallmentOperationKey(),
          planId: plan.id,
          amountMinor: amount,
          method: PaymentMethod.wallet,
        ),
        isA<AppSuccess<int>>(),
      );
    }
    final rows = await db.select(db.installmentPayments).get();
    expect(rows.first.status, 'paid');
    final snapshot = await uc.workbenchSnapshot();
    expect(
      snapshot.dueInstallments.any((due) => due.payment.id == rows.first.id),
      isFalse,
    );
    expect((await db.select(db.installmentPlans).getSingle()).paidMinor, 10000);
  });

  test('duplicate sale lines are rejected without changing stock', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final uc = V2UseCases(db);
    final product =
        (await uc.createProduct(
                  operationKey: uc.newOpeningStockOperationKey(),
                  name: 'audit',
                  salePriceMinor: 10000,
                  openingQty: 5,
                  openingCostMinor: 5000,
                )
                as AppSuccess<Product>)
            .value;
    expect(
      await uc.createSale(
        operationKey: uc.newSaleOperationKey(),
        items: [
          for (var i = 0; i < 2; i++)
            SaleLineInput(productId: product.id, qty: 3, unitPriceMinor: 10000),
        ],
        payments: [const PaymentInput(PaymentMethod.wallet, 60000)],
      ),
      isA<AppFailure<int>>(),
    );
    expect((await db.select(db.products).getSingle()).stockQty, 5);
    expect(
      (await db.select(db.saleItems).get()).fold<int>(
        0,
        (sum, row) => sum + row.qty,
      ),
      0,
    );
  });

  test('invalid backup leaves the open database usable', () async {
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
    addTearDown(db.close);
    await expectLater(uc.restoreFromBackup(bad), throwsA(isA<Exception>()));
    expect(await db.select(db.users).get(), isEmpty);
    expect(await dir.list().where((f) => f.path.endsWith('.bak')).length, 0);
  });

  test(
    'duplicate purchase lines leave invoices and inventory unchanged',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final uc = V2UseCases(db);
      final product =
          (await uc.createProduct(
                    operationKey: uc.newOpeningStockOperationKey(),
                    name: 'test',
                    salePriceMinor: 10000,
                    openingQty: 2,
                    openingCostMinor: 5000,
                  )
                  as AppSuccess<Product>)
              .value;
      final before = await uc.dashboardSnapshot();
      expect(
        await uc.createPurchase(
          operationKey: uc.newPurchaseOperationKey(),
          items: [
            for (var i = 0; i < 2; i++)
              PurchaseLineInput(
                productId: product.id,
                qty: 3,
                unitCostMinor: 7000,
              ),
          ],
          payments: [const PaymentInput(PaymentMethod.wallet, 42000)],
          allowNegativeBalance: true,
        ),
        isA<AppFailure<int>>(),
      );
      expect(await db.select(db.purchaseInvoices).get(), isEmpty);
      expect((await db.select(db.products).getSingle()).stockQty, 2);
      expect(
        (await uc.dashboardSnapshot()).inventoryMinor,
        before.inventoryMinor,
      );
    },
  );

  for (final defect in ['future-version', 'missing-table', 'foreign-key']) {
    test('restore rejects $defect before closing live database', () async {
      final dir = await Directory.systemTemp.createTemp('restore-validation-');
      addTearDown(() => dir.delete(recursive: true));
      final db = AppDatabase(NativeDatabase(File('${dir.path}/live.db')));
      addTearDown(db.close);
      final uc = V2UseCases(db);
      await uc.bootstrap();
      final backup = await uc.backupToDirectory(
        Directory('${dir.path}/backups'),
      );
      final edit = sqlite.sqlite3.open(backup.path);
      switch (defect) {
        case 'future-version':
          edit.execute('PRAGMA user_version = 999;');
        case 'missing-table':
          edit.execute('DROP TABLE products;');
        case 'foreign-key':
          edit.execute(
            "INSERT INTO ledger_lines(entry_id, account_code, debit_minor, credit_minor) VALUES (999, 'cash', 10, 0);",
          );
      }
      edit.close();
      await expectLater(
        uc.restoreFromBackup(backup),
        throwsA(isA<FormatException>()),
      );
      expect(uc.databaseClosedForRestore, isFalse);
      expect(await uc.login('owner', 'owner123'), isA<AppSuccess<User>>());
    });
  }

  test('inaccessible backup directory does not fail bootstrap', () async {
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
    await uc.bootstrap();
    expect(await uc.login('owner', 'owner123'), isA<AppSuccess<User>>());
    final failedStatus = (await uc.workbenchSnapshot()).backupStatus;
    expect(failedStatus.warning, isNotNull);
    expect(failedStatus.lastDate, isNull);
    await uc.setBackupDirectory('${dir.path}/working');
    expect(await uc.runAutomaticBackupIfDue(), isNotNull);
    expect((await uc.workbenchSnapshot()).backupStatus.warning, isNull);
  });
}

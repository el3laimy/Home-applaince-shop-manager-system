import 'dart:io';

import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ALIkhlasPOS v2 use-cases', () {
    late AppDatabase db;
    late V2UseCases useCases;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      useCases = V2UseCases(db);
      await useCases.bootstrap();
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'bootstraps owner login and requires default password change',
      () async {
        final owner = await successOf(useCases.login('owner', 'owner123'));
        final settings = await useCases.shopSettings();

        expect(owner.username, 'owner');
        expect(owner.mustChangePassword, isTrue);
        expect(settings.shopName, 'إخلاص للأجهزة المنزلية');

        final updatedOwner = await successOf(
          useCases.changePassword(owner.id, 'new-owner-pass'),
        );
        final oldLogin = await useCases.login('owner', 'owner123');
        final newLogin = await successOf(
          useCases.login('owner', 'new-owner-pass'),
        );

        expect(updatedOwner.mustChangePassword, isFalse);
        expect(oldLogin, isA<AppFailure<User>>());
        expect(newLogin.mustChangePassword, isFalse);
      },
    );

    test(
      'cash and wallet sale posts balanced ledger and historical COGS',
      () async {
        final product = await successOf(
          useCases.createProduct(
            name: 'ثلاجة 14 قدم',
            salePriceMinor: 100000,
            openingQty: 3,
            openingCostMinor: 70000,
          ),
        );
        await successOf(useCases.openShift(50000));
        await successOf(
          useCases.updateShopSettings(
            shopName: 'محل الإخلاص',
            phone: '01000000000',
            address: 'القاهرة',
            receiptFooter: 'نورتونا',
          ),
        );

        final saleId = await successOf(
          useCases.createSale(
            items: [
              SaleLineInput(
                productId: product.id,
                qty: 1,
                unitPriceMinor: 100000,
              ),
            ],
            payments: const [
              PaymentInput(PaymentMethod.cash, 50000),
              PaymentInput(PaymentMethod.wallet, 40000),
            ],
            discountMinor: 10000,
          ),
        );

        final storedProduct = await productById(db, product.id);
        final saleItem = await (db.select(
          db.saleItems,
        )..where((item) => item.saleId.equals(saleId))).getSingle();
        final receipt = await useCases.saleReceipt(saleId);
        final snapshot = await useCases.dashboardSnapshot();
        final closedShift = await successOf(useCases.closeShift(100000));

        expect(storedProduct.stockQty, 2);
        expect(saleItem.unitCostMinor, 70000);
        expect(receipt.invoice.invoiceNo, startsWith('S-'));
        expect(receipt.shopSettings.shopName, 'محل الإخلاص');
        expect(receipt.shopSettings.phone, '01000000000');
        expect(receipt.shopSettings.address, 'القاهرة');
        expect(receipt.shopSettings.receiptFooter, 'نورتونا');
        expect(receipt.invoice.discountMinor, 10000);
        expect(receipt.invoice.totalMinor, 90000);
        expect(receipt.lines.single.productName, 'ثلاجة 14 قدم');
        expect(receipt.lines.single.lineTotalMinor, 100000);
        expect(receipt.payments.map((payment) => payment.method), [
          PaymentMethod.cash,
          PaymentMethod.wallet,
        ]);
        expect(snapshot.cashMinor, 50000);
        expect(snapshot.walletMinor, 40000);
        expect(snapshot.salesMinor, 90000);
        expect(snapshot.cogsMinor, 70000);
        expect(snapshot.grossProfitMinor, 20000);
        expect(closedShift.expectedCashMinor, 100000);
        expect(closedShift.differenceMinor, 0);
        await expectAllLedgerEntriesBalanced(db);
      },
    );

    test('purchase updates weighted average cost', () async {
      final product = await successOf(
        useCases.createProduct(
          name: 'غسالة',
          salePriceMinor: 35000,
          openingQty: 2,
          openingCostMinor: 10000,
        ),
      );

      await successOf(
        useCases.createPurchase(
          items: [
            PurchaseLineInput(
              productId: product.id,
              qty: 2,
              unitCostMinor: 20000,
            ),
          ],
          payments: const [PaymentInput(PaymentMethod.wallet, 40000)],
        ),
      );

      final storedProduct = await productById(db, product.id);

      expect(storedProduct.stockQty, 4);
      expect(storedProduct.avgCostMinor, 15000);
      await expectAllLedgerEntriesBalanced(db);
    });

    test(
      'installment sale allocates flat interest and rounding remainder',
      () async {
        final customerId = await db
            .into(db.customers)
            .insert(CustomersCompanion.insert(name: 'عميل تقسيط'));
        final product = await successOf(
          useCases.createProduct(
            name: 'بوتاجاز',
            salePriceMinor: 10000,
            openingQty: 1,
            openingCostMinor: 5000,
          ),
        );
        await successOf(useCases.openShift(0));

        await successOf(
          useCases.createSale(
            customerId: customerId,
            items: [
              SaleLineInput(
                productId: product.id,
                qty: 1,
                unitPriceMinor: 10000,
              ),
            ],
            payments: const [PaymentInput(PaymentMethod.cash, 2000)],
            installmentTerms: InstallmentTerms(
              partyId: customerId,
              count: 3,
              firstDueDate: DateTime(2026, 7),
              interestMinor: 1001,
            ),
          ),
        );

        final plan = await (db.select(
          db.installmentPlans,
        )..where((plan) => plan.ownerType.equals('sale'))).getSingle();
        final payments = await db.select(db.installmentPayments).get();
        final snapshot = await useCases.dashboardSnapshot();

        expect(plan.principalMinor, 8000);
        expect(plan.interestMinor, 1001);
        expect(plan.totalMinor, 9001);
        expect(payments.map((payment) => payment.amountMinor), [
          3000,
          3000,
          3001,
        ]);
        expect(snapshot.receivablesMinor, 9001);
        await expectAllLedgerEntriesBalanced(db);
      },
    );

    test('collects customer installment and reduces receivables', () async {
      final customerId = await db
          .into(db.customers)
          .insert(CustomersCompanion.insert(name: 'عميل تحصيل'));
      final product = await successOf(
        useCases.createProduct(
          name: 'سخان',
          salePriceMinor: 10000,
          openingQty: 1,
          openingCostMinor: 5000,
        ),
      );
      await successOf(useCases.openShift(0));
      await successOf(
        useCases.createSale(
          customerId: customerId,
          items: [
            SaleLineInput(productId: product.id, qty: 1, unitPriceMinor: 10000),
          ],
          payments: const [PaymentInput(PaymentMethod.cash, 2000)],
          installmentTerms: InstallmentTerms(
            partyId: customerId,
            count: 3,
            firstDueDate: DateTime(2026, 7),
            interestMinor: 1001,
          ),
        ),
      );
      final plan = await db.select(db.installmentPlans).getSingle();

      await successOf(
        useCases.collectInstallment(
          planId: plan.id,
          amountMinor: 3000,
          method: PaymentMethod.cash,
        ),
      );

      final updatedPlan = await db.select(db.installmentPlans).getSingle();
      final installments = await db.select(db.installmentPayments).get();
      final snapshot = await useCases.dashboardSnapshot();

      expect(updatedPlan.paidMinor, 3000);
      expect(updatedPlan.status, 'open');
      expect(installments.first.status, 'paid');
      expect(snapshot.cashMinor, 5000);
      expect(snapshot.receivablesMinor, 6001);
      await expectAllLedgerEntriesBalanced(db);
    });

    test(
      'workbench snapshot includes daily report and due installments',
      () async {
        final customerId = await db
            .into(db.customers)
            .insert(CustomersCompanion.insert(name: 'عميل تقرير'));
        final product = await successOf(
          useCases.createProduct(
            name: 'تكييف',
            salePriceMinor: 10000,
            openingQty: 3,
            openingCostMinor: 5000,
          ),
        );
        await successOf(useCases.openShift(0));

        await successOf(
          useCases.createSale(
            customerId: customerId,
            items: [
              SaleLineInput(
                productId: product.id,
                qty: 1,
                unitPriceMinor: 10000,
              ),
            ],
            payments: const [PaymentInput(PaymentMethod.cash, 3000)],
            installmentTerms: InstallmentTerms(
              partyId: customerId,
              count: 2,
              firstDueDate: DateTime.now().subtract(const Duration(days: 1)),
              interestMinor: 500,
            ),
          ),
        );
        await successOf(
          useCases.recordExpense(
            description: 'مصروف تشغيل',
            amountMinor: 500,
            method: PaymentMethod.cash,
          ),
        );
        await successOf(
          useCases.createPurchase(
            items: [
              PurchaseLineInput(
                productId: product.id,
                qty: 1,
                unitCostMinor: 7000,
              ),
            ],
            payments: const [PaymentInput(PaymentMethod.wallet, 7000)],
          ),
        );

        final snapshot = await useCases.workbenchSnapshot();
        final summary = snapshot.dailySummary;

        expect(summary.salesMinor, 10000);
        expect(summary.cogsMinor, 5000);
        expect(summary.expensesMinor, 500);
        expect(summary.interestMinor, 500);
        expect(summary.profitMinor, 5000);
        expect(summary.cashNetMinor, 2500);
        expect(summary.walletNetMinor, -7000);
        expect(summary.purchaseMinor, 7000);
        expect(summary.saleCount, 1);
        expect(summary.purchaseCount, 1);
        expect(snapshot.dueInstallments, hasLength(1));
        expect(snapshot.dueInstallments.single.partyName, 'عميل تقرير');
        expect(snapshot.dueInstallments.single.isOverdue, isTrue);
        expect(snapshot.installmentSummaries, hasLength(1));
        expect(snapshot.installmentSummaries.single.partyName, 'عميل تقرير');
        expect(snapshot.installmentSummaries.single.remainingMinor, 7500);
        expect(snapshot.installmentSummaries.single.overdueMinor, 3750);
        expect(snapshot.installmentSummaries.single.nextDueMinor, 3750);

        final today = DateTime.now();
        final period = await useCases.periodReport(start: today, end: today);
        final statement = await useCases.partyStatement(
          partyType: 'customer',
          partyId: customerId,
        );

        expect(period.salesMinor, summary.salesMinor);
        expect(period.profitMinor, summary.profitMinor);
        expect(statement, hasLength(1));
        expect(statement.single.debitMinor, 7500);
        expect(statement.single.balanceMinor, 7500);
        await expectAllLedgerEntriesBalanced(db);
      },
    );

    test('pays supplier installment and records daily expenses', () async {
      final supplierId = await db
          .into(db.suppliers)
          .insert(SuppliersCompanion.insert(name: 'مورد'));
      final product = await successOf(
        useCases.createProduct(
          name: 'شفاط',
          salePriceMinor: 20000,
          openingQty: 0,
          openingCostMinor: 0,
        ),
      );

      await successOf(
        useCases.createPurchase(
          supplierId: supplierId,
          items: [
            PurchaseLineInput(
              productId: product.id,
              qty: 2,
              unitCostMinor: 10000,
            ),
          ],
          payments: const [],
        ),
      );
      final plan = await db.select(db.installmentPlans).getSingle();

      await successOf(
        useCases.paySupplierInstallment(
          planId: plan.id,
          amountMinor: 20000,
          method: PaymentMethod.wallet,
        ),
      );
      await successOf(useCases.openShift(0));
      await successOf(
        useCases.recordExpense(
          description: 'نقل بضاعة',
          amountMinor: 1500,
          method: PaymentMethod.cash,
        ),
      );

      final updatedPlan = await db.select(db.installmentPlans).getSingle();
      final snapshot = await useCases.dashboardSnapshot();

      expect(updatedPlan.status, 'closed');
      expect(snapshot.payablesMinor, 0);
      expect(snapshot.walletMinor, -20000);
      expect(snapshot.expensesMinor, 1500);
      expect(snapshot.cashMinor, -1500);
      await expectAllLedgerEntriesBalanced(db);
    });

    test('sale return restores stock and reverses sales and COGS', () async {
      final product = await successOf(
        useCases.createProduct(
          name: 'مروحة',
          salePriceMinor: 10000,
          openingQty: 2,
          openingCostMinor: 5000,
        ),
      );
      await successOf(useCases.openShift(0));
      final saleId = await successOf(
        useCases.createSale(
          items: [
            SaleLineInput(productId: product.id, qty: 2, unitPriceMinor: 10000),
          ],
          payments: const [PaymentInput(PaymentMethod.cash, 20000)],
        ),
      );
      final saleItem = await (db.select(
        db.saleItems,
      )..where((item) => item.saleId.equals(saleId))).getSingle();
      final previewBeforeReturn = await useCases.saleReturnPreview(saleId);

      expect(previewBeforeReturn.lines.single.productName, 'مروحة');
      expect(previewBeforeReturn.lines.single.returnableQty, 2);
      await successOf(
        useCases.createSaleReturn(
          saleId: saleId,
          saleItemQuantities: {saleItem.id: 1},
          refundMethod: PaymentMethod.cash,
        ),
      );
      final invalidSecondReturn = await useCases.createSaleReturn(
        saleId: saleId,
        saleItemQuantities: {saleItem.id: 2},
        refundMethod: PaymentMethod.cash,
      );

      final storedProduct = await productById(db, product.id);
      final snapshot = await useCases.dashboardSnapshot();
      final previewAfterReturn = await useCases.saleReturnPreview(saleId);

      expect(invalidSecondReturn, isA<AppFailure<int>>());
      expect(previewAfterReturn.lines.single.returnedQty, 1);
      expect(previewAfterReturn.lines.single.returnableQty, 1);
      expect(storedProduct.stockQty, 1);
      expect(snapshot.cashMinor, 10000);
      expect(snapshot.salesMinor, 10000);
      expect(snapshot.cogsMinor, 5000);
      expect(snapshot.inventoryMinor, 5000);
      await expectAllLedgerEntriesBalanced(db);
    });

    test(
      'full day flow keeps stock, shifts, installments, and returns aligned',
      () async {
        final customerId = await db
            .into(db.customers)
            .insert(CustomersCompanion.insert(name: 'عميل يوم كامل'));
        final supplierId = await db
            .into(db.suppliers)
            .insert(SuppliersCompanion.insert(name: 'مورد يوم كامل'));
        final product = await successOf(
          useCases.createProduct(
            name: 'غلاية كهرباء',
            salePriceMinor: 10000,
            openingQty: 0,
            openingCostMinor: 0,
            minStockQty: 1,
          ),
        );

        await successOf(useCases.openShift(10000));
        await successOf(
          useCases.createPurchase(
            supplierId: supplierId,
            items: [
              PurchaseLineInput(
                productId: product.id,
                qty: 3,
                unitCostMinor: 7000,
              ),
            ],
            payments: const [
              PaymentInput(PaymentMethod.cash, 5000),
              PaymentInput(PaymentMethod.wallet, 6000),
            ],
          ),
        );
        final saleId = await successOf(
          useCases.createSale(
            customerId: customerId,
            items: [
              SaleLineInput(
                productId: product.id,
                qty: 2,
                unitPriceMinor: 10000,
              ),
            ],
            payments: const [
              PaymentInput(PaymentMethod.cash, 5000),
              PaymentInput(PaymentMethod.wallet, 3000),
            ],
            installmentTerms: InstallmentTerms(
              partyId: customerId,
              count: 2,
              firstDueDate: DateTime(2026, 7),
              interestMinor: 1000,
            ),
            discountMinor: 2000,
          ),
        );
        final plan = await (db.select(
          db.installmentPlans,
        )..where((plan) => plan.ownerType.equals('sale'))).getSingle();
        await successOf(
          useCases.collectInstallment(
            planId: plan.id,
            amountMinor: 1000,
            method: PaymentMethod.cash,
          ),
        );
        final saleItem = await (db.select(
          db.saleItems,
        )..where((line) => line.saleId.equals(saleId))).getSingle();
        await successOf(
          useCases.createSaleReturn(
            saleId: saleId,
            saleItemQuantities: {saleItem.id: 1},
            refundMethod: PaymentMethod.installment,
          ),
        );
        final closedShift = await successOf(useCases.closeShift(11000));

        final storedProduct = await productById(db, product.id);
        final dashboard = await useCases.dashboardSnapshot();
        final today = DateTime.now();
        final period = await useCases.periodReport(start: today, end: today);
        final returnItem = await db.select(db.saleReturnItems).getSingle();
        final updatedPlan = await (db.select(
          db.installmentPlans,
        )..where((plan) => plan.ownerType.equals('sale'))).getSingle();

        expect(storedProduct.stockQty, 2);
        expect(storedProduct.avgCostMinor, 7000);
        expect(returnItem.unitPriceMinor, 9000);
        expect(updatedPlan.paidMinor, 1000);
        expect(dashboard.salesMinor, 9000);
        expect(dashboard.cogsMinor, 7000);
        expect(period.interestMinor, 1000);
        expect(dashboard.receivablesMinor, 1000);
        expect(dashboard.payablesMinor, -10000);
        expect(dashboard.cashMinor, 1000);
        expect(dashboard.walletMinor, -3000);
        expect(dashboard.inventoryMinor, 14000);
        expect(closedShift.expectedCashMinor, 11000);
        expect(closedShift.differenceMinor, 0);
        await expectAllLedgerEntriesBalanced(db);
      },
    );

    test(
      'rejects invoice discount that consumes the full sale subtotal',
      () async {
        final product = await successOf(
          useCases.createProduct(
            name: 'مكواة',
            salePriceMinor: 10000,
            openingQty: 1,
            openingCostMinor: 5000,
          ),
        );

        final result = await useCases.createSale(
          items: [
            SaleLineInput(productId: product.id, qty: 1, unitPriceMinor: 10000),
          ],
          payments: const [],
          discountMinor: 10000,
        );

        expect(result, isA<AppFailure<int>>());
        expect((await productById(db, product.id)).stockQty, 1);
        expect(await db.select(db.saleInvoices).get(), isEmpty);
      },
    );

    test('rejects selling unavailable stock atomically', () async {
      final product = await successOf(
        useCases.createProduct(
          name: 'ديب فريزر',
          salePriceMinor: 25000,
          openingQty: 1,
          openingCostMinor: 18000,
        ),
      );

      final result = await useCases.createSale(
        items: [
          SaleLineInput(productId: product.id, qty: 2, unitPriceMinor: 25000),
        ],
        payments: const [PaymentInput(PaymentMethod.wallet, 50000)],
      );

      expect(result, isA<AppFailure<int>>());
      expect((await productById(db, product.id)).stockQty, 1);
      expect(await db.select(db.saleInvoices).get(), isEmpty);
      await expectAllLedgerEntriesBalanced(db);
    });

    test('backup and restore returns to the backed-up state', () async {
      await db.close();

      final tempDir = await Directory.systemTemp.createTemp(
        'alikhlas-v2-test-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final dbFile = File('${tempDir.path}/app.db');
      db = AppDatabase(NativeDatabase(dbFile));
      useCases = V2UseCases(db);
      await useCases.bootstrap();
      final autoBackupBeforeDirectory = await useCases
          .runAutomaticBackupIfDue();
      expect(autoBackupBeforeDirectory, isNull);

      await successOf(
        useCases.createProduct(
          name: 'منتج قبل النسخة',
          salePriceMinor: 1000,
          openingQty: 1,
          openingCostMinor: 700,
        ),
      );
      final backup = await useCases.backupToDirectory(
        Directory('${tempDir.path}/backups'),
      );
      await useCases.setBackupDirectory('${tempDir.path}/backups');
      final dailyBackup = await useCases.runAutomaticBackupIfDue();
      final secondDailyBackup = await useCases.runAutomaticBackupIfDue();
      await successOf(
        useCases.createProduct(
          name: 'منتج بعد النسخة',
          salePriceMinor: 2000,
          openingQty: 1,
          openingCostMinor: 1200,
        ),
      );

      await useCases.restoreFromBackup(backup);

      db = AppDatabase(NativeDatabase(dbFile));
      final products = await db.select(db.products).get();

      expect(products.map((product) => product.name), ['منتج قبل النسخة']);
      expect(dailyBackup, isNotNull);
      expect(await dailyBackup!.exists(), isTrue);
      expect(secondDailyBackup, isNull);
    });
  });
}

Future<T> successOf<T>(Future<AppResult<T>> future) async {
  final result = await future;
  if (result is AppSuccess<T>) {
    return result.value;
  }
  if (result is AppFailure<T>) {
    fail(result.message);
  }
  fail('Unexpected result type: $result');
}

Future<Product> productById(AppDatabase db, int productId) {
  return (db.select(
    db.products,
  )..where((product) => product.id.equals(productId))).getSingle();
}

Future<void> expectAllLedgerEntriesBalanced(AppDatabase db) async {
  final entries = await db.select(db.ledgerEntries).get();
  expect(entries, isNotEmpty);

  for (final entry in entries) {
    final lines = await (db.select(
      db.ledgerLines,
    )..where((line) => line.entryId.equals(entry.id))).get();
    final debit = lines.fold<int>(0, (sum, line) => sum + line.debitMinor);
    final credit = lines.fold<int>(0, (sum, line) => sum + line.creditMinor);

    expect(debit, credit, reason: 'Ledger entry ${entry.id} is unbalanced');
  }
}

Future<int> accountBalance(AppDatabase db, String accountCode) async {
  final lines = await (db.select(
    db.ledgerLines,
  )..where((line) => line.accountCode.equals(accountCode))).get();
  return lines.fold<int>(
    0,
    (sum, line) => sum + line.debitMinor - line.creditMinor,
  );
}

Future<void> expectAccountBalance(
  AppDatabase db,
  String accountCode,
  int expected,
) async {
  expect(await accountBalance(db, accountCode), expected);
}

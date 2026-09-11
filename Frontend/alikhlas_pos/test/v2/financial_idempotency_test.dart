import 'dart:io';

import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<T> success<T>(Future<AppResult<T>> result) async =>
    (await result as AppSuccess<T>).value;

void main() {
  test(
    'customer collection replays one ledger entry after reopening the file',
    () async {
      final dir = Directory.systemTemp.createTempSync('installment-once-');
      var db = AppDatabase(NativeDatabase(File('${dir.path}/shop.db')));
      addTearDown(() async {
        await db.close();
        dir.deleteSync(recursive: true);
      });
      var uc = V2UseCases(db);
      final customerId = await db
          .into(db.customers)
          .insert(CustomersCompanion.insert(name: 'عميل التحصيل'));
      final product = await success(
        uc.createProduct(
          operationKey: uc.newOpeningStockOperationKey(),
          name: 'ثلاجة',
          salePriceMinor: 10000,
          openingQty: 1,
          openingCostMinor: 5000,
        ),
      );
      await success(
        uc.createSale(
          operationKey: uc.newSaleOperationKey(),
          customerId: customerId,
          items: [
            SaleLineInput(productId: product.id, qty: 1, unitPriceMinor: 10000),
          ],
          payments: const [],
          installmentTerms: InstallmentTerms(
            partyId: customerId,
            count: 1,
            firstDueDate: DateTime(2026, 9, 10),
            interestMinor: 0,
          ),
        ),
      );
      final plan = await db.select(db.installmentPlans).getSingle();
      final ledgersBefore = (await db.select(db.ledgerEntries).get()).length;
      final key = uc.newInstallmentOperationKey();

      final results = await Future.wait([
        uc.collectInstallment(
          operationKey: key,
          planId: plan.id,
          amountMinor: 10000,
          method: PaymentMethod.wallet,
        ),
        uc.collectInstallment(
          operationKey: key,
          planId: plan.id,
          amountMinor: 10000,
          method: PaymentMethod.wallet,
        ),
      ]);
      final ledgerId = (results.first as AppSuccess<int>).value;
      expect((results.last as AppSuccess<int>).value, ledgerId);
      expect(
        (await db.select(db.installmentPlans).getSingle()).paidMinor,
        10000,
      );
      expect(
        (await db.select(db.ledgerEntries).get()).length,
        ledgersBefore + 1,
      );

      await db.close();
      db = AppDatabase(NativeDatabase(File('${dir.path}/shop.db')));
      uc = V2UseCases(db);
      expect(
        await success(
          uc.collectInstallment(
            operationKey: key,
            planId: plan.id,
            amountMinor: 10000,
            method: PaymentMethod.wallet,
          ),
        ),
        ledgerId,
      );
      expect(
        await uc.collectInstallment(
          operationKey: key,
          planId: plan.id,
          amountMinor: 9999,
          method: PaymentMethod.wallet,
        ),
        isA<AppFailure<int>>(),
      );
      expect(
        (await db.select(db.ledgerEntries).get()).length,
        ledgersBefore + 1,
      );

      final uncommitted = PendingFinancialOperation.expense(
        operationKey: uc.newExpenseOperationKey(),
        description: 'طلب أُلغي',
        amountMinor: 500,
        method: PaymentMethod.wallet,
      );
      await uc.stagePendingFinancialOperation(uncommitted);
      expect(
        await uc.discardUncommittedPendingFinancialOperation(
          uncommitted.operationKey,
        ),
        isTrue,
      );
      expect(
        await uc.submitPendingFinancialOperation(uncommitted),
        isA<AppFailure<int>>(),
      );
    },
  );

  test(
    'supplier payment needs approval once and then has one durable result',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final uc = V2UseCases(db);
      final supplierId = await db
          .into(db.suppliers)
          .insert(SuppliersCompanion.insert(name: 'مورد السداد'));
      final product = await success(
        uc.createProduct(
          operationKey: uc.newOpeningStockOperationKey(),
          name: 'بوتاجاز',
          salePriceMinor: 20000,
          openingQty: 0,
          openingCostMinor: 0,
        ),
      );
      await success(
        uc.createPurchase(
          operationKey: uc.newPurchaseOperationKey(),
          supplierId: supplierId,
          items: [
            PurchaseLineInput(
              productId: product.id,
              qty: 1,
              unitCostMinor: 7000,
            ),
          ],
          payments: const [],
        ),
      );
      final plan = await db.select(db.installmentPlans).getSingle();
      final key = uc.newInstallmentOperationKey();
      expect(
        await uc.paySupplierInstallment(
          operationKey: key,
          planId: plan.id,
          amountMinor: 7000,
          method: PaymentMethod.wallet,
        ),
        isA<AppConfirmationRequired<int>>(),
      );
      expect((await db.select(db.ledgerEntries).get()).length, 1);

      final results = await Future.wait([
        uc.paySupplierInstallment(
          operationKey: key,
          planId: plan.id,
          amountMinor: 7000,
          method: PaymentMethod.wallet,
          allowNegativeBalance: true,
        ),
        uc.paySupplierInstallment(
          operationKey: key,
          planId: plan.id,
          amountMinor: 7000,
          method: PaymentMethod.wallet,
          allowNegativeBalance: true,
        ),
      ]);
      expect(
        (results.first as AppSuccess<int>).value,
        (results.last as AppSuccess<int>).value,
      );
      expect(
        (await db.select(db.installmentPlans).getSingle()).paidMinor,
        7000,
      );
      expect((await db.select(db.ledgerEntries).get()).length, 2);
    },
  );

  test(
    'pending financial request survives a missed reply and is acknowledged',
    () async {
      final dir = Directory.systemTemp.createTempSync('financial-pending-');
      var db = AppDatabase(NativeDatabase(File('${dir.path}/shop.db')));
      addTearDown(() async {
        await db.close();
        dir.deleteSync(recursive: true);
      });
      var uc = V2UseCases(db);
      final customerId = await db
          .into(db.customers)
          .insert(CustomersCompanion.insert(name: 'عميل طلب معلّق'));
      final product = await success(
        uc.createProduct(
          operationKey: uc.newOpeningStockOperationKey(),
          name: 'مكيف',
          salePriceMinor: 9000,
          openingQty: 1,
          openingCostMinor: 4000,
        ),
      );
      await success(
        uc.createSale(
          operationKey: uc.newSaleOperationKey(),
          customerId: customerId,
          items: [
            SaleLineInput(productId: product.id, qty: 1, unitPriceMinor: 9000),
          ],
          payments: const [],
          installmentTerms: InstallmentTerms(
            partyId: customerId,
            count: 1,
            firstDueDate: DateTime(2026, 9, 10),
          ),
        ),
      );
      final plan = await db.select(db.installmentPlans).getSingle();
      final request = PendingFinancialOperation.customerInstallment(
        operationKey: uc.newInstallmentOperationKey(),
        planId: plan.id,
        amountMinor: 9000,
        method: PaymentMethod.wallet,
      );
      final ledgersBefore = (await db.select(db.ledgerEntries).get()).length;
      expect(
        (await uc.stagePendingFinancialOperation(request)).encode(),
        request.encode(),
      );
      final ledgerId = await success(
        uc.submitPendingFinancialOperation(request),
      );
      expect(
        await (db.select(db.appSettings)..where(
              (row) => row.key.equals(
                'operation.installment.customer.${request.operationKey}',
              ),
            ))
            .getSingleOrNull(),
        isNotNull,
      );

      // Simulate losing the reply before the UI can acknowledge it.
      await db.close();
      db = AppDatabase(NativeDatabase(File('${dir.path}/shop.db')));
      uc = V2UseCases(db);
      final restored = await uc.pendingFinancialOperation();
      expect(restored?.encode(), request.encode());
      expect(
        await (db.select(db.appSettings)..where(
              (row) => row.key.equals(
                'operation.installment.customer.${request.operationKey}',
              ),
            ))
            .getSingleOrNull(),
        isNotNull,
      );
      expect(
        await uc.discardUncommittedPendingFinancialOperation(
          request.operationKey,
        ),
        isFalse,
      );
      expect(
        await success(uc.submitPendingFinancialOperation(restored!)),
        ledgerId,
      );
      expect(
        await uc.acknowledgePendingFinancialOperation(request.operationKey),
        isTrue,
      );
      expect(await uc.pendingFinancialOperation(), isNull);
      expect(
        (await db.select(db.ledgerEntries).get()).length,
        ledgersBefore + 1,
      );
    },
  );

  test(
    'return and expense operation keys each commit their effect once',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final uc = V2UseCases(db);
      await success(uc.openShift(0, operationKey: uc.newShiftOperationKey()));
      final product = await success(
        uc.createProduct(
          operationKey: uc.newOpeningStockOperationKey(),
          name: 'غسالة',
          salePriceMinor: 10000,
          openingQty: 1,
          openingCostMinor: 5000,
        ),
      );
      final saleId = await success(
        uc.createSale(
          operationKey: uc.newSaleOperationKey(),
          items: [
            SaleLineInput(productId: product.id, qty: 1, unitPriceMinor: 10000),
          ],
          payments: const [PaymentInput(PaymentMethod.cash, 10000)],
        ),
      );
      final saleItem = await db.select(db.saleItems).getSingle();
      final returnKey = uc.newSaleReturnOperationKey();
      final returnResults = await Future.wait([
        uc.createSaleReturn(
          operationKey: returnKey,
          saleId: saleId,
          saleItemQuantities: {saleItem.id: 1},
          refundMethod: PaymentMethod.cash,
        ),
        uc.createSaleReturn(
          operationKey: returnKey,
          saleId: saleId,
          saleItemQuantities: {saleItem.id: 1},
          refundMethod: PaymentMethod.cash,
        ),
      ]);
      expect(
        (returnResults.first as AppSuccess<int>).value,
        (returnResults.last as AppSuccess<int>).value,
      );
      expect(await db.select(db.saleReturns).get(), hasLength(1));
      expect((await db.select(db.products).getSingle()).stockQty, 1);

      final expenseKey = uc.newExpenseOperationKey();
      expect(
        await uc.recordExpense(
          operationKey: expenseKey,
          description: 'توصيل',
          amountMinor: 500,
          method: PaymentMethod.wallet,
        ),
        isA<AppConfirmationRequired<int>>(),
      );
      final expenseResults = await Future.wait([
        uc.recordExpense(
          operationKey: expenseKey,
          description: 'توصيل',
          amountMinor: 500,
          method: PaymentMethod.wallet,
          allowNegativeBalance: true,
        ),
        uc.recordExpense(
          operationKey: expenseKey,
          description: 'توصيل',
          amountMinor: 500,
          method: PaymentMethod.wallet,
          allowNegativeBalance: true,
        ),
      ]);
      expect(
        (expenseResults.first as AppSuccess<int>).value,
        (expenseResults.last as AppSuccess<int>).value,
      );
      expect(await db.select(db.expenses).get(), hasLength(1));
    },
  );

  test('opening and closing a shift replay the same saved shift', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final uc = V2UseCases(db);
    final openKey = uc.newShiftOperationKey();
    final opened = await Future.wait([
      uc.openShift(1200, operationKey: openKey),
      uc.openShift(1200, operationKey: openKey),
    ]);
    final shiftId = (opened.first as AppSuccess<Shift>).value.id;
    expect((opened.last as AppSuccess<Shift>).value.id, shiftId);
    expect(await db.select(db.shifts).get(), hasLength(1));

    final closeKey = uc.newShiftOperationKey();
    final closed = await Future.wait([
      uc.closeShift(1200, operationKey: closeKey),
      uc.closeShift(1200, operationKey: closeKey),
    ]);
    expect((closed.first as AppSuccess<Shift>).value.id, shiftId);
    expect((closed.last as AppSuccess<Shift>).value.id, shiftId);
    expect((await db.select(db.shifts).getSingle()).status, 'closed');
  });
}

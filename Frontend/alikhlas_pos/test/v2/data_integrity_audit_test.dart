import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<T> success<T>(Future<AppResult<T>> future) async =>
    (await future as AppSuccess<T>).value;

void main() {
  test('opening stock is recorded as an auditable stock movement', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final uc = V2UseCases(db);
    final product = await success(
      uc.createProduct(
        operationKey: uc.newOpeningStockOperationKey(),
        name: 'رصيد افتتاحي',
        salePriceMinor: 10000,
        openingQty: 3,
        openingCostMinor: 2500,
      ),
    );

    final movement = await db.select(db.stockMovements).getSingle();
    expect(movement.productId, product.id);
    expect(movement.type, 'opening_stock');
    expect(movement.qtyDelta, 3);
    expect(movement.balanceAfter, 3);
    expect((await uc.dataIntegrityAudit()).isConsistent, isTrue);
  });

  test(
    'data integrity audit accepts a complete normal operation flow',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final uc = V2UseCases(db, clock: () => DateTime(2026, 9, 10, 9));
      await success(uc.openShift(0, operationKey: uc.newShiftOperationKey()));
      final product = await success(
        uc.createProduct(
          operationKey: uc.newOpeningStockOperationKey(),
          name: 'صنف فحص',
          salePriceMinor: 10000,
          openingQty: 2,
          openingCostMinor: 4000,
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
      await success(
        uc.createSaleReturn(
          operationKey: uc.newSaleReturnOperationKey(),
          saleId: saleId,
          saleItemQuantities: {saleItem.id: 1},
          refundMethod: PaymentMethod.cash,
        ),
      );
      await success(
        uc.recordExpense(
          operationKey: uc.newExpenseOperationKey(),
          description: 'تشغيل',
          amountMinor: 100,
          method: PaymentMethod.wallet,
          allowNegativeBalance: true,
        ),
      );
      final customerId = await db
          .into(db.customers)
          .insert(CustomersCompanion.insert(name: 'عميل اتساق'));
      await success(
        uc.createSale(
          operationKey: uc.newSaleOperationKey(),
          customerId: customerId,
          items: [
            SaleLineInput(productId: product.id, qty: 1, unitPriceMinor: 5000),
          ],
          payments: const [],
          installmentTerms: InstallmentTerms(
            partyId: customerId,
            count: 2,
            firstDueDate: DateTime(2026, 9, 10),
          ),
        ),
      );
      final customerPlan = (await db.select(db.installmentPlans).get())
          .singleWhere((plan) => plan.partyType == 'customer');
      await success(
        uc.collectInstallment(
          operationKey: uc.newInstallmentOperationKey(),
          planId: customerPlan.id,
          amountMinor: 2500,
          method: PaymentMethod.wallet,
        ),
      );
      final supplierId = await db
          .into(db.suppliers)
          .insert(SuppliersCompanion.insert(name: 'مورد اتساق'));
      await success(
        uc.createPurchase(
          operationKey: uc.newPurchaseOperationKey(),
          supplierId: supplierId,
          items: [
            PurchaseLineInput(
              productId: product.id,
              qty: 1,
              unitCostMinor: 3000,
            ),
          ],
          payments: const [],
        ),
      );
      final supplierPlan = (await db.select(db.installmentPlans).get())
          .singleWhere((plan) => plan.partyType == 'supplier');
      await success(
        uc.paySupplierInstallment(
          operationKey: uc.newInstallmentOperationKey(),
          planId: supplierPlan.id,
          amountMinor: 1000,
          method: PaymentMethod.wallet,
          allowNegativeBalance: true,
        ),
      );

      final audit = await uc.dataIntegrityAudit();
      expect(
        audit.isConsistent,
        isTrue,
        reason: audit.issues.map((i) => i.message).join('\n'),
      );
      expect(audit.ledgerEntryCount, greaterThan(0));
      expect(audit.productCount, 1);
    },
  );

  test(
    'data integrity audit identifies ledger and stock corruption without repair',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final uc = V2UseCases(db);
      final product = await success(
        uc.createProduct(
          operationKey: uc.newOpeningStockOperationKey(),
          name: 'صنف متعارض',
          salePriceMinor: 10000,
          openingQty: 1,
          openingCostMinor: 5000,
        ),
      );
      await success(uc.openShift(0, operationKey: uc.newShiftOperationKey()));
      await success(
        uc.createSale(
          operationKey: uc.newSaleOperationKey(),
          items: [
            SaleLineInput(productId: product.id, qty: 1, unitPriceMinor: 10000),
          ],
          payments: const [PaymentInput(PaymentMethod.cash, 10000)],
        ),
      );
      final badEntryId = await db
          .into(db.ledgerEntries)
          .insert(
            LedgerEntriesCompanion.insert(
              referenceType: 'expense',
              referenceId: 999999,
              description: 'قيد اختبار غير متزن',
            ),
          );
      await db
          .into(db.ledgerLines)
          .insert(
            LedgerLinesCompanion.insert(
              entryId: badEntryId,
              accountCode: 'cash',
              debitMinor: const Value(10),
            ),
          );
      await (db.update(db.products)..where((row) => row.id.equals(product.id)))
          .write(const ProductsCompanion(stockQty: Value(99)));

      final audit = await uc.dataIntegrityAudit();
      expect(audit.isConsistent, isFalse);
      expect(
        audit.issues.map((issue) => issue.code),
        contains('ledger_unbalanced'),
      );
      expect(
        audit.issues.map((issue) => issue.code),
        contains('ledger_reference'),
      );
      expect(
        audit.issues.map((issue) => issue.code),
        contains('stock_current_balance'),
      );
      expect((await db.select(db.products).getSingle()).stockQty, 99);
    },
  );
}

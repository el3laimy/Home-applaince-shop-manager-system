import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'financial commands reject a missing operation key before writing',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final useCases = V2UseCases(db);

      expect(await useCases.openShift(0), isA<AppFailure<Shift>>());
      expect(await db.select(db.shifts).get(), isEmpty);

      expect(
        await useCases.createProduct(
          name: 'رصيد افتتاحي بلا مفتاح',
          salePriceMinor: 10000,
          openingQty: 1,
          openingCostMinor: 5000,
        ),
        isA<AppFailure<Product>>(),
      );
      expect(await db.select(db.products).get(), isEmpty);
      expect(await db.select(db.stockMovements).get(), isEmpty);
      expect(await db.select(db.ledgerEntries).get(), isEmpty);
    },
  );

  test(
    'every money-moving command rejects a missing key with valid inputs',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final useCases = V2UseCases(db);
      final customerId = await db
          .into(db.customers)
          .insert(CustomersCompanion.insert(name: 'عميل المفتاح'));
      final supplierId = await db
          .into(db.suppliers)
          .insert(SuppliersCompanion.insert(name: 'مورد المفتاح'));
      final product =
          (await useCases.createProduct(
                    operationKey: useCases.newOpeningStockOperationKey(),
                    name: 'منتج المفتاح',
                    salePriceMinor: 10000,
                    openingQty: 3,
                    openingCostMinor: 5000,
                  )
                  as AppSuccess<Product>)
              .value;

      final creditSaleId =
          (await useCases.createSale(
                    operationKey: useCases.newSaleOperationKey(),
                    customerId: customerId,
                    items: [
                      SaleLineInput(
                        productId: product.id,
                        qty: 1,
                        unitPriceMinor: 10000,
                      ),
                    ],
                    payments: const [],
                    installmentTerms: InstallmentTerms(
                      partyId: customerId,
                      count: 1,
                      firstDueDate: DateTime(2026, 9, 12),
                    ),
                  )
                  as AppSuccess<int>)
              .value;
      final customerPlan = (await db.select(db.installmentPlans).get())
          .singleWhere(
            (row) => row.ownerType == 'sale' && row.ownerId == creditSaleId,
          );

      await useCases.openShift(
        0,
        operationKey: useCases.newShiftOperationKey(),
      );
      final cashSaleId =
          (await useCases.createSale(
                    operationKey: useCases.newSaleOperationKey(),
                    items: [
                      SaleLineInput(
                        productId: product.id,
                        qty: 1,
                        unitPriceMinor: 10000,
                      ),
                    ],
                    payments: const [PaymentInput(PaymentMethod.cash, 10000)],
                  )
                  as AppSuccess<int>)
              .value;
      final cashSaleItem = await (db.select(
        db.saleItems,
      )..where((row) => row.saleId.equals(cashSaleId))).getSingle();

      final purchaseId =
          (await useCases.createPurchase(
                    operationKey: useCases.newPurchaseOperationKey(),
                    supplierId: supplierId,
                    items: [
                      PurchaseLineInput(
                        productId: product.id,
                        qty: 1,
                        unitCostMinor: 4000,
                      ),
                    ],
                    payments: const [],
                  )
                  as AppSuccess<int>)
              .value;
      final supplierPlan = (await db.select(db.installmentPlans).get())
          .singleWhere(
            (row) => row.ownerType == 'purchase' && row.ownerId == purchaseId,
          );

      final invoicesBefore = (await db.select(db.saleInvoices).get()).length;
      final purchasesBefore =
          (await db.select(db.purchaseInvoices).get()).length;
      final returnsBefore = (await db.select(db.saleReturns).get()).length;
      final expensesBefore = (await db.select(db.expenses).get()).length;
      final ledgerBefore = (await db.select(db.ledgerEntries).get()).length;
      final adjustmentsBefore =
          (await db.select(db.inventoryAdjustments).get()).length;

      expect(
        await useCases.createSale(
          items: [
            SaleLineInput(productId: product.id, qty: 1, unitPriceMinor: 10000),
          ],
          payments: const [PaymentInput(PaymentMethod.wallet, 10000)],
        ),
        isA<AppFailure<int>>(),
      );
      expect(
        await useCases.createPurchase(
          supplierId: supplierId,
          items: [
            PurchaseLineInput(
              productId: product.id,
              qty: 1,
              unitCostMinor: 4000,
            ),
          ],
          payments: const [],
        ),
        isA<AppFailure<int>>(),
      );
      expect(
        await useCases.collectInstallment(
          planId: customerPlan.id,
          amountMinor: 10000,
          method: PaymentMethod.wallet,
        ),
        isA<AppFailure<int>>(),
      );
      expect(
        await useCases.paySupplierInstallment(
          planId: supplierPlan.id,
          amountMinor: 4000,
          method: PaymentMethod.wallet,
          allowNegativeBalance: true,
        ),
        isA<AppFailure<int>>(),
      );
      expect(
        await useCases.createSaleReturn(
          saleId: cashSaleId,
          saleItemQuantities: {cashSaleItem.id: 1},
          refundMethod: PaymentMethod.cash,
        ),
        isA<AppFailure<int>>(),
      );
      expect(
        await useCases.recordExpense(
          description: 'مصروف بلا مفتاح',
          amountMinor: 100,
          method: PaymentMethod.wallet,
          allowNegativeBalance: true,
        ),
        isA<AppFailure<int>>(),
      );
      expect(await useCases.closeShift(10000), isA<AppFailure<Shift>>());
      expect(
        await useCases.reconcileInventory(
          productId: product.id,
          expectedStockQty: product.stockQty,
          countedQty: product.stockQty + 1,
          reason: InventoryAdjustmentReason.physicalCount,
          unitCostMinor: product.avgCostMinor,
        ),
        isA<AppFailure<int>>(),
      );
      expect(
        await useCases.recordOpeningBalance(
          type: OpeningBalanceType.wallet,
          amountMinor: 1000,
        ),
        isA<AppFailure<int>>(),
      );

      expect((await db.select(db.saleInvoices).get()).length, invoicesBefore);
      expect(
        (await db.select(db.purchaseInvoices).get()).length,
        purchasesBefore,
      );
      expect((await db.select(db.saleReturns).get()).length, returnsBefore);
      expect((await db.select(db.expenses).get()).length, expensesBefore);
      expect((await db.select(db.ledgerEntries).get()).length, ledgerBefore);
      expect(
        (await db.select(db.inventoryAdjustments).get()).length,
        adjustmentsBefore,
      );
      expect(await db.select(db.openingBalances).get(), isEmpty);
    },
  );
}

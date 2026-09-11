import 'package:alikhlas_pos/v2/accounting/account_codes.dart';
import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<T> _success<T>(Future<AppResult<T>> future) async =>
    (await future as AppSuccess<T>).value;

Future<int> _accountBalance(AppDatabase db, String accountCode) async {
  final lines = await (db.select(
    db.ledgerLines,
  )..where((line) => line.accountCode.equals(accountCode))).get();
  return lines.fold<int>(
    0,
    (sum, line) => sum + line.debitMinor - line.creditMinor,
  );
}

Future<Product> _product(AppDatabase db, int productId) {
  return (db.select(
    db.products,
  )..where((product) => product.id.equals(productId))).getSingle();
}

void main() {
  test(
    'exact cost basis drains inventory and ledger together after weighted purchases',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final useCases = V2UseCases(db);
      final supplierId = await db
          .into(db.suppliers)
          .insert(SuppliersCompanion.insert(name: 'مورد الكسور'));
      await _success(
        useCases.openShift(0, operationKey: useCases.newShiftOperationKey()),
      );
      final product = await _success(
        useCases.createProduct(
          operationKey: useCases.newOpeningStockOperationKey(),
          name: 'صنف متوسطه كسري',
          salePriceMinor: 1000,
          openingQty: 0,
          openingCostMinor: 0,
        ),
      );
      await _success(
        useCases.createPurchase(
          operationKey: useCases.newPurchaseOperationKey(),
          supplierId: supplierId,
          items: [
            PurchaseLineInput(
              productId: product.id,
              qty: 2,
              unitCostMinor: 100,
            ),
          ],
          payments: const [],
        ),
      );
      await _success(
        useCases.createPurchase(
          operationKey: useCases.newPurchaseOperationKey(),
          supplierId: supplierId,
          items: [
            PurchaseLineInput(
              productId: product.id,
              qty: 1,
              unitCostMinor: 101,
            ),
          ],
          payments: const [],
        ),
      );

      await _success(
        useCases.createSale(
          operationKey: useCases.newSaleOperationKey(),
          items: [
            SaleLineInput(productId: product.id, qty: 1, unitPriceMinor: 1000),
          ],
          payments: const [PaymentInput(PaymentMethod.cash, 1000)],
        ),
      );
      var stored = await _product(db, product.id);
      expect(stored.stockQty, 2);
      expect(stored.inventoryValueMinor, 201);

      await _success(
        useCases.createSale(
          operationKey: useCases.newSaleOperationKey(),
          items: [
            SaleLineInput(productId: product.id, qty: 2, unitPriceMinor: 1000),
          ],
          payments: const [PaymentInput(PaymentMethod.cash, 2000)],
        ),
      );
      stored = await _product(db, product.id);
      expect(stored.stockQty, 0);
      expect(stored.inventoryValueMinor, 0);
      expect(await _accountBalance(db, AccountCodes.inventory), 0);
      final costs = (await db.select(db.saleItems).get())
          .map((line) => line.costMinor)
          .toList();
      expect(costs, [100, 201]);

      final audit = await useCases.dataIntegrityAudit();
      expect(
        audit.isConsistent,
        isTrue,
        reason: audit.issues.map((issue) => issue.message).join('\n'),
      );
    },
  );

  test(
    'sale returns restore the original exact cost after later purchases',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final useCases = V2UseCases(db);
      final supplierId = await db
          .into(db.suppliers)
          .insert(SuppliersCompanion.insert(name: 'مورد مرتجع كسري'));
      await _success(
        useCases.openShift(0, operationKey: useCases.newShiftOperationKey()),
      );
      final product = await _success(
        useCases.createProduct(
          operationKey: useCases.newOpeningStockOperationKey(),
          name: 'بوتاجاز مرتجع كسري',
          salePriceMinor: 1000,
          openingQty: 0,
          openingCostMinor: 0,
        ),
      );
      for (final purchase in [(2, 100), (1, 101)]) {
        await _success(
          useCases.createPurchase(
            operationKey: useCases.newPurchaseOperationKey(),
            supplierId: supplierId,
            items: [
              PurchaseLineInput(
                productId: product.id,
                qty: purchase.$1,
                unitCostMinor: purchase.$2,
              ),
            ],
            payments: const [],
          ),
        );
      }
      final saleId = await _success(
        useCases.createSale(
          operationKey: useCases.newSaleOperationKey(),
          items: [
            SaleLineInput(productId: product.id, qty: 3, unitPriceMinor: 1000),
          ],
          payments: const [PaymentInput(PaymentMethod.cash, 3000)],
        ),
      );
      final saleItem = await db.select(db.saleItems).getSingle();
      expect(saleItem.costMinor, 301);
      await _success(
        useCases.createPurchase(
          operationKey: useCases.newPurchaseOperationKey(),
          supplierId: supplierId,
          items: [
            PurchaseLineInput(
              productId: product.id,
              qty: 1,
              unitCostMinor: 1000,
            ),
          ],
          payments: const [],
        ),
      );

      await _success(
        useCases.createSaleReturn(
          operationKey: useCases.newSaleReturnOperationKey(),
          saleId: saleId,
          saleItemQuantities: {saleItem.id: 1},
          refundMethod: PaymentMethod.cash,
        ),
      );
      var stored = await _product(db, product.id);
      expect(stored.stockQty, 2);
      expect(stored.inventoryValueMinor, 1100);

      await _success(
        useCases.createSaleReturn(
          operationKey: useCases.newSaleReturnOperationKey(),
          saleId: saleId,
          saleItemQuantities: {saleItem.id: 2},
          refundMethod: PaymentMethod.cash,
        ),
      );
      stored = await _product(db, product.id);
      expect(stored.stockQty, 4);
      expect(stored.inventoryValueMinor, 1301);
      expect(await _accountBalance(db, AccountCodes.inventory), 1301);
      expect(
        (await db.select(db.saleReturnItems).get()).fold<int>(
          0,
          (sum, line) => sum + line.costMinor,
        ),
        301,
      );

      await _success(
        useCases.createSale(
          operationKey: useCases.newSaleOperationKey(),
          items: [
            SaleLineInput(productId: product.id, qty: 4, unitPriceMinor: 1000),
          ],
          payments: const [PaymentInput(PaymentMethod.cash, 4000)],
        ),
      );
      stored = await _product(db, product.id);
      expect(stored.stockQty, 0);
      expect(stored.inventoryValueMinor, 0);
      expect(await _accountBalance(db, AccountCodes.inventory), 0);
      final audit = await useCases.dataIntegrityAudit();
      expect(
        audit.isConsistent,
        isTrue,
        reason: audit.issues.map((issue) => issue.message).join('\n'),
      );
    },
  );

  test(
    'counted shortage drains exact inventory value and blocks unsafe deactivation',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final useCases = V2UseCases(db);
      final product = await _success(
        useCases.createProduct(
          operationKey: useCases.newOpeningStockOperationKey(),
          name: 'صنف تعطيل آمن',
          salePriceMinor: 1000,
          openingQty: 3,
          openingCostMinor: 100,
        ),
      );
      expect(
        await useCases.deactivateProduct(product.id),
        isA<AppFailure<void>>(),
      );

      await _success(
        useCases.reconcileInventory(
          operationKey: useCases.newInventoryAdjustmentOperationKey(),
          productId: product.id,
          expectedStockQty: 3,
          countedQty: 0,
          reason: InventoryAdjustmentReason.damage,
          unitCostMinor: 100,
        ),
      );
      final stored = await _product(db, product.id);
      expect(stored.stockQty, 0);
      expect(stored.inventoryValueMinor, 0);
      expect(await _accountBalance(db, AccountCodes.inventory), 0);
      expect(
        await useCases.deactivateProduct(product.id),
        isA<AppSuccess<void>>(),
      );
      expect(
        await useCases.reactivateProduct(product.id),
        isA<AppSuccess<void>>(),
      );
      final audit = await useCases.dataIntegrityAudit();
      expect(audit.isConsistent, isTrue);
    },
  );
}

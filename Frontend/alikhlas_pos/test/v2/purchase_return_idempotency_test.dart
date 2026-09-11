import 'dart:io';

import 'package:alikhlas_pos/v2/accounting/account_codes.dart';
import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<T> _success<T>(Future<AppResult<T>> result) async =>
    (await result as AppSuccess<T>).value;

void main() {
  test(
    'purchase return replays once and reduces the supplier debt at its original cost',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'purchase-return-once-',
      );
      late AppDatabase db;
      addTearDown(() async {
        await db.close();
        directory.deleteSync(recursive: true);
      });
      db = AppDatabase(NativeDatabase(File('${directory.path}/shop.db')));
      var useCases = V2UseCases(db);
      final supplierId = await db
          .into(db.suppliers)
          .insert(SuppliersCompanion.insert(name: 'مورد المرتجع'));
      final product = await _success(
        useCases.createProduct(
          operationKey: useCases.newOpeningStockOperationKey(),
          name: 'ثلاجة مرتجع شراء',
          salePriceMinor: 30000,
          openingQty: 0,
          openingCostMinor: 0,
        ),
      );
      final purchaseId = await _success(
        useCases.createPurchase(
          operationKey: useCases.newPurchaseOperationKey(),
          supplierId: supplierId,
          items: [
            PurchaseLineInput(
              productId: product.id,
              qty: 4,
              unitCostMinor: 10000,
            ),
          ],
          payments: const [],
        ),
      );
      final purchaseItem = await (db.select(
        db.purchaseItems,
      )..where((item) => item.purchaseId.equals(purchaseId))).getSingle();
      final key = useCases.newPurchaseReturnOperationKey();

      final results = await Future.wait([
        useCases.createPurchaseReturn(
          operationKey: key,
          purchaseId: purchaseId,
          purchaseItemQuantities: {purchaseItem.id: 2},
          settlementMethod: PaymentMethod.installment,
        ),
        useCases.createPurchaseReturn(
          operationKey: key,
          purchaseId: purchaseId,
          purchaseItemQuantities: {purchaseItem.id: 2},
          settlementMethod: PaymentMethod.installment,
        ),
      ]);
      final returnId = (results.first as AppSuccess<int>).value;
      expect((results.last as AppSuccess<int>).value, returnId);
      expect(await db.select(db.purchaseReturns).get(), hasLength(1));
      expect(await db.select(db.purchaseReturnItems).get(), hasLength(1));
      expect((await db.select(db.products).getSingle()).stockQty, 2);
      final plan = (await db.select(db.installmentPlans).get()).singleWhere(
        (row) => row.ownerType == 'purchase' && row.ownerId == purchaseId,
      );
      expect(plan.totalMinor, 20000);
      expect(plan.paidMinor, 0);
      final returnEntry = (await db.select(db.ledgerEntries).get()).singleWhere(
        (entry) =>
            entry.referenceType == 'purchase_return' &&
            entry.referenceId == returnId,
      );
      final lines = await (db.select(
        db.ledgerLines,
      )..where((line) => line.entryId.equals(returnEntry.id))).get();
      expect(
        lines.any(
          (line) =>
              line.accountCode == AccountCodes.payables &&
              line.debitMinor == 20000 &&
              line.partyId == supplierId,
        ),
        isTrue,
      );
      expect(
        lines.any(
          (line) =>
              line.accountCode == AccountCodes.inventory &&
              line.creditMinor == 20000,
        ),
        isTrue,
      );

      await db.close();
      db = AppDatabase(NativeDatabase(File('${directory.path}/shop.db')));
      useCases = V2UseCases(db);
      expect(
        await _success(
          useCases.createPurchaseReturn(
            operationKey: key,
            purchaseId: purchaseId,
            purchaseItemQuantities: {purchaseItem.id: 2},
            settlementMethod: PaymentMethod.installment,
          ),
        ),
        returnId,
      );
      expect(
        await useCases.createPurchaseReturn(
          operationKey: key,
          purchaseId: purchaseId,
          purchaseItemQuantities: {purchaseItem.id: 1},
          settlementMethod: PaymentMethod.installment,
        ),
        isA<AppFailure<int>>(),
      );
      final audit = await useCases.dataIntegrityAudit();
      expect(
        audit.isConsistent,
        isTrue,
        reason: audit.issues.map((issue) => issue.message).join('\n'),
      );
    },
  );

  test(
    'purchase return preserves weighted inventory cost and posts the variance',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final useCases = V2UseCases(db);
      final supplierId = await db
          .into(db.suppliers)
          .insert(SuppliersCompanion.insert(name: 'مورد متوسط التكلفة'));
      final product = await _success(
        useCases.createProduct(
          operationKey: useCases.newOpeningStockOperationKey(),
          name: 'بوتاجاز متوسط التكلفة',
          salePriceMinor: 50000,
          openingQty: 0,
          openingCostMinor: 0,
        ),
      );
      final firstPurchase = await _success(
        useCases.createPurchase(
          operationKey: useCases.newPurchaseOperationKey(),
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
      await _success(
        useCases.createPurchase(
          operationKey: useCases.newPurchaseOperationKey(),
          supplierId: supplierId,
          items: [
            PurchaseLineInput(
              productId: product.id,
              qty: 2,
              unitCostMinor: 30000,
            ),
          ],
          payments: const [],
        ),
      );
      final firstItem = await (db.select(
        db.purchaseItems,
      )..where((item) => item.purchaseId.equals(firstPurchase))).getSingle();

      final returnId = await _success(
        useCases.createPurchaseReturn(
          operationKey: useCases.newPurchaseReturnOperationKey(),
          purchaseId: firstPurchase,
          purchaseItemQuantities: {firstItem.id: 1},
          settlementMethod: PaymentMethod.installment,
        ),
      );
      final updatedProduct = await db.select(db.products).getSingle();
      expect(updatedProduct.stockQty, 3);
      expect(updatedProduct.avgCostMinor, 20000);
      final item = await db.select(db.purchaseReturnItems).getSingle();
      expect(item.unitCostMinor, 10000);
      expect(item.inventoryUnitCostMinor, 20000);
      final entry = (await db.select(db.ledgerEntries).get()).singleWhere(
        (row) =>
            row.referenceType == 'purchase_return' &&
            row.referenceId == returnId,
      );
      final lines = await (db.select(
        db.ledgerLines,
      )..where((line) => line.entryId.equals(entry.id))).get();
      expect(
        lines.any(
          (line) =>
              line.accountCode == AccountCodes.inventory &&
              line.creditMinor == 20000,
        ),
        isTrue,
      );
      expect(
        lines.any(
          (line) =>
              line.accountCode == AccountCodes.inventoryVariance &&
              line.debitMinor == 10000,
        ),
        isTrue,
      );
      final audit = await useCases.dataIntegrityAudit();
      expect(
        audit.isConsistent,
        isTrue,
        reason: audit.issues.map((issue) => issue.message).join('\n'),
      );
    },
  );

  test(
    'pending purchase return survives reopening and replays its saved result',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'pending-purchase-return-',
      );
      late AppDatabase db;
      addTearDown(() async {
        await db.close();
        directory.deleteSync(recursive: true);
      });
      db = AppDatabase(NativeDatabase(File('${directory.path}/shop.db')));
      var useCases = V2UseCases(db);
      final supplierId = await db
          .into(db.suppliers)
          .insert(SuppliersCompanion.insert(name: 'مورد الاستعادة'));
      final product = await _success(
        useCases.createProduct(
          operationKey: useCases.newOpeningStockOperationKey(),
          name: 'منتج استعادة مرتجع شراء',
          salePriceMinor: 12000,
          openingQty: 0,
          openingCostMinor: 0,
        ),
      );
      final purchaseId = await _success(
        useCases.createPurchase(
          operationKey: useCases.newPurchaseOperationKey(),
          supplierId: supplierId,
          items: [
            PurchaseLineInput(
              productId: product.id,
              qty: 1,
              unitCostMinor: 6000,
            ),
          ],
          payments: const [],
        ),
      );
      final purchaseItem = await db.select(db.purchaseItems).getSingle();
      final request = PendingFinancialOperation.purchaseReturn(
        operationKey: useCases.newPurchaseReturnOperationKey(),
        purchaseId: purchaseId,
        purchaseItemQuantities: {purchaseItem.id: 1},
        settlementMethod: PaymentMethod.installment,
      );
      await useCases.stagePendingFinancialOperation(request);

      await db.close();
      db = AppDatabase(NativeDatabase(File('${directory.path}/shop.db')));
      useCases = V2UseCases(db);
      final restored = await useCases.pendingFinancialOperation();
      expect(restored?.encode(), request.encode());
      final saved = restored!;
      final returnId = await _success(
        useCases.submitPendingFinancialOperation(saved),
      );
      expect(
        await _success(useCases.submitPendingFinancialOperation(saved)),
        returnId,
      );
      expect(
        await useCases.acknowledgePendingFinancialOperation(
          request.operationKey,
        ),
        isTrue,
      );
      expect(await useCases.pendingFinancialOperation(), isNull);
      expect(await db.select(db.purchaseReturns).get(), hasLength(1));
      expect((await useCases.dataIntegrityAudit()).isConsistent, isTrue);
    },
  );

  test('purchase return rolls back when its receipt cannot be saved', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final useCases = V2UseCases(db);
    final supplierId = await db
        .into(db.suppliers)
        .insert(SuppliersCompanion.insert(name: 'مورد فشل الحفظ'));
    final product = await _success(
      useCases.createProduct(
        operationKey: useCases.newOpeningStockOperationKey(),
        name: 'منتج فشل مرتجع الشراء',
        salePriceMinor: 10000,
        openingQty: 0,
        openingCostMinor: 0,
      ),
    );
    final purchaseId = await _success(
      useCases.createPurchase(
        operationKey: useCases.newPurchaseOperationKey(),
        supplierId: supplierId,
        items: [
          PurchaseLineInput(productId: product.id, qty: 1, unitCostMinor: 5000),
        ],
        payments: const [],
      ),
    );
    final purchaseItem = await db.select(db.purchaseItems).getSingle();
    await db.customStatement(
      "CREATE TEMP TRIGGER fail_purchase_return_receipt "
      "BEFORE INSERT ON app_settings "
      "WHEN NEW.key = 'operation.purchase_return.fail-write' "
      "BEGIN SELECT RAISE(ABORT, 'simulated receipt failure'); END",
    );

    await expectLater(
      useCases.createPurchaseReturn(
        operationKey: 'fail-write',
        purchaseId: purchaseId,
        purchaseItemQuantities: {purchaseItem.id: 1},
        settlementMethod: PaymentMethod.installment,
      ),
      throwsA(isA<SqliteException>()),
    );
    expect(await db.select(db.purchaseReturns).get(), isEmpty);
    expect(await db.select(db.purchaseReturnItems).get(), isEmpty);
    expect((await db.select(db.products).getSingle()).stockQty, 1);
  });
}

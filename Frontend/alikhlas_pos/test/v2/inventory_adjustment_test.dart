import 'dart:io';

import 'package:alikhlas_pos/v2/accounting/account_codes.dart';
import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<T> _success<T>(Future<AppResult<T>> result) async =>
    (await result as AppSuccess<T>).value;

void main() {
  test(
    'shortage and surplus create auditable stock and ledger records',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final useCases = V2UseCases(db, clock: () => DateTime(2026, 9, 11, 12));
      final product = await _success(
        useCases.createProduct(
          operationKey: useCases.newOpeningStockOperationKey(),
          name: 'غسالة الجرد',
          salePriceMinor: 100000,
          openingQty: 10,
          openingCostMinor: 50000,
        ),
      );

      final shortageId = await _success(
        useCases.reconcileInventory(
          operationKey: useCases.newInventoryAdjustmentOperationKey(),
          productId: product.id,
          expectedStockQty: 10,
          countedQty: 8,
          reason: InventoryAdjustmentReason.damage,
          note: 'كسر أثناء النقل',
          unitCostMinor: 50000,
        ),
      );
      var updated = await (db.select(
        db.products,
      )..where((row) => row.id.equals(product.id))).getSingle();
      expect(updated.stockQty, 8);
      final shortage = await (db.select(
        db.inventoryAdjustments,
      )..where((row) => row.id.equals(shortageId))).getSingle();
      expect(shortage.previousQty, 10);
      expect(shortage.countedQty, 8);
      expect(shortage.valueDeltaMinor, -100000);
      expect(shortage.reason, InventoryAdjustmentReason.damage.name);

      final shortageLines = await db
          .customSelect(
            'SELECT account_code, debit_minor, credit_minor FROM ledger_lines '
            'WHERE entry_id = (SELECT id FROM ledger_entries '
            'WHERE reference_type = ? AND reference_id = ?)',
            variables: [
              Variable.withString('inventory_adjustment'),
              Variable.withInt(shortageId),
            ],
          )
          .get();
      expect(
        shortageLines.any(
          (row) =>
              row.read<String>('account_code') ==
                  AccountCodes.inventoryVariance &&
              row.read<int>('debit_minor') == 100000,
        ),
        isTrue,
      );
      expect(
        shortageLines.any(
          (row) =>
              row.read<String>('account_code') == AccountCodes.inventory &&
              row.read<int>('credit_minor') == 100000,
        ),
        isTrue,
      );

      await _success(
        useCases.reconcileInventory(
          operationKey: useCases.newInventoryAdjustmentOperationKey(),
          productId: product.id,
          expectedStockQty: 8,
          countedQty: 9,
          reason: InventoryAdjustmentReason.found,
          unitCostMinor: 50000,
        ),
      );
      updated = await (db.select(
        db.products,
      )..where((row) => row.id.equals(product.id))).getSingle();
      expect(updated.stockQty, 9);
      final dashboard = await useCases.dashboardSnapshot();
      expect(dashboard.inventoryMinor, 450000);
      expect(dashboard.inventoryVarianceMinor, 50000);
      expect(dashboard.grossProfitMinor, -50000);
      final audit = await useCases.dataIntegrityAudit();
      expect(
        audit.isConsistent,
        isTrue,
        reason: audit.issues
            .map((issue) => '${issue.code}: ${issue.record}: ${issue.message}')
            .join('\n'),
      );
    },
  );

  test('zero-cost product requires and adopts a reviewed unit cost', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final useCases = V2UseCases(db);
    final product = await _success(
      useCases.createProduct(
        name: 'صنف بلا تكلفة',
        salePriceMinor: 15000,
        openingQty: 0,
        openingCostMinor: 0,
      ),
    );

    expect(
      await useCases.reconcileInventory(
        operationKey: useCases.newInventoryAdjustmentOperationKey(),
        productId: product.id,
        expectedStockQty: 0,
        countedQty: 3,
        reason: InventoryAdjustmentReason.physicalCount,
        unitCostMinor: 0,
      ),
      isA<AppFailure<int>>(),
    );
    expect(await db.select(db.inventoryAdjustments).get(), isEmpty);

    await _success(
      useCases.reconcileInventory(
        operationKey: useCases.newInventoryAdjustmentOperationKey(),
        productId: product.id,
        expectedStockQty: 0,
        countedQty: 3,
        reason: InventoryAdjustmentReason.physicalCount,
        unitCostMinor: 7000,
      ),
    );
    final updated = await db.select(db.products).getSingle();
    expect(updated.stockQty, 3);
    expect(updated.avgCostMinor, 7000);
    expect((await useCases.dashboardSnapshot()).inventoryVarianceMinor, -21000);
  });

  test(
    'same adjustment key survives reopening and cannot change payload',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'inventory-adjust-',
      );
      late AppDatabase db;
      addTearDown(() async {
        await db.close();
        directory.deleteSync(recursive: true);
      });
      db = AppDatabase(NativeDatabase(File('${directory.path}/shop.db')));
      var useCases = V2UseCases(db);
      final product = await _success(
        useCases.createProduct(
          operationKey: useCases.newOpeningStockOperationKey(),
          name: 'ثلاجة جرد',
          salePriceMinor: 30000,
          openingQty: 4,
          openingCostMinor: 20000,
        ),
      );
      final key = useCases.newInventoryAdjustmentOperationKey();
      final request = PendingFinancialOperation.inventoryAdjustment(
        operationKey: key,
        productId: product.id,
        expectedStockQty: 4,
        countedQty: 2,
        reason: InventoryAdjustmentReason.loss,
        note: 'فرق جرد المخزن',
        unitCostMinor: 20000,
      );
      await useCases.stagePendingFinancialOperation(request);
      final firstId = await _success(
        useCases.submitPendingFinancialOperation(request),
      );

      await db.close();
      db = AppDatabase(NativeDatabase(File('${directory.path}/shop.db')));
      useCases = V2UseCases(db);
      final restored = await useCases.pendingFinancialOperation();
      expect(restored?.encode(), request.encode());
      expect(
        await _success(useCases.submitPendingFinancialOperation(restored!)),
        firstId,
      );
      expect(
        await useCases.reconcileInventory(
          operationKey: key,
          productId: product.id,
          expectedStockQty: 4,
          countedQty: 1,
          reason: InventoryAdjustmentReason.loss,
          note: 'فرق جرد المخزن',
          unitCostMinor: 20000,
        ),
        isA<AppFailure<int>>(),
      );
      expect(await db.select(db.inventoryAdjustments).get(), hasLength(1));
      expect(await db.select(db.stockMovements).get(), hasLength(2));
      expect(await useCases.acknowledgePendingFinancialOperation(key), isTrue);
    },
  );

  test(
    'stale stock and receipt write failure leave no partial adjustment',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final useCases = V2UseCases(db);
      final product = await _success(
        useCases.createProduct(
          operationKey: useCases.newOpeningStockOperationKey(),
          name: 'بوتاجاز جرد',
          salePriceMinor: 30000,
          openingQty: 4,
          openingCostMinor: 20000,
        ),
      );
      expect(
        await useCases.reconcileInventory(
          operationKey: useCases.newInventoryAdjustmentOperationKey(),
          productId: product.id,
          expectedStockQty: 3,
          countedQty: 2,
          reason: InventoryAdjustmentReason.physicalCount,
          unitCostMinor: 20000,
        ),
        isA<AppFailure<int>>(),
      );
      expect(await db.select(db.inventoryAdjustments).get(), isEmpty);

      await db.customStatement(
        "CREATE TEMP TRIGGER fail_adjustment_receipt BEFORE INSERT ON app_settings "
        "WHEN NEW.key = 'operation.inventory_adjustment.fail-write' "
        "BEGIN SELECT RAISE(ABORT, 'simulated receipt failure'); END",
      );
      await expectLater(
        useCases.reconcileInventory(
          operationKey: 'fail-write',
          productId: product.id,
          expectedStockQty: 4,
          countedQty: 2,
          reason: InventoryAdjustmentReason.physicalCount,
          unitCostMinor: 20000,
        ),
        throwsA(isA<SqliteException>()),
      );
      expect((await db.select(db.products).getSingle()).stockQty, 4);
      expect(await db.select(db.inventoryAdjustments).get(), isEmpty);
      expect(await db.select(db.stockMovements).get(), hasLength(1));
      expect(await db.select(db.ledgerEntries).get(), hasLength(1));
    },
  );

  test(
    'integrity audit detects a missing inventory adjustment ledger',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final useCases = V2UseCases(db);
      final product = await _success(
        useCases.createProduct(
          operationKey: useCases.newOpeningStockOperationKey(),
          name: 'صنف فحص قيد الجرد',
          salePriceMinor: 20000,
          openingQty: 2,
          openingCostMinor: 10000,
        ),
      );
      final adjustmentId = await _success(
        useCases.reconcileInventory(
          operationKey: useCases.newInventoryAdjustmentOperationKey(),
          productId: product.id,
          expectedStockQty: 2,
          countedQty: 1,
          reason: InventoryAdjustmentReason.damage,
          unitCostMinor: 10000,
        ),
      );
      final entry =
          await (db.select(db.ledgerEntries)..where(
                (row) =>
                    row.referenceType.equals('inventory_adjustment') &
                    row.referenceId.equals(adjustmentId),
              ))
              .getSingle();
      await (db.delete(
        db.ledgerLines,
      )..where((row) => row.entryId.equals(entry.id))).go();
      await (db.delete(
        db.ledgerEntries,
      )..where((row) => row.id.equals(entry.id))).go();

      final audit = await useCases.dataIntegrityAudit();
      expect(
        audit.issues.map((issue) => issue.code),
        contains('inventory_adjustment_ledger'),
      );
    },
  );
}

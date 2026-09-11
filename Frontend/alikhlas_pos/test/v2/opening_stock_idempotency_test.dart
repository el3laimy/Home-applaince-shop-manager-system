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
    'opening stock replays one product, stock movement, and ledger entry after reopening',
    () async {
      final directory = Directory.systemTemp.createTempSync('opening-stock-');
      late AppDatabase db;
      addTearDown(() async {
        await db.close();
        directory.deleteSync(recursive: true);
      });
      db = AppDatabase(NativeDatabase(File('${directory.path}/shop.db')));
      var useCases = V2UseCases(db);
      final key = useCases.newOpeningStockOperationKey();

      final results = await Future.wait([
        useCases.createProduct(
          operationKey: key,
          name: 'رصيد افتتاحي آمن',
          salePriceMinor: 12500,
          openingQty: 2,
          openingCostMinor: 7000,
        ),
        useCases.createProduct(
          operationKey: key,
          name: 'رصيد افتتاحي آمن',
          salePriceMinor: 12500,
          openingQty: 2,
          openingCostMinor: 7000,
        ),
      ]);
      final productId = (results.first as AppSuccess<Product>).value.id;
      expect((results.last as AppSuccess<Product>).value.id, productId);
      expect(await db.select(db.products).get(), hasLength(1));
      expect(await db.select(db.stockMovements).get(), hasLength(1));
      expect(await db.select(db.ledgerEntries).get(), hasLength(1));

      await db.close();
      db = AppDatabase(NativeDatabase(File('${directory.path}/shop.db')));
      useCases = V2UseCases(db);
      expect(
        (await success(
          useCases.createProduct(
            operationKey: key,
            name: 'رصيد افتتاحي آمن',
            salePriceMinor: 12500,
            openingQty: 2,
            openingCostMinor: 7000,
          ),
        )).id,
        productId,
      );
      expect(
        await useCases.createProduct(
          operationKey: key,
          name: 'رصيد افتتاحي آمن',
          salePriceMinor: 12500,
          openingQty: 3,
          openingCostMinor: 7000,
        ),
        isA<AppFailure<Product>>(),
      );
      expect(await db.select(db.products).get(), hasLength(1));
      expect(await db.select(db.stockMovements).get(), hasLength(1));
      expect(await db.select(db.ledgerEntries).get(), hasLength(1));
    },
  );

  test(
    'pending opening stock survives a missed reply and can only replay',
    () async {
      final directory = Directory.systemTemp.createTempSync('opening-pending-');
      late AppDatabase db;
      addTearDown(() async {
        await db.close();
        directory.deleteSync(recursive: true);
      });
      db = AppDatabase(NativeDatabase(File('${directory.path}/shop.db')));
      var useCases = V2UseCases(db);
      final request = PendingFinancialOperation.openingStock(
        operationKey: useCases.newOpeningStockOperationKey(),
        name: 'رصيد مستعاد',
        barcode: 'OPENING-RECOVERY',
        category: 'اختبار',
        salePriceMinor: 18000,
        openingQty: 1,
        openingCostMinor: 9500,
        minStockQty: 1,
      );

      expect(
        (await useCases.stagePendingFinancialOperation(request)).encode(),
        request.encode(),
      );
      final productId = await success(
        useCases.submitPendingFinancialOperation(request),
      );
      await db.close();
      db = AppDatabase(NativeDatabase(File('${directory.path}/shop.db')));
      useCases = V2UseCases(db);

      final restored = await useCases.pendingFinancialOperation();
      expect(restored?.encode(), request.encode());
      expect(
        await success(useCases.submitPendingFinancialOperation(restored!)),
        productId,
      );
      expect(
        await useCases.acknowledgePendingFinancialOperation(
          request.operationKey,
        ),
        isTrue,
      );
      expect(await useCases.pendingFinancialOperation(), isNull);
      expect(await db.select(db.products).get(), hasLength(1));
      expect(await db.select(db.stockMovements).get(), hasLength(1));
      expect(await db.select(db.ledgerEntries).get(), hasLength(1));
    },
  );

  test(
    'opening stock rolls back if its durable receipt cannot be written',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final useCases = V2UseCases(db);
      await db.customStatement(
        "CREATE TEMP TRIGGER fail_opening_receipt BEFORE INSERT ON app_settings WHEN NEW.key = 'operation.opening_stock.fail-write' BEGIN SELECT RAISE(ABORT, 'simulated receipt failure'); END",
      );

      await expectLater(
        useCases.createProduct(
          operationKey: 'fail-write',
          name: 'لا يجب حفظه',
          salePriceMinor: 9000,
          openingQty: 1,
          openingCostMinor: 4000,
        ),
        throwsA(isA<SqliteException>()),
      );
      expect(await db.select(db.products).get(), isEmpty);
      expect(await db.select(db.stockMovements).get(), isEmpty);
      expect(await db.select(db.ledgerEntries).get(), isEmpty);
    },
  );
}

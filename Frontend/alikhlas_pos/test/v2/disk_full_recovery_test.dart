import 'dart:io';

import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test(
    'disk full rolls back opening stock and the same operation can retry',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'alikhlas-disk-full-',
      );
      final databaseFile = File('${directory.path}/shop.db');
      final db = AppDatabase(NativeDatabase(databaseFile));
      addTearDown(() async {
        await db.close();
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      final useCases = V2UseCases(db);
      await useCases.bootstrap(createDefaultOwner: false);
      await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE);');

      final pageCount =
          (await db.customSelect('PRAGMA page_count;').getSingle())
                  .data
                  .values
                  .single
              as int;
      final appliedLimit =
          (await db
                      .customSelect('PRAGMA max_page_count = $pageCount;')
                      .getSingle())
                  .data
                  .values
                  .single
              as int;
      expect(appliedLimit, pageCount);

      const operationKey = 'disk-full-opening-stock';
      final largeName = 'ثلاجة اختبار المساحة ${'س' * (4 * 1024 * 1024)}';
      Future<AppResult<Product>> submit() => useCases.createProduct(
        operationKey: operationKey,
        name: largeName,
        salePriceMinor: 120000,
        openingQty: 2,
        openingCostMinor: 80000,
      );

      await expectLater(submit(), throwsA(isA<sqlite.SqliteException>()));

      expect(await db.select(db.products).get(), isEmpty);
      expect(await db.select(db.stockMovements).get(), isEmpty);
      expect(await db.select(db.ledgerEntries).get(), isEmpty);
      expect(await db.select(db.ledgerLines).get(), isEmpty);
      final receiptsAfterFailure = await db
          .customSelect(
            "SELECT count(*) AS total FROM app_settings WHERE key LIKE 'operation.opening_stock.%';",
          )
          .getSingle();
      expect(receiptsAfterFailure.read<int>('total'), 0);
      expect(
        (await db.customSelect('PRAGMA quick_check;').getSingle())
            .data
            .values
            .single,
        'ok',
      );

      await db.customSelect('PRAGMA max_page_count = 1073741823;').getSingle();
      final retried = await submit();
      expect(retried, isA<AppSuccess<Product>>());
      expect(await db.select(db.products).get(), hasLength(1));
      expect(await db.select(db.stockMovements).get(), hasLength(1));
      expect(await db.select(db.ledgerEntries).get(), hasLength(1));
      expect(await db.select(db.ledgerLines).get(), hasLength(2));
      final receiptsAfterRetry = await db
          .customSelect(
            "SELECT count(*) AS total FROM app_settings WHERE key LIKE 'operation.opening_stock.%';",
          )
          .getSingle();
      expect(receiptsAfterRetry.read<int>('total'), 1);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

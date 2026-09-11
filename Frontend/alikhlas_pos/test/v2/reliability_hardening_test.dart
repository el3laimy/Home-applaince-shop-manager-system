import 'dart:io';

import 'package:alikhlas_pos/v2/application/backup_file_operations.dart';
import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('a failed prune keeps a valid backup and records a warning', () async {
    final root = await Directory.systemTemp.createTemp('backup-prune-');
    addTearDown(() => root.delete(recursive: true));
    final db = AppDatabase(NativeDatabase(File('${root.path}/shop.db')));
    addTearDown(db.close);
    final backups = Directory('${root.path}/backups');
    await backups.create();
    final oldBackup = File('${backups.path}/alikhlas-v2-old.db');
    await oldBackup.writeAsBytes([1]);
    await oldBackup.setLastModified(DateTime(2020));
    final useCases = V2UseCases(
      db,
      backupFileOperations: const _LockedBackupFileOperations(),
      clock: () => DateTime(2026, 9, 12, 10),
    );
    await useCases.bootstrap(createDefaultOwner: false);
    await useCases.setBackupDirectory(backups.path);
    await db
        .into(db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: 'backup.keepCopies', value: '1'),
        );

    final created = await useCases.runAutomaticBackupIfDue();

    expect(created, isNotNull);
    expect(await created!.exists(), isTrue);
    expect(useCases.backupWarning, contains('تعذر حذف'));
    final lastSuccess =
        await (db.select(db.appSettings)
              ..where((setting) => setting.key.equals('backup.lastSuccessAt')))
            .getSingle();
    expect(lastSuccess.value, DateTime(2026, 9, 12, 10).toIso8601String());
  });

  test(
    'login throttling blocks brute-force attempts without exposing data',
    () async {
      var now = DateTime(2026, 9, 12, 11);
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final useCases = V2UseCases(db, clock: () => now);
      await useCases.bootstrap(createDefaultOwner: false);
      final owner = await useCases.createInitialOwner(
        fullName: 'مالك الاختبار',
        password: 'safe-owner-password',
      );
      expect(owner, isA<AppSuccess<User>>());

      for (var attempt = 0; attempt < 5; attempt += 1) {
        expect(
          await useCases.login('unknown', 'wrong-password'),
          isA<AppFailure<User>>(),
        );
      }
      final locked = await useCases.login('owner', 'safe-owner-password');
      expect(locked, isA<AppFailure<User>>());
      expect((locked as AppFailure<User>).message, contains('مؤقتًا'));

      now = now.add(const Duration(minutes: 16));
      expect(
        await useCases.login('owner', 'safe-owner-password'),
        isA<AppSuccess<User>>(),
      );
    },
  );

  test(
    'business rules reject zero-cost opening stock, inactive purchases, and negative shifts',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final useCases = V2UseCases(db);

      expect(
        await useCases.createProduct(
          operationKey: useCases.newOpeningStockOperationKey(),
          name: 'رصيد بدون تكلفة',
          salePriceMinor: 1000,
          openingQty: 1,
          openingCostMinor: 0,
        ),
        isA<AppFailure<Product>>(),
      );
      expect(
        await useCases.openShift(
          -1,
          operationKey: useCases.newShiftOperationKey(),
        ),
        isA<AppFailure<Shift>>(),
      );

      final product = await useCases.createProduct(
        operationKey: useCases.newOpeningStockOperationKey(),
        name: 'صنف مؤرشف',
        salePriceMinor: 1000,
        openingQty: 0,
        openingCostMinor: 0,
      );
      final productId = (product as AppSuccess<Product>).value.id;
      expect(
        await useCases.deactivateProduct(productId),
        isA<AppSuccess<void>>(),
      );
      expect(
        await useCases.createPurchase(
          operationKey: useCases.newPurchaseOperationKey(),
          items: [
            PurchaseLineInput(productId: productId, qty: 1, unitCostMinor: 500),
          ],
          payments: const [],
        ),
        isA<AppFailure<int>>(),
      );
    },
  );

  test('SQLite guards reject invalid inventory and ledger rows', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.select(db.products).get();

    await expectLater(
      db.customStatement(
        "INSERT INTO products(name, stock_qty, min_stock_qty, sale_price_minor, avg_cost_minor, inventory_value_minor) VALUES ('invalid', -1, 0, 100, 0, 0);",
      ),
      throwsA(isA<sqlite.SqliteException>()),
    );
    final entryId = await db
        .into(db.ledgerEntries)
        .insert(
          LedgerEntriesCompanion.insert(
            referenceType: 'test',
            referenceId: 1,
            description: 'حاجز قاعدة البيانات',
          ),
        );
    await expectLater(
      db.customStatement(
        "INSERT INTO ledger_lines(entry_id, account_code, debit_minor, credit_minor) VALUES ($entryId, 'cash', 1, 1);",
      ),
      throwsA(isA<sqlite.SqliteException>()),
    );
  });
}

class _LockedBackupFileOperations extends BackupFileOperations {
  const _LockedBackupFileOperations();

  @override
  Future<void> deleteFile(File file) async {
    throw FileSystemException('simulated locked backup', file.path);
  }
}

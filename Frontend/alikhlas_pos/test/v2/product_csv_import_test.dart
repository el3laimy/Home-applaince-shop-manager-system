import 'dart:io';

import 'package:alikhlas_pos/v2/accounting/account_codes.dart';
import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

Future<T> _success<T>(Future<AppResult<T>> result) async =>
    (await result as AppSuccess<T>).value;

void main() {
  test('template and preview accept quoted Arabic UTF-8 product rows', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final useCases = V2UseCases(db);
    final template = useCases.productCsvTemplate();
    expect(template, startsWith('\ufeff"اسم المنتج","الباركود"'));

    final preview = await useCases.previewProductCsv(
      '$template\r\n"غسالة, كبيرة","ABC-1","غسالات","١٢٥٠٫٥٠","٢","٨٠٠","١"\r\n',
    );

    expect(preview.issues, isEmpty);
    expect(preview.rows, hasLength(1));
    final row = preview.rows.single;
    expect(row.sourceRow, 3);
    expect(row.name, 'غسالة, كبيرة');
    expect(row.salePriceMinor, 125050);
    expect(row.openingQty, 2);
    expect(row.openingCostMinor, 80000);
  });

  test(
    'preview reports each bad row and existing or repeated barcodes',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final useCases = V2UseCases(db);
      await _success(
        useCases.createProduct(
          name: 'موجود',
          barcode: 'USED',
          salePriceMinor: 10000,
          openingQty: 0,
          openingCostMinor: 0,
        ),
      );
      final header = useCases.productCsvTemplate();
      final preview = await useCases.previewProductCsv(
        '$header\u0635نف أول,USED,تصنيف,100,1,50,1\r\n'
        'صنف ثان,DUP,تصنيف,100,1,50,1\r\n'
        'صنف ثالث,DUP,تصنيف,100,1,50,1\r\n'
        'صنف ناقص,ONLY,TWO\r\n'
        'صنف تكلفة,ZERO,تصنيف,100,2,0,1\r\n',
      );

      expect(preview.canImport, isFalse);
      expect(
        preview.issues.map((issue) => issue.sourceRow),
        containsAll([2, 4, 5, 6]),
      );
      expect(
        preview.issues.any((issue) => issue.message.contains('مستخدم بالفعل')),
        isTrue,
      );
      expect(
        preview.issues.any(
          (issue) => issue.message.contains('مكرر داخل الملف'),
        ),
        isTrue,
      );
      expect(await db.select(db.products).get(), hasLength(1));
    },
  );

  test('valid import is atomic, balanced, and idempotent', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final useCases = V2UseCases(db);
    final preview = await useCases.previewProductCsv(
      '${useCases.productCsvTemplate()}'
      'ثلاجة,FRIDGE-1,ثلاجات,15000,2,10000,1\r\n'
      'مروحة,,مراوح,2000,0,0,2\r\n',
    );
    expect(preview.canImport, isTrue);
    const key = 'products-csv-once';

    expect(
      await _success(
        useCases.importProductCsv(operationKey: key, rows: preview.rows),
      ),
      2,
    );
    expect(
      await _success(
        useCases.importProductCsv(operationKey: key, rows: preview.rows),
      ),
      2,
    );

    final products = await db.select(db.products).get();
    expect(products, hasLength(2));
    expect(products.singleWhere((row) => row.name == 'ثلاجة').stockQty, 2);
    expect(
      products.singleWhere((row) => row.name == 'مروحة').barcode,
      isNotEmpty,
    );
    expect(await db.select(db.stockMovements).get(), hasLength(1));
    final lines = await db.select(db.ledgerLines).get();
    expect(lines, hasLength(2));
    expect(
      lines
          .singleWhere((line) => line.accountCode == AccountCodes.inventory)
          .debitMinor,
      2000000,
    );
    expect((await useCases.dataIntegrityAudit()).isConsistent, isTrue);

    final changed = [
      ProductCsvImportRow(
        sourceRow: preview.rows.first.sourceRow,
        name: preview.rows.first.name,
        barcode: preview.rows.first.barcode,
        category: preview.rows.first.category,
        salePriceMinor: preview.rows.first.salePriceMinor + 1,
        openingQty: preview.rows.first.openingQty,
        openingCostMinor: preview.rows.first.openingCostMinor,
        minStockQty: preview.rows.first.minStockQty,
      ),
    ];
    expect(
      await useCases.importProductCsv(operationKey: key, rows: changed),
      isA<AppFailure<int>>(),
    );
    expect(await db.select(db.products).get(), hasLength(2));
  });

  test('direct invalid input rejects the whole batch without writes', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final useCases = V2UseCases(db);
    final rows = [
      const ProductCsvImportRow(
        sourceRow: 2,
        name: 'سليم',
        barcode: 'OK',
        category: null,
        salePriceMinor: 10000,
        openingQty: 1,
        openingCostMinor: 5000,
        minStockQty: 1,
      ),
      const ProductCsvImportRow(
        sourceRow: 3,
        name: 'غير سليم',
        barcode: 'BAD',
        category: null,
        salePriceMinor: 10000,
        openingQty: 2,
        openingCostMinor: 0,
        minStockQty: 1,
      ),
    ];

    expect(
      await useCases.importProductCsv(
        operationKey: 'invalid-batch',
        rows: rows,
      ),
      isA<AppFailure<int>>(),
    );
    expect(await db.select(db.products).get(), isEmpty);
    expect(await db.select(db.stockMovements).get(), isEmpty);
    expect(await db.select(db.ledgerEntries).get(), isEmpty);
  });

  test('import requires a durable operation key before any write', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final useCases = V2UseCases(db);
    const row = ProductCsvImportRow(
      sourceRow: 2,
      name: 'ثلاجة',
      barcode: 'NO-KEY',
      category: 'ثلاجات',
      salePriceMinor: 1500000,
      openingQty: 1,
      openingCostMinor: 1000000,
      minStockQty: 1,
    );

    expect(
      await useCases.importProductCsv(rows: const [row]),
      isA<AppFailure<int>>(),
    );
    expect(await db.select(db.products).get(), isEmpty);
    expect(await db.select(db.ledgerEntries).get(), isEmpty);
  });

  test('pending import replays once after reopening the database', () async {
    final directory = Directory.systemTemp.createTempSync('csv-import-once-');
    late AppDatabase db;
    addTearDown(() async {
      await db.close();
      directory.deleteSync(recursive: true);
    });
    db = AppDatabase(NativeDatabase(File('${directory.path}/shop.db')));
    var useCases = V2UseCases(db);
    final preview = await useCases.previewProductCsv(
      '${useCases.productCsvTemplate()}بوتاجاز,COOKER,بوتاجازات,9000,1,7000,1\r\n',
    );
    final request = PendingFinancialOperation.productCsvImport(
      operationKey: useCases.newProductCsvImportOperationKey(),
      rows: preview.rows,
    );
    await useCases.stagePendingFinancialOperation(request);
    expect(
      await _success(useCases.submitPendingFinancialOperation(request)),
      1,
    );

    await db.close();
    db = AppDatabase(NativeDatabase(File('${directory.path}/shop.db')));
    useCases = V2UseCases(db);
    final restored = await useCases.pendingFinancialOperation();
    expect(restored?.encode(), request.encode());
    expect(
      await _success(useCases.submitPendingFinancialOperation(restored!)),
      1,
    );
    expect(await db.select(db.products).get(), hasLength(1));
    expect(
      await useCases.acknowledgePendingFinancialOperation(request.operationKey),
      isTrue,
    );
  });

  test(
    'receipt failure rolls back every imported row and ledger line',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final useCases = V2UseCases(db);
      final preview = await useCases.previewProductCsv(
        '${useCases.productCsvTemplate()}تكييف,AC-1,تكييفات,20000,1,15000,1\r\n'
        'شاشة,TV-1,شاشات,10000,1,8000,1\r\n',
      );
      await db.customStatement(
        "CREATE TEMP TRIGGER fail_csv_receipt "
        "BEFORE INSERT ON app_settings "
        "WHEN NEW.key = 'operation.product_csv_import.fail-csv' "
        "BEGIN SELECT RAISE(ABORT, 'simulated receipt failure'); END",
      );

      await expectLater(
        useCases.importProductCsv(operationKey: 'fail-csv', rows: preview.rows),
        throwsA(isA<sqlite.SqliteException>()),
      );
      expect(await db.select(db.products).get(), isEmpty);
      expect(await db.select(db.stockMovements).get(), isEmpty);
      expect(await db.select(db.ledgerEntries).get(), isEmpty);
      expect(await db.select(db.ledgerLines).get(), isEmpty);
    },
  );
}

import 'dart:io';
import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<T> success<T>(Future<AppResult<T>> result) async =>
    (await result as AppSuccess<T>).value;

void main() {
  test('sale operation survives reopen and rejects changed payload', () async {
    final dir = Directory.systemTemp.createTempSync('sale-once-');
    var db = AppDatabase(NativeDatabase(File('${dir.path}/shop.db')));
    addTearDown(() async {
      await db.close();
      dir.deleteSync(recursive: true);
    });
    var uc = V2UseCases(db);
    await uc.bootstrap(createDefaultOwner: true);
    final product = await success(
      uc.createProduct(
        operationKey: uc.newOpeningStockOperationKey(),
        name: 'منتج',
        salePriceMinor: 100,
        openingQty: 3,
        openingCostMinor: 50,
      ),
    );
    final key = uc.newSaleOperationKey();
    final items = [
      SaleLineInput(productId: product.id, qty: 1, unitPriceMinor: 100),
    ];
    const payments = [PaymentInput(PaymentMethod.wallet, 100)];
    final results = await Future.wait([
      for (var i = 0; i < 2; i++)
        uc.createSale(operationKey: key, items: items, payments: payments),
    ]);
    final id = (results.first as AppSuccess<int>).value;
    expect((results.last as AppSuccess<int>).value, id);
    expect(await db.select(db.saleInvoices).get(), hasLength(1));
    expect((await db.select(db.products).getSingle()).stockQty, 2);
    final entriesBefore = (await db.select(db.ledgerEntries).get()).length;
    await db.close();
    db = AppDatabase(NativeDatabase(File('${dir.path}/shop.db')));
    uc = V2UseCases(db);
    expect(
      await success(
        uc.createSale(operationKey: key, items: items, payments: payments),
      ),
      id,
    );
    expect(
      await uc.createSale(
        operationKey: key,
        items: [
          SaleLineInput(productId: product.id, qty: 2, unitPriceMinor: 100),
        ],
        payments: const [PaymentInput(PaymentMethod.wallet, 200)],
      ),
      isA<AppFailure<int>>(),
    );
    expect((await db.select(db.ledgerEntries).get()).length, entriesBefore);
    expect((await db.select(db.products).getSingle()).stockQty, 2);
    expect(await db.select(db.saleInvoices).get(), hasLength(1));
    final failedKey = uc.newSaleOperationKey();
    expect(
      await uc.createSale(
        operationKey: failedKey,
        items: [
          SaleLineInput(productId: product.id, qty: 4, unitPriceMinor: 100),
        ],
        payments: const [PaymentInput(PaymentMethod.wallet, 400)],
      ),
      isA<AppFailure<int>>(),
    );
    expect(
      await success(
        uc.createSale(
          operationKey: failedKey,
          items: items,
          payments: payments,
        ),
      ),
      isNot(id),
    );
    expect(await db.select(db.saleInvoices).get(), hasLength(2));
    final ledgerCount = (await db.select(db.ledgerEntries).get()).length;
    await db.customStatement(
      "CREATE TEMP TRIGGER fail_operation BEFORE INSERT ON app_settings WHEN NEW.key = 'operation.sale.failed-write' BEGIN SELECT RAISE(ABORT, 'simulated operation receipt failure'); END",
    );
    await expectLater(
      uc.createSale(
        operationKey: 'failed-write',
        items: items,
        payments: payments,
      ),
      throwsA(isA<SqliteException>()),
    );
    expect(await db.select(db.saleInvoices).get(), hasLength(2));
    expect((await db.select(db.ledgerEntries).get()).length, ledgerCount);
    expect((await db.select(db.products).getSingle()).stockQty, 1);
  });
}

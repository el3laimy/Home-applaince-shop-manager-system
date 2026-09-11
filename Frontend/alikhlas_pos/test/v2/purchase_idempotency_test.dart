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
    'purchase retries preserve approval stock and ledger across reopen',
    () async {
      final dir = Directory.systemTemp.createTempSync('purchase-once-');
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
          name: 'شراء',
          salePriceMinor: 200,
          openingQty: 0,
          openingCostMinor: 0,
        ),
      );
      final items = [
        PurchaseLineInput(productId: product.id, qty: 1, unitCostMinor: 100),
      ];
      const payments = [PaymentInput(PaymentMethod.wallet, 100)];
      final key = uc.newPurchaseOperationKey();
      expect(
        await uc.createPurchase(
          operationKey: key,
          items: items,
          payments: payments,
        ),
        isA<AppConfirmationRequired<int>>(),
      );
      expect(await db.select(db.purchaseInvoices).get(), isEmpty);
      final results = await Future.wait([
        for (var i = 0; i < 2; i++)
          uc.createPurchase(
            operationKey: key,
            items: items,
            payments: payments,
            allowNegativeBalance: true,
          ),
      ]);
      final id = (results.first as AppSuccess<int>).value;
      expect((results.last as AppSuccess<int>).value, id);
      final ledgerCount = (await db.select(db.ledgerEntries).get()).length;
      await db.close();
      db = AppDatabase(NativeDatabase(File('${dir.path}/shop.db')));
      uc = V2UseCases(db);
      expect(
        await success(
          uc.createPurchase(
            operationKey: key,
            items: items,
            payments: payments,
          ),
        ),
        id,
      );
      expect(
        await uc.createPurchase(
          operationKey: key,
          items: [
            PurchaseLineInput(
              productId: product.id,
              qty: 2,
              unitCostMinor: 100,
            ),
          ],
          payments: const [PaymentInput(PaymentMethod.wallet, 200)],
          allowNegativeBalance: true,
        ),
        isA<AppFailure<int>>(),
      );
      await db.customStatement(
        "CREATE TEMP TRIGGER fail_purchase_receipt BEFORE INSERT ON app_settings WHEN NEW.key = 'operation.purchase.fail-write' BEGIN SELECT RAISE(ABORT, 'simulated write failure'); END",
      );
      await expectLater(
        uc.createPurchase(
          operationKey: 'fail-write',
          items: items,
          payments: payments,
          allowNegativeBalance: true,
        ),
        throwsA(isA<SqliteException>()),
      );
      expect(await db.select(db.purchaseInvoices).get(), hasLength(1));
      expect((await db.select(db.products).getSingle()).stockQty, 1);
      expect((await db.select(db.products).getSingle()).avgCostMinor, 100);
      expect((await db.select(db.ledgerEntries).get()).length, ledgerCount);
    },
  );
}

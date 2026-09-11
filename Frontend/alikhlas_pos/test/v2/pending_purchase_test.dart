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
    'pending purchase recovers without persisting negative balance consent',
    () async {
      final dir = Directory.systemTemp.createTempSync('pending-purchase-');
      var db = AppDatabase(NativeDatabase(File('${dir.path}/shop.db')));
      addTearDown(() async {
        await db.close();
        dir.deleteSync(recursive: true);
      });
      var uc = V2UseCases(db);
      await uc.bootstrap();
      final product = await success(
        uc.createProduct(
          operationKey: uc.newOpeningStockOperationKey(),
          name: 'شراء',
          salePriceMinor: 200,
          openingQty: 0,
          openingCostMinor: 0,
        ),
      );
      final request = PendingPurchase(
        operationKey: uc.newPurchaseOperationKey(),
        items: [
          PurchaseLineInput(productId: product.id, qty: 1, unitCostMinor: 100),
        ],
        payments: const [PaymentInput(PaymentMethod.wallet, 100, note: 'دفعة')],
      );
      final other = PendingPurchase(
        operationKey: uc.newPurchaseOperationKey(),
        items: request.items,
        payments: request.payments,
      );
      await uc.stagePendingPurchase(request);
      expect(
        (await uc.stagePendingPurchase(other)).operationKey,
        request.operationKey,
      );
      expect(
        await uc.submitPendingPurchase(request),
        isA<AppConfirmationRequired<int>>(),
      );
      expect(
        await uc.acknowledgePendingPurchase(request.operationKey),
        isFalse,
      );
      await db.close();
      db = AppDatabase(NativeDatabase(File('${dir.path}/shop.db')));
      uc = V2UseCases(db);
      final restored = (await uc.pendingPurchase())!;
      expect(restored.encode(), request.encode());
      expect(
        await uc.submitPendingPurchase(restored),
        isA<AppConfirmationRequired<int>>(),
      );
      expect(await db.select(db.purchaseInvoices).get(), isEmpty);
      final id = await success(
        uc.submitPendingPurchase(restored, allowNegativeBalance: true),
      );
      await db.close();
      db = AppDatabase(NativeDatabase(File('${dir.path}/shop.db')));
      uc = V2UseCases(db);
      expect(
        await uc.discardUncommittedPendingPurchase(request.operationKey),
        isFalse,
      );
      expect(await uc.acknowledgePendingPurchase(other.operationKey), isFalse);
      expect(
        await success(uc.submitPendingPurchase((await uc.pendingPurchase())!)),
        id,
      );
      expect(await db.select(db.purchaseInvoices).get(), hasLength(1));
      expect((await db.select(db.products).getSingle()).stockQty, 1);
      expect(await uc.acknowledgePendingPurchase(request.operationKey), isTrue);
      expect(await uc.pendingPurchase(), isNull);
      await uc.stagePendingPurchase(other);
      expect(
        await uc.discardUncommittedPendingPurchase(other.operationKey),
        isTrue,
      );
      expect(
        await uc.submitPendingPurchase(other, allowNegativeBalance: true),
        isA<AppFailure<int>>(),
      );
      await uc.stagePendingPurchase(other);
      final racing = await Future.wait<Object>([
        uc.submitPendingPurchase(other, allowNegativeBalance: true),
        uc.discardUncommittedPendingPurchase(other.operationKey),
      ]);
      final committed = racing[0] is AppSuccess<int>;
      expect(racing[1], !committed);
      expect(
        await db.select(db.purchaseInvoices).get(),
        hasLength(committed ? 2 : 1),
      );
      if (committed) {
        expect(await uc.acknowledgePendingPurchase(other.operationKey), isTrue);
      }
      await db.customStatement(
        "INSERT INTO app_settings (key,value) VALUES ('pending.purchase.v1','{\"version\":99}')",
      );
      await expectLater(uc.pendingPurchase(), throwsFormatException);
      await expectLater(uc.stagePendingPurchase(other), throwsFormatException);
    },
  );
}

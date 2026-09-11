import 'dart:io';
import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<T> success<T>(Future<AppResult<T>> result) async =>
    (await result as AppSuccess<T>).value;

void main() {
  test('pending sale retains installment terms and exact amounts', () {
    final request = PendingSale(
      operationKey: 'terms',
      customerId: 4,
      items: const [SaleLineInput(productId: 7, qty: 3, unitPriceMinor: 333)],
      payments: const [
        PaymentInput(PaymentMethod.cash, 1, note: 'دفعة'),
        PaymentInput(PaymentMethod.wallet, 2),
      ],
      discountMinor: 5,
      installmentTerms: InstallmentTerms(
        partyId: 4,
        count: 7,
        firstDueDate: DateTime(2026, 10, 3),
        interestMinor: 17,
        periodDays: 13,
      ),
    );
    expect(PendingSale.decode(request.encode()).encode(), request.encode());
  });

  test(
    'pending sale survives reopening before and after commit until acknowledged',
    () async {
      final dir = Directory.systemTemp.createTempSync('pending-sale-');
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
          openingQty: 2,
          openingCostMinor: 50,
        ),
      );
      final first = PendingSale(
        operationKey: uc.newSaleOperationKey(),
        items: [
          SaleLineInput(productId: product.id, qty: 1, unitPriceMinor: 100),
        ],
        payments: const [PaymentInput(PaymentMethod.wallet, 100)],
      );
      final second = PendingSale(
        operationKey: uc.newSaleOperationKey(),
        items: first.items,
        payments: first.payments,
      );
      await uc.stagePendingSale(first);
      expect(
        (await uc.stagePendingSale(second)).operationKey,
        first.operationKey,
      );
      expect(await uc.acknowledgePendingSale(first.operationKey), isFalse);
      await db.close();
      db = AppDatabase(NativeDatabase(File('${dir.path}/shop.db')));
      uc = V2UseCases(db);
      final restored = (await uc.pendingSale())!;
      expect(restored.encode(), first.encode());
      final saleId = await success(uc.submitPendingSale(restored));
      // Simulate losing the UI acknowledgement after SQLite has committed.
      await db.close();
      db = AppDatabase(NativeDatabase(File('${dir.path}/shop.db')));
      uc = V2UseCases(db);
      expect(
        await uc.discardUncommittedPendingSale(first.operationKey),
        isFalse,
      );
      expect(await uc.acknowledgePendingSale(second.operationKey), isFalse);
      expect(
        await success(uc.submitPendingSale((await uc.pendingSale())!)),
        saleId,
      );
      expect(await db.select(db.saleInvoices).get(), hasLength(1));
      expect((await db.select(db.products).getSingle()).stockQty, 1);
      expect(await uc.acknowledgePendingSale(first.operationKey), isTrue);
      expect(await uc.pendingSale(), isNull);
      await uc.stagePendingSale(second);
      expect(
        await uc.discardUncommittedPendingSale(second.operationKey),
        isTrue,
      );
      expect(await uc.submitPendingSale(second), isA<AppFailure<int>>());
      expect(await db.select(db.saleInvoices).get(), hasLength(1));
      await uc.stagePendingSale(second);
      final racing = await Future.wait<Object>([
        uc.submitPendingSale(second),
        uc.discardUncommittedPendingSale(second.operationKey),
      ]);
      final committed = racing[0] is AppSuccess<int>;
      expect(racing[1], !committed);
      expect(
        await db.select(db.saleInvoices).get(),
        hasLength(committed ? 2 : 1),
      );
      if (committed) {
        expect(await uc.acknowledgePendingSale(second.operationKey), isTrue);
      }
      await db.customStatement(
        "INSERT INTO app_settings (key, value) VALUES ('pending.sale.v1', '{\"version\":99}')",
      );
      await expectLater(uc.pendingSale(), throwsFormatException);
      await expectLater(uc.stagePendingSale(second), throwsFormatException);
    },
  );
}

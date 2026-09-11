import 'dart:io';

import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<T> _success<T>(Future<AppResult<T>> result) async =>
    (await result as AppSuccess<T>).value;

void main() {
  test(
    'sale and purchase drafts survive reopening and can be discarded',
    () async {
      final directory = Directory.systemTemp.createTempSync('invoice-drafts-');
      late AppDatabase db;
      addTearDown(() async {
        await db.close();
        directory.deleteSync(recursive: true);
      });
      final file = File('${directory.path}/shop.db');
      db = AppDatabase(NativeDatabase(file));
      var useCases = V2UseCases(db);
      final saleDraft = SaleDraft(
        customerId: 8,
        items: const [
          SaleLineInput(productId: 11, qty: 2, unitPriceMinor: 12550),
        ],
        cashMinor: 5000,
        walletMinor: 1000,
        discountMinor: 50,
        interestMinor: 300,
        installmentCount: 4,
        firstDueDate: DateTime.utc(2026, 10, 1),
        periodDays: 45,
        savedAt: DateTime.utc(2026, 9, 11, 12, 30),
      );
      final purchaseDraft = PurchaseDraft(
        supplierId: 9,
        items: const [
          PurchaseLineInput(productId: 11, qty: 3, unitCostMinor: 9000),
        ],
        cashMinor: 0,
        walletMinor: 2000,
        savedAt: DateTime.utc(2026, 9, 11, 12, 31),
      );

      await useCases.saveSaleDraft(saleDraft);
      await useCases.savePurchaseDraft(purchaseDraft);
      await db.close();

      db = AppDatabase(NativeDatabase(file));
      useCases = V2UseCases(db);
      expect((await useCases.saleDraft())?.encode(), saleDraft.encode());
      expect(
        (await useCases.purchaseDraft())?.encode(),
        purchaseDraft.encode(),
      );

      await useCases.discardSaleDraft();
      await useCases.discardPurchaseDraft();
      expect(await useCases.saleDraft(), isNull);
      expect(await useCases.purchaseDraft(), isNull);
    },
  );

  test(
    'staging atomically replaces its draft and blocks a concurrent new draft',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final useCases = V2UseCases(db);
      await useCases.bootstrap();
      final supplierId = await db
          .into(db.suppliers)
          .insert(SuppliersCompanion.insert(name: 'مورد المسودة'));
      final product = await _success(
        useCases.createProduct(
          operationKey: useCases.newOpeningStockOperationKey(),
          name: 'منتج المسودة',
          salePriceMinor: 10000,
          openingQty: 2,
          openingCostMinor: 6000,
        ),
      );
      await _success(
        useCases.openShift(0, operationKey: useCases.newShiftOperationKey()),
      );

      await useCases.saveSaleDraft(
        SaleDraft(
          items: [
            SaleLineInput(productId: product.id, qty: 1, unitPriceMinor: 10000),
          ],
          cashMinor: 10000,
          walletMinor: 0,
          discountMinor: 0,
          interestMinor: 0,
          installmentCount: 3,
          firstDueDate: DateTime(2026, 10, 1),
          periodDays: 30,
          savedAt: DateTime(2026, 9, 11),
        ),
      );
      final pendingSale = PendingSale(
        operationKey: useCases.newSaleOperationKey(),
        items: [
          SaleLineInput(productId: product.id, qty: 1, unitPriceMinor: 10000),
        ],
        payments: const [PaymentInput(PaymentMethod.cash, 10000)],
      );
      await useCases.stagePendingSale(pendingSale);
      expect(await useCases.saleDraft(), isNull);
      final laterDraft = SaleDraft(
        items: [
          SaleLineInput(productId: product.id, qty: 2, unitPriceMinor: 10000),
        ],
        cashMinor: 0,
        walletMinor: 0,
        discountMinor: 0,
        interestMinor: 0,
        installmentCount: 3,
        firstDueDate: DateTime(2026, 11, 1),
        periodDays: 30,
        savedAt: DateTime(2026, 9, 11, 13),
      );
      await expectLater(
        useCases.saveSaleDraft(laterDraft),
        throwsA(isA<StateError>()),
      );
      expect(
        await useCases.submitPendingSale(pendingSale),
        isA<AppSuccess<int>>(),
      );
      expect(await useCases.saleDraft(), isNull);

      await useCases.savePurchaseDraft(
        PurchaseDraft(
          supplierId: supplierId,
          items: [
            PurchaseLineInput(
              productId: product.id,
              qty: 1,
              unitCostMinor: 7000,
            ),
          ],
          cashMinor: 0,
          walletMinor: 0,
          savedAt: DateTime(2026, 9, 11),
        ),
      );
      final pendingPurchase = PendingPurchase(
        operationKey: useCases.newPurchaseOperationKey(),
        supplierId: supplierId,
        items: [
          PurchaseLineInput(productId: product.id, qty: 1, unitCostMinor: 7000),
        ],
        payments: const [],
      );
      await useCases.stagePendingPurchase(pendingPurchase);
      expect(await useCases.purchaseDraft(), isNull);
      expect(
        await useCases.submitPendingPurchase(pendingPurchase),
        isA<AppSuccess<int>>(),
      );
      expect(await useCases.purchaseDraft(), isNull);
    },
  );

  test(
    'an uncommitted request returns to a draft with its exact editable values',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final useCases = V2UseCases(db, clock: () => DateTime(2026, 9, 11, 14));
      final pending = PendingSale(
        operationKey: useCases.newSaleOperationKey(),
        customerId: 4,
        items: const [
          SaleLineInput(productId: 7, qty: 2, unitPriceMinor: 12000),
        ],
        payments: const [
          PaymentInput(PaymentMethod.cash, 5000),
          PaymentInput(PaymentMethod.wallet, 1000),
        ],
        discountMinor: 500,
        installmentTerms: InstallmentTerms(
          partyId: 4,
          count: 4,
          firstDueDate: DateTime(2026, 10, 1),
          interestMinor: 800,
          periodDays: 15,
        ),
      );

      await useCases.stagePendingSale(pending);
      expect(
        await useCases.restoreUncommittedPendingSaleAsDraft(
          pending.operationKey,
        ),
        isTrue,
      );
      expect(await useCases.pendingSale(), isNull);
      final restored = (await useCases.saleDraft())!;
      expect(restored.customerId, 4);
      expect(restored.items.single.qty, 2);
      expect(restored.cashMinor, 5000);
      expect(restored.walletMinor, 1000);
      expect(restored.discountMinor, 500);
      expect(restored.installmentCount, 4);
      expect(restored.interestMinor, 800);
      expect(restored.periodDays, 15);

      await useCases.stagePendingSale(pending);
      final newer = SaleDraft(
        items: const [
          SaleLineInput(productId: 9, qty: 1, unitPriceMinor: 20000),
        ],
        cashMinor: 0,
        walletMinor: 0,
        discountMinor: 0,
        interestMinor: 0,
        installmentCount: 2,
        firstDueDate: DateTime(2026, 11, 1),
        periodDays: 30,
        savedAt: DateTime(2026, 9, 11, 15),
      );
      await expectLater(
        useCases.saveSaleDraft(newer),
        throwsA(isA<StateError>()),
      );
      expect(
        await useCases.restoreUncommittedPendingSaleAsDraft(
          pending.operationKey,
        ),
        isTrue,
      );
      expect((await useCases.saleDraft())?.items.single.productId, 7);
      expect(await useCases.pendingSale(), isNull);

      await useCases.discardSaleDraft();
      final pendingPurchase = PendingPurchase(
        operationKey: useCases.newPurchaseOperationKey(),
        supplierId: 5,
        items: const [
          PurchaseLineInput(productId: 7, qty: 3, unitCostMinor: 9000),
        ],
        payments: const [PaymentInput(PaymentMethod.wallet, 4000)],
      );
      await useCases.stagePendingPurchase(pendingPurchase);
      await expectLater(
        useCases.savePurchaseDraft(
          PurchaseDraft(
            items: const [
              PurchaseLineInput(productId: 8, qty: 1, unitCostMinor: 10000),
            ],
            cashMinor: 0,
            walletMinor: 0,
            savedAt: DateTime(2026, 9, 11, 16),
          ),
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        await useCases.restoreUncommittedPendingPurchaseAsDraft(
          pendingPurchase.operationKey,
        ),
        isTrue,
      );
      expect(await useCases.pendingPurchase(), isNull);
      final purchaseDraft = (await useCases.purchaseDraft())!;
      expect(purchaseDraft.supplierId, 5);
      expect(purchaseDraft.items.single.qty, 3);
      expect(purchaseDraft.items.single.unitCostMinor, 9000);
      expect(purchaseDraft.walletMinor, 4000);
    },
  );
}

import 'package:alikhlas_pos/v2/app/v2_app.dart';
import 'package:alikhlas_pos/v2/app/v2_providers.dart';
import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scenario in [
    'double',
    'printingFailure',
    'lostReply',
    'existingPending',
  ]) {
    testWidgets('purchase submission: $scenario', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final useCases = V2UseCases(db);
      await useCases.bootstrap();
      final owner = await _success(useCases.login('owner', 'owner123'));
      await _success(useCases.changePassword(owner.id, 'new-owner-pass'));
      final product = await _success(
        useCases.createProduct(
          operationKey: useCases.newOpeningStockOperationKey(),
          name: 'ثلاجة شراء',
          salePriceMinor: 15000,
          openingQty: 1,
          openingCostMinor: 100,
        ),
      );
      await _success(
        useCases.openShift(0, operationKey: useCases.newShiftOperationKey()),
      );
      await _success(
        useCases.createSale(
          operationKey: useCases.newSaleOperationKey(),
          items: [
            SaleLineInput(productId: product.id, qty: 1, unitPriceMinor: 50000),
          ],
          payments: const [PaymentInput(PaymentMethod.cash, 50000)],
        ),
      );

      var attempts = 0;
      Widget buildApp() => ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          if (scenario == 'printingFailure')
            barcodeLabelPrinterProvider.overrideWithValue(
              (_, __) async => throw StateError('printer failed'),
            ),
          if (scenario == 'lostReply')
            purchaseWriterProvider.overrideWithValue(({
              operationKey,
              supplierId,
              required items,
              required payments,
              required allowNegativeBalance,
            }) async {
              final result = await useCases.submitPendingPurchase(
                PendingPurchase(
                  operationKey: operationKey!,
                  supplierId: supplierId,
                  items: items,
                  payments: payments,
                ),
                allowNegativeBalance: allowNegativeBalance,
              );
              if (++attempts == 1) {
                throw StateError('reply lost after commit');
              }
              return result;
            }),
        ],
        child: const ALIkhlasV2App(),
      );
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'كلمة المرور'),
        'new-owner-pass',
      );
      await tester.tap(find.text('دخول'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('الشراء').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();

      final unitCostField = find.widgetWithText(TextFormField, 'تكلفة الوحدة');
      await tester.enterText(unitCostField, '150');
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'كاش'), '150');
      if (scenario == 'existingPending') {
        await useCases.stagePendingPurchase(
          PendingPurchase(
            operationKey: useCases.newPurchaseOperationKey(),
            items: [
              PurchaseLineInput(
                productId: product.id,
                qty: 1,
                unitCostMinor: 15000,
              ),
            ],
            payments: const [PaymentInput(PaymentMethod.cash, 15000)],
          ),
        );
      }
      final submit = tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'تسجيل الشراء'),
          )
          .onPressed!;
      submit();
      submit();
      await tester.pumpAndSettle();

      if (scenario == 'existingPending') {
        expect(await db.select(db.purchaseInvoices).get(), isEmpty);
        expect(find.textContaining('يوجد طلب شراء سابق'), findsOneWidget);
        await tester.tap(find.text('التحقق وإعادة المحاولة'));
        await tester.pumpAndSettle();
      }
      if (scenario == 'lostReply') {
        expect(await db.select(db.purchaseInvoices).get(), hasLength(1));
        final key = (await useCases.pendingPurchase())!.operationKey;
        await tester.tap(find.text('اليومية').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('الشراء').first);
        await tester.pumpAndSettle();
        expect(find.text('التحقق وإعادة المحاولة'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'كلمة المرور'),
          'new-owner-pass',
        );
        await tester.tap(find.text('دخول'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('الشراء').first);
        await tester.pumpAndSettle();
        expect((await useCases.pendingPurchase())!.operationKey, key);
        await tester.tap(find.text('العودة لتعديل المسودة'));
        await tester.pumpAndSettle();
        expect((await useCases.pendingPurchase())!.operationKey, key);
        await tester.tap(find.text('التحقق وإعادة المحاولة'));
        await tester.pumpAndSettle();
        expect(attempts, 2);
      }
      expect(find.text('طباعة باركود الوارد؟'), findsOneWidget);
      if (scenario == 'printingFailure') {
        await tester.tap(find.widgetWithText(FilledButton, 'طباعة الباركود'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('تم حفظ الشراء. تعذرت طباعة الباركود'),
          findsOneWidget,
        );
      } else {
        await tester.tap(find.text('تخطي'));
        await tester.pumpAndSettle();
      }
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'تسجيل الشراء'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
      expect(await useCases.pendingPurchase(), isNull);
      expect(await db.select(db.purchaseInvoices).get(), hasLength(1));
      expect(
        (await (db.select(
          db.products,
        )..where((p) => p.id.equals(product.id))).getSingle()).stockQty,
        1,
      );
    });
  }
}

Future<T> _success<T>(Future<AppResult<T>> result) async =>
    (await result as AppSuccess<T>).value;

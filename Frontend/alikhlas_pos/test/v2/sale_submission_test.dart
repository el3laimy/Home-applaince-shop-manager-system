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
    'receiptFailure',
    'lostReply',
    'existingPending',
  ]) {
    testWidgets('sale submission: $scenario', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final useCases = V2UseCases(db);
      await useCases.bootstrap(createDefaultOwner: true);
      final owner = await _success(useCases.login('owner', 'owner123'));
      await _success(useCases.changePassword(owner.id, 'new-owner-pass'));
      await _success(
        useCases.createProduct(
          operationKey: useCases.newOpeningStockOperationKey(),
          name: 'غسالة اختبار',
          salePriceMinor: 10000,
          openingQty: 2,
          openingCostMinor: 7000,
        ),
      );
      await _success(
        useCases.openShift(0, operationKey: useCases.newShiftOperationKey()),
      );

      var attempts = 0;
      Widget buildApp() => ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          if (scenario == 'receiptFailure')
            saleReceiptLoaderProvider.overrideWithValue(
              (_) async => throw StateError('receipt failed'),
            ),
          if (scenario == 'lostReply')
            saleWriterProvider.overrideWithValue(({
              operationKey,
              customerId,
              required items,
              required payments,
              installmentTerms,
              required discountMinor,
            }) async {
              final result = await useCases.submitPendingSale(
                PendingSale(
                  operationKey: operationKey!,
                  customerId: customerId,
                  items: items,
                  payments: payments,
                  installmentTerms: installmentTerms,
                  discountMinor: discountMinor,
                ),
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

      await tester.tap(find.text('البيع').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('غسالة اختبار'));
      await tester.pumpAndSettle();
      expect(find.textContaining('أول قسط'), findsWidgets);
      expect(find.text('الفترة'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'كاش'), '100');
      if (scenario == 'existingPending') {
        final product = await db.select(db.products).getSingle();
        await useCases.stagePendingSale(
          PendingSale(
            operationKey: useCases.newSaleOperationKey(),
            items: [
              SaleLineInput(
                productId: product.id,
                qty: 1,
                unitPriceMinor: 10000,
              ),
            ],
            payments: const [PaymentInput(PaymentMethod.cash, 10000)],
          ),
        );
      }
      final submit = tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'تسجيل البيع'),
          )
          .onPressed!;
      submit();
      submit();
      await tester.pumpAndSettle();

      if (scenario == 'existingPending') {
        expect(await db.select(db.saleInvoices).get(), isEmpty);
        expect(
          find.textContaining('يوجد طلب سابق لم تُحسم نتيجته'),
          findsOneWidget,
        );
        await tester.tap(find.text('التحقق وإعادة المحاولة'));
        await tester.pumpAndSettle();
      }
      if (scenario == 'lostReply') {
        expect(await db.select(db.saleInvoices).get(), hasLength(1));
        final pendingKey = (await useCases.pendingSale())!.operationKey;
        await tester.tap(find.text('اليومية').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('البيع').first);
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
        await tester.tap(find.text('البيع').first);
        await tester.pumpAndSettle();
        expect((await useCases.pendingSale())!.operationKey, pendingKey);
        await tester.tap(find.text('العودة لتعديل المسودة'));
        await tester.pumpAndSettle();
        expect(find.textContaining('قد تكون الفاتورة محفوظة'), findsOneWidget);
        expect((await useCases.pendingSale())!.operationKey, pendingKey);
        await tester.tap(find.text('التحقق وإعادة المحاولة'));
        await tester.pumpAndSettle();
        expect(attempts, 2);
      }
      if (scenario == 'receiptFailure') {
        expect(
          find.textContaining('تم حفظ البيع. تعذر عرض الفاتورة'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'تسجيل البيع'),
              )
              .onPressed,
          isNull,
        );
      } else {
        expect(find.text('تم تسجيل البيع'), findsOneWidget);
      }
      expect(await useCases.pendingSale(), isNull);
      expect((await db.select(db.products).getSingle()).stockQty, 1);
      expect(tester.takeException(), isNull);
      expect((await db.select(db.saleInvoices).get()).length, 1);
    });
  }
}

Future<T> _success<T>(Future<AppResult<T>> result) async =>
    (await result as AppSuccess<T>).value;

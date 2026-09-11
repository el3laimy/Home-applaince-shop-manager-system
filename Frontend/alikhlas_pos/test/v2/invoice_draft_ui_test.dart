import 'package:alikhlas_pos/v2/app/v2_app.dart';
import 'package:alikhlas_pos/v2/app/v2_providers.dart';
import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<T> _success<T>(Future<AppResult<T>> result) async =>
    (await result as AppSuccess<T>).value;

void main() {
  testWidgets(
    'sale warns before leaving and restores a saved draft on restart',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final useCases = V2UseCases(db);
      await useCases.bootstrap();
      final owner = await _success(useCases.login('owner', 'owner123'));
      await _success(useCases.changePassword(owner.id, 'draft-owner-pass'));
      await _success(
        useCases.createProduct(
          operationKey: useCases.newOpeningStockOperationKey(),
          name: 'غسالة المسودة',
          salePriceMinor: 10000,
          openingQty: 2,
          openingCostMinor: 7000,
        ),
      );
      await _success(
        useCases.openShift(0, operationKey: useCases.newShiftOperationKey()),
      );

      Widget buildApp() => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const ALIkhlasV2App(),
      );

      Future<void> loginAndOpenSale() async {
        await tester.enterText(
          find.widgetWithText(TextField, 'كلمة المرور'),
          'draft-owner-pass',
        );
        await tester.tap(find.text('دخول'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('البيع').first);
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      await loginAndOpenSale();
      await tester.tap(find.text('غسالة المسودة').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('اليومية').first);
      await tester.pumpAndSettle();
      expect(find.text('فاتورة البيع غير محفوظة'), findsOneWidget);
      await tester.tap(find.text('العودة للفاتورة'));
      await tester.pumpAndSettle();
      expect(find.text('تسجيل البيع'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'كاش'), '١٠٠');
      await tester.tap(find.text('حفظ مسودة'));
      await tester.pumpAndSettle();
      expect(await useCases.saleDraft(), isNotNull);
      expect(find.text('تم حفظ مسودة البيع'), findsOneWidget);

      await tester.tap(find.text('اليومية').first);
      await tester.pumpAndSettle();
      expect(find.text('فاتورة البيع غير محفوظة'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      await loginAndOpenSale();
      expect(find.text('تمت استعادة مسودة البيع المحفوظة.'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'تسجيل البيع'));
      await tester.pumpAndSettle();
      expect(await useCases.saleDraft(), isNull);
      expect(await db.select(db.saleInvoices).get(), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('purchase warns before leaving and restores its exact draft', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final useCases = V2UseCases(db);
    await useCases.bootstrap();
    final owner = await _success(useCases.login('owner', 'owner123'));
    await _success(useCases.changePassword(owner.id, 'draft-owner-pass'));
    await _success(
      useCases.createProduct(
        name: 'ثلاجة المسودة',
        salePriceMinor: 15000,
        openingQty: 0,
        openingCostMinor: 0,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const ALIkhlasV2App(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'كلمة المرور'),
      'draft-owner-pass',
    );
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الشراء').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('إضافة للفاتورة').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('اليومية').first);
    await tester.pumpAndSettle();
    expect(find.text('فاتورة الشراء غير محفوظة'), findsOneWidget);
    await tester.tap(find.text('العودة للفاتورة'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'تكلفة الوحدة'),
      '٨٠',
    );
    await tester.tap(find.text('حفظ مسودة'));
    await tester.pumpAndSettle();
    expect((await useCases.purchaseDraft())?.items.single.unitCostMinor, 8000);

    await tester.tap(find.text('اليومية').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('الشراء').first);
    await tester.pumpAndSettle();
    expect(find.text('تمت استعادة مسودة الشراء المحفوظة.'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'تكلفة الوحدة'),
          )
          .initialValue,
      '80.00',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unreadable draft can be cleared without blocking sales', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final useCases = V2UseCases(db);
    await useCases.bootstrap();
    final owner = await _success(useCases.login('owner', 'owner123'));
    await _success(useCases.changePassword(owner.id, 'draft-owner-pass'));
    await db
        .into(db.appSettings)
        .insert(
          AppSettingsCompanion.insert(key: 'draft.sale.v1', value: '{broken'),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const ALIkhlasV2App(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'كلمة المرور'),
      'draft-owner-pass',
    );
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('البيع').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('تعذر قراءة مسودة البيع'), findsOneWidget);
    expect(find.text('تسجيل البيع'), findsOneWidget);
    await tester.tap(find.text('مسح'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مسح المسودة'));
    await tester.pumpAndSettle();

    expect(await useCases.saleDraft(), isNull);
    expect(find.textContaining('تعذر قراءة مسودة البيع'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an uncommitted sale request returns to the editable draft', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final useCases = V2UseCases(db);
    await useCases.bootstrap();
    final owner = await _success(useCases.login('owner', 'owner123'));
    await _success(useCases.changePassword(owner.id, 'draft-owner-pass'));
    final product = await _success(
      useCases.createProduct(
        operationKey: useCases.newOpeningStockOperationKey(),
        name: 'بوتاجاز المسودة',
        salePriceMinor: 20000,
        openingQty: 2,
        openingCostMinor: 12000,
      ),
    );
    final request = PendingSale(
      operationKey: useCases.newSaleOperationKey(),
      items: [
        SaleLineInput(
          productId: product.id,
          qty: 1,
          unitPriceMinor: product.salePriceMinor,
        ),
      ],
      payments: const [PaymentInput(PaymentMethod.wallet, 20000)],
    );
    await useCases.stagePendingSale(request);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const ALIkhlasV2App(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'كلمة المرور'),
      'draft-owner-pass',
    );
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('البيع').first);
    await tester.pumpAndSettle();

    expect(find.text('العودة لتعديل المسودة'), findsOneWidget);
    await tester.tap(find.text('العودة لتعديل المسودة'));
    await tester.pumpAndSettle();

    expect(await useCases.pendingSale(), isNull);
    expect(await useCases.saleDraft(), isNotNull);
    expect(find.text('تمت استعادة مسودة البيع المحفوظة.'), findsOneWidget);
    expect(find.text('تسجيل البيع'), findsOneWidget);
    expect(await db.select(db.saleInvoices).get(), isEmpty);
    expect(tester.takeException(), isNull);
  });
}

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
  testWidgets('login forces default password change before dashboard', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const ALIkhlasV2App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('إخلاص POS'), findsOneWidget);

    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();

    expect(find.text('تغيير كلمة المرور'), findsOneWidget);
    expect(find.text('يومية المحل'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextField, 'كلمة المرور الجديدة'),
      'new-owner-pass',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'تأكيد كلمة المرور'),
      'new-owner-pass',
    );
    await tester.tap(find.text('حفظ ومتابعة'));
    await tester.pumpAndSettle();

    expect(find.text('يومية المحل'), findsOneWidget);
  });

  testWidgets('desktop sale flow records a cash invoice from POS', (
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
    await _success(useCases.changePassword(owner.id, 'new-owner-pass'));
    await _success(
      useCases.createProduct(
        name: 'غسالة اختبار',
        salePriceMinor: 10000,
        openingQty: 2,
        openingCostMinor: 7000,
      ),
    );
    await _success(useCases.openShift(0));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const ALIkhlasV2App(),
      ),
    );
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
    await tester.enterText(find.widgetWithText(TextField, 'كاش'), '100');
    await tester.tap(find.text('تسجيل البيع'));
    await tester.pumpAndSettle();

    expect(find.text('تم تسجيل البيع'), findsOneWidget);
    expect((await db.select(db.saleInvoices).get()).length, 1);
  });

  testWidgets('desktop sale blocks invalid money input before posting', (
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
    await _success(useCases.changePassword(owner.id, 'new-owner-pass'));
    await _success(
      useCases.createProduct(
        name: 'بوتاجاز اختبار',
        salePriceMinor: 10000,
        openingQty: 1,
        openingCostMinor: 7000,
      ),
    );
    await _success(useCases.openShift(0));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const ALIkhlasV2App(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'كلمة المرور'),
      'new-owner-pass',
    );
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('البيع').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('بوتاجاز اختبار'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'كاش'), '100x');
    await tester.tap(find.text('تسجيل البيع'));
    await tester.pumpAndSettle();

    expect(find.text('كاش: استخدم أرقامًا وفاصلًا عشريًا فقط'), findsWidgets);
    expect(await db.select(db.saleInvoices).get(), isEmpty);
  });

  testWidgets('desktop purchase flow records stock intake from purchases', (
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
    await _success(useCases.changePassword(owner.id, 'new-owner-pass'));
    final product = await _success(
      useCases.createProduct(
        name: 'ثلاجة شراء',
        salePriceMinor: 15000,
        openingQty: 0,
        openingCostMinor: 0,
      ),
    );
    await _success(useCases.openShift(0));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const ALIkhlasV2App(),
      ),
    );
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
    await tester.enterText(find.widgetWithText(TextField, 'كاش'), '150');
    await tester.tap(find.text('تسجيل الشراء'));
    await tester.pumpAndSettle();

    expect(find.text('تم تسجيل الشراء'), findsOneWidget);
    expect((await db.select(db.purchaseInvoices).get()).length, 1);
    final storedProduct = await (db.select(
      db.products,
    )..where((p) => p.id.equals(product.id))).getSingle();
    expect(storedProduct.stockQty, 1);
  });
}

Future<T> _success<T>(Future<AppResult<T>> future) async {
  final result = await future;
  if (result is AppSuccess<T>) return result.value;
  if (result is AppFailure<T>) fail(result.message);
  fail('Unexpected result: $result');
}

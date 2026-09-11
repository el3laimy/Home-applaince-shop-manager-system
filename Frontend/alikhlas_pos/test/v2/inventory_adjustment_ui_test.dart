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
  testWidgets('inventory count records one reviewed shortage at minimum size', (
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
    await _success(useCases.changePassword(owner.id, 'inventory-owner-pass'));
    await _success(
      useCases.createProduct(
        operationKey: useCases.newOpeningStockOperationKey(),
        name: 'غسالة للعد',
        salePriceMinor: 50000,
        openingQty: 5,
        openingCostMinor: 10000,
      ),
    );

    await _pumpLoggedIn(tester, db);
    await tester.tap(find.text('المخزون').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('جرد وتسوية الرصيد'));
    await tester.pumpAndSettle();

    expect(find.text('الرصيد المسجل حاليًا: 5'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'الكمية الفعلية بعد العد'),
      '٣',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('الفرق -2'), findsOneWidget);
    await tester.tap(find.text('مراجعة التسوية'));
    await tester.pumpAndSettle();

    expect(find.text('تأكيد تسوية الجرد'), findsOneWidget);
    expect(find.text('الرصيد المسجل: 5'), findsOneWidget);
    expect(find.text('الكمية الفعلية: 3'), findsOneWidget);
    await tester.tap(find.text('اعتماد التسوية'));
    await tester.pumpAndSettle();

    expect(find.text('تم تسجيل تسوية الجرد'), findsOneWidget);
    expect(find.textContaining('رصيد 3'), findsOneWidget);
    expect(await db.select(db.inventoryAdjustments).get(), hasLength(1));
    expect((await db.select(db.products).getSingle()).stockQty, 3);
  });

  testWidgets('inventory count asks for cost when the product has none', (
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
    await _success(useCases.changePassword(owner.id, 'inventory-owner-pass'));
    await _success(
      useCases.createProduct(
        name: 'صنف بلا تكلفة للعد',
        salePriceMinor: 10000,
        openingQty: 0,
        openingCostMinor: 0,
      ),
    );

    await _pumpLoggedIn(tester, db);
    await tester.tap(find.text('المخزون').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('جرد وتسوية الرصيد'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'الكمية الفعلية بعد العد'),
      '٢',
    );
    await tester.tap(find.text('مراجعة التسوية'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('تكلفة الوحدة يجب أن تكون أكبر'),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'تكلفة الوحدة للتسوية'),
      '٧٠',
    );
    await tester.tap(find.text('مراجعة التسوية'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اعتماد التسوية'));
    await tester.pumpAndSettle();

    final product = await db.select(db.products).getSingle();
    expect(product.stockQty, 2);
    expect(product.avgCostMinor, 7000);
    expect(await db.select(db.inventoryAdjustments).get(), hasLength(1));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpLoggedIn(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const ALIkhlasV2App(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextField, 'كلمة المرور'),
    'inventory-owner-pass',
  );
  await tester.tap(find.text('دخول'));
  await tester.pumpAndSettle();
}

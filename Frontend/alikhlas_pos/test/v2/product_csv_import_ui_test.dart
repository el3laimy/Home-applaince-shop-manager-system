import 'dart:convert';

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
  testWidgets('inventory saves the CSV template and imports a reviewed file', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final useCases = V2UseCases(db);
    await _prepareOwner(useCases);
    String? savedTemplate;
    final csv =
        '${useCases.productCsvTemplate()}'
        'غسالة,WASH-1,غسالات,12000,2,9000,1\r\n'
        'مروحة,,مراوح,2000,0,0,2\r\n';

    await _pumpLoggedIn(
      tester,
      db,
      picker: () async =>
          ProductCsvPickedFile(name: 'products.csv', bytes: utf8.encode(csv)),
      saver: (template) async {
        savedTemplate = template;
        return true;
      },
    );
    await tester.tap(find.text('المخزون').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('product-csv-template')));
    await tester.pumpAndSettle();
    expect(savedTemplate, startsWith('\ufeff"اسم المنتج"'));

    await tester.tap(find.byKey(const ValueKey('product-csv-import')));
    await tester.pumpAndSettle();
    expect(find.text('معاينة استيراد المنتجات'), findsOneWidget);
    expect(find.text('الصفوف السليمة: 2'), findsOneWidget);
    expect(find.text('الأخطاء: 0'), findsOneWidget);
    await tester.tap(find.text('اعتماد 2 منتج'));
    await tester.pumpAndSettle();

    final products = await db.select(db.products).get();
    expect(products, hasLength(2));
    expect(products.singleWhere((row) => row.name == 'غسالة').stockQty, 2);
    expect((await useCases.dataIntegrityAudit()).isConsistent, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CSV row errors block the entire import from the UI', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final useCases = V2UseCases(db);
    await _prepareOwner(useCases);
    final csv =
        '${useCases.productCsvTemplate()}'
        'صنف سليم,OK-1,تصنيف,100,1,50,1\r\n'
        'صنف خاطئ,BAD-1,تصنيف,100,2,0,1\r\n';

    await _pumpLoggedIn(
      tester,
      db,
      picker: () async => ProductCsvPickedFile(
        name: 'bad-products.csv',
        bytes: utf8.encode(csv),
      ),
      saver: (_) async => true,
    );
    await tester.tap(find.text('المخزون').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('product-csv-import')));
    await tester.pumpAndSettle();

    expect(find.text('الأخطاء: 1'), findsOneWidget);
    expect(find.text('الصف 3'), findsOneWidget);
    expect(find.textContaining('تكلفة الوحدة مطلوبة'), findsOneWidget);
    expect(find.textContaining('لن يُحفظ أي منتج'), findsOneWidget);
    expect(find.textContaining('اعتماد '), findsNothing);
    expect(await db.select(db.products).get(), isEmpty);
    await tester.tap(find.text('إغلاق وتصحيح الملف'));
    await tester.pumpAndSettle();
    expect(await db.select(db.products).get(), isEmpty);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _prepareOwner(V2UseCases useCases) async {
  await useCases.bootstrap(createDefaultOwner: true);
  final owner = await _success(useCases.login('owner', 'owner123'));
  await _success(useCases.changePassword(owner.id, 'csv-owner-pass'));
}

Future<void> _pumpLoggedIn(
  WidgetTester tester,
  AppDatabase db, {
  required ProductCsvFilePicker picker,
  required ProductCsvTemplateSaver saver,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        productCsvFilePickerProvider.overrideWithValue(picker),
        productCsvTemplateSaverProvider.overrideWithValue(saver),
      ],
      child: const ALIkhlasV2App(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextField, 'كلمة المرور'),
    'csv-owner-pass',
  );
  await tester.tap(find.text('دخول'));
  await tester.pumpAndSettle();
}

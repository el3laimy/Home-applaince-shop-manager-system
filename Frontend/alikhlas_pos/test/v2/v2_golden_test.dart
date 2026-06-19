import 'dart:io';

import 'package:alikhlas_pos/v2/app/v2_app.dart';
import 'package:alikhlas_pos/v2/app/v2_providers.dart';
import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadCairoFonts);

  testWidgets('login liquid glass surface matches golden', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const ALIkhlasV2App(),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/login_liquid_glass.png'),
    );
  });

  testWidgets('dashboard liquid glass shell matches golden', (tester) async {
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

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/dashboard_liquid_glass.png'),
    );
  });

  testWidgets('pos liquid glass selling surface matches golden', (
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
    await _success(useCases.openShift(0));
    await _success(
      useCases.createProduct(
        name: 'خلاط زجاجي',
        barcode: 'POS-GLASS-001',
        salePriceMinor: 24500,
        openingQty: 4,
        openingCostMinor: 18000,
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
      'new-owner-pass',
    );
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('البيع').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('خلاط زجاجي'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/pos_liquid_glass.png'),
    );
  });

  testWidgets('reports liquid glass surface matches golden', (tester) async {
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
    await tester.tap(find.text('التقارير').first);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/reports_liquid_glass.png'),
    );
  });
}

Future<void> _loadCairoFonts() async {
  final cairoLoader = FontLoader('Cairo')
    ..addFont(rootBundle.load('assets/fonts/Cairo-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Cairo-Medium.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Cairo-SemiBold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Cairo-Bold.ttf'));
  await cairoLoader.load();

  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) return;
  final materialIconsFile = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!materialIconsFile.existsSync()) return;

  final materialIconsLoader = FontLoader('MaterialIcons')
    ..addFont(_fontBytes(materialIconsFile));
  await materialIconsLoader.load();
}

Future<ByteData> _fontBytes(File file) async {
  final bytes = await file.readAsBytes();
  return ByteData.sublistView(bytes);
}

Future<T> _success<T>(Future<AppResult<T>> future) async {
  final result = await future;
  if (result is AppSuccess<T>) return result.value;
  if (result is AppFailure<T>) fail(result.message);
  fail('Unexpected result: $result');
}

import 'package:alikhlas_pos/v2/app/v2_app.dart';
import 'package:alikhlas_pos/v2/app/v2_providers.dart';
import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<T> success<T>(Future<AppResult<T>> future) async =>
    (await future as AppSuccess<T>).value;

void main() {
  testWidgets('backup screen exposes a read-only integrity check', (
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
    final owner = await success(useCases.login('owner', 'owner123'));
    await success(useCases.changePassword(owner.id, 'new-owner-pass'));

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
    await tester.tap(find.text('النسخ').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('فحص اتساق البيانات'));
    await tester.pumpAndSettle();

    expect(find.text('فحص اتساق البيانات'), findsWidgets);
    expect(find.textContaining('الفحص للقراءة فقط'), findsOneWidget);
  });
}

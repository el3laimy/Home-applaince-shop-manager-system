import 'dart:async';
import 'dart:io';

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
  testWidgets('support failures are actionable and printer can be retried', (
    tester,
  ) async {
    var attempts = 0;
    await _openHelp(
      tester,
      save: (_) async => throw const FileSystemException('private path'),
      print: (_) async {
        if (++attempts == 1) throw StateError('private printer');
        return true;
      },
    );
    final printer = find.widgetWithText(OutlinedButton, 'اختبار الطابعة');
    await tester.ensureVisible(printer);
    await tester.tap(printer);
    await tester.pumpAndSettle();
    expect(find.textContaining('تعذر فتح نافذة الطباعة'), findsOneWidget);
    expect(find.textContaining('private printer'), findsNothing);
    await tester.tap(printer);
    await tester.pumpAndSettle();
    expect(find.textContaining('أُرسل طلب الطباعة'), findsOneWidget);

    await _approveReport(tester);
    expect(
      find.textContaining('اختر مجلدًا تملك صلاحية الكتابة فيه'),
      findsOneWidget,
    );
    expect(find.textContaining('private path'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'حفظ تقرير للدعم'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('pending save finishes safely after leaving the help screen', (
    tester,
  ) async {
    final completion = Completer<bool>();
    var requests = 0;
    await _openHelp(
      tester,
      save: (_) {
        requests++;
        return completion.future;
      },
      print: (_) async => true,
    );
    await tester.ensureVisible(find.text('حفظ تقرير للدعم'));
    await tester.tap(find.text('حفظ تقرير للدعم'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اختيار مكان الحفظ'));
    await tester.pump();
    expect(requests, 1);
    // The OS picker/write may outlive its originating screen.
    await tester.pumpWidget(const SizedBox.shrink());
    completion.complete(true);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(requests, 1);
  });
}

Future<void> _approveReport(WidgetTester tester) async {
  await tester.ensureVisible(find.text('حفظ تقرير للدعم'));
  await tester.tap(find.text('حفظ تقرير للدعم'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('اختيار مكان الحفظ'));
  await tester.pumpAndSettle();
}

Future<void> _openHelp(
  WidgetTester tester, {
  required SupportReportSaver save,
  required PrinterTestPage print,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final useCases = V2UseCases(db);
  await useCases.bootstrap(createDefaultOwner: true);
  final login = await useCases.login('owner', 'owner123');
  final owner = (login as AppSuccess<User>).value;
  expect(
    await useCases.changePassword(owner.id, 'help-test-password'),
    isA<AppSuccess<User>>(),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        appVersionProvider.overrideWith((ref) async => '1.2.3+4'),
        supportReportSaverProvider.overrideWithValue(save),
        printerTestPageProvider.overrideWithValue(print),
      ],
      child: const ALIkhlasV2App(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextField, 'كلمة المرور'),
    'help-test-password',
  );
  await tester.tap(find.text('دخول'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('المساعدة'));
  await tester.pumpAndSettle();
}

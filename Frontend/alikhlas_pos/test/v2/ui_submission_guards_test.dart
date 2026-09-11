import 'dart:async';

import 'package:alikhlas_pos/v2/app/v2_app.dart';
import 'package:alikhlas_pos/v2/app/v2_providers.dart';
import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<T> _success<T>(Future<AppResult<T>> future) async {
  final result = await future;
  expect(result, isA<AppSuccess<T>>());
  return (result as AppSuccess<T>).value;
}

class _HeldWriteBarrier extends V2WriteBarrier {
  bool _holding = false;
  int heldWriteCount = 0;
  Completer<void>? _entered;
  Completer<void>? _release;

  void holdWrites() {
    _holding = true;
    _entered = Completer<void>();
    _release = Completer<void>();
  }

  Future<void> get entered => _entered!.future;

  void release() {
    _holding = false;
    _release?.complete();
  }

  @override
  Future<T> write<T>(Future<T> Function() action) async {
    if (_holding) {
      heldWriteCount++;
      _entered?.complete();
      await _release!.future;
    }
    return super.write(action);
  }
}

Future<void> _prepareOwnerAndShift(V2UseCases useCases) async {
  await useCases.bootstrap();
  final owner = await _success(useCases.login('owner', 'owner123'));
  await _success(useCases.changePassword(owner.id, 'new-owner-pass'));
  await _success(
    useCases.openShift(10000, operationKey: useCases.newShiftOperationKey()),
  );
}

Future<void> _pumpLoggedInApp(
  WidgetTester tester,
  AppDatabase db,
  V2UseCases useCases,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        useCasesProvider.overrideWithValue(useCases),
      ],
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
}

Future<void> _pumpOperationCompletion(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('expense save admits one rapid tap before the dialog repaints', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final setup = V2UseCases(db);
    await _prepareOwnerAndShift(setup);
    final barrier = _HeldWriteBarrier();
    final useCases = V2UseCases(db, writeBarrier: barrier);

    await _pumpLoggedInApp(tester, db, useCases);
    await tester.tap(find.text('التقارير').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'مصروف جديد'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'وصف المصروف'),
      'مصروف نقرة سريعة',
    );
    await tester.enterText(find.widgetWithText(TextField, 'المبلغ'), '50');

    barrier.holdWrites();
    final save = find.widgetWithText(FilledButton, 'حفظ المصروف');
    final saveAction = tester.widget<FilledButton>(save).onPressed!;
    saveAction();
    saveAction();
    await tester.pump();
    await barrier.entered;

    expect(barrier.heldWriteCount, 1);
    barrier.release();
    await _pumpOperationCompletion(tester);
    await tester.tap(
      find.widgetWithText(FilledButton, 'أوافق على الرصيد السالب'),
    );
    await _pumpOperationCompletion(tester);

    expect(await db.select(db.expenses).get(), hasLength(1));
  });

  testWidgets(
    'recovery retry blocks rapid retry and discard before the dialog repaints',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final setup = V2UseCases(db);
      await _prepareOwnerAndShift(setup);
      final request = PendingFinancialOperation.expense(
        operationKey: setup.newExpenseOperationKey(),
        description: 'طلب استعادة سريع',
        amountMinor: 5000,
        method: PaymentMethod.cash,
      );
      await setup.stagePendingFinancialOperation(request);
      final barrier = _HeldWriteBarrier();
      final useCases = V2UseCases(db, writeBarrier: barrier);

      await _pumpLoggedInApp(tester, db, useCases);
      expect(find.text('تحقق من طلب مالي سابق'), findsOneWidget);

      barrier.holdWrites();
      final retry = find.widgetWithText(FilledButton, 'التحقق وإعادة المحاولة');
      final retryAction = tester.widget<FilledButton>(retry).onPressed!;
      final discardAction = tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'إلغاء الطلب غير المحفوظ'),
          )
          .onPressed!;
      retryAction();
      retryAction();
      discardAction();
      await tester.pump();
      await barrier.entered;

      expect(barrier.heldWriteCount, 1);
      barrier.release();
      await _pumpOperationCompletion(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, 'أوافق على الرصيد السالب'),
      );
      await _pumpOperationCompletion(tester);

      expect(find.text('تحقق من طلب مالي سابق'), findsNothing);
      expect(await db.select(db.expenses).get(), hasLength(1));
      expect(await useCases.pendingFinancialOperation(), isNull);
    },
  );

  testWidgets('recovery discard blocks a rapid retry before repaint', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final setup = V2UseCases(db);
    await _prepareOwnerAndShift(setup);
    final request = PendingFinancialOperation.expense(
      operationKey: setup.newExpenseOperationKey(),
      description: 'طلب إلغاء سريع',
      amountMinor: 5000,
      method: PaymentMethod.cash,
    );
    await setup.stagePendingFinancialOperation(request);
    final barrier = _HeldWriteBarrier();
    final useCases = V2UseCases(db, writeBarrier: barrier);

    await _pumpLoggedInApp(tester, db, useCases);
    expect(find.text('تحقق من طلب مالي سابق'), findsOneWidget);

    barrier.holdWrites();
    final discardAction = tester
        .widget<TextButton>(
          find.widgetWithText(TextButton, 'إلغاء الطلب غير المحفوظ'),
        )
        .onPressed!;
    final retryAction = tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'التحقق وإعادة المحاولة'),
        )
        .onPressed!;
    discardAction();
    retryAction();
    await tester.pump();
    await barrier.entered;

    expect(barrier.heldWriteCount, 1);
    barrier.release();
    await _pumpOperationCompletion(tester);

    expect(find.text('تحقق من طلب مالي سابق'), findsNothing);
    expect(await db.select(db.expenses).get(), isEmpty);
    expect(await useCases.pendingFinancialOperation(), isNull);
  });
}

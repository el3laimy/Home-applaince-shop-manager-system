import 'package:alikhlas_pos/v2/app/v2_app.dart';
import 'package:alikhlas_pos/v2/app/v2_providers.dart';
import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/money.dart';
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
    'settings records one reviewed wallet correction at minimum size',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final useCases = V2UseCases(db);
      await useCases.bootstrap(createDefaultOwner: true);
      final owner = await _success(useCases.login('owner', 'owner123'));
      await _success(
        useCases.changePassword(owner.id, 'correction-owner-pass'),
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
        'correction-owner-pass',
      );
      await tester.tap(find.text('دخول'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('side-navigation-scroll')),
        const Offset(0, -360),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('الإعدادات').first);
      await tester.pumpAndSettle();

      final openButton = find.widgetWithText(
        OutlinedButton,
        'تصحيح خزينة أو محفظة',
      );
      await tester.scrollUntilVisible(
        openButton,
        500,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('settings-page-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(openButton);
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(AlertDialog, 'تصحيح خزينة أو محفظة'),
        findsOneWidget,
      );
      await tester.tap(
        find.byType(DropdownButtonFormField<FinancialCorrectionTarget>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('المحفظة').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'قيمة الفرق'),
        '١٢٥٠',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'سبب التصحيح'),
        'فرق عدّ المحفظة',
      );
      await tester.tap(find.text('مراجعة التصحيح'));
      await tester.pumpAndSettle();

      expect(find.text('تأكيد التصحيح المالي'), findsOneWidget);
      expect(find.text(Money(125000).format()), findsOneWidget);
      expect(find.text('فرق عدّ المحفظة'), findsOneWidget);
      await tester.tap(find.text('اعتماد التصحيح'));
      await tester.pumpAndSettle();

      expect(find.text('تم تسجيل التصحيح المالي'), findsOneWidget);
      final correction = await db.select(db.financialCorrections).getSingle();
      expect(correction.target, FinancialCorrectionTarget.wallet.name);
      expect(correction.deltaMinor, 125000);
      expect((await useCases.dashboardSnapshot()).walletMinor, 125000);

      final reversalButton = find.widgetWithText(
        OutlinedButton,
        'عكس تصحيح مالي',
      );
      await tester.scrollUntilVisible(
        reversalButton,
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('settings-page-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(reversalButton);
      await tester.pumpAndSettle();
      expect(find.text('عكس تصحيح مالي'), findsWidgets);
      await tester.enterText(
        find.widgetWithText(TextField, 'سبب العكس'),
        'التصحيح سُجل على الحساب الخطأ',
      );
      await tester.tap(find.text('مراجعة العكس'));
      await tester.pumpAndSettle();
      expect(find.text('تأكيد عكس التصحيح المالي'), findsOneWidget);
      await tester.tap(find.text('اعتماد العكس'));
      await tester.pumpAndSettle();

      final reversal = await db
          .select(db.financialCorrectionReversals)
          .getSingle();
      expect(reversal.correctionId, correction.id);
      expect((await useCases.dashboardSnapshot()).walletMinor, 0);
      expect((await useCases.dataIntegrityAudit()).isConsistent, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}

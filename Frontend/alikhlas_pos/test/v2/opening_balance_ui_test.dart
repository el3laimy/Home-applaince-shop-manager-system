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
    'existing shop records one reviewed customer opening balance at minimum size',
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
        useCases.changePassword(owner.id, 'opening-balance-owner-pass'),
      );
      await db
          .into(db.customers)
          .insert(CustomersCompanion.insert(name: 'عميل افتتاحي'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const ALIkhlasV2App(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'كلمة المرور'),
        'opening-balance-owner-pass',
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
        'إدخال رصيد افتتاحي',
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
        find.widgetWithText(AlertDialog, 'إدخال رصيد افتتاحي'),
        findsOneWidget,
      );
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('عميل افتتاحي').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'قيمة الرصيد'),
        '١٢٥٠',
      );
      await tester.tap(find.text('مراجعة الرصيد'));
      await tester.pumpAndSettle();

      expect(find.text('تأكيد الرصيد الافتتاحي'), findsOneWidget);
      expect(find.text(Money(125000).format()), findsOneWidget);
      expect(find.text('عميل افتتاحي'), findsOneWidget);
      await tester.tap(find.text('اعتماد الرصيد'));
      await tester.pumpAndSettle();

      expect(find.text('تم تسجيل الرصيد الافتتاحي'), findsOneWidget);
      final openingBalance = await db.select(db.openingBalances).getSingle();
      expect(openingBalance.amountMinor, 125000);
      expect(openingBalance.partyId, isNotNull);
      expect(await db.select(db.installmentPlans).get(), hasLength(1));
      expect((await useCases.dashboardSnapshot()).receivablesMinor, 125000);
      expect((await useCases.dataIntegrityAudit()).isConsistent, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}

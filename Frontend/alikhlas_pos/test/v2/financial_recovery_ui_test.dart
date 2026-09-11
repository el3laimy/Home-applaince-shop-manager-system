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
  testWidgets(
    'uncommitted financial request is explicit and can be cancelled',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final useCases = V2UseCases(db);
      await useCases.bootstrap();
      final owner = await success(useCases.login('owner', 'owner123'));
      await success(useCases.changePassword(owner.id, 'new-owner-pass'));
      final request = PendingFinancialOperation.expense(
        operationKey: useCases.newExpenseOperationKey(),
        description: 'مصروف لم يؤكد',
        amountMinor: 700,
        method: PaymentMethod.wallet,
      );
      await useCases.stagePendingFinancialOperation(request);

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

      expect(find.text('تحقق من طلب مالي سابق'), findsOneWidget);
      expect(find.text('الطلب: تسجيل مصروف'), findsOneWidget);
      expect(await db.select(db.expenses).get(), isEmpty);
      await tester.tap(find.text('إلغاء الطلب غير المحفوظ'));
      await tester.pumpAndSettle();
      expect(find.text('تحقق من طلب مالي سابق'), findsNothing);
      expect(await useCases.pendingFinancialOperation(), isNull);
    },
  );
}

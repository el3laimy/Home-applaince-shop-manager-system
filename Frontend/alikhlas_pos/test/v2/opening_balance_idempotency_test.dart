import 'dart:io';

import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<T> _success<T>(Future<AppResult<T>> result) async =>
    (await result as AppSuccess<T>).value;

void main() {
  test(
    'opening balance pending request replays once after reopening the database',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'opening-balance-once-',
      );
      late AppDatabase db;
      addTearDown(() async {
        await db.close();
        directory.deleteSync(recursive: true);
      });
      db = AppDatabase(NativeDatabase(File('${directory.path}/shop.db')));
      var useCases = V2UseCases(db);
      final customerId = await db
          .into(db.customers)
          .insert(CustomersCompanion.insert(name: 'عميل رصيد افتتاحي'));
      final request = PendingFinancialOperation.openingBalance(
        operationKey: useCases.newOpeningBalanceOperationKey(),
        type: OpeningBalanceType.customerReceivable,
        partyId: customerId,
        amountMinor: 125000,
        dueDate: DateTime(2026, 9, 30),
        note: 'رصيد من الدفاتر السابقة',
      );

      await useCases.stagePendingFinancialOperation(request);
      final firstId = await _success(
        useCases.submitPendingFinancialOperation(request),
      );

      await db.close();
      db = AppDatabase(NativeDatabase(File('${directory.path}/shop.db')));
      useCases = V2UseCases(db);
      final restored = await useCases.pendingFinancialOperation();
      expect(restored?.encode(), request.encode());
      expect(
        await _success(useCases.submitPendingFinancialOperation(restored!)),
        firstId,
      );
      expect(await db.select(db.openingBalances).get(), hasLength(1));
      expect(await db.select(db.installmentPlans).get(), hasLength(1));
      expect(await db.select(db.installmentPayments).get(), hasLength(1));
      expect(await db.select(db.ledgerEntries).get(), hasLength(1));
      expect(
        await useCases.recordOpeningBalance(
          operationKey: request.operationKey,
          type: OpeningBalanceType.customerReceivable,
          partyId: customerId,
          amountMinor: 120000,
          dueDate: DateTime(2026, 9, 30),
          note: 'رصيد من الدفاتر السابقة',
        ),
        isA<AppFailure<int>>(),
      );
      expect(
        await useCases.acknowledgePendingFinancialOperation(
          request.operationKey,
        ),
        isTrue,
      );
      expect((await useCases.dataIntegrityAudit()).isConsistent, isTrue);
    },
  );

  test('opening balance rolls back when its receipt cannot be saved', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final useCases = V2UseCases(db);
    await db.customStatement(
      "CREATE TEMP TRIGGER fail_opening_balance_receipt "
      "BEFORE INSERT ON app_settings "
      "WHEN NEW.key = 'operation.opening_balance.fail-write' "
      "BEGIN SELECT RAISE(ABORT, 'simulated receipt failure'); END",
    );

    await expectLater(
      useCases.recordOpeningBalance(
        operationKey: 'fail-write',
        type: OpeningBalanceType.wallet,
        amountMinor: 50000,
      ),
      throwsA(isA<SqliteException>()),
    );
    expect(await db.select(db.openingBalances).get(), isEmpty);
    expect(await db.select(db.ledgerEntries).get(), isEmpty);
    expect(await db.select(db.ledgerLines).get(), isEmpty);
  });
}

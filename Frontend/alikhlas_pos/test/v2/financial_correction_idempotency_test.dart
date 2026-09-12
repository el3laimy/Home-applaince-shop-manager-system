import 'dart:io';

import 'package:alikhlas_pos/v2/accounting/account_codes.dart';
import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

Future<T> _success<T>(Future<AppResult<T>> result) async =>
    (await result as AppSuccess<T>).value;

void main() {
  test(
    'wallet correction is idempotent, balanced, and included in reports',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final useCases = V2UseCases(db);
      const key = 'wallet-counted-excess';

      final ids = await Future.wait([
        _success(
          useCases.recordFinancialCorrection(
            operationKey: key,
            target: FinancialCorrectionTarget.wallet,
            amountMinor: 12500,
            increasesBalance: true,
            reason: 'فرق عدّ المحفظة',
            note: 'بعد المطابقة اليومية',
          ),
        ),
        _success(
          useCases.recordFinancialCorrection(
            operationKey: key,
            target: FinancialCorrectionTarget.wallet,
            amountMinor: 12500,
            increasesBalance: true,
            reason: 'فرق عدّ المحفظة',
            note: 'بعد المطابقة اليومية',
          ),
        ),
      ]);

      expect(ids[0], ids[1]);
      final correction = await db.select(db.financialCorrections).getSingle();
      expect(correction.target, FinancialCorrectionTarget.wallet.name);
      expect(correction.deltaMinor, 12500);
      expect(correction.reason, 'فرق عدّ المحفظة');

      final lines = await db.select(db.ledgerLines).get();
      expect(lines, hasLength(2));
      expect(
        lines
            .where((line) => line.accountCode == AccountCodes.wallet)
            .single
            .debitMinor,
        12500,
      );
      expect(
        lines
            .where((line) => line.accountCode == AccountCodes.financialVariance)
            .single
            .creditMinor,
        12500,
      );

      final dashboard = await useCases.dashboardSnapshot();
      expect(dashboard.walletMinor, 12500);
      expect(dashboard.financialVarianceMinor, -12500);
      expect(dashboard.grossProfitMinor, 12500);
      final today = DateTime.now();
      final report = await useCases.periodReport(start: today, end: today);
      expect(report.financialVarianceMinor, -12500);
      expect(report.profitMinor, 12500);
      expect((await useCases.dataIntegrityAudit()).isConsistent, isTrue);

      expect(
        await useCases.recordFinancialCorrection(
          operationKey: key,
          target: FinancialCorrectionTarget.wallet,
          amountMinor: 13000,
          increasesBalance: true,
          reason: 'فرق عدّ المحفظة',
        ),
        isA<AppFailure<int>>(),
      );
      expect(await db.select(db.financialCorrections).get(), hasLength(1));
    },
  );

  test(
    'cash correction requires a shift and asks before a negative balance',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final useCases = V2UseCases(db);

      expect(
        await useCases.recordFinancialCorrection(
          operationKey: 'cash-no-shift',
          target: FinancialCorrectionTarget.cash,
          amountMinor: 100,
          increasesBalance: true,
          reason: 'فرق عدّ',
        ),
        isA<AppFailure<int>>(),
      );
      expect(await db.select(db.financialCorrections).get(), isEmpty);

      await _success(
        useCases.openShift(0, operationKey: useCases.newShiftOperationKey()),
      );
      final first = await useCases.recordFinancialCorrection(
        operationKey: 'cash-shortage',
        target: FinancialCorrectionTarget.cash,
        amountMinor: 100,
        increasesBalance: false,
        reason: 'عجز عند التسليم',
      );
      expect(first, isA<AppConfirmationRequired<int>>());
      expect(await db.select(db.financialCorrections).get(), isEmpty);

      final correctionId = await _success(
        useCases.recordFinancialCorrection(
          operationKey: 'cash-shortage',
          target: FinancialCorrectionTarget.cash,
          amountMinor: 100,
          increasesBalance: false,
          reason: 'عجز عند التسليم',
          allowNegativeBalance: true,
        ),
      );
      expect(correctionId, greaterThan(0));
      expect((await useCases.dashboardSnapshot()).cashMinor, -100);
      expect((await useCases.dataIntegrityAudit()).isConsistent, isTrue);
    },
  );

  test(
    'pending correction replays once after reopening the database',
    () async {
      final directory = Directory.systemTemp.createTempSync('correction-once-');
      late AppDatabase db;
      addTearDown(() async {
        await db.close();
        directory.deleteSync(recursive: true);
      });
      db = AppDatabase(NativeDatabase(File('${directory.path}/shop.db')));
      var useCases = V2UseCases(db);
      final request = PendingFinancialOperation.financialCorrection(
        operationKey: useCases.newFinancialCorrectionOperationKey(),
        target: FinancialCorrectionTarget.wallet,
        amountMinor: 800,
        increasesBalance: false,
        reason: 'عجز محفظة موثق',
      );

      await useCases.stagePendingFinancialOperation(request);
      final firstId = await _success(
        useCases.submitPendingFinancialOperation(
          request,
          allowNegativeBalance: true,
        ),
      );

      await db.close();
      db = AppDatabase(NativeDatabase(File('${directory.path}/shop.db')));
      useCases = V2UseCases(db);
      final restored = await useCases.pendingFinancialOperation();
      expect(restored?.encode(), request.encode());
      expect(
        await _success(
          useCases.submitPendingFinancialOperation(
            restored!,
            allowNegativeBalance: true,
          ),
        ),
        firstId,
      );
      expect(await db.select(db.financialCorrections).get(), hasLength(1));
      expect(
        await useCases.acknowledgePendingFinancialOperation(
          request.operationKey,
        ),
        isTrue,
      );
      expect((await useCases.dataIntegrityAudit()).isConsistent, isTrue);
    },
  );

  test('correction rolls back when its receipt cannot be saved', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final useCases = V2UseCases(db);
    await db.customStatement(
      "CREATE TEMP TRIGGER fail_correction_receipt "
      "BEFORE INSERT ON app_settings "
      "WHEN NEW.key = 'operation.financial_correction.fail-write' "
      "BEGIN SELECT RAISE(ABORT, 'simulated receipt failure'); END",
    );

    await expectLater(
      useCases.recordFinancialCorrection(
        operationKey: 'fail-write',
        target: FinancialCorrectionTarget.wallet,
        amountMinor: 500,
        increasesBalance: true,
        reason: 'اختبار تراجع',
      ),
      throwsA(isA<sqlite.SqliteException>()),
    );
    expect(await db.select(db.financialCorrections).get(), isEmpty);
    expect(await db.select(db.ledgerEntries).get(), isEmpty);
    expect(await db.select(db.ledgerLines).get(), isEmpty);
  });

  test(
    'reversal preserves the source, posts its exact inverse, and is idempotent',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final useCases = V2UseCases(db);
      final correctionId = await _success(
        useCases.recordFinancialCorrection(
          operationKey: 'correction-to-reverse',
          target: FinancialCorrectionTarget.wallet,
          amountMinor: 12500,
          increasesBalance: true,
          reason: 'فرق عد موثق',
        ),
      );
      const reversalKey = 'reverse-correction-once';

      final reversalId = await _success(
        useCases.reverseFinancialCorrection(
          operationKey: reversalKey,
          correctionId: correctionId,
          reason: 'أدخل الفرق على الحساب الخطأ',
          note: 'راجعه المالك',
        ),
      );
      expect(
        await _success(
          useCases.reverseFinancialCorrection(
            operationKey: reversalKey,
            correctionId: correctionId,
            reason: 'أدخل الفرق على الحساب الخطأ',
            note: 'راجعه المالك',
          ),
        ),
        reversalId,
      );

      expect(await db.select(db.financialCorrections).get(), hasLength(1));
      final reversal = await db
          .select(db.financialCorrectionReversals)
          .getSingle();
      expect(reversal.id, reversalId);
      expect(reversal.correctionId, correctionId);
      expect(reversal.reason, 'أدخل الفرق على الحساب الخطأ');
      expect(await useCases.reversibleFinancialCorrections(), isEmpty);

      final walletLines = (await db.select(db.ledgerLines).get())
          .where((line) => line.accountCode == AccountCodes.wallet)
          .toList();
      expect(walletLines, hasLength(2));
      expect(
        walletLines.fold<int>(0, (sum, row) => sum + row.debitMinor),
        12500,
      );
      expect(
        walletLines.fold<int>(0, (sum, row) => sum + row.creditMinor),
        12500,
      );
      final dashboard = await useCases.dashboardSnapshot();
      expect(dashboard.walletMinor, 0);
      expect(dashboard.financialVarianceMinor, 0);
      final today = DateTime.now();
      final report = await useCases.periodReport(start: today, end: today);
      expect(report.financialVarianceMinor, 0);
      expect((await useCases.dataIntegrityAudit()).isConsistent, isTrue);

      expect(
        await useCases.reverseFinancialCorrection(
          operationKey: 'second-independent-reversal',
          correctionId: correctionId,
          reason: 'محاولة عكس أخرى',
        ),
        isA<AppFailure<int>>(),
      );
      expect(
        await db.select(db.financialCorrectionReversals).get(),
        hasLength(1),
      );
    },
  );

  test(
    'cash reversal requires a shift and confirms a negative balance',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final useCases = V2UseCases(db);
      await _success(
        useCases.openShift(0, operationKey: useCases.newShiftOperationKey()),
      );
      final correctionId = await _success(
        useCases.recordFinancialCorrection(
          operationKey: 'cash-reversal-source',
          target: FinancialCorrectionTarget.cash,
          amountMinor: 100,
          increasesBalance: true,
          reason: 'فرق نقدي',
        ),
      );
      await _success(
        useCases.recordExpense(
          operationKey: 'spend-cash-before-reversal',
          description: 'مصروف نقدي',
          amountMinor: 100,
          method: PaymentMethod.cash,
        ),
      );

      final first = await useCases.reverseFinancialCorrection(
        operationKey: 'cash-reversal-negative',
        correctionId: correctionId,
        reason: 'التصحيح الأصلي غير صحيح',
      );
      expect(first, isA<AppConfirmationRequired<int>>());
      expect(await db.select(db.financialCorrectionReversals).get(), isEmpty);

      await _success(
        useCases.reverseFinancialCorrection(
          operationKey: 'cash-reversal-negative',
          correctionId: correctionId,
          reason: 'التصحيح الأصلي غير صحيح',
          allowNegativeBalance: true,
        ),
      );
      expect((await useCases.dashboardSnapshot()).cashMinor, -100);
      expect((await useCases.dataIntegrityAudit()).isConsistent, isTrue);
    },
  );

  test('pending reversal replays once after reopening the database', () async {
    final directory = Directory.systemTemp.createTempSync('reversal-once-');
    late AppDatabase db;
    addTearDown(() async {
      await db.close();
      directory.deleteSync(recursive: true);
    });
    db = AppDatabase(NativeDatabase(File('${directory.path}/shop.db')));
    var useCases = V2UseCases(db);
    final correctionId = await _success(
      useCases.recordFinancialCorrection(
        operationKey: 'pending-reversal-source',
        target: FinancialCorrectionTarget.wallet,
        amountMinor: 800,
        increasesBalance: true,
        reason: 'فرق مؤقت',
      ),
    );
    final request = PendingFinancialOperation.financialCorrectionReversal(
      operationKey: useCases.newFinancialCorrectionReversalOperationKey(),
      correctionId: correctionId,
      reason: 'ثبت أن الفرق غير صحيح',
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
    expect(
      await db.select(db.financialCorrectionReversals).get(),
      hasLength(1),
    );
    expect(
      await useCases.acknowledgePendingFinancialOperation(request.operationKey),
      isTrue,
    );
    expect((await useCases.dataIntegrityAudit()).isConsistent, isTrue);
  });

  test('reversal rolls back when its receipt cannot be saved', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final useCases = V2UseCases(db);
    final correctionId = await _success(
      useCases.recordFinancialCorrection(
        operationKey: 'rollback-reversal-source',
        target: FinancialCorrectionTarget.wallet,
        amountMinor: 500,
        increasesBalance: true,
        reason: 'فرق للاختبار',
      ),
    );
    final entriesBefore = (await db.select(db.ledgerEntries).get()).length;
    final linesBefore = (await db.select(db.ledgerLines).get()).length;
    await db.customStatement(
      "CREATE TEMP TRIGGER fail_reversal_receipt "
      "BEFORE INSERT ON app_settings "
      "WHEN NEW.key = 'operation.financial_correction_reversal.fail-reversal' "
      "BEGIN SELECT RAISE(ABORT, 'simulated receipt failure'); END",
    );

    await expectLater(
      useCases.reverseFinancialCorrection(
        operationKey: 'fail-reversal',
        correctionId: correctionId,
        reason: 'اختبار تراجع العكس',
      ),
      throwsA(isA<sqlite.SqliteException>()),
    );
    expect(await db.select(db.financialCorrectionReversals).get(), isEmpty);
    expect((await db.select(db.ledgerEntries).get()).length, entriesBefore);
    expect((await db.select(db.ledgerLines).get()).length, linesBefore);
    expect((await useCases.dashboardSnapshot()).walletMinor, 500);
  });
}

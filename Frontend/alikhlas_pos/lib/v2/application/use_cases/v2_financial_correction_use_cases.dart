part of '../v2_use_cases.dart';

/// Records a counted difference in the cash drawer or wallet without changing
/// sales, purchases, stock, or party balances. Those domains each require
/// their own source document and reversal flow.
extension V2FinancialCorrectionUseCases on V2UseCases {
  String newFinancialCorrectionOperationKey() => newFinancialOperationKey();

  String newFinancialCorrectionReversalOperationKey() =>
      newFinancialOperationKey();

  Future<List<FinancialCorrection>> reversibleFinancialCorrections() async {
    final corrections = await (db.select(
      db.financialCorrections,
    )..orderBy([(row) => OrderingTerm.desc(row.createdAt)])).get();
    final reversedIds = (await db.select(db.financialCorrectionReversals).get())
        .map((row) => row.correctionId)
        .toSet();
    return [
      for (final correction in corrections)
        if (!reversedIds.contains(correction.id)) correction,
    ];
  }

  Future<AppResult<int>> recordFinancialCorrection({
    String? operationKey,
    required FinancialCorrectionTarget target,
    required int amountMinor,
    required bool increasesBalance,
    required String reason,
    String? note,
    bool allowNegativeBalance = false,
  }) {
    if (operationKey == null) {
      return Future.value(
        const AppFailure<int>('معرّف مستند التصحيح مطلوب لمنع تسجيله مرتين.'),
      );
    }
    final cleanReason = reason.trim();
    final cleanNote = _blankToNull(note);
    return _runIdempotentFinancialOperation(
      namespace: 'financial_correction',
      operationKey: operationKey,
      fingerprintPayload: [
        target.name,
        amountMinor,
        increasesBalance,
        cleanReason,
        cleanNote,
      ],
      conflictMessage:
          'مستند التصحيح محفوظ ببيانات مختلفة. راجع دفتر الخزينة أو المحفظة.',
      execute: () => _recordFinancialCorrection(
        target: target,
        amountMinor: amountMinor,
        increasesBalance: increasesBalance,
        reason: cleanReason,
        note: cleanNote,
        allowNegativeBalance: allowNegativeBalance,
      ),
    );
  }

  Future<AppResult<int>> _recordFinancialCorrection({
    required FinancialCorrectionTarget target,
    required int amountMinor,
    required bool increasesBalance,
    required String reason,
    required String? note,
    required bool allowNegativeBalance,
  }) async {
    if (amountMinor <= 0) {
      return const AppFailure<int>('قيمة التصحيح يجب أن تكون أكبر من صفر.');
    }
    if (reason.isEmpty) {
      return const AppFailure<int>('سبب التصحيح مطلوب.');
    }
    if (reason.length > 240) {
      return const AppFailure<int>('سبب التصحيح لا يزيد عن 240 حرفًا.');
    }
    if (note != null && note.length > 500) {
      return const AppFailure<int>('التوضيح لا يزيد عن 500 حرف.');
    }
    if (target == FinancialCorrectionTarget.cash &&
        await currentShift() == null) {
      return const AppFailure<int>('افتح وردية قبل تسجيل تصحيح للخزينة.');
    }

    final assetLine = _LedgerLineDraft(
      target.accountCode,
      debitMinor: increasesBalance ? amountMinor : 0,
      creditMinor: increasesBalance ? 0 : amountMinor,
    );
    if (!allowNegativeBalance) {
      final confirmation = await _negativeBalanceConfirmationFor([assetLine]);
      if (confirmation != null) return confirmation;
    }

    return _writeTransaction(() async {
      if (target == FinancialCorrectionTarget.cash &&
          await currentShift() == null) {
        return const AppFailure<int>('افتح وردية قبل تسجيل تصحيح للخزينة.');
      }

      final deltaMinor = increasesBalance ? amountMinor : -amountMinor;
      final correctionId = await db
          .into(db.financialCorrections)
          .insert(
            FinancialCorrectionsCompanion.insert(
              target: target.name,
              deltaMinor: deltaMinor,
              reason: reason,
              note: Value(note),
              createdAt: Value(clock()),
            ),
          );
      await _postLedger(
        referenceType: 'financial_correction',
        referenceId: correctionId,
        description:
            'تصحيح ${target.label}: $reason${note == null ? '' : ' — $note'}',
        lines: [
          assetLine,
          _LedgerLineDraft(
            AccountCodes.financialVariance,
            debitMinor: increasesBalance ? 0 : amountMinor,
            creditMinor: increasesBalance ? amountMinor : 0,
          ),
        ],
      );
      return AppSuccess<int>(correctionId);
    });
  }

  Future<AppResult<int>> reverseFinancialCorrection({
    String? operationKey,
    required int correctionId,
    required String reason,
    String? note,
    bool allowNegativeBalance = false,
  }) {
    if (operationKey == null) {
      return Future.value(
        const AppFailure<int>('معرّف مستند العكس مطلوب لمنع تسجيله مرتين.'),
      );
    }
    final cleanReason = reason.trim();
    final cleanNote = _blankToNull(note);
    return _runIdempotentFinancialOperation(
      namespace: 'financial_correction_reversal',
      operationKey: operationKey,
      fingerprintPayload: [correctionId, cleanReason, cleanNote],
      conflictMessage:
          'مستند العكس محفوظ ببيانات مختلفة. راجع سجل التصحيحات المالية.',
      execute: () => _reverseFinancialCorrection(
        correctionId: correctionId,
        reason: cleanReason,
        note: cleanNote,
        allowNegativeBalance: allowNegativeBalance,
      ),
    );
  }

  Future<AppResult<int>> _reverseFinancialCorrection({
    required int correctionId,
    required String reason,
    required String? note,
    required bool allowNegativeBalance,
  }) async {
    if (reason.isEmpty) {
      return const AppFailure<int>('سبب عكس التصحيح مطلوب.');
    }
    if (reason.length > 240) {
      return const AppFailure<int>('سبب العكس لا يزيد عن 240 حرفًا.');
    }
    if (note != null && note.length > 500) {
      return const AppFailure<int>('التوضيح لا يزيد عن 500 حرف.');
    }
    final correction = await (db.select(
      db.financialCorrections,
    )..where((row) => row.id.equals(correctionId))).getSingleOrNull();
    if (correction == null) {
      return const AppFailure<int>('مستند التصحيح الأصلي غير موجود.');
    }
    final existing = await (db.select(
      db.financialCorrectionReversals,
    )..where((row) => row.correctionId.equals(correctionId))).getSingleOrNull();
    if (existing != null) {
      return const AppFailure<int>('تم عكس هذا التصحيح من قبل.');
    }
    final target = FinancialCorrectionTarget.values
        .where((candidate) => candidate.name == correction.target)
        .firstOrNull;
    if (target == null || correction.deltaMinor == 0) {
      return const AppFailure<int>('بيانات التصحيح الأصلي غير صالحة للعكس.');
    }
    if (target == FinancialCorrectionTarget.cash &&
        await currentShift() == null) {
      return const AppFailure<int>('افتح وردية قبل عكس تصحيح الخزينة.');
    }

    final reversalDelta = -correction.deltaMinor;
    final amountMinor = reversalDelta.abs();
    final assetLine = _LedgerLineDraft(
      target.accountCode,
      debitMinor: reversalDelta > 0 ? amountMinor : 0,
      creditMinor: reversalDelta < 0 ? amountMinor : 0,
    );
    if (!allowNegativeBalance) {
      final confirmation = await _negativeBalanceConfirmationFor([assetLine]);
      if (confirmation != null) return confirmation;
    }

    return _writeTransaction(() async {
      final latestCorrection = await (db.select(
        db.financialCorrections,
      )..where((row) => row.id.equals(correctionId))).getSingleOrNull();
      final latestReversal =
          await (db.select(db.financialCorrectionReversals)
                ..where((row) => row.correctionId.equals(correctionId)))
              .getSingleOrNull();
      if (latestCorrection == null) {
        return const AppFailure<int>('مستند التصحيح الأصلي غير موجود.');
      }
      if (latestReversal != null) {
        return const AppFailure<int>('تم عكس هذا التصحيح من قبل.');
      }
      if (target == FinancialCorrectionTarget.cash &&
          await currentShift() == null) {
        return const AppFailure<int>('افتح وردية قبل عكس تصحيح الخزينة.');
      }

      final reversalId = await db
          .into(db.financialCorrectionReversals)
          .insert(
            FinancialCorrectionReversalsCompanion.insert(
              correctionId: correctionId,
              reason: reason,
              note: Value(note),
              createdAt: Value(clock()),
            ),
          );
      await _postLedger(
        referenceType: 'financial_correction_reversal',
        referenceId: reversalId,
        description:
            'عكس تصحيح ${target.label} #$correctionId: $reason${note == null ? '' : ' — $note'}',
        lines: [
          assetLine,
          _LedgerLineDraft(
            AccountCodes.financialVariance,
            debitMinor: reversalDelta < 0 ? amountMinor : 0,
            creditMinor: reversalDelta > 0 ? amountMinor : 0,
          ),
        ],
      );
      return AppSuccess<int>(reversalId);
    });
  }
}

part of '../v2_use_cases.dart';

/// Records a counted difference in the cash drawer or wallet without changing
/// sales, purchases, stock, or party balances. Those domains each require
/// their own source document and reversal flow.
extension V2FinancialCorrectionUseCases on V2UseCases {
  String newFinancialCorrectionOperationKey() => newFinancialOperationKey();

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
}

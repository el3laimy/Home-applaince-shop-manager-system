part of '../v2_use_cases.dart';

extension V2ExpenseUseCases on V2UseCases {
  String newExpenseOperationKey() => newFinancialOperationKey();

  Future<AppResult<int>> recordExpense({
    String? operationKey,
    required String description,
    required int amountMinor,
    required PaymentMethod method,
    bool allowNegativeBalance = false,
  }) async {
    final normalizedDescription = description.trim();
    if (operationKey == null) {
      return const AppFailure<int>(
        'معرّف عملية المصروف مطلوب لمنع تسجيله مرتين.',
      );
    }
    return _runIdempotentFinancialOperation(
      namespace: 'expense',
      operationKey: operationKey,
      fingerprintPayload: [normalizedDescription, amountMinor, method.name],
      conflictMessage: 'هذا المصروف محفوظ ببيانات مختلفة. راجع سجل المصروفات.',
      execute: () => _recordExpense(
        description: normalizedDescription,
        amountMinor: amountMinor,
        method: method,
        allowNegativeBalance: allowNegativeBalance,
      ),
    );
  }

  Future<AppResult<int>> _recordExpense({
    required String description,
    required int amountMinor,
    required PaymentMethod method,
    required bool allowNegativeBalance,
  }) async {
    final normalizedDescription = description.trim();
    if (normalizedDescription.isEmpty) {
      return const AppFailure('وصف المصروف مطلوب');
    }
    if (amountMinor <= 0) {
      return const AppFailure('قيمة المصروف يجب أن تكون أكبر من صفر');
    }
    if (method == PaymentMethod.installment) {
      return const AppFailure('المصروف لا يدعم التقسيط');
    }

    final shift = await currentShift();
    if (method == PaymentMethod.cash && shift == null) {
      return const AppFailure('افتح وردية قبل تسجيل مصروف نقدي');
    }
    if (!allowNegativeBalance) {
      final confirmation = await _negativeBalanceConfirmationFor([
        _LedgerLineDraft(
          method == PaymentMethod.cash
              ? AccountCodes.cash
              : AccountCodes.wallet,
          creditMinor: amountMinor,
        ),
      ]);
      if (confirmation != null) return confirmation;
    }

    final expenseId = await _writeTransaction(() async {
      final expenseId = await db
          .into(db.expenses)
          .insert(
            ExpensesCompanion.insert(
              description: description.trim(),
              amountMinor: amountMinor,
              method: method.name,
            ),
          );
      await _postLedger(
        referenceType: 'expense',
        referenceId: expenseId,
        description: 'مصروف: $normalizedDescription',
        lines: [
          _LedgerLineDraft(AccountCodes.expenses, debitMinor: amountMinor),
          _LedgerLineDraft(
            method == PaymentMethod.cash
                ? AccountCodes.cash
                : AccountCodes.wallet,
            creditMinor: amountMinor,
          ),
        ],
      );
      return expenseId;
    });

    return AppSuccess(expenseId);
  }
}

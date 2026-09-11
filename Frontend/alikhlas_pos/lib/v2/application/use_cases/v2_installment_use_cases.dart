part of '../v2_use_cases.dart';

extension V2InstallmentUseCases on V2UseCases {
  String newInstallmentOperationKey() => newFinancialOperationKey();

  Future<AppResult<int>> collectInstallment({
    String? operationKey,
    required int planId,
    required int amountMinor,
    required PaymentMethod method,
  }) async {
    if (operationKey == null) {
      return const AppFailure<int>(
        'معرّف عملية التحصيل مطلوب لمنع تسجيل القسط مرتين.',
      );
    }
    return _runIdempotentFinancialOperation(
      namespace: 'installment.customer',
      operationKey: operationKey,
      fingerprintPayload: ['customer', planId, amountMinor, method.name],
      conflictMessage:
          'هذا التحصيل محفوظ ببيانات مختلفة. راجع كشف حساب العميل.',
      execute: () => _settleInstallment(
        planId: planId,
        amountMinor: amountMinor,
        method: method,
        expectedPartyType: 'customer',
        debitAccount: method == PaymentMethod.cash
            ? AccountCodes.cash
            : AccountCodes.wallet,
        creditAccount: AccountCodes.receivables,
        description: 'تحصيل قسط عميل',
      ),
    );
  }

  Future<AppResult<int>> paySupplierInstallment({
    String? operationKey,
    required int planId,
    required int amountMinor,
    required PaymentMethod method,
    bool allowNegativeBalance = false,
  }) async {
    if (operationKey == null) {
      return const AppFailure<int>(
        'معرّف عملية السداد مطلوب لمنع تسجيل قسط المورد مرتين.',
      );
    }
    return _runIdempotentFinancialOperation(
      namespace: 'installment.supplier',
      operationKey: operationKey,
      fingerprintPayload: ['supplier', planId, amountMinor, method.name],
      conflictMessage: 'هذا السداد محفوظ ببيانات مختلفة. راجع كشف حساب المورد.',
      execute: () => _settleInstallment(
        planId: planId,
        amountMinor: amountMinor,
        method: method,
        expectedPartyType: 'supplier',
        debitAccount: AccountCodes.payables,
        creditAccount: method == PaymentMethod.cash
            ? AccountCodes.cash
            : AccountCodes.wallet,
        description: 'سداد قسط مورد',
        allowNegativeBalance: allowNegativeBalance,
      ),
    );
  }

  Future<void> _createInstallmentPlan({
    required String ownerType,
    required int ownerId,
    required String partyType,
    required int partyId,
    required int principalMinor,
    required int interestMinor,
    required InstallmentTerms terms,
  }) async {
    final total = principalMinor + interestMinor;
    final planId = await db
        .into(db.installmentPlans)
        .insert(
          InstallmentPlansCompanion.insert(
            ownerType: ownerType,
            ownerId: ownerId,
            partyType: partyType,
            partyId: partyId,
            principalMinor: principalMinor,
            interestMinor: Value(interestMinor),
            totalMinor: total,
            installmentCount: terms.count,
          ),
        );

    for (var i = 0; i < terms.count; i++) {
      await db
          .into(db.installmentPayments)
          .insert(
            InstallmentPaymentsCompanion.insert(
              planId: planId,
              amountMinor: allocateRemainderToLast(total, terms.count, i),
              dueDate: terms.firstDueDate.add(
                Duration(days: terms.periodDays * i),
              ),
            ),
          );
    }
  }

  Future<AppResult<int>> _settleInstallment({
    required int planId,
    required int amountMinor,
    required PaymentMethod method,
    required String expectedPartyType,
    required String debitAccount,
    required String creditAccount,
    required String description,
    bool allowNegativeBalance = false,
  }) async {
    if (amountMinor <= 0) {
      return const AppFailure<int>('قيمة السداد يجب أن تكون أكبر من صفر');
    }
    if (method == PaymentMethod.installment) {
      return const AppFailure<int>('سداد الأقساط يكون كاش أو محفظة فقط');
    }
    final shift = await currentShift();
    if (method == PaymentMethod.cash && shift == null) {
      return const AppFailure<int>('افتح وردية قبل أي حركة كاش');
    }

    try {
      final ledgerId = await _writeTransaction(() async {
        final plan = await (db.select(
          db.installmentPlans,
        )..where((p) => p.id.equals(planId))).getSingleOrNull();
        if (plan == null || plan.partyType != expectedPartyType) {
          throw _BusinessError('خطة الأقساط غير موجودة');
        }
        if (plan.status == 'closed') {
          throw _BusinessError('خطة الأقساط مغلقة بالفعل');
        }

        final remaining = plan.totalMinor - plan.paidMinor;
        if (amountMinor > remaining) {
          throw _BusinessError('قيمة السداد أكبر من المتبقي');
        }
        if (!allowNegativeBalance) {
          final confirmation = await _negativeBalanceConfirmationFor([
            _LedgerLineDraft(creditAccount, creditMinor: amountMinor),
          ]);
          if (confirmation != null) {
            throw _ConfirmationRequired(confirmation);
          }
        }

        await _allocateInstallmentPayment(planId, amountMinor);
        final newPaid = plan.paidMinor + amountMinor;
        await (db.update(
          db.installmentPlans,
        )..where((p) => p.id.equals(planId))).write(
          InstallmentPlansCompanion(
            paidMinor: Value(newPaid),
            status: Value(newPaid == plan.totalMinor ? 'closed' : 'open'),
          ),
        );

        await _insertPayments('installment_plan', planId, [
          PaymentInput(method, amountMinor),
        ]);

        return _postLedger(
          referenceType: 'installment_payment',
          referenceId: planId,
          description: description,
          lines: [
            _LedgerLineDraft(
              debitAccount,
              debitMinor: amountMinor,
              partyType:
                  debitAccount == AccountCodes.receivables ||
                      debitAccount == AccountCodes.payables
                  ? plan.partyType
                  : null,
              partyId:
                  debitAccount == AccountCodes.receivables ||
                      debitAccount == AccountCodes.payables
                  ? plan.partyId
                  : null,
            ),
            _LedgerLineDraft(
              creditAccount,
              creditMinor: amountMinor,
              partyType:
                  creditAccount == AccountCodes.receivables ||
                      creditAccount == AccountCodes.payables
                  ? plan.partyType
                  : null,
              partyId:
                  creditAccount == AccountCodes.receivables ||
                      creditAccount == AccountCodes.payables
                  ? plan.partyId
                  : null,
            ),
          ],
        );
      });
      return AppSuccess(ledgerId);
    } on _ConfirmationRequired catch (e) {
      return e.result;
    } on _BusinessError catch (e) {
      return AppFailure(e.message);
    }
  }

  Future<void> _allocateInstallmentPayment(int planId, int amountMinor) async {
    final plan = await (db.select(
      db.installmentPlans,
    )..where((p) => p.id.equals(planId))).getSingle();
    var remaining = plan.paidMinor + amountMinor;
    final installments =
        await (db.select(db.installmentPayments)
              ..where((p) => p.planId.equals(planId))
              ..orderBy([
                (p) =>
                    OrderingTerm(expression: p.dueDate, mode: OrderingMode.asc),
              ]))
            .get();

    for (final installment in installments) {
      if (remaining == 0) break;

      if (remaining < installment.amountMinor) {
        await (db.update(
          db.installmentPayments,
        )..where((p) => p.id.equals(installment.id))).write(
          const InstallmentPaymentsCompanion(status: Value('partial')),
        );
        break;
      }
      await (db.update(
        db.installmentPayments,
      )..where((p) => p.id.equals(installment.id))).write(
        InstallmentPaymentsCompanion(
          status: const Value('paid'),
          paidAt: Value(installment.paidAt ?? clock()),
        ),
      );
      remaining -= installment.amountMinor;
    }
  }
}

part of '../v2_use_cases.dart';

extension V2OpeningBalanceUseCases on V2UseCases {
  String newOpeningBalanceOperationKey() => newFinancialOperationKey();

  Future<AppResult<int>> recordOpeningBalance({
    String? operationKey,
    required OpeningBalanceType type,
    int? partyId,
    required int amountMinor,
    DateTime? dueDate,
    String? note,
  }) {
    if (operationKey == null) {
      return Future.value(
        const AppFailure<int>(
          'معرّف الرصيد الافتتاحي مطلوب لمنع تسجيله مرتين.',
        ),
      );
    }
    final cleanNote = _blankToNull(note);
    final normalizedDueDate = dueDate == null
        ? null
        : DateTime(dueDate.year, dueDate.month, dueDate.day);
    return _runIdempotentFinancialOperation(
      namespace: 'opening_balance',
      operationKey: operationKey,
      fingerprintPayload: [
        type.name,
        partyId,
        amountMinor,
        normalizedDueDate?.toIso8601String(),
        cleanNote,
      ],
      conflictMessage:
          'هذا الرصيد الافتتاحي محفوظ ببيانات مختلفة. راجع كشف الحساب قبل المحاولة.',
      execute: () => _recordOpeningBalance(
        type: type,
        partyId: partyId,
        amountMinor: amountMinor,
        dueDate: normalizedDueDate,
        note: cleanNote,
      ),
    );
  }

  Future<AppResult<int>> _recordOpeningBalance({
    required OpeningBalanceType type,
    required int? partyId,
    required int amountMinor,
    required DateTime? dueDate,
    required String? note,
  }) async {
    if (amountMinor <= 0) {
      return const AppFailure<int>('قيمة الرصيد يجب أن تكون أكبر من صفر.');
    }
    if (note != null && note.length > 200) {
      return const AppFailure<int>('التوضيح لا يزيد عن 200 حرف.');
    }
    if (type.requiresParty && (partyId == null || partyId < 1)) {
      return const AppFailure<int>('اختر العميل أو المورد صاحب الرصيد.');
    }
    if (type.requiresParty && dueDate == null) {
      return const AppFailure<int>('حدد تاريخ استحقاق الرصيد.');
    }
    if (!type.requiresParty && (partyId != null || dueDate != null)) {
      return const AppFailure<int>('رصيد الخزينة أو المحفظة لا يرتبط بطرف أو استحقاق.');
    }

    return _writeTransaction(() async {
      final duplicateQuery = db.select(db.openingBalances)
        ..where(
          (row) =>
              row.balanceType.equals(type.name) &
              (partyId == null
                  ? row.partyId.isNull()
                  : row.partyId.equals(partyId)),
        )
        ..limit(1);
      if ((await duplicateQuery.get()).isNotEmpty) {
        return const AppFailure<int>(
          'يوجد رصيد افتتاحي مسجل لهذا الحساب بالفعل. لا تسجله مرة أخرى.',
        );
      }

      String? partyType;
      String? partyName;
      String accountCode;
      if (type == OpeningBalanceType.customerReceivable) {
        final customer = await (db.select(
          db.customers,
        )..where((row) => row.id.equals(partyId!))).getSingleOrNull();
        if (customer == null) {
          return const AppFailure<int>('العميل غير موجود. حدّث الشاشة وحاول مرة أخرى.');
        }
        partyType = 'customer';
        partyName = customer.name;
        accountCode = AccountCodes.receivables;
      } else if (type == OpeningBalanceType.supplierPayable) {
        final supplier = await (db.select(
          db.suppliers,
        )..where((row) => row.id.equals(partyId!))).getSingleOrNull();
        if (supplier == null) {
          return const AppFailure<int>('المورد غير موجود. حدّث الشاشة وحاول مرة أخرى.');
        }
        partyType = 'supplier';
        partyName = supplier.name;
        accountCode = AccountCodes.payables;
      } else {
        if (await currentShift() != null) {
          return const AppFailure<int>(
            'أغلق الوردية قبل إدخال رصيد افتتاحي للخزينة أو المحفظة.',
          );
        }
        accountCode = type == OpeningBalanceType.cash
            ? AccountCodes.cash
            : AccountCodes.wallet;
      }

      final priorLines =
          await (db.select(db.ledgerLines)
                ..where(
                  (line) =>
                      line.accountCode.equals(accountCode) &
                      (partyType == null
                          ? const Constant(true)
                          : line.partyType.equals(partyType) &
                                line.partyId.equals(partyId!)),
                )
                ..limit(1))
              .get();
      if (priorLines.isNotEmpty) {
        return AppFailure<int>(
          type.requiresParty
              ? 'يوجد نشاط سابق في حساب $partyName. استخدم مستند تصحيح بدل رصيد افتتاحي.'
              : 'يوجد نشاط سابق في ${type.label}. استخدم مستند تصحيح بدل رصيد افتتاحي.',
        );
      }
      if (type.requiresParty) {
        final priorPlans =
            await (db.select(db.installmentPlans)
                  ..where(
                    (plan) =>
                        plan.partyType.equals(partyType!) &
                        plan.partyId.equals(partyId!),
                  )
                  ..limit(1))
                .get();
        if (priorPlans.isNotEmpty) {
          return AppFailure<int>(
            'يوجد جدول مديونية سابق في حساب $partyName. لا تضف رصيدًا افتتاحيًا.',
          );
        }
      }

      final openingBalanceId = await db
          .into(db.openingBalances)
          .insert(
            OpeningBalancesCompanion.insert(
              balanceType: type.name,
              partyId: Value(partyId),
              amountMinor: amountMinor,
              dueDate: Value(dueDate),
              note: Value(note),
              createdAt: Value(clock()),
            ),
          );

      if (type.requiresParty) {
        await _createInstallmentPlan(
          ownerType: 'opening_balance',
          ownerId: openingBalanceId,
          partyType: partyType!,
          partyId: partyId!,
          principalMinor: amountMinor,
          interestMinor: 0,
          terms: InstallmentTerms(
            partyId: partyId,
            count: 1,
            firstDueDate: dueDate!,
          ),
        );
      }

      final liquidOrReceivable =
          type == OpeningBalanceType.customerReceivable ||
          type == OpeningBalanceType.cash ||
          type == OpeningBalanceType.wallet;
      await _postLedger(
        referenceType: 'opening_balance',
        referenceId: openingBalanceId,
        description: partyName == null
            ? 'رصيد افتتاحي: ${type.label}${note == null ? '' : ' — $note'}'
            : 'رصيد افتتاحي: ${type.label} — $partyName${note == null ? '' : ' — $note'}',
        lines: liquidOrReceivable
            ? [
                _LedgerLineDraft(
                  accountCode,
                  debitMinor: amountMinor,
                  partyType: partyType,
                  partyId: partyId,
                ),
                _LedgerLineDraft(AccountCodes.capital, creditMinor: amountMinor),
              ]
            : [
                _LedgerLineDraft(AccountCodes.capital, debitMinor: amountMinor),
                _LedgerLineDraft(
                  accountCode,
                  creditMinor: amountMinor,
                  partyType: partyType,
                  partyId: partyId,
                ),
              ],
      );
      return AppSuccess<int>(openingBalanceId);
    });
  }
}

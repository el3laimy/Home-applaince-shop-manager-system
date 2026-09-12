part of '../v2_use_cases.dart';

extension _IntegrityPlansCorrectionsAudit on _IntegrityAuditContext {
  void auditPlansBalancesAndCorrections() {
    final linesByEntry = _groupIntegrityRows(lines, (line) => line.entryId);
    final planById = {for (final plan in plans) plan.id: plan};
    final scheduledByPlan = _groupIntegrityRows(
      scheduled,
      (payment) => payment.planId,
    );
    for (final plan in plans) {
      final rows = scheduledByPlan[plan.id] ?? const <InstallmentPayment>[];
      final scheduledTotal = rows.fold<int>(
        0,
        (total, payment) => total + payment.amountMinor,
      );
      if (rows.length != plan.installmentCount ||
          scheduledTotal != plan.totalMinor) {
        issues.add(
          DataIntegrityIssue(
            code: 'installment_schedule',
            record: 'خطة أقساط #${plan.id}',
            message: 'عدد أو مجموع أقساط الخطة لا يطابق إجماليها.',
          ),
        );
      }
      if (plan.paidMinor < 0 || plan.paidMinor > plan.totalMinor) {
        issues.add(
          DataIntegrityIssue(
            code: 'installment_paid_range',
            record: 'خطة أقساط #${plan.id}',
            message: 'المبلغ المسدد خارج نطاق إجمالي الخطة.',
          ),
        );
      }
      final expectedStatus = plan.paidMinor == plan.totalMinor
          ? 'closed'
          : 'open';
      if (plan.status != expectedStatus) {
        issues.add(
          DataIntegrityIssue(
            code: 'installment_status',
            record: 'خطة أقساط #${plan.id}',
            message: 'حالة خطة الأقساط لا توافق المبلغ المسدد.',
          ),
        );
      }
    }
    for (final payment in scheduled) {
      if (!planById.containsKey(payment.planId)) {
        issues.add(
          DataIntegrityIssue(
            code: 'installment_orphan_schedule',
            record: 'قسط مجدول #${payment.id}',
            message: 'القسط المجدول غير مرتبط بخطة أقساط.',
          ),
        );
      }
    }

    final customerIds = {for (final customer in customers) customer.id};
    final supplierIds = {for (final supplier in suppliers) supplier.id};
    final openingBalanceIds = {
      for (final balance in openingBalances) balance.id,
    };
    final seenOpeningTargets = <String>{};
    for (final balance in openingBalances) {
      final type = OpeningBalanceType.values
          .where((candidate) => candidate.name == balance.balanceType)
          .firstOrNull;
      final targetKey = '${balance.balanceType}:${balance.partyId ?? 0}';
      final duplicateTarget = !seenOpeningTargets.add(targetKey);
      final partyIsValid = switch (type) {
        OpeningBalanceType.customerReceivable =>
          balance.partyId != null && customerIds.contains(balance.partyId),
        OpeningBalanceType.supplierPayable =>
          balance.partyId != null && supplierIds.contains(balance.partyId),
        OpeningBalanceType.cash ||
        OpeningBalanceType.wallet => balance.partyId == null,
        null => false,
      };
      final dueDateIsValid = type?.requiresParty == true
          ? balance.dueDate != null
          : balance.dueDate == null;
      if (type == null ||
          balance.amountMinor <= 0 ||
          !partyIsValid ||
          !dueDateIsValid ||
          duplicateTarget) {
        issues.add(
          DataIntegrityIssue(
            code: 'opening_balance_data',
            record: 'رصيد افتتاحي #${balance.id}',
            message: 'بيانات الرصيد الافتتاحي أو الطرف أو تفرّده غير متسقة.',
          ),
        );
      }

      final matchingPlans = plans
          .where(
            (plan) =>
                plan.ownerType == 'opening_balance' &&
                plan.ownerId == balance.id,
          )
          .toList();
      if (type?.requiresParty == true) {
        final plan = matchingPlans.length == 1 ? matchingPlans.single : null;
        final expectedPartyType = type == OpeningBalanceType.customerReceivable
            ? 'customer'
            : 'supplier';
        if (plan == null ||
            plan.partyType != expectedPartyType ||
            plan.partyId != balance.partyId ||
            plan.principalMinor != balance.amountMinor ||
            plan.interestMinor != 0 ||
            plan.totalMinor != balance.amountMinor ||
            plan.installmentCount != 1) {
          issues.add(
            DataIntegrityIssue(
              code: 'opening_balance_plan',
              record: 'رصيد افتتاحي #${balance.id}',
              message: 'الرصيد الافتتاحي للطرف لا يطابق خطة المديونية.',
            ),
          );
        }
      } else if (matchingPlans.isNotEmpty) {
        issues.add(
          DataIntegrityIssue(
            code: 'opening_balance_plan',
            record: 'رصيد افتتاحي #${balance.id}',
            message: 'رصيد الخزينة أو المحفظة لا يجب أن ينشئ خطة مديونية.',
          ),
        );
      }

      final matchingEntries = entries
          .where(
            (entry) =>
                entry.referenceType == 'opening_balance' &&
                entry.referenceId == balance.id,
          )
          .toList();
      final openingEntry = matchingEntries.length == 1
          ? matchingEntries.single
          : null;
      final openingLines = openingEntry == null
          ? const <LedgerLine>[]
          : linesByEntry[openingEntry.id] ?? const <LedgerLine>[];
      bool hasExactLine({
        required String accountCode,
        required int debitMinor,
        required int creditMinor,
        String? partyType,
        int? partyId,
      }) => openingLines.any(
        (line) =>
            line.accountCode == accountCode &&
            line.debitMinor == debitMinor &&
            line.creditMinor == creditMinor &&
            line.partyType == partyType &&
            line.partyId == partyId,
      );
      final capitalIsDebit = type == OpeningBalanceType.supplierPayable;
      final targetAccount = switch (type) {
        OpeningBalanceType.customerReceivable => AccountCodes.receivables,
        OpeningBalanceType.supplierPayable => AccountCodes.payables,
        OpeningBalanceType.cash => AccountCodes.cash,
        OpeningBalanceType.wallet => AccountCodes.wallet,
        null => '',
      };
      final targetPartyType = switch (type) {
        OpeningBalanceType.customerReceivable => 'customer',
        OpeningBalanceType.supplierPayable => 'supplier',
        _ => null,
      };
      final ledgerIsValid =
          type != null &&
          openingEntry != null &&
          openingLines.length == 2 &&
          hasExactLine(
            accountCode: AccountCodes.capital,
            debitMinor: capitalIsDebit ? balance.amountMinor : 0,
            creditMinor: capitalIsDebit ? 0 : balance.amountMinor,
          ) &&
          hasExactLine(
            accountCode: targetAccount,
            debitMinor: capitalIsDebit ? 0 : balance.amountMinor,
            creditMinor: capitalIsDebit ? balance.amountMinor : 0,
            partyType: targetPartyType,
            partyId: targetPartyType == null ? null : balance.partyId,
          );
      if (!ledgerIsValid) {
        issues.add(
          DataIntegrityIssue(
            code: 'opening_balance_ledger',
            record: 'رصيد افتتاحي #${balance.id}',
            message: 'قيد الرصيد الافتتاحي مفقود أو لا يطابق المستند.',
          ),
        );
      }
    }
    for (final plan in plans.where(
      (plan) => plan.ownerType == 'opening_balance',
    )) {
      if (!openingBalanceIds.contains(plan.ownerId)) {
        issues.add(
          DataIntegrityIssue(
            code: 'opening_balance_orphan_plan',
            record: 'خطة أقساط #${plan.id}',
            message: 'خطة المديونية لا ترتبط برصيد افتتاحي موجود.',
          ),
        );
      }
    }

    for (final correction in financialCorrections) {
      final target = FinancialCorrectionTarget.values
          .where((candidate) => candidate.name == correction.target)
          .firstOrNull;
      if (target == null ||
          correction.deltaMinor == 0 ||
          correction.reason.trim().isEmpty ||
          correction.reason.length > 240 ||
          (correction.note?.length ?? 0) > 500) {
        issues.add(
          DataIntegrityIssue(
            code: 'financial_correction_data',
            record: 'تصحيح مالي #${correction.id}',
            message: 'بيانات مستند التصحيح المالي غير مكتملة أو غير صالحة.',
          ),
        );
      }

      final matchingEntries = entries
          .where(
            (entry) =>
                entry.referenceType == 'financial_correction' &&
                entry.referenceId == correction.id,
          )
          .toList();
      final correctionEntry = matchingEntries.length == 1
          ? matchingEntries.single
          : null;
      final correctionLines = correctionEntry == null
          ? const <LedgerLine>[]
          : linesByEntry[correctionEntry.id] ?? const <LedgerLine>[];
      final assetNet = correctionLines
          .where((line) => line.accountCode == target?.accountCode)
          .fold<int>(
            0,
            (total, line) => total + line.debitMinor - line.creditMinor,
          );
      final varianceNet = correctionLines
          .where((line) => line.accountCode == AccountCodes.financialVariance)
          .fold<int>(
            0,
            (total, line) => total + line.debitMinor - line.creditMinor,
          );
      final onlyExpectedAccounts = correctionLines.every(
        (line) =>
            line.accountCode == target?.accountCode ||
            line.accountCode == AccountCodes.financialVariance,
      );
      final isIncrease = correction.deltaMinor > 0;
      final amountMinor = correction.deltaMinor.abs();
      bool hasExactLine({
        required String accountCode,
        required int debitMinor,
        required int creditMinor,
      }) => correctionLines.any(
        (line) =>
            line.accountCode == accountCode &&
            line.debitMinor == debitMinor &&
            line.creditMinor == creditMinor &&
            line.partyType == null &&
            line.partyId == null,
      );
      if (target == null ||
          correctionEntry == null ||
          correctionLines.length != 2 ||
          !onlyExpectedAccounts ||
          assetNet != correction.deltaMinor ||
          varianceNet != -correction.deltaMinor ||
          !hasExactLine(
            accountCode: target.accountCode,
            debitMinor: isIncrease ? amountMinor : 0,
            creditMinor: isIncrease ? 0 : amountMinor,
          ) ||
          !hasExactLine(
            accountCode: AccountCodes.financialVariance,
            debitMinor: isIncrease ? 0 : amountMinor,
            creditMinor: isIncrease ? amountMinor : 0,
          )) {
        issues.add(
          DataIntegrityIssue(
            code: 'financial_correction_ledger',
            record: 'تصحيح مالي #${correction.id}',
            message: 'قيد التصحيح المالي مفقود أو لا يطابق المستند.',
          ),
        );
      }
    }

    final financialCorrectionById = {
      for (final correction in financialCorrections) correction.id: correction,
    };
    final reversedCorrectionIds = <int>{};
    for (final reversal in financialCorrectionReversals) {
      final correction = financialCorrectionById[reversal.correctionId];
      final duplicateSource = !reversedCorrectionIds.add(reversal.correctionId);
      final target = correction == null
          ? null
          : FinancialCorrectionTarget.values
                .where((candidate) => candidate.name == correction.target)
                .firstOrNull;
      if (correction == null ||
          duplicateSource ||
          reversal.reason.trim().isEmpty ||
          reversal.reason.length > 240 ||
          (reversal.note?.length ?? 0) > 500) {
        issues.add(
          DataIntegrityIssue(
            code: 'financial_correction_reversal_data',
            record: 'عكس تصحيح مالي #${reversal.id}',
            message: 'بيانات مستند العكس أو ارتباطه بالتصحيح الأصلي غير صالحة.',
          ),
        );
      }

      final matchingEntries = entries
          .where(
            (entry) =>
                entry.referenceType == 'financial_correction_reversal' &&
                entry.referenceId == reversal.id,
          )
          .toList();
      final reversalEntry = matchingEntries.length == 1
          ? matchingEntries.single
          : null;
      final reversalLines = reversalEntry == null
          ? const <LedgerLine>[]
          : linesByEntry[reversalEntry.id] ?? const <LedgerLine>[];
      final expectedDelta = -(correction?.deltaMinor ?? 0);
      final assetNet = reversalLines
          .where((line) => line.accountCode == target?.accountCode)
          .fold<int>(
            0,
            (total, line) => total + line.debitMinor - line.creditMinor,
          );
      final varianceNet = reversalLines
          .where((line) => line.accountCode == AccountCodes.financialVariance)
          .fold<int>(
            0,
            (total, line) => total + line.debitMinor - line.creditMinor,
          );
      final onlyExpectedAccounts = reversalLines.every(
        (line) =>
            line.accountCode == target?.accountCode ||
            line.accountCode == AccountCodes.financialVariance,
      );
      if (target == null ||
          correction == null ||
          reversalEntry == null ||
          reversalLines.length != 2 ||
          !onlyExpectedAccounts ||
          assetNet != expectedDelta ||
          varianceNet != -expectedDelta) {
        issues.add(
          DataIntegrityIssue(
            code: 'financial_correction_reversal_ledger',
            record: 'عكس تصحيح مالي #${reversal.id}',
            message: 'قيد العكس مفقود أو لا يعكس التصحيح الأصلي بدقة.',
          ),
        );
      }
    }
  }
}

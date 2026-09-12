part of '../v2_use_cases.dart';

extension _IntegrityReferenceAudit on _IntegrityAuditContext {
  void auditReferencesAndPartyBalances() {
    final saleById = {for (final sale in sales) sale.id: sale};
    final purchaseById = {
      for (final purchase in purchases) purchase.id: purchase,
    };
    final planById = {for (final plan in plans) plan.id: plan};
    final returnById = {for (final row in returns) row.id: row};
    final purchaseReturnById = {for (final row in purchaseReturns) row.id: row};
    final adjustmentById = {for (final row in adjustments) row.id: row};
    final openingBalanceIds = {for (final row in openingBalances) row.id};
    final financialCorrectionIds = {
      for (final row in financialCorrections) row.id,
    };
    final financialCorrectionReversalIds = {
      for (final row in financialCorrectionReversals) row.id,
    };
    final expenseIds = {for (final expense in expenses) expense.id};
    final productIds = {for (final product in products) product.id};
    final returnIds = returnById.keys.toSet();
    final purchaseReturnIds = purchaseReturnById.keys.toSet();
    final adjustmentIds = adjustmentById.keys.toSet();
    for (final entry in entries) {
      final referenceExists = switch (entry.referenceType) {
        'sale' || 'sale_cogs' => saleById.containsKey(entry.referenceId),
        'purchase' => purchaseById.containsKey(entry.referenceId),
        'sale_return' ||
        'sale_return_cogs' => returnIds.contains(entry.referenceId),
        'purchase_return' => purchaseReturnIds.contains(entry.referenceId),
        'installment_payment' => planById.containsKey(entry.referenceId),
        'expense' => expenseIds.contains(entry.referenceId),
        'opening_stock' => productIds.contains(entry.referenceId),
        'inventory_adjustment' => adjustmentIds.contains(entry.referenceId),
        'opening_balance' => openingBalanceIds.contains(entry.referenceId),
        'financial_correction' => financialCorrectionIds.contains(
          entry.referenceId,
        ),
        'financial_correction_reversal' =>
          financialCorrectionReversalIds.contains(entry.referenceId),
        _ => false,
      };
      if (!referenceExists) {
        issues.add(
          DataIntegrityIssue(
            code: 'ledger_reference',
            record: 'قيد #${entry.id}',
            message: 'مرجع القيد غير موجود أو نوعه غير معروف.',
          ),
        );
      }
    }

    _auditPartyPlanBalances();
  }

  void _auditPartyPlanBalances() {
    final expected = <String, int>{};
    for (final plan in plans) {
      final remaining = plan.totalMinor - plan.paidMinor;
      final key = '${plan.partyType}:${plan.partyId}';
      expected.update(
        key,
        (total) => total + remaining,
        ifAbsent: () => remaining,
      );
    }
    final actual = <String, int>{};
    for (final line in lines) {
      final partyType = line.partyType;
      final partyId = line.partyId;
      if ((partyType != 'customer' && partyType != 'supplier') ||
          partyId == null) {
        continue;
      }
      final expectedAccount = partyType == 'customer'
          ? AccountCodes.receivables
          : AccountCodes.payables;
      if (line.accountCode != expectedAccount) continue;
      final key = '$partyType:$partyId';
      actual.update(
        key,
        (total) => total + line.debitMinor - line.creditMinor,
        ifAbsent: () => line.debitMinor - line.creditMinor,
      );
    }
    for (final key in {...expected.keys, ...actual.keys}) {
      final expectedBalance = expected[key] ?? 0;
      final actualBalance = actual[key] ?? 0;
      final expectedLedger = key.startsWith('supplier:')
          ? -expectedBalance
          : expectedBalance;
      if (actualBalance != expectedLedger) {
        issues.add(
          DataIntegrityIssue(
            code: 'party_plan_balance',
            record: key,
            message: 'رصيد الطرف في الدفتر لا يطابق المتبقي في خطط الأقساط.',
          ),
        );
      }
    }
  }
}

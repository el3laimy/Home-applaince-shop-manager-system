part of '../v2_use_cases.dart';

extension V2ReportUseCaseHelpers on V2UseCases {
  Future<DailySummarySnapshot> _dailySummary(DateTime date) async {
    final start = _dayStart(date);
    final report = await _periodReport(
      start,
      start.add(const Duration(days: 1)),
    );
    return DailySummarySnapshot(
      date: start,
      salesMinor: report.salesMinor,
      cogsMinor: report.cogsMinor,
      expensesMinor: report.expensesMinor,
      inventoryVarianceMinor: report.inventoryVarianceMinor,
      financialVarianceMinor: report.financialVarianceMinor,
      interestMinor: report.interestMinor,
      cashNetMinor: report.cashNetMinor,
      walletNetMinor: report.walletNetMinor,
      purchaseMinor: report.purchaseMinor,
      saleCount: report.saleCount,
      purchaseCount: report.purchaseCount,
      returnCount: report.returnCount,
    );
  }

  Future<PeriodReportSnapshot> _periodReport(
    DateTime start,
    DateTime end,
  ) async {
    final salesMinor = -(await _accountNetBetween(
      AccountCodes.sales,
      start,
      end,
    ));
    final cogsMinor = await _accountNetBetween(AccountCodes.cogs, start, end);
    final expensesMinor = await _accountNetBetween(
      AccountCodes.expenses,
      start,
      end,
    );
    final inventoryVarianceMinor = await _accountNetBetween(
      AccountCodes.inventoryVariance,
      start,
      end,
    );
    final financialVarianceMinor = await _accountNetBetween(
      AccountCodes.financialVariance,
      start,
      end,
    );
    final interestMinor = -(await _accountNetBetween(
      AccountCodes.interestIncome,
      start,
      end,
    ));
    final purchaseMinor = await _accountNetBetween(
      AccountCodes.inventory,
      start,
      end,
      referenceType: 'purchase',
    );

    final saleCount =
        await (db.select(db.saleInvoices)..where(
              (sale) =>
                  sale.createdAt.isBiggerOrEqualValue(start) &
                  sale.createdAt.isSmallerThanValue(end),
            ))
            .get()
            .then((rows) => rows.length);
    final purchaseCount =
        await (db.select(db.purchaseInvoices)..where(
              (purchase) =>
                  purchase.createdAt.isBiggerOrEqualValue(start) &
                  purchase.createdAt.isSmallerThanValue(end),
            ))
            .get()
            .then((rows) => rows.length);
    final returnCount =
        await (db.select(db.saleReturns)..where(
              (saleReturn) =>
                  saleReturn.createdAt.isBiggerOrEqualValue(start) &
                  saleReturn.createdAt.isSmallerThanValue(end),
            ))
            .get()
            .then((rows) => rows.length);

    return PeriodReportSnapshot(
      start: start,
      end: end,
      salesMinor: salesMinor,
      cogsMinor: cogsMinor,
      expensesMinor: expensesMinor,
      inventoryVarianceMinor: inventoryVarianceMinor,
      financialVarianceMinor: financialVarianceMinor,
      interestMinor: interestMinor,
      cashNetMinor: await _accountNetBetween(AccountCodes.cash, start, end),
      walletNetMinor: await _accountNetBetween(AccountCodes.wallet, start, end),
      purchaseMinor: purchaseMinor,
      saleCount: saleCount,
      purchaseCount: purchaseCount,
      returnCount: returnCount,
    );
  }

  DateTime _dayStart(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  Future<List<InstallmentDuePreview>> _dueInstallments({
    required List<InstallmentPlan> plans,
    required List<Customer> customers,
    required List<Supplier> suppliers,
  }) async {
    final planById = {for (final plan in plans) plan.id: plan};
    if (planById.isEmpty) return const [];

    final customerNames = {
      for (final customer in customers) customer.id: customer.name,
    };
    final supplierNames = {
      for (final supplier in suppliers) supplier.id: supplier.name,
    };
    final now = clock();
    final horizon = now.add(const Duration(days: 7));
    final payments = await (db.select(
      db.installmentPayments,
    )..orderBy([(payment) => OrderingTerm(expression: payment.dueDate)])).get();

    return payments
        .where((payment) => payment.status != 'paid')
        .where((payment) => !payment.dueDate.isAfter(horizon))
        .where((payment) => planById.containsKey(payment.planId))
        .take(12)
        .map((payment) {
          final plan = planById[payment.planId]!;
          final names = plan.partyType == 'customer'
              ? customerNames
              : supplierNames;
          return InstallmentDuePreview(
            plan: plan,
            payment: payment,
            partyName: names[plan.partyId] ?? '#${plan.partyId}',
            remainingMinor: plan.totalMinor - plan.paidMinor,
            isOverdue: payment.dueDate.isBefore(
              DateTime(now.year, now.month, now.day),
            ),
          );
        })
        .toList();
  }

  Future<List<InstallmentPlanPreview>> _installmentSummaries({
    required List<InstallmentPlan> plans,
    required List<Customer> customers,
    required List<Supplier> suppliers,
  }) async {
    if (plans.isEmpty) return const [];

    final customerNames = {
      for (final customer in customers) customer.id: customer.name,
    };
    final supplierNames = {
      for (final supplier in suppliers) supplier.id: supplier.name,
    };
    final payments = await (db.select(
      db.installmentPayments,
    )..orderBy([(payment) => OrderingTerm.asc(payment.dueDate)])).get();
    final paymentsByPlan = <int, List<InstallmentPayment>>{};
    for (final payment in payments) {
      paymentsByPlan.putIfAbsent(payment.planId, () => []).add(payment);
    }

    final today = _dayStart(clock());
    final horizon = today.add(const Duration(days: 8));
    final previews = <InstallmentPlanPreview>[];

    for (final plan in plans) {
      final schedule = paymentsByPlan[plan.id] ?? const <InstallmentPayment>[];
      var paidRemainder = plan.paidMinor;
      var overdueMinor = 0;
      var dueSoonMinor = 0;
      var nextDueMinor = 0;
      DateTime? nextDueDate;
      final schedulePreview = <InstallmentSchedulePreview>[];

      for (final payment in schedule) {
        final allocated = paidRemainder <= 0
            ? 0
            : paidRemainder > payment.amountMinor
            ? payment.amountMinor
            : paidRemainder;
        final unpaid = payment.amountMinor - allocated;
        paidRemainder -= allocated;
        final isOverdue = unpaid > 0 && payment.dueDate.isBefore(today);
        final isDueSoon =
            unpaid > 0 &&
            !payment.dueDate.isBefore(today) &&
            payment.dueDate.isBefore(horizon);
        schedulePreview.add(
          InstallmentSchedulePreview(
            payment: payment,
            paidMinor: allocated,
            remainingMinor: unpaid,
            isOverdue: isOverdue,
            isDueSoon: isDueSoon,
          ),
        );
        if (unpaid == 0) continue;

        if (isOverdue) {
          overdueMinor += unpaid;
        }
        if (isDueSoon) {
          dueSoonMinor += unpaid;
        }
        if (nextDueDate == null || payment.dueDate.isBefore(nextDueDate)) {
          nextDueDate = payment.dueDate;
          nextDueMinor = unpaid;
        }
      }

      final names = plan.partyType == 'customer'
          ? customerNames
          : supplierNames;
      previews.add(
        InstallmentPlanPreview(
          plan: plan,
          partyName: names[plan.partyId] ?? '#${plan.partyId}',
          remainingMinor: plan.totalMinor - plan.paidMinor,
          overdueMinor: overdueMinor,
          dueSoonMinor: dueSoonMinor,
          nextDueMinor: nextDueMinor,
          schedule: schedulePreview,
          nextDueDate: nextDueDate,
        ),
      );
    }

    previews.sort((a, b) {
      if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
      final aDate = a.nextDueDate ?? DateTime(9999);
      final bDate = b.nextDueDate ?? DateTime(9999);
      return aDate.compareTo(bDate);
    });
    return previews;
  }

  Future<List<PartyBalance>> _partyBalances({
    required String partyType,
    required String accountCode,
    required Map<int, String> names,
    required Map<int, String?> phones,
  }) async {
    final balances = <int, int>{};
    final rows = await db
        .customSelect(
          '''
          SELECT party_id, COALESCE(SUM(debit_minor - credit_minor), 0) AS net
          FROM ledger_lines
          WHERE account_code = ? AND party_type = ? AND party_id IS NOT NULL
          GROUP BY party_id
          ''',
          variables: [
            Variable<String>(accountCode),
            Variable<String>(partyType),
          ],
          readsFrom: {db.ledgerLines},
        )
        .get();
    for (final row in rows) {
      balances[row.data['party_id'] as int] = row.data['net'] as int;
    }
    return names.entries
        .map(
          (entry) => PartyBalance(
            id: entry.key,
            name: entry.value,
            type: partyType,
            balanceMinor: balances[entry.key] ?? 0,
            phone: phones[entry.key],
          ),
        )
        .toList()
      ..sort((a, b) => b.balanceMinor.abs().compareTo(a.balanceMinor.abs()));
  }

  Future<List<LedgerEntryPreview>> _recentLedgerEntries() async {
    final entries =
        await (db.select(db.ledgerEntries)
              ..orderBy([
                (entry) => OrderingTerm(
                  expression: entry.createdAt,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(14))
            .get();
    final previews = <LedgerEntryPreview>[];
    for (final entry in entries) {
      final lines = await (db.select(
        db.ledgerLines,
      )..where((line) => line.entryId.equals(entry.id))).get();
      previews.add(
        LedgerEntryPreview(
          entry: entry,
          debitMinor: lines.fold(0, (sum, line) => sum + line.debitMinor),
          creditMinor: lines.fold(0, (sum, line) => sum + line.creditMinor),
        ),
      );
    }
    return previews;
  }
}

part of '../v2_use_cases.dart';

/// Conservative, read-only consistency checks for a shop's existing history.
///
/// The audit deliberately reports instead of repairing. Correcting a prior
/// operation needs an explicit documented adjustment, not a silent rewrite.
extension V2IntegrityAuditUseCases on V2UseCases {
  Future<DataIntegrityAudit> dataIntegrityAudit() => db.transaction(() async {
    final entries = await db.select(db.ledgerEntries).get();
    final lines = await db.select(db.ledgerLines).get();
    final products = await db.select(db.products).get();
    final movements = await db.select(db.stockMovements).get();
    final adjustments = await db.select(db.inventoryAdjustments).get();
    final openingBalances = await db.select(db.openingBalances).get();
    final customers = await db.select(db.customers).get();
    final suppliers = await db.select(db.suppliers).get();
    final plans = await db.select(db.installmentPlans).get();
    final scheduled = await db.select(db.installmentPayments).get();
    final sales = await db.select(db.saleInvoices).get();
    final saleItems = await db.select(db.saleItems).get();
    final purchases = await db.select(db.purchaseInvoices).get();
    final purchaseItems = await db.select(db.purchaseItems).get();
    final payments = await db.select(db.payments).get();
    final returns = await db.select(db.saleReturns).get();
    final returnItems = await db.select(db.saleReturnItems).get();
    final expenses = await db.select(db.expenses).get();
    final issues = <DataIntegrityIssue>[];

    final entryById = {for (final entry in entries) entry.id: entry};
    final linesByEntry = _groupByInt(lines, (line) => line.entryId);
    for (final entry in entries) {
      final entryLines = linesByEntry[entry.id] ?? const <LedgerLine>[];
      final debit = entryLines.fold<int>(
        0,
        (total, line) => total + line.debitMinor,
      );
      final credit = entryLines.fold<int>(
        0,
        (total, line) => total + line.creditMinor,
      );
      if (entryLines.isEmpty || debit == 0 || debit != credit) {
        issues.add(
          DataIntegrityIssue(
            code: 'ledger_unbalanced',
            record: 'قيد #${entry.id}',
            message: 'القيد غير متزن أو لا يحتوي على سطور محاسبية.',
          ),
        );
      }
    }
    for (final line in lines) {
      if (!entryById.containsKey(line.entryId)) {
        issues.add(
          DataIntegrityIssue(
            code: 'ledger_orphan_line',
            record: 'سطر دفتر #${line.id}',
            message: 'سطر الدفتر غير مرتبط بقيد رئيسي.',
          ),
        );
      }
    }

    final movementsByProduct = _groupByInt(
      movements,
      (movement) => movement.productId,
    );
    for (final product in products) {
      final productMovements = [...(movementsByProduct[product.id] ?? const [])]
        // The auto-increment id is the committed movement sequence. A device
        // clock can move backwards and must not make a healthy chain look
        // corrupt.
        ..sort((left, right) => left.id.compareTo(right.id));
      if (productMovements.isEmpty) {
        if (product.stockQty != 0) {
          issues.add(
            DataIntegrityIssue(
              code: 'stock_untracked_balance',
              record: 'الصنف ${product.name}',
              message: 'رصيد الصنف موجود بلا حركة مخزون مرجعية قابلة للمطابقة.',
            ),
          );
        }
        continue;
      }
      var expected =
          productMovements.first.balanceAfter - productMovements.first.qtyDelta;
      for (final movement in productMovements) {
        expected += movement.qtyDelta;
        if (expected != movement.balanceAfter) {
          issues.add(
            DataIntegrityIssue(
              code: 'stock_movement_chain',
              record: 'حركة مخزون #${movement.id}',
              message: 'رصيد الحركة لا يطابق الرصيد الناتج من الحركة السابقة.',
            ),
          );
        }
      }
      if (expected != product.stockQty) {
        issues.add(
          DataIntegrityIssue(
            code: 'stock_current_balance',
            record: 'الصنف ${product.name}',
            message: 'رصيد الصنف الحالي لا يطابق سلسلة حركات المخزون.',
          ),
        );
      }
    }

    final productById = {for (final product in products) product.id: product};
    final adjustmentById = {
      for (final adjustment in adjustments) adjustment.id: adjustment,
    };
    final adjustmentReasonNames = InventoryAdjustmentReason.values
        .map((reason) => reason.name)
        .toSet();
    for (final adjustment in adjustments) {
      final delta = adjustment.countedQty - adjustment.previousQty;
      final matchingMovements = movements
          .where(
            (movement) =>
                movement.referenceType == 'inventory_adjustment' &&
                movement.referenceId == adjustment.id,
          )
          .toList();
      final matchingMovement = matchingMovements.length == 1
          ? matchingMovements.single
          : null;
      if (!productById.containsKey(adjustment.productId) ||
          adjustment.previousQty < 0 ||
          adjustment.countedQty < 0 ||
          adjustment.unitCostMinor <= 0 ||
          adjustment.valueDeltaMinor != delta * adjustment.unitCostMinor ||
          !adjustmentReasonNames.contains(adjustment.reason)) {
        issues.add(
          DataIntegrityIssue(
            code: 'inventory_adjustment_data',
            record: 'تسوية مخزون #${adjustment.id}',
            message: 'بيانات تسوية المخزون أو تكلفتها أو سببها غير متسقة.',
          ),
        );
      }
      if (matchingMovement == null ||
          matchingMovement.productId != adjustment.productId ||
          matchingMovement.qtyDelta != delta ||
          matchingMovement.balanceAfter != adjustment.countedQty) {
        issues.add(
          DataIntegrityIssue(
            code: 'inventory_adjustment_movement',
            record: 'تسوية مخزون #${adjustment.id}',
            message: 'تسوية المخزون لا تطابق حركة المخزون المرجعية.',
          ),
        );
      }
      final matchingEntries = entries
          .where(
            (entry) =>
                entry.referenceType == 'inventory_adjustment' &&
                entry.referenceId == adjustment.id,
          )
          .toList();
      final adjustmentEntry = matchingEntries.length == 1
          ? matchingEntries.single
          : null;
      final adjustmentLines = adjustmentEntry == null
          ? const <LedgerLine>[]
          : linesByEntry[adjustmentEntry.id] ?? const <LedgerLine>[];
      final inventoryNet = adjustmentLines
          .where((line) => line.accountCode == AccountCodes.inventory)
          .fold<int>(
            0,
            (total, line) => total + line.debitMinor - line.creditMinor,
          );
      final varianceNet = adjustmentLines
          .where((line) => line.accountCode == AccountCodes.inventoryVariance)
          .fold<int>(
            0,
            (total, line) => total + line.debitMinor - line.creditMinor,
          );
      if (adjustmentEntry == null ||
          adjustmentLines.length != 2 ||
          inventoryNet != adjustment.valueDeltaMinor ||
          varianceNet != -adjustment.valueDeltaMinor) {
        issues.add(
          DataIntegrityIssue(
            code: 'inventory_adjustment_ledger',
            record: 'تسوية مخزون #${adjustment.id}',
            message: 'قيد فرق الجرد مفقود أو لا يطابق قيمة التسوية.',
          ),
        );
      }
    }
    for (final movement in movements.where(
      (movement) => movement.referenceType == 'inventory_adjustment',
    )) {
      if (!adjustmentById.containsKey(movement.referenceId)) {
        issues.add(
          DataIntegrityIssue(
            code: 'inventory_adjustment_orphan_movement',
            record: 'حركة مخزون #${movement.id}',
            message: 'حركة فرق الجرد غير مرتبطة بمستند تسوية موجود.',
          ),
        );
      }
    }

    final planById = {for (final plan in plans) plan.id: plan};
    final scheduledByPlan = _groupByInt(scheduled, (payment) => payment.planId);
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

    final saleById = {for (final sale in sales) sale.id: sale};
    final saleItemsBySale = _groupByInt(saleItems, (item) => item.saleId);
    final purchaseById = {
      for (final purchase in purchases) purchase.id: purchase,
    };
    final purchaseItemsByPurchase = _groupByInt(
      purchaseItems,
      (item) => item.purchaseId,
    );
    final paymentsByOwner = <String, List<Payment>>{};
    for (final payment in payments) {
      paymentsByOwner
          .putIfAbsent('${payment.ownerType}:${payment.ownerId}', () => [])
          .add(payment);
    }
    for (final sale in sales) {
      final itemTotal = (saleItemsBySale[sale.id] ?? const <SaleItem>[])
          .fold<int>(0, (total, item) => total + item.lineTotalMinor);
      final paymentTotal =
          (paymentsByOwner['sale:${sale.id}'] ?? const <Payment>[]).fold<int>(
            0,
            (total, payment) => total + payment.amountMinor,
          );
      if (itemTotal != sale.subtotalMinor ||
          paymentTotal != sale.paidMinor ||
          sale.totalMinor != sale.paidMinor + sale.remainingMinor) {
        issues.add(
          DataIntegrityIssue(
            code: 'sale_totals',
            record: 'فاتورة البيع ${sale.invoiceNo}',
            message: 'إجمالي الفاتورة أو مدفوعاتها لا يطابق بنودها المحفوظة.',
          ),
        );
      }
    }
    for (final purchase in purchases) {
      final itemTotal =
          (purchaseItemsByPurchase[purchase.id] ?? const <PurchaseItem>[])
              .fold<int>(0, (total, item) => total + item.lineTotalMinor);
      final paymentTotal =
          (paymentsByOwner['purchase:${purchase.id}'] ?? const <Payment>[])
              .fold<int>(0, (total, payment) => total + payment.amountMinor);
      if (itemTotal != purchase.totalMinor ||
          paymentTotal != purchase.paidMinor ||
          purchase.totalMinor != purchase.paidMinor + purchase.remainingMinor) {
        issues.add(
          DataIntegrityIssue(
            code: 'purchase_totals',
            record: 'فاتورة الشراء ${purchase.invoiceNo}',
            message: 'إجمالي فاتورة الشراء أو مدفوعاتها لا يطابق بنودها.',
          ),
        );
      }
    }

    for (final payment in payments) {
      final isKnownOwner = switch (payment.ownerType) {
        'sale' => saleById.containsKey(payment.ownerId),
        'purchase' => purchaseById.containsKey(payment.ownerId),
        'installment_plan' => planById.containsKey(payment.ownerId),
        _ => false,
      };
      if (!isKnownOwner) {
        issues.add(
          DataIntegrityIssue(
            code: 'payment_orphan_owner',
            record: 'مدفوع #${payment.id}',
            message: 'المدفوع غير مرتبط بمستند أو خطة معروفة.',
          ),
        );
      }
    }

    final returnById = {
      for (final saleReturn in returns) saleReturn.id: saleReturn,
    };
    final saleItemById = {for (final item in saleItems) item.id: item};
    final returnTotalById = <int, int>{};
    final returnedQtyBySaleItem = <int, int>{};
    for (final item in returnItems) {
      final saleReturn = returnById[item.returnId];
      final saleItem = saleItemById[item.saleItemId];
      if (saleReturn == null ||
          saleItem == null ||
          saleItem.saleId != saleReturn.saleId ||
          saleItem.productId != item.productId) {
        issues.add(
          DataIntegrityIssue(
            code: 'return_item_link',
            record: 'سطر مرتجع #${item.id}',
            message: 'سطر المرتجع لا يطابق فاتورة البيع أو الصنف الأصلي.',
          ),
        );
      }
      returnTotalById.update(
        item.returnId,
        (total) => total + item.qty * item.unitPriceMinor,
        ifAbsent: () => item.qty * item.unitPriceMinor,
      );
      returnedQtyBySaleItem.update(
        item.saleItemId,
        (total) => total + item.qty,
        ifAbsent: () => item.qty,
      );
    }
    for (final saleReturn in returns) {
      if (!saleById.containsKey(saleReturn.saleId) ||
          returnTotalById[saleReturn.id] != saleReturn.refundMinor) {
        issues.add(
          DataIntegrityIssue(
            code: 'return_total',
            record: 'مرتجع ${saleReturn.returnNo}',
            message: 'إجمالي المرتجع لا يطابق بنوده أو فاتورة البيع الأصلية.',
          ),
        );
      }
    }
    for (final entry in returnedQtyBySaleItem.entries) {
      final item = saleItemById[entry.key];
      if (item != null && entry.value > item.qty) {
        issues.add(
          DataIntegrityIssue(
            code: 'return_quantity',
            record: 'سطر البيع #${entry.key}',
            message: 'كمية المرتجعات أكبر من كمية البيع الأصلية.',
          ),
        );
      }
    }

    final expenseIds = {for (final expense in expenses) expense.id};
    final productIds = {for (final product in products) product.id};
    final returnIds = returnById.keys.toSet();
    final adjustmentIds = adjustmentById.keys.toSet();
    for (final entry in entries) {
      final referenceExists = switch (entry.referenceType) {
        'sale' || 'sale_cogs' => saleById.containsKey(entry.referenceId),
        'purchase' => purchaseById.containsKey(entry.referenceId),
        'sale_return' ||
        'sale_return_cogs' => returnIds.contains(entry.referenceId),
        'installment_payment' => planById.containsKey(entry.referenceId),
        'expense' => expenseIds.contains(entry.referenceId),
        'opening_stock' => productIds.contains(entry.referenceId),
        'inventory_adjustment' => adjustmentIds.contains(entry.referenceId),
        'opening_balance' => openingBalanceIds.contains(entry.referenceId),
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

    _auditPartyPlanBalances(plans, lines, issues);
    return DataIntegrityAudit(
      checkedAt: clock(),
      ledgerEntryCount: entries.length,
      productCount: products.length,
      installmentPlanCount: plans.length,
      issues: List.unmodifiable(issues),
    );
  });

  void _auditPartyPlanBalances(
    List<InstallmentPlan> plans,
    List<LedgerLine> lines,
    List<DataIntegrityIssue> issues,
  ) {
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

  Map<int, List<T>> _groupByInt<T>(
    Iterable<T> rows,
    int Function(T row) keyOf,
  ) {
    final grouped = <int, List<T>>{};
    for (final row in rows) {
      grouped.putIfAbsent(keyOf(row), () => []).add(row);
    }
    return grouped;
  }
}

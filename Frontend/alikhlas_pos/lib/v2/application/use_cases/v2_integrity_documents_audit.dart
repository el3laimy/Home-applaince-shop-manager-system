part of '../v2_use_cases.dart';

extension _IntegrityDocumentsAudit on _IntegrityAuditContext {
  void auditInvoicesAndReturns() {
    final planById = {for (final plan in plans) plan.id: plan};
    final linesByEntry = _groupIntegrityRows(lines, (line) => line.entryId);
    final saleById = {for (final sale in sales) sale.id: sale};
    final saleItemsBySale = _groupIntegrityRows(
      saleItems,
      (item) => item.saleId,
    );
    final purchaseById = {
      for (final purchase in purchases) purchase.id: purchase,
    };
    final purchaseItemsByPurchase = _groupIntegrityRows(
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

    final purchaseReturnById = {
      for (final purchaseReturn in purchaseReturns)
        purchaseReturn.id: purchaseReturn,
    };
    final purchaseItemById = {
      for (final purchaseItem in purchaseItems) purchaseItem.id: purchaseItem,
    };
    final creditTotalByPurchaseReturn = <int, int>{};
    final inventoryValueByPurchaseReturn = <int, int>{};
    final returnedQtyByPurchaseItem = <int, int>{};
    final expectedMovementsByReturnProduct =
        <String, ({int returnId, int productId, int qty, int itemCount})>{};
    for (final item in purchaseReturnItems) {
      final purchaseReturn = purchaseReturnById[item.returnId];
      final purchaseItem = purchaseItemById[item.purchaseItemId];
      if (purchaseReturn == null ||
          purchaseItem == null ||
          purchaseItem.purchaseId != purchaseReturn.purchaseId ||
          purchaseItem.productId != item.productId ||
          purchaseItem.unitCostMinor != item.unitCostMinor ||
          item.qty <= 0 ||
          item.inventoryUnitCostMinor < 0) {
        issues.add(
          DataIntegrityIssue(
            code: 'purchase_return_item_link',
            record: 'سطر مرتجع شراء #${item.id}',
            message:
                'سطر مرتجع الشراء لا يطابق فاتورة الشراء أو تكلفته الأصلية.',
          ),
        );
      }
      creditTotalByPurchaseReturn.update(
        item.returnId,
        (total) => total + item.qty * item.unitCostMinor,
        ifAbsent: () => item.qty * item.unitCostMinor,
      );
      inventoryValueByPurchaseReturn.update(
        item.returnId,
        (total) => total + item.qty * item.inventoryUnitCostMinor,
        ifAbsent: () => item.qty * item.inventoryUnitCostMinor,
      );
      returnedQtyByPurchaseItem.update(
        item.purchaseItemId,
        (total) => total + item.qty,
        ifAbsent: () => item.qty,
      );
      final movementKey = '${item.returnId}:${item.productId}';
      final expectedMovement = expectedMovementsByReturnProduct[movementKey];
      expectedMovementsByReturnProduct[movementKey] = (
        returnId: item.returnId,
        productId: item.productId,
        qty: (expectedMovement?.qty ?? 0) + item.qty,
        itemCount: (expectedMovement?.itemCount ?? 0) + 1,
      );
    }
    for (final expectedMovement in expectedMovementsByReturnProduct.values) {
      final matchingMovements = movements
          .where(
            (movement) =>
                movement.referenceType == 'purchase_return' &&
                movement.referenceId == expectedMovement.returnId &&
                movement.productId == expectedMovement.productId,
          )
          .toList();
      final movementQty = matchingMovements.fold<int>(
        0,
        (total, movement) => total + movement.qtyDelta,
      );
      if (matchingMovements.length != expectedMovement.itemCount ||
          movementQty != -expectedMovement.qty) {
        issues.add(
          DataIntegrityIssue(
            code: 'purchase_return_movement',
            record: 'مرتجع شراء #${expectedMovement.returnId}',
            message: 'مرتجع الشراء لا يطابق حركة المخزون المرجعية.',
          ),
        );
      }
    }
    for (final purchaseReturn in purchaseReturns) {
      final purchase = purchaseById[purchaseReturn.purchaseId];
      final credit = creditTotalByPurchaseReturn[purchaseReturn.id];
      final inventoryValue = inventoryValueByPurchaseReturn[purchaseReturn.id];
      if (purchase == null ||
          credit == null ||
          inventoryValue == null ||
          credit != purchaseReturn.creditMinor ||
          credit <= 0) {
        issues.add(
          DataIntegrityIssue(
            code: 'purchase_return_total',
            record: 'مرتجع شراء ${purchaseReturn.returnNo}',
            message: 'إجمالي مرتجع الشراء لا يطابق بنوده أو فاتورته الأصلية.',
          ),
        );
      }

      final matchingEntries = entries
          .where(
            (entry) =>
                entry.referenceType == 'purchase_return' &&
                entry.referenceId == purchaseReturn.id,
          )
          .toList();
      final purchaseReturnEntry = matchingEntries.length == 1
          ? matchingEntries.single
          : null;
      final purchaseReturnLines = purchaseReturnEntry == null
          ? const <LedgerLine>[]
          : linesByEntry[purchaseReturnEntry.id] ?? const <LedgerLine>[];
      final inventoryNet = purchaseReturnLines
          .where((line) => line.accountCode == AccountCodes.inventory)
          .fold<int>(
            0,
            (total, line) => total + line.debitMinor - line.creditMinor,
          );
      final varianceNet = purchaseReturnLines
          .where((line) => line.accountCode == AccountCodes.inventoryVariance)
          .fold<int>(
            0,
            (total, line) => total + line.debitMinor - line.creditMinor,
          );
      final supplierPayableDebit = purchaseReturnLines
          .where(
            (line) =>
                line.accountCode == AccountCodes.payables &&
                line.partyType == 'supplier' &&
                line.partyId == purchase?.supplierId,
          )
          .fold<int>(0, (total, line) => total + line.debitMinor);
      final liquidDebit = purchaseReturnLines
          .where(
            (line) =>
                line.accountCode == AccountCodes.cash ||
                line.accountCode == AccountCodes.wallet,
          )
          .fold<int>(0, (total, line) => total + line.debitMinor);
      final containsOnlyExpectedAccounts = purchaseReturnLines.every(
        (line) =>
            line.accountCode == AccountCodes.inventory ||
            line.accountCode == AccountCodes.inventoryVariance ||
            line.accountCode == AccountCodes.payables ||
            line.accountCode == AccountCodes.cash ||
            line.accountCode == AccountCodes.wallet,
      );
      final ledgerIsValid =
          purchase != null &&
          credit != null &&
          inventoryValue != null &&
          purchaseReturnEntry != null &&
          containsOnlyExpectedAccounts &&
          inventoryNet == -inventoryValue &&
          varianceNet == inventoryValue - credit &&
          supplierPayableDebit + liquidDebit == credit;
      if (!ledgerIsValid) {
        issues.add(
          DataIntegrityIssue(
            code: 'purchase_return_ledger',
            record: 'مرتجع شراء ${purchaseReturn.returnNo}',
            message: 'قيد مرتجع الشراء مفقود أو لا يطابق قيمة المورد والمخزون.',
          ),
        );
      }
    }
    for (final entry in returnedQtyByPurchaseItem.entries) {
      final item = purchaseItemById[entry.key];
      if (item != null && entry.value > item.qty) {
        issues.add(
          DataIntegrityIssue(
            code: 'purchase_return_quantity',
            record: 'سطر الشراء #${entry.key}',
            message: 'كمية مرتجع الشراء أكبر من كمية الشراء الأصلية.',
          ),
        );
      }
    }
    for (final movement in movements.where(
      (movement) => movement.referenceType == 'purchase_return',
    )) {
      if (!purchaseReturnById.containsKey(movement.referenceId)) {
        issues.add(
          DataIntegrityIssue(
            code: 'purchase_return_orphan_movement',
            record: 'حركة مخزون #${movement.id}',
            message: 'حركة مرتجع الشراء لا ترتبط بمستند مرتجع موجود.',
          ),
        );
      }
    }
  }
}

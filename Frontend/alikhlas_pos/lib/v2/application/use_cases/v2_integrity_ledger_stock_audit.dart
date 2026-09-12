part of '../v2_use_cases.dart';

extension _IntegrityLedgerStockAudit on _IntegrityAuditContext {
  void auditLedgerStockAndAdjustments() {
    final entryById = {for (final entry in entries) entry.id: entry};
    final linesByEntry = _groupIntegrityRows(lines, (line) => line.entryId);
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

    final movementsByProduct = _groupIntegrityRows(
      movements,
      (movement) => movement.productId,
    );
    var productInventoryValue = 0;
    for (final product in products) {
      productInventoryValue += product.inventoryValueMinor;
      if (product.inventoryValueMinor < 0 ||
          (product.stockQty == 0 && product.inventoryValueMinor != 0)) {
        issues.add(
          DataIntegrityIssue(
            code: 'inventory_product_value',
            record: 'الصنف ${product.name}',
            message: 'قيمة المخزون لا تتفق مع رصيد الصنف الحالي.',
          ),
        );
      }
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

    final ledgerInventoryValue = lines
        .where((line) => line.accountCode == AccountCodes.inventory)
        .fold<int>(0, (sum, line) => sum + line.debitMinor - line.creditMinor);
    if (productInventoryValue != ledgerInventoryValue) {
      issues.add(
        DataIntegrityIssue(
          code: 'inventory_ledger_reconciliation',
          record: 'قيمة المخزون',
          message: 'قيمة أرصدة الأصناف لا تطابق حساب المخزون في دفتر الأستاذ.',
        ),
      );
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
          adjustment.valueDeltaMinor == 0 ||
          adjustment.valueDeltaMinor.sign != delta.sign ||
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
  }
}

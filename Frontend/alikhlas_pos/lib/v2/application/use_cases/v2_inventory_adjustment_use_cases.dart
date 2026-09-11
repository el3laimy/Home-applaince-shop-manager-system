part of '../v2_use_cases.dart';

extension V2InventoryAdjustmentUseCases on V2UseCases {
  String newInventoryAdjustmentOperationKey() => newFinancialOperationKey();

  Future<AppResult<int>> reconcileInventory({
    String? operationKey,
    required int productId,
    required int expectedStockQty,
    required int countedQty,
    required InventoryAdjustmentReason reason,
    String? note,
    required int unitCostMinor,
  }) {
    if (operationKey == null) {
      return Future.value(
        const AppFailure<int>('معرّف عملية الجرد مطلوب لمنع تكرار التسوية.'),
      );
    }
    final cleanNote = _blankToNull(note);
    return _runIdempotentFinancialOperation(
      namespace: 'inventory_adjustment',
      operationKey: operationKey,
      fingerprintPayload: [
        productId,
        expectedStockQty,
        countedQty,
        reason.name,
        cleanNote,
        unitCostMinor,
      ],
      conflictMessage:
          'عملية الجرد محفوظة ببيانات مختلفة. راجع حركة المخزون قبل المحاولة.',
      execute: () => _reconcileInventory(
        productId: productId,
        expectedStockQty: expectedStockQty,
        countedQty: countedQty,
        reason: reason,
        note: cleanNote,
        unitCostMinor: unitCostMinor,
      ),
    );
  }

  Future<AppResult<int>> _reconcileInventory({
    required int productId,
    required int expectedStockQty,
    required int countedQty,
    required InventoryAdjustmentReason reason,
    required String? note,
    required int unitCostMinor,
  }) async {
    if (productId < 1 ||
        expectedStockQty < 0 ||
        countedQty < 0 ||
        countedQty > 1000000) {
      return const AppFailure<int>(
        'الكمية الفعلية يجب أن تكون رقمًا من صفر إلى 1000000.',
      );
    }
    if (unitCostMinor <= 0) {
      return const AppFailure<int>('تكلفة الوحدة يجب أن تكون أكبر من صفر.');
    }
    if (reason == InventoryAdjustmentReason.dataCorrection && note == null) {
      return const AppFailure<int>('اكتب توضيحًا عند اختيار تصحيح إدخال.');
    }

    return _writeTransaction(() async {
      final product = await (db.select(
        db.products,
      )..where((row) => row.id.equals(productId))).getSingleOrNull();
      if (product == null) {
        return const AppFailure<int>(
          'الصنف غير موجود. حدّث الشاشة وحاول مرة أخرى.',
        );
      }
      if (product.stockQty != expectedStockQty) {
        return const AppFailure<int>(
          'تغير رصيد الصنف بعد فتح الجرد. حدّث الشاشة وأعد عدّ الصنف.',
        );
      }
      if (product.stockQty == countedQty) {
        return const AppFailure<int>(
          'الكمية الفعلية تساوي الرصيد الحالي؛ لا يوجد فرق لتسجيله.',
        );
      }

      if (product.avgCostMinor > 0 && product.avgCostMinor != unitCostMinor) {
        return const AppFailure<int>(
          'تغير متوسط تكلفة الصنف بعد فتح الجرد. حدّث الشاشة وحاول مرة أخرى.',
        );
      }

      final qtyDelta = countedQty - product.stockQty;
      final valueDeltaMinor = qtyDelta > 0
          ? qtyDelta * unitCostMinor
          : -_allocateInventoryValue(
              inventoryValueMinor: product.inventoryValueMinor,
              stockQty: product.stockQty,
              qty: -qtyDelta,
            );
      final newInventoryValue = product.inventoryValueMinor + valueDeltaMinor;
      final now = clock();
      final adjustmentId = await db
          .into(db.inventoryAdjustments)
          .insert(
            InventoryAdjustmentsCompanion.insert(
              productId: product.id,
              previousQty: product.stockQty,
              countedQty: countedQty,
              unitCostMinor: unitCostMinor,
              valueDeltaMinor: valueDeltaMinor,
              reason: reason.name,
              note: Value(note),
              createdAt: Value(now),
            ),
          );

      await (db.update(
        db.products,
      )..where((row) => row.id.equals(product.id))).write(
        ProductsCompanion(
          stockQty: Value(countedQty),
          avgCostMinor: Value(
            _roundedAverageCost(newInventoryValue, countedQty),
          ),
          inventoryValueMinor: Value(newInventoryValue),
          updatedAt: Value(now),
        ),
      );
      await db
          .into(db.stockMovements)
          .insert(
            StockMovementsCompanion.insert(
              productId: product.id,
              type: 'inventory_adjustment',
              qtyDelta: qtyDelta,
              balanceAfter: countedQty,
              referenceType: 'inventory_adjustment',
              referenceId: adjustmentId,
              createdAt: Value(now),
            ),
          );

      final value = valueDeltaMinor.abs();
      await _postLedger(
        referenceType: 'inventory_adjustment',
        referenceId: adjustmentId,
        description:
            'فرق جرد ${product.name}: ${reason.label}${note == null ? '' : ' — $note'}',
        lines: valueDeltaMinor > 0
            ? [
                _LedgerLineDraft(AccountCodes.inventory, debitMinor: value),
                _LedgerLineDraft(
                  AccountCodes.inventoryVariance,
                  creditMinor: value,
                ),
              ]
            : [
                _LedgerLineDraft(
                  AccountCodes.inventoryVariance,
                  debitMinor: value,
                ),
                _LedgerLineDraft(AccountCodes.inventory, creditMinor: value),
              ],
      );
      return AppSuccess<int>(adjustmentId);
    });
  }
}

part of '../v2_use_cases.dart';

extension V2PurchaseReturnUseCases on V2UseCases {
  String newPurchaseReturnOperationKey() => newFinancialOperationKey();

  Future<AppResult<int>> createPurchaseReturn({
    String? operationKey,
    required int purchaseId,
    required Map<int, int> purchaseItemQuantities,
    required PaymentMethod settlementMethod,
    PaymentMethod? overflowRefundMethod,
  }) async {
    if (operationKey == null) {
      return const AppFailure<int>(
        'معرّف عملية مرتجع الشراء مطلوب لمنع رد المخزون أو قيمة المورد مرتين.',
      );
    }
    final quantities = Map<int, int>.unmodifiable(purchaseItemQuantities);
    final orderedQuantities = quantities.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    return _runIdempotentFinancialOperation(
      namespace: 'purchase_return',
      operationKey: operationKey,
      fingerprintPayload: [
        purchaseId,
        [
          for (final item in orderedQuantities) [item.key, item.value],
        ],
        settlementMethod.name,
        overflowRefundMethod?.name,
      ],
      conflictMessage:
          'مرتجع الشراء محفوظ ببيانات مختلفة. راجع سجل مشتريات المورد.',
      execute: () => _createPurchaseReturn(
        purchaseId: purchaseId,
        purchaseItemQuantities: quantities,
        settlementMethod: settlementMethod,
        overflowRefundMethod: overflowRefundMethod,
      ),
    );
  }

  Future<AppResult<int>> _createPurchaseReturn({
    required int purchaseId,
    required Map<int, int> purchaseItemQuantities,
    required PaymentMethod settlementMethod,
    required PaymentMethod? overflowRefundMethod,
  }) async {
    if (purchaseItemQuantities.isEmpty) {
      return const AppFailure('اختر صنفًا واحدًا على الأقل لمرتجع الشراء');
    }
    if (overflowRefundMethod == PaymentMethod.installment) {
      return const AppFailure('فائض رصيد المورد يرد كاش أو محفظة فقط');
    }

    final shift = await currentShift();
    if (settlementMethod == PaymentMethod.cash && shift == null) {
      return const AppFailure('افتح وردية قبل استلام مرتجع شراء كاش');
    }

    try {
      final returnId = await _writeTransaction(() async {
        final purchase = await (db.select(
          db.purchaseInvoices,
        )..where((invoice) => invoice.id.equals(purchaseId))).getSingleOrNull();
        if (purchase == null) throw _BusinessError('فاتورة الشراء غير موجودة');
        if (settlementMethod == PaymentMethod.installment &&
            purchase.supplierId == null) {
          throw _BusinessError('رصيد المورد يحتاج فاتورة شراء مرتبطة بمورد');
        }

        var supplierCredit = 0;
        var inventoryValue = 0;
        final productBalances = <int, int>{};
        final productValues = <int, int>{};
        final returnLines =
            <
              ({
                Product product,
                PurchaseItem purchaseItem,
                int qty,
                int inventoryUnitCostMinor,
                int balanceAfter,
              })
            >[];

        for (final entry in purchaseItemQuantities.entries) {
          final purchaseItem = await (db.select(
            db.purchaseItems,
          )..where((item) => item.id.equals(entry.key))).getSingleOrNull();
          if (purchaseItem == null || purchaseItem.purchaseId != purchaseId) {
            throw _BusinessError('سطر مرتجع الشراء غير صالح');
          }
          final qty = entry.value;
          final priorReturns =
              await (db.select(db.purchaseReturnItems)..where(
                    (item) => item.purchaseItemId.equals(purchaseItem.id),
                  ))
                  .get();
          final alreadyReturned = priorReturns.fold<int>(
            0,
            (total, item) => total + item.qty,
          );
          final returnableQty = purchaseItem.qty - alreadyReturned;
          if (qty <= 0 || qty > returnableQty) {
            throw _BusinessError('كمية مرتجع الشراء غير صحيحة');
          }

          final product =
              await (db.select(db.products)
                    ..where((item) => item.id.equals(purchaseItem.productId)))
                  .getSingle();
          final currentQty = productBalances[product.id] ?? product.stockQty;
          final currentValue =
              productValues[product.id] ?? product.inventoryValueMinor;
          if (currentQty < qty) {
            throw _BusinessError(
              'لا يمكن رد $qty من ${product.name} لأن المخزون الحالي أقل من الكمية.',
            );
          }
          final balanceAfter = currentQty - qty;
          final inventoryLineValue = _allocateInventoryValue(
            inventoryValueMinor: currentValue,
            stockQty: currentQty,
            qty: qty,
          );
          productBalances[product.id] = balanceAfter;
          productValues[product.id] = currentValue - inventoryLineValue;
          supplierCredit += qty * purchaseItem.unitCostMinor;
          inventoryValue += inventoryLineValue;
          returnLines.add((
            product: product,
            purchaseItem: purchaseItem,
            qty: qty,
            inventoryUnitCostMinor: qty == 0 ? 0 : inventoryLineValue ~/ qty,
            balanceAfter: balanceAfter,
          ));
        }

        var payableSettlement = 0;
        var liquidRefund = 0;
        PaymentMethod? liquidRefundMethod;
        InstallmentPlan? supplierPlan;
        if (settlementMethod == PaymentMethod.installment) {
          supplierPlan =
              await (db.select(db.installmentPlans)..where(
                    (plan) =>
                        plan.ownerType.equals('purchase') &
                        plan.ownerId.equals(purchaseId) &
                        plan.partyType.equals('supplier') &
                        plan.partyId.equals(purchase.supplierId!),
                  ))
                  .getSingleOrNull();
          if (supplierPlan == null) {
            throw _BusinessError('لا توجد مديونية مورد مفتوحة لهذه الفاتورة');
          }
          final remaining = supplierPlan.totalMinor - supplierPlan.paidMinor;
          payableSettlement = math.min(supplierCredit, remaining);
          liquidRefund = supplierCredit - payableSettlement;
          if (liquidRefund > 0) {
            liquidRefundMethod = overflowRefundMethod;
            if (liquidRefundMethod == null) {
              throw _BusinessError(
                'اختر كاش أو محفظة لاستلام فائض رصيد المورد.',
              );
            }
            if (liquidRefundMethod == PaymentMethod.cash && shift == null) {
              throw _BusinessError(
                'افتح وردية قبل استلام فائض رصيد المورد كاش',
              );
            }
          }
        } else {
          liquidRefund = supplierCredit;
          liquidRefundMethod = settlementMethod;
        }

        final returnNo = await _nextNumber('purchaseReturnNo', prefix: 'PR');
        final returnId = await db
            .into(db.purchaseReturns)
            .insert(
              PurchaseReturnsCompanion.insert(
                purchaseId: purchaseId,
                returnNo: returnNo,
                creditMinor: supplierCredit,
              ),
            );

        for (final entry in productBalances.entries) {
          await (db.update(
            db.products,
          )..where((product) => product.id.equals(entry.key))).write(
            ProductsCompanion(
              stockQty: Value(entry.value),
              inventoryValueMinor: Value(productValues[entry.key]!),
              avgCostMinor: Value(
                _roundedAverageCost(productValues[entry.key]!, entry.value),
              ),
              updatedAt: Value(clock()),
            ),
          );
        }

        for (final line in returnLines) {
          await db
              .into(db.purchaseReturnItems)
              .insert(
                PurchaseReturnItemsCompanion.insert(
                  returnId: returnId,
                  purchaseItemId: line.purchaseItem.id,
                  productId: line.product.id,
                  qty: line.qty,
                  unitCostMinor: line.purchaseItem.unitCostMinor,
                  inventoryUnitCostMinor: line.inventoryUnitCostMinor,
                ),
              );
          await db
              .into(db.stockMovements)
              .insert(
                StockMovementsCompanion.insert(
                  productId: line.product.id,
                  type: 'purchase_return',
                  qtyDelta: -line.qty,
                  balanceAfter: line.balanceAfter,
                  referenceType: 'purchase_return',
                  referenceId: returnId,
                ),
              );
        }

        if (supplierPlan != null && payableSettlement > 0) {
          await _reduceInstallmentPlanForReturn(
            plan: supplierPlan,
            settlementMinor: payableSettlement,
          );
        }

        final variance = inventoryValue - supplierCredit;
        await _postLedger(
          referenceType: 'purchase_return',
          referenceId: returnId,
          description: 'مرتجع شراء $returnNo',
          lines: [
            if (payableSettlement > 0)
              _LedgerLineDraft(
                AccountCodes.payables,
                debitMinor: payableSettlement,
                partyType: 'supplier',
                partyId: purchase.supplierId,
              ),
            if (liquidRefund > 0)
              _LedgerLineDraft(
                liquidRefundMethod == PaymentMethod.wallet
                    ? AccountCodes.wallet
                    : AccountCodes.cash,
                debitMinor: liquidRefund,
              ),
            if (variance > 0)
              _LedgerLineDraft(
                AccountCodes.inventoryVariance,
                debitMinor: variance,
              ),
            _LedgerLineDraft(
              AccountCodes.inventory,
              creditMinor: inventoryValue,
            ),
            if (variance < 0)
              _LedgerLineDraft(
                AccountCodes.inventoryVariance,
                creditMinor: -variance,
              ),
          ],
        );

        return returnId;
      });
      return AppSuccess(returnId);
    } on _BusinessError catch (error) {
      return AppFailure(error.message);
    }
  }
}

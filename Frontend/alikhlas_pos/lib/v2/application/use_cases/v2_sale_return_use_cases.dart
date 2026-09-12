part of '../v2_use_cases.dart';

extension V2SaleReturnUseCases on V2UseCases {
  String newSaleReturnOperationKey() => newFinancialOperationKey();

  Future<AppResult<int>> createSaleReturn({
    String? operationKey,
    required int saleId,
    required Map<int, int> saleItemQuantities,
    required PaymentMethod refundMethod,
    PaymentMethod? overflowRefundMethod,
    bool allowNegativeBalance = false,
  }) async {
    if (operationKey == null) {
      return const AppFailure<int>(
        'معرّف عملية المرتجع مطلوب لمنع رد المبلغ أو المخزون مرتين.',
      );
    }
    final quantities = Map<int, int>.unmodifiable(saleItemQuantities);
    final orderedQuantities = quantities.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    return _runIdempotentFinancialOperation(
      namespace: 'sale_return',
      operationKey: operationKey,
      fingerprintPayload: [
        saleId,
        [
          for (final item in orderedQuantities) [item.key, item.value],
        ],
        refundMethod.name,
        overflowRefundMethod?.name,
      ],
      conflictMessage: 'هذا المرتجع محفوظ ببيانات مختلفة. راجع سجل المرتجعات.',
      execute: () => _createSaleReturn(
        saleId: saleId,
        saleItemQuantities: quantities,
        refundMethod: refundMethod,
        overflowRefundMethod: overflowRefundMethod,
        allowNegativeBalance: allowNegativeBalance,
      ),
    );
  }

  Future<AppResult<int>> _createSaleReturn({
    required int saleId,
    required Map<int, int> saleItemQuantities,
    required PaymentMethod refundMethod,
    required PaymentMethod? overflowRefundMethod,
    required bool allowNegativeBalance,
  }) async {
    if (saleItemQuantities.isEmpty) {
      return const AppFailure('اختر صنفًا واحدًا على الأقل');
    }
    if (overflowRefundMethod == PaymentMethod.installment) {
      return const AppFailure('فائض المرتجع يرد كاش أو محفظة فقط');
    }

    final shift = await currentShift();
    if (refundMethod == PaymentMethod.cash && shift == null) {
      return const AppFailure('افتح وردية قبل رد مرتجع كاش');
    }

    try {
      final returnId = await _writeTransaction(() async {
        final sale = await (db.select(
          db.saleInvoices,
        )..where((s) => s.id.equals(saleId))).getSingleOrNull();
        if (sale == null) throw _BusinessError('فاتورة البيع غير موجودة');
        if (refundMethod == PaymentMethod.installment &&
            sale.customerId == null) {
          throw _BusinessError('مرتجع التقسيط يحتاج فاتورة مرتبطة بعميل');
        }

        final invoiceItems = await (db.select(
          db.saleItems,
        )..where((item) => item.saleId.equals(saleId))).get();
        final netTotals = _netSaleItemTotals(sale, invoiceItems);
        var refund = 0;
        var returnedCost = 0;
        final returnLines =
            <
              ({
                Product product,
                SaleItem saleItem,
                int qty,
                int refundMinor,
                int costMinor,
              })
            >[];

        for (final entry in saleItemQuantities.entries) {
          final saleItem = await (db.select(
            db.saleItems,
          )..where((i) => i.id.equals(entry.key))).getSingleOrNull();
          if (saleItem == null || saleItem.saleId != saleId) {
            throw _BusinessError('سطر المرتجع غير صالح');
          }
          final qty = entry.value;
          final priorReturns = await (db.select(
            db.saleReturnItems,
          )..where((r) => r.saleItemId.equals(saleItem.id))).get();
          final alreadyReturned = priorReturns.fold<int>(
            0,
            (sum, row) => sum + row.qty,
          );
          final returnableQty = saleItem.qty - alreadyReturned;
          if (qty <= 0 || qty > returnableQty) {
            throw _BusinessError('كمية المرتجع غير صحيحة');
          }
          final refundedMinor = priorReturns.fold<int>(
            0,
            (sum, row) => sum + row.qty * row.unitPriceMinor,
          );
          final lineRefund = _refundForQuantity(
            netTotals[saleItem.id]!,
            saleItem.qty,
            alreadyReturned,
            refundedMinor,
            qty,
          );
          final returnedLineCost = _returnCostForQuantity(
            totalCostMinor: saleItem.costMinor,
            totalQty: saleItem.qty,
            alreadyReturnedQty: alreadyReturned,
            alreadyReturnedCostMinor: priorReturns.fold<int>(
              0,
              (sum, row) => sum + row.costMinor,
            ),
            qty: qty,
          );

          final product = await (db.select(
            db.products,
          )..where((p) => p.id.equals(saleItem.productId))).getSingle();

          refund += lineRefund;
          returnedCost += returnedLineCost;
          returnLines.add((
            product: product,
            saleItem: saleItem,
            qty: qty,
            refundMinor: lineRefund,
            costMinor: returnedLineCost,
          ));
        }

        var receivableSettlement = 0;
        var overflowRefund = 0;
        PaymentMethod? effectiveOverflowRefundMethod;

        if (refundMethod == PaymentMethod.installment) {
          final plan =
              await (db.select(db.installmentPlans)..where(
                    (plan) =>
                        plan.ownerType.equals('sale') &
                        plan.ownerId.equals(saleId) &
                        plan.partyType.equals('customer') &
                        plan.partyId.equals(sale.customerId!),
                  ))
                  .getSingleOrNull();
          if (plan == null) {
            throw _BusinessError('خطة التقسيط غير موجودة لهذه الفاتورة');
          }

          final remainingReceivable = plan.totalMinor - plan.paidMinor;
          receivableSettlement = refund > remainingReceivable
              ? remainingReceivable
              : refund;
          overflowRefund = refund - receivableSettlement;
          if (overflowRefund > 0) {
            effectiveOverflowRefundMethod = overflowRefundMethod;
            if (effectiveOverflowRefundMethod == null) {
              throw _BusinessError('اختر طريقة رد فائض المرتجع كاش أو محفظة');
            }
            if (effectiveOverflowRefundMethod == PaymentMethod.cash &&
                shift == null) {
              throw _BusinessError('افتح وردية قبل رد فائض المرتجع كاش');
            }
          }
        }

        final creditLines = <_LedgerLineDraft>[];
        if (refundMethod == PaymentMethod.installment) {
          if (receivableSettlement > 0) {
            creditLines.add(
              _LedgerLineDraft(
                AccountCodes.receivables,
                creditMinor: receivableSettlement,
                partyType: 'customer',
                partyId: sale.customerId,
              ),
            );
          }
          if (overflowRefund > 0) {
            creditLines.add(
              _LedgerLineDraft(
                effectiveOverflowRefundMethod == PaymentMethod.wallet
                    ? AccountCodes.wallet
                    : AccountCodes.cash,
                creditMinor: overflowRefund,
              ),
            );
          }
        } else {
          creditLines.add(
            _LedgerLineDraft(
              refundMethod == PaymentMethod.wallet
                  ? AccountCodes.wallet
                  : AccountCodes.cash,
              creditMinor: refund,
            ),
          );
        }
        if (!allowNegativeBalance) {
          final confirmation = await _negativeBalanceConfirmationFor(
            creditLines,
          );
          if (confirmation != null) throw _ConfirmationRequired(confirmation);
        }

        final returnNo = await _nextNumber('returnNo', prefix: 'R');
        final returnId = await db
            .into(db.saleReturns)
            .insert(
              SaleReturnsCompanion.insert(
                saleId: saleId,
                returnNo: returnNo,
                refundMinor: refund,
              ),
            );

        final productBalances = <int, int>{};
        final productValues = <int, int>{};
        for (final line in returnLines) {
          final currentQty =
              productBalances[line.product.id] ?? line.product.stockQty;
          final currentValue =
              productValues[line.product.id] ??
              line.product.inventoryValueMinor;
          final newQty = currentQty + line.qty;
          final newValue = currentValue + line.costMinor;
          productBalances[line.product.id] = newQty;
          productValues[line.product.id] = newValue;
          await (db.update(
            db.products,
          )..where((p) => p.id.equals(line.product.id))).write(
            ProductsCompanion(
              stockQty: Value(newQty),
              inventoryValueMinor: Value(newValue),
              avgCostMinor: Value(_roundedAverageCost(newValue, newQty)),
              updatedAt: Value(clock()),
            ),
          );

          // Split at most two unit-price groups to preserve every minor unit
          // without changing the historical return-item schema.
          final basePrice = line.refundMinor ~/ line.qty;
          final extraUnits = line.refundMinor % line.qty;
          var allocatedGroupQty = 0;
          var allocatedGroupCost = 0;
          for (final group in [
            (line.qty - extraUnits, basePrice),
            (extraUnits, basePrice + 1),
          ]) {
            if (group.$1 == 0) continue;
            final groupCost = _returnCostForQuantity(
              totalCostMinor: line.costMinor,
              totalQty: line.qty,
              alreadyReturnedQty: allocatedGroupQty,
              alreadyReturnedCostMinor: allocatedGroupCost,
              qty: group.$1,
            );
            allocatedGroupQty += group.$1;
            allocatedGroupCost += groupCost;
            await db
                .into(db.saleReturnItems)
                .insert(
                  SaleReturnItemsCompanion.insert(
                    returnId: returnId,
                    saleItemId: line.saleItem.id,
                    productId: line.product.id,
                    qty: group.$1,
                    unitPriceMinor: group.$2,
                    unitCostMinor: line.saleItem.unitCostMinor,
                    costMinor: Value(groupCost),
                  ),
                );
          }
          await db
              .into(db.stockMovements)
              .insert(
                StockMovementsCompanion.insert(
                  productId: line.product.id,
                  type: 'sale_return',
                  qtyDelta: line.qty,
                  balanceAfter: newQty,
                  referenceType: 'sale_return',
                  referenceId: returnId,
                ),
              );
        }

        if (refundMethod == PaymentMethod.installment) {
          final plan =
              await (db.select(db.installmentPlans)..where(
                    (plan) =>
                        plan.ownerType.equals('sale') &
                        plan.ownerId.equals(saleId) &
                        plan.partyType.equals('customer') &
                        plan.partyId.equals(sale.customerId!),
                  ))
                  .getSingle();
          await _reduceInstallmentPlanForReturn(
            plan: plan,
            settlementMinor: receivableSettlement,
          );
        }

        if (refund > 0) {
          await _postLedger(
            referenceType: 'sale_return',
            referenceId: returnId,
            description: 'مرتجع بيع $returnNo',
            lines: [
              _LedgerLineDraft(AccountCodes.sales, debitMinor: refund),
              ...creditLines,
            ],
          );
        }

        if (returnedCost > 0) {
          await _postLedger(
            referenceType: 'sale_return_cogs',
            referenceId: returnId,
            description: 'عكس تكلفة مرتجع $returnNo',
            lines: [
              _LedgerLineDraft(
                AccountCodes.inventory,
                debitMinor: returnedCost,
              ),
              _LedgerLineDraft(AccountCodes.cogs, creditMinor: returnedCost),
            ],
          );
        }

        return returnId;
      });
      return AppSuccess(returnId);
    } on _ConfirmationRequired catch (e) {
      return e.result;
    } on _BusinessError catch (e) {
      return AppFailure(e.message);
    }
  }

  Future<void> _reduceInstallmentPlanForReturn({
    required InstallmentPlan plan,
    required int settlementMinor,
  }) async {
    if (settlementMinor <= 0) return;

    final remaining = plan.totalMinor - plan.paidMinor;
    if (settlementMinor > remaining) {
      throw StateError('Installment return settlement exceeds remaining debt.');
    }

    final newTotal = plan.totalMinor - settlementMinor;
    final newRemaining = newTotal - plan.paidMinor;
    final installments =
        await (db.select(db.installmentPayments)
              ..where((payment) => payment.planId.equals(plan.id))
              ..orderBy([(payment) => OrderingTerm.asc(payment.dueDate)]))
            .get();
    final paidScheduledMinor = installments
        .where((payment) => payment.status == 'paid')
        .fold<int>(0, (sum, payment) => sum + payment.amountMinor);
    final adjustableInstallments = installments
        .where((payment) => payment.status != 'paid')
        .toList();
    final adjustableTotal = newTotal - paidScheduledMinor;
    if (adjustableTotal < 0) {
      throw StateError(
        'Adjusted installment total is less than paid schedule.',
      );
    }

    await (db.update(
      db.installmentPlans,
    )..where((p) => p.id.equals(plan.id))).write(
      InstallmentPlansCompanion(
        totalMinor: Value(newTotal),
        status: Value(newRemaining == 0 ? 'closed' : 'open'),
      ),
    );

    if (adjustableInstallments.isEmpty) return;

    for (var i = 0; i < adjustableInstallments.length; i++) {
      final installment = adjustableInstallments[i];
      await (db.update(
        db.installmentPayments,
      )..where((payment) => payment.id.equals(installment.id))).write(
        InstallmentPaymentsCompanion(
          amountMinor: Value(
            allocateRemainderToLast(
              adjustableTotal,
              adjustableInstallments.length,
              i,
            ),
          ),
          status: Value(newRemaining == 0 ? 'paid' : 'pending'),
          paidAt: Value(newRemaining == 0 ? clock() : null),
        ),
      );
    }
  }

  Map<int, int> _netSaleItemTotals(SaleInvoice sale, List<SaleItem> items) {
    final ordered = [...items]..sort((a, b) => a.id.compareTo(b.id));
    final result = <int, int>{};
    var prefix = BigInt.zero;
    final net = BigInt.from(sale.subtotalMinor - sale.discountMinor);
    final subtotal = BigInt.from(sale.subtotalMinor);
    for (final item in ordered) {
      final before = prefix;
      prefix += BigInt.from(item.lineTotalMinor);
      result[item.id] = subtotal == BigInt.zero
          ? 0
          : ((prefix * net ~/ subtotal) - (before * net ~/ subtotal)).toInt();
    }
    return result;
  }
}

int _allocateInventoryValue({
  required int inventoryValueMinor,
  required int stockQty,
  required int qty,
}) {
  if (qty <= 0 || stockQty <= 0 || qty > stockQty) {
    throw StateError('Invalid inventory cost allocation.');
  }
  if (qty == stockQty) return inventoryValueMinor;
  return inventoryValueMinor * qty ~/ stockQty;
}

int _roundedAverageCost(int inventoryValueMinor, int stockQty) {
  if (stockQty == 0) return 0;
  return (inventoryValueMinor / stockQty).round();
}

int _returnCostForQuantity({
  required int totalCostMinor,
  required int totalQty,
  required int alreadyReturnedQty,
  required int alreadyReturnedCostMinor,
  required int qty,
}) {
  final remainingQty = totalQty - alreadyReturnedQty;
  if (totalQty <= 0 || qty <= 0 || qty > remainingQty) {
    throw StateError('Invalid return cost allocation.');
  }
  if (qty == remainingQty) return totalCostMinor - alreadyReturnedCostMinor;
  final before = totalCostMinor * alreadyReturnedQty ~/ totalQty;
  final after = totalCostMinor * (alreadyReturnedQty + qty) ~/ totalQty;
  return after - before;
}

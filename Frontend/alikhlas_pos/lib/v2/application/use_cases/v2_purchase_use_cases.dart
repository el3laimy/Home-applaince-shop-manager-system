part of '../v2_use_cases.dart';

extension V2PurchaseUseCases on V2UseCases {
  String newPurchaseOperationKey() => newFinancialOperationKey();

  Future<AppResult<int>> createPurchase({
    String? operationKey,
    int? supplierId,
    required List<PurchaseLineInput> items,
    required List<PaymentInput> payments,
    bool allowNegativeBalance = false,
  }) async {
    if (operationKey == null) {
      return const AppFailure<int>(
        'معرّف عملية الشراء مطلوب لمنع تسجيل الفاتورة مرتين.',
      );
    }
    final frozenItems = List<PurchaseLineInput>.unmodifiable(items);
    final frozenPayments = List<PaymentInput>.unmodifiable(payments);
    return _runIdempotentFinancialOperation(
      namespace: 'purchase',
      operationKey: operationKey,
      fingerprintPayload: [
        supplierId,
        [
          for (final item in frozenItems)
            [item.productId, item.qty, item.unitCostMinor],
        ],
        [
          for (final payment in frozenPayments)
            [payment.method.name, payment.amountMinor, payment.note],
        ],
      ],
      conflictMessage: 'هذه العملية محفوظة ببيانات مختلفة. راجع فواتير الشراء.',
      legacyIdFields: const ['purchaseId'],
      execute: () => _createPurchase(
        supplierId: supplierId,
        items: frozenItems,
        payments: frozenPayments,
        allowNegativeBalance: allowNegativeBalance,
      ),
    );
  }

  Future<AppResult<int>> _createPurchase({
    int? supplierId,
    required List<PurchaseLineInput> items,
    required List<PaymentInput> payments,
    required bool allowNegativeBalance,
  }) async {
    if (items.isEmpty) return const AppFailure('أضف صنفًا واحدًا على الأقل');
    if (items.map((item) => item.productId).toSet().length != items.length) {
      return const AppFailure('الصنف مكرر. اجمع كميته في سطر واحد.');
    }
    if (payments.any((payment) => payment.amountMinor < 0)) {
      return const AppFailure('المدفوعات لا يمكن أن تكون سالبة');
    }
    final shift = await currentShift();
    if (payments.any((p) => p.method == PaymentMethod.cash) && shift == null) {
      return const AppFailure('افتح وردية قبل دفع مشتريات نقدية');
    }

    try {
      final result = await _writeTransaction<AppResult<int>>(() async {
        var total = 0;
        final products = <int, Product>{};
        for (final item in items) {
          if (item.qty <= 0) {
            throw _BusinessError('تحقق من الكمية وسعر الشراء');
          }
          if (item.unitCostMinor <= 0) {
            throw _BusinessError('أدخل سعر شراء صحيح للصنف');
          }
          final product =
              await (db.select(db.products)..where(
                    (p) =>
                        p.id.equals(item.productId) & p.isActive.equals(true),
                  ))
                  .getSingleOrNull();
          if (product == null) {
            throw _BusinessError('المنتج غير موجود أو معطل. فعّله قبل الشراء.');
          }
          products[item.productId] = product;
          total += item.qty * item.unitCostMinor;
        }

        final cashPaid = _sumPayments(payments, PaymentMethod.cash);
        final walletPaid = _sumPayments(payments, PaymentMethod.wallet);
        final paid = cashPaid + walletPaid;
        final remaining = total - paid;
        if (paid > total) {
          throw _BusinessError('المدفوع أكبر من إجمالي فاتورة الشراء');
        }
        if (remaining > 0 && supplierId == null) {
          throw _BusinessError('المشتريات الآجلة تحتاج مورد');
        }
        if (!allowNegativeBalance) {
          final confirmation = await _negativeBalanceConfirmationFor([
            if (cashPaid > 0)
              _LedgerLineDraft(AccountCodes.cash, creditMinor: cashPaid),
            if (walletPaid > 0)
              _LedgerLineDraft(AccountCodes.wallet, creditMinor: walletPaid),
          ]);
          if (confirmation != null) return confirmation;
        }

        final invoiceNo = await _nextNumber('purchaseNo', prefix: 'P');
        final purchaseId = await db
            .into(db.purchaseInvoices)
            .insert(
              PurchaseInvoicesCompanion.insert(
                invoiceNo: invoiceNo,
                supplierId: Value(supplierId),
                shiftId: Value(shift?.id),
                totalMinor: total,
                paidMinor: paid,
                remainingMinor: remaining,
              ),
            );

        for (final item in items) {
          final product = products[item.productId]!;
          final oldValue = product.inventoryValueMinor;
          final newQty = product.stockQty + item.qty;
          final newValue = oldValue + (item.qty * item.unitCostMinor);
          final newAvg = newQty == 0
              ? item.unitCostMinor
              : (newValue / newQty).round();

          await db
              .into(db.purchaseItems)
              .insert(
                PurchaseItemsCompanion.insert(
                  purchaseId: purchaseId,
                  productId: product.id,
                  qty: item.qty,
                  unitCostMinor: item.unitCostMinor,
                  lineTotalMinor: item.qty * item.unitCostMinor,
                ),
              );
          await (db.update(
            db.products,
          )..where((p) => p.id.equals(product.id))).write(
            ProductsCompanion(
              stockQty: Value(newQty),
              avgCostMinor: Value(newAvg),
              inventoryValueMinor: Value(newValue),
              updatedAt: Value(clock()),
            ),
          );
          await db
              .into(db.stockMovements)
              .insert(
                StockMovementsCompanion.insert(
                  productId: product.id,
                  type: 'purchase',
                  qtyDelta: item.qty,
                  balanceAfter: newQty,
                  referenceType: 'purchase',
                  referenceId: purchaseId,
                ),
              );
        }

        await _insertPayments('purchase', purchaseId, payments);
        if (remaining > 0 && supplierId != null) {
          // Supplier credit is one due installment. Keeping an explicit
          // schedule makes the balance and consistency checks auditable.
          await _createInstallmentPlan(
            ownerType: 'purchase',
            ownerId: purchaseId,
            partyType: 'supplier',
            partyId: supplierId,
            principalMinor: remaining,
            interestMinor: 0,
            terms: InstallmentTerms(
              partyId: supplierId,
              count: 1,
              firstDueDate: clock(),
            ),
          );
        }

        await _postLedger(
          referenceType: 'purchase',
          referenceId: purchaseId,
          description: 'فاتورة مشتريات $invoiceNo',
          lines: [
            _LedgerLineDraft(AccountCodes.inventory, debitMinor: total),
            if (cashPaid > 0)
              _LedgerLineDraft(AccountCodes.cash, creditMinor: cashPaid),
            if (walletPaid > 0)
              _LedgerLineDraft(AccountCodes.wallet, creditMinor: walletPaid),
            if (remaining > 0)
              _LedgerLineDraft(
                AccountCodes.payables,
                creditMinor: remaining,
                partyType: 'supplier',
                partyId: supplierId,
              ),
          ],
        );

        return AppSuccess(purchaseId);
      });
      return result;
    } on _BusinessError catch (e) {
      return AppFailure(e.message);
    }
  }
}

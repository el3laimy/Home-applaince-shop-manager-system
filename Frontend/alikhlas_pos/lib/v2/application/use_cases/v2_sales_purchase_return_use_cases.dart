part of '../v2_use_cases.dart';

extension V2SalesPurchaseReturnUseCases on V2UseCases {
  String newSaleOperationKey() => newFinancialOperationKey();

  Future<AppResult<int>> createSale({
    String? operationKey,
    int? customerId,
    required List<SaleLineInput> items,
    required List<PaymentInput> payments,
    InstallmentTerms? installmentTerms,
    int discountMinor = 0,
  }) async {
    if (operationKey == null) {
      return const AppFailure<int>(
        'معرّف عملية البيع مطلوب لمنع تسجيل الفاتورة مرتين.',
      );
    }
    final frozenItems = List<SaleLineInput>.unmodifiable(items);
    final frozenPayments = List<PaymentInput>.unmodifiable(payments);
    return _runIdempotentFinancialOperation(
      namespace: 'sale',
      operationKey: operationKey,
      fingerprintPayload: [
        customerId,
        discountMinor,
        [
          for (final item in frozenItems)
            [item.productId, item.qty, item.unitPriceMinor],
        ],
        [
          for (final payment in frozenPayments)
            [payment.method.name, payment.amountMinor, payment.note],
        ],
        if (installmentTerms == null)
          null
        else
          [
            installmentTerms.partyId,
            installmentTerms.count,
            installmentTerms.firstDueDate.toIso8601String(),
            installmentTerms.interestMinor,
            installmentTerms.periodDays,
          ],
      ],
      conflictMessage: 'هذه العملية محفوظة ببيانات مختلفة. راجع سجل الفواتير.',
      legacyIdFields: const ['saleId'],
      legacyFingerprintPayload: [
        customerId,
        discountMinor,
        [
          for (final item in frozenItems)
            [item.productId, item.qty, item.unitPriceMinor],
        ],
        [
          for (final payment in frozenPayments)
            [payment.method.name, payment.amountMinor],
        ],
        if (installmentTerms == null)
          null
        else
          [
            installmentTerms.partyId,
            installmentTerms.count,
            installmentTerms.firstDueDate.toIso8601String(),
            installmentTerms.interestMinor,
            installmentTerms.periodDays,
          ],
      ],
      execute: () => _createSale(
        customerId: customerId,
        items: frozenItems,
        payments: frozenPayments,
        installmentTerms: installmentTerms,
        discountMinor: discountMinor,
      ),
    );
  }

  Future<AppResult<int>> _createSale({
    int? customerId,
    required List<SaleLineInput> items,
    required List<PaymentInput> payments,
    InstallmentTerms? installmentTerms,
    required int discountMinor,
  }) async {
    if (items.isEmpty) return const AppFailure('أضف صنفًا واحدًا على الأقل');
    if (items.map((item) => item.productId).toSet().length != items.length) {
      return const AppFailure('الصنف مكرر. اجمع كميته في سطر واحد.');
    }
    if (payments.any((payment) => payment.amountMinor < 0)) {
      return const AppFailure('المدفوعات لا يمكن أن تكون سالبة');
    }
    if (discountMinor < 0) {
      return const AppFailure('الخصم لا يمكن أن يكون سالبًا');
    }
    final shift = await currentShift();
    if (payments.any((p) => p.method == PaymentMethod.cash) && shift == null) {
      return const AppFailure('افتح وردية قبل البيع النقدي');
    }

    try {
      final saleId = await _writeTransaction(() async {
        var subtotal = 0;
        var cogs = 0;
        final productRows = <int, Product>{};

        for (final item in items) {
          if (item.qty <= 0 || item.unitPriceMinor < 0) {
            throw _BusinessError('تحقق من الكمية والسعر');
          }
          final product =
              await (db.select(db.products)..where(
                    (p) =>
                        p.id.equals(item.productId) & p.isActive.equals(true),
                  ))
                  .getSingleOrNull();
          if (product == null) throw _BusinessError('منتج غير موجود');
          if (product.stockQty < item.qty) {
            throw _BusinessError('الرصيد غير كافٍ للصنف ${product.name}');
          }
          productRows[item.productId] = product;
          subtotal += item.qty * item.unitPriceMinor;
          cogs += item.qty * product.avgCostMinor;
        }

        final cashPaid = _sumPayments(payments, PaymentMethod.cash);
        final walletPaid = _sumPayments(payments, PaymentMethod.wallet);
        final paid = cashPaid + walletPaid;
        if (discountMinor >= subtotal) {
          throw _BusinessError('الخصم يجب أن يكون أقل من إجمالي الفاتورة');
        }
        final netSubtotal = subtotal - discountMinor;
        if (paid > netSubtotal) {
          throw _BusinessError('المدفوع أكبر من إجمالي الفاتورة');
        }
        final installmentPrincipal = netSubtotal - paid;
        final interest = installmentPrincipal > 0
            ? (installmentTerms?.interestMinor ?? 0)
            : 0;
        final total = netSubtotal + interest;
        final remaining = total - paid;

        if (remaining > 0 && (customerId == null || installmentTerms == null)) {
          throw _BusinessError('البيع الآجل يحتاج عميل وخطة أقساط');
        }
        if (remaining > 0 && installmentTerms!.count <= 0) {
          throw _BusinessError('عدد الأقساط يجب أن يكون أكبر من صفر');
        }
        if (remaining > 0 && installmentTerms!.periodDays <= 0) {
          throw _BusinessError('فترة الأقساط يجب أن تكون أكبر من صفر يوم');
        }

        final invoiceNo = await _nextNumber('saleNo', prefix: 'S');
        final saleId = await db
            .into(db.saleInvoices)
            .insert(
              SaleInvoicesCompanion.insert(
                invoiceNo: invoiceNo,
                customerId: Value(customerId),
                shiftId: Value(shift?.id),
                subtotalMinor: subtotal,
                discountMinor: Value(discountMinor),
                interestMinor: Value(interest),
                totalMinor: total,
                paidMinor: paid,
                remainingMinor: remaining,
              ),
            );

        for (final item in items) {
          final product = productRows[item.productId]!;
          await db
              .into(db.saleItems)
              .insert(
                SaleItemsCompanion.insert(
                  saleId: saleId,
                  productId: item.productId,
                  qty: item.qty,
                  unitPriceMinor: item.unitPriceMinor,
                  unitCostMinor: product.avgCostMinor,
                  lineTotalMinor: item.qty * item.unitPriceMinor,
                ),
              );

          final newQty = product.stockQty - item.qty;
          await (db.update(
            db.products,
          )..where((p) => p.id.equals(product.id))).write(
            ProductsCompanion(
              stockQty: Value(newQty),
              updatedAt: Value(DateTime.now()),
            ),
          );
          await db
              .into(db.stockMovements)
              .insert(
                StockMovementsCompanion.insert(
                  productId: product.id,
                  type: 'sale',
                  qtyDelta: -item.qty,
                  balanceAfter: newQty,
                  referenceType: 'sale',
                  referenceId: saleId,
                ),
              );
        }

        await _insertPayments('sale', saleId, payments);
        if (remaining > 0 && installmentTerms != null && customerId != null) {
          await _createInstallmentPlan(
            ownerType: 'sale',
            ownerId: saleId,
            partyType: 'customer',
            partyId: customerId,
            principalMinor: installmentPrincipal,
            interestMinor: interest,
            terms: installmentTerms,
          );
        }

        final ledgerLines = <_LedgerLineDraft>[
          if (cashPaid > 0)
            _LedgerLineDraft(AccountCodes.cash, debitMinor: cashPaid),
          if (walletPaid > 0)
            _LedgerLineDraft(AccountCodes.wallet, debitMinor: walletPaid),
          if (remaining > 0)
            _LedgerLineDraft(
              AccountCodes.receivables,
              debitMinor: remaining,
              partyType: 'customer',
              partyId: customerId,
            ),
          _LedgerLineDraft(AccountCodes.sales, creditMinor: netSubtotal),
          if (interest > 0)
            _LedgerLineDraft(
              AccountCodes.interestIncome,
              creditMinor: interest,
            ),
        ];
        await _postLedger(
          referenceType: 'sale',
          referenceId: saleId,
          description: 'فاتورة بيع $invoiceNo',
          lines: ledgerLines,
        );

        if (cogs > 0) {
          await _postLedger(
            referenceType: 'sale_cogs',
            referenceId: saleId,
            description: 'تكلفة بضاعة مباعة $invoiceNo',
            lines: [
              _LedgerLineDraft(AccountCodes.cogs, debitMinor: cogs),
              _LedgerLineDraft(AccountCodes.inventory, creditMinor: cogs),
            ],
          );
        }

        return saleId;
      });
      return AppSuccess(saleId);
    } on _BusinessError catch (e) {
      return AppFailure(e.message);
    }
  }

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
          final product = await (db.select(
            db.products,
          )..where((p) => p.id.equals(item.productId))).getSingleOrNull();
          if (product == null) throw _BusinessError('منتج غير موجود');
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
          final oldValue = product.stockQty * product.avgCostMinor;
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
              updatedAt: Value(DateTime.now()),
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
              ({Product product, SaleItem saleItem, int qty, int refundMinor})
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

          final product = await (db.select(
            db.products,
          )..where((p) => p.id.equals(saleItem.productId))).getSingle();

          refund += lineRefund;
          // Sale returns reverse inventory at the historical sold cost; current WAC is not recalculated in v2.
          returnedCost += qty * saleItem.unitCostMinor;
          returnLines.add((
            product: product,
            saleItem: saleItem,
            qty: qty,
            refundMinor: lineRefund,
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
        for (final line in returnLines) {
          final currentQty =
              productBalances[line.product.id] ?? line.product.stockQty;
          final newQty = currentQty + line.qty;
          productBalances[line.product.id] = newQty;
          await (db.update(
            db.products,
          )..where((p) => p.id.equals(line.product.id))).write(
            ProductsCompanion(
              stockQty: Value(newQty),
              updatedAt: Value(DateTime.now()),
            ),
          );

          // Split at most two unit-price groups to preserve every minor unit
          // without changing the historical return-item schema.
          final basePrice = line.refundMinor ~/ line.qty;
          final extraUnits = line.refundMinor % line.qty;
          for (final group in [
            (line.qty - extraUnits, basePrice),
            (extraUnits, basePrice + 1),
          ]) {
            if (group.$1 == 0) continue;
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
          paidAt: Value(newRemaining == 0 ? DateTime.now() : null),
        ),
      );
    }
  }

  String newExpenseOperationKey() => newFinancialOperationKey();

  Future<AppResult<int>> recordExpense({
    String? operationKey,
    required String description,
    required int amountMinor,
    required PaymentMethod method,
    bool allowNegativeBalance = false,
  }) async {
    final normalizedDescription = description.trim();
    if (operationKey == null) {
      return const AppFailure<int>(
        'معرّف عملية المصروف مطلوب لمنع تسجيله مرتين.',
      );
    }
    return _runIdempotentFinancialOperation(
      namespace: 'expense',
      operationKey: operationKey,
      fingerprintPayload: [normalizedDescription, amountMinor, method.name],
      conflictMessage: 'هذا المصروف محفوظ ببيانات مختلفة. راجع سجل المصروفات.',
      execute: () => _recordExpense(
        description: normalizedDescription,
        amountMinor: amountMinor,
        method: method,
        allowNegativeBalance: allowNegativeBalance,
      ),
    );
  }

  Future<AppResult<int>> _recordExpense({
    required String description,
    required int amountMinor,
    required PaymentMethod method,
    required bool allowNegativeBalance,
  }) async {
    final normalizedDescription = description.trim();
    if (normalizedDescription.isEmpty) {
      return const AppFailure('وصف المصروف مطلوب');
    }
    if (amountMinor <= 0) {
      return const AppFailure('قيمة المصروف يجب أن تكون أكبر من صفر');
    }
    if (method == PaymentMethod.installment) {
      return const AppFailure('المصروف لا يدعم التقسيط');
    }

    final shift = await currentShift();
    if (method == PaymentMethod.cash && shift == null) {
      return const AppFailure('افتح وردية قبل تسجيل مصروف نقدي');
    }
    if (!allowNegativeBalance) {
      final confirmation = await _negativeBalanceConfirmationFor([
        _LedgerLineDraft(
          method == PaymentMethod.cash
              ? AccountCodes.cash
              : AccountCodes.wallet,
          creditMinor: amountMinor,
        ),
      ]);
      if (confirmation != null) return confirmation;
    }

    final expenseId = await _writeTransaction(() async {
      final expenseId = await db
          .into(db.expenses)
          .insert(
            ExpensesCompanion.insert(
              description: description.trim(),
              amountMinor: amountMinor,
              method: method.name,
            ),
          );
      await _postLedger(
        referenceType: 'expense',
        referenceId: expenseId,
        description: 'مصروف: $normalizedDescription',
        lines: [
          _LedgerLineDraft(AccountCodes.expenses, debitMinor: amountMinor),
          _LedgerLineDraft(
            method == PaymentMethod.cash
                ? AccountCodes.cash
                : AccountCodes.wallet,
            creditMinor: amountMinor,
          ),
        ],
      );
      return expenseId;
    });

    return AppSuccess(expenseId);
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

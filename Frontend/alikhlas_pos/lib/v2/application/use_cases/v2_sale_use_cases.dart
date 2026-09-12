part of '../v2_use_cases.dart';

extension V2SaleUseCases on V2UseCases {
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
        final saleCosts = <int, int>{};

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
          final exactCost = _allocateInventoryValue(
            inventoryValueMinor: product.inventoryValueMinor,
            stockQty: product.stockQty,
            qty: item.qty,
          );
          saleCosts[item.productId] = exactCost;
          cogs += exactCost;
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
          final exactCost = saleCosts[item.productId]!;
          final newQty = product.stockQty - item.qty;
          final newValue = product.inventoryValueMinor - exactCost;
          await db
              .into(db.saleItems)
              .insert(
                SaleItemsCompanion.insert(
                  saleId: saleId,
                  productId: item.productId,
                  qty: item.qty,
                  unitPriceMinor: item.unitPriceMinor,
                  unitCostMinor: product.avgCostMinor,
                  costMinor: Value(exactCost),
                  lineTotalMinor: item.qty * item.unitPriceMinor,
                ),
              );

          await (db.update(
            db.products,
          )..where((p) => p.id.equals(product.id))).write(
            ProductsCompanion(
              stockQty: Value(newQty),
              inventoryValueMinor: Value(newValue),
              avgCostMinor: Value(_roundedAverageCost(newValue, newQty)),
              updatedAt: Value(clock()),
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
}

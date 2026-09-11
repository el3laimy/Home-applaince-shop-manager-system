part of '../v2_use_cases.dart';

extension V2StatementReceiptUseCases on V2UseCases {
  Future<List<SaleInvoice>> saleInvoiceHistory({
    String query = '',
    DateTime? createdFrom,
    DateTime? createdBefore,
    int offset = 0,
    int limit = 20,
  }) async {
    if (offset < 0 || limit < 1 || limit > 100) {
      throw ArgumentError('Invalid page');
    }
    if (createdFrom != null &&
        createdBefore != null &&
        !createdFrom.isBefore(createdBefore)) {
      throw ArgumentError('Invalid date range');
    }
    final term = query.trim();
    final rows = await db
        .customSelect(
          '''
      SELECT s.* FROM sale_invoices s
      LEFT JOIN customers c ON c.id = s.customer_id
      WHERE (? = '' OR instr(s.invoice_no, ?) > 0 OR instr(COALESCE(c.name, ''), ?) > 0 OR instr(COALESCE(c.phone, ''), ?) > 0)
      ${createdFrom == null ? '' : 'AND s.created_at >= ?'}
      ${createdBefore == null ? '' : 'AND s.created_at < ?'}
      ORDER BY s.created_at DESC, s.id DESC LIMIT ? OFFSET ?
      ''',
          variables: [
            for (var i = 0; i < 4; i++) Variable<String>(term),
            if (createdFrom != null) Variable<DateTime>(createdFrom),
            if (createdBefore != null) Variable<DateTime>(createdBefore),
            Variable<int>(limit),
            Variable<int>(offset),
          ],
          readsFrom: {db.saleInvoices, db.customers},
        )
        .get();
    return rows.map((row) => db.saleInvoices.map(row.data)).toList();
  }

  Future<List<PurchaseInvoice>> purchaseInvoiceHistory({
    String query = '',
    DateTime? createdFrom,
    DateTime? createdBefore,
    int offset = 0,
    int limit = 20,
  }) async {
    if (offset < 0 || limit < 1 || limit > 100) {
      throw ArgumentError('Invalid page');
    }
    if (createdFrom != null &&
        createdBefore != null &&
        !createdFrom.isBefore(createdBefore)) {
      throw ArgumentError('Invalid date range');
    }
    final term = query.trim();
    final rows = await db
        .customSelect(
          '''
      SELECT p.* FROM purchase_invoices p
      LEFT JOIN suppliers s ON s.id = p.supplier_id
      WHERE (? = '' OR instr(p.invoice_no, ?) > 0 OR instr(COALESCE(s.name, ''), ?) > 0 OR instr(COALESCE(s.phone, ''), ?) > 0)
      ${createdFrom == null ? '' : 'AND p.created_at >= ?'}
      ${createdBefore == null ? '' : 'AND p.created_at < ?'}
      ORDER BY p.created_at DESC, p.id DESC LIMIT ? OFFSET ?
      ''',
          variables: [
            for (var i = 0; i < 4; i++) Variable<String>(term),
            if (createdFrom != null) Variable<DateTime>(createdFrom),
            if (createdBefore != null) Variable<DateTime>(createdBefore),
            Variable<int>(limit),
            Variable<int>(offset),
          ],
          readsFrom: {db.purchaseInvoices, db.suppliers},
        )
        .get();
    return rows.map((row) => db.purchaseInvoices.map(row.data)).toList();
  }

  Future<StatementInvoiceDetails?> _statementInvoiceDetails(
    LedgerEntry entry,
  ) async {
    return switch (entry.referenceType) {
      'sale' => _saleStatementDetails(entry.referenceId),
      'purchase' => _purchaseStatementDetails(entry.referenceId),
      'installment_payment' => _installmentOwnerStatementDetails(
        entry.referenceId,
      ),
      'sale_return' => _saleReturnStatementDetails(entry.referenceId),
      _ => Future.value(null),
    };
  }

  Future<StatementInvoiceDetails?> _installmentOwnerStatementDetails(
    int planId,
  ) async {
    final plan = await (db.select(
      db.installmentPlans,
    )..where((row) => row.id.equals(planId))).getSingleOrNull();
    if (plan == null) return null;
    return switch (plan.ownerType) {
      'sale' => _saleStatementDetails(plan.ownerId),
      'purchase' => _purchaseStatementDetails(plan.ownerId),
      _ => null,
    };
  }

  Future<StatementInvoiceDetails?> _saleReturnStatementDetails(
    int returnId,
  ) async {
    final saleReturn = await (db.select(
      db.saleReturns,
    )..where((row) => row.id.equals(returnId))).getSingleOrNull();
    if (saleReturn == null) return null;
    return _saleStatementDetails(saleReturn.saleId);
  }

  Future<StatementInvoiceDetails?> _saleStatementDetails(int saleId) async {
    final invoice = await (db.select(
      db.saleInvoices,
    )..where((row) => row.id.equals(saleId))).getSingleOrNull();
    if (invoice == null) return null;
    final items =
        await (db.select(db.saleItems)
              ..where((row) => row.saleId.equals(saleId))
              ..orderBy([(row) => OrderingTerm.asc(row.id)]))
            .get();
    final plan =
        await (db.select(db.installmentPlans)..where(
              (row) =>
                  row.ownerType.equals('sale') & row.ownerId.equals(saleId),
            ))
            .getSingleOrNull();
    final paymentRows = await _invoicePayments('sale', saleId, plan);
    final returnedMinor = await _saleReturnedMinor(saleId);
    return StatementInvoiceDetails(
      type: 'sale',
      invoiceNo: invoice.invoiceNo,
      createdAt: invoice.createdAt,
      subtotalMinor: invoice.subtotalMinor,
      discountMinor: invoice.discountMinor,
      interestMinor: invoice.interestMinor,
      returnedMinor: returnedMinor,
      totalMinor: invoice.totalMinor,
      paidMinor: invoice.paidMinor + (plan?.paidMinor ?? 0),
      remainingMinor: plan == null
          ? math.max(0, invoice.totalMinor - invoice.paidMinor - returnedMinor)
          : math.max(0, plan.totalMinor - plan.paidMinor),
      items: await _saleStatementItems(items),
      payments: paymentRows,
      installments: plan == null ? const [] : await _installmentsFor(plan),
    );
  }

  Future<StatementInvoiceDetails?> _purchaseStatementDetails(
    int purchaseId,
  ) async {
    final invoice = await (db.select(
      db.purchaseInvoices,
    )..where((row) => row.id.equals(purchaseId))).getSingleOrNull();
    if (invoice == null) return null;
    final items =
        await (db.select(db.purchaseItems)
              ..where((row) => row.purchaseId.equals(purchaseId))
              ..orderBy([(row) => OrderingTerm.asc(row.id)]))
            .get();
    final plan =
        await (db.select(db.installmentPlans)..where(
              (row) =>
                  row.ownerType.equals('purchase') &
                  row.ownerId.equals(purchaseId),
            ))
            .getSingleOrNull();
    final paymentRows = await _invoicePayments('purchase', purchaseId, plan);
    return StatementInvoiceDetails(
      type: 'purchase',
      invoiceNo: invoice.invoiceNo,
      createdAt: invoice.createdAt,
      totalMinor: invoice.totalMinor,
      paidMinor: invoice.paidMinor + (plan?.paidMinor ?? 0),
      remainingMinor: plan == null
          ? math.max(0, invoice.totalMinor - invoice.paidMinor)
          : math.max(0, plan.totalMinor - plan.paidMinor),
      items: await _purchaseStatementItems(items),
      payments: paymentRows,
      installments: plan == null ? const [] : await _installmentsFor(plan),
    );
  }

  Future<List<StatementInvoiceItem>> _saleStatementItems(
    List<SaleItem> saleItems,
  ) async {
    final items = <StatementInvoiceItem>[];
    for (final item in saleItems) {
      final product = await (db.select(
        db.products,
      )..where((row) => row.id.equals(item.productId))).getSingle();
      items.add(
        StatementInvoiceItem(
          productName: product.name,
          qty: item.qty,
          unitMinor: item.unitPriceMinor,
          lineTotalMinor: item.lineTotalMinor,
        ),
      );
    }
    return items;
  }

  Future<List<StatementInvoiceItem>> _purchaseStatementItems(
    List<PurchaseItem> purchaseItems,
  ) async {
    final items = <StatementInvoiceItem>[];
    for (final item in purchaseItems) {
      final product = await (db.select(
        db.products,
      )..where((row) => row.id.equals(item.productId))).getSingle();
      items.add(
        StatementInvoiceItem(
          productName: product.name,
          qty: item.qty,
          unitMinor: item.unitCostMinor,
          lineTotalMinor: item.lineTotalMinor,
        ),
      );
    }
    return items;
  }

  Future<List<StatementPaymentDetail>> _invoicePayments(
    String ownerType,
    int ownerId,
    InstallmentPlan? plan,
  ) async {
    final payments = [
      ...await _paymentsFor(ownerType, ownerId),
      if (plan != null) ...await _paymentsFor('installment_plan', plan.id),
    ];
    payments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return payments;
  }

  Future<List<StatementPaymentDetail>> _paymentsFor(
    String ownerType,
    int ownerId,
  ) async {
    final rows =
        await (db.select(db.payments)
              ..where(
                (row) =>
                    row.ownerType.equals(ownerType) &
                    row.ownerId.equals(ownerId),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.id)]))
            .get();
    return rows.map((payment) {
      return StatementPaymentDetail(
        method: PaymentMethod.values.byName(payment.method),
        amountMinor: payment.amountMinor,
        createdAt: payment.createdAt,
      );
    }).toList();
  }

  Future<int> _saleReturnedMinor(int saleId) async {
    final returns = await (db.select(
      db.saleReturns,
    )..where((row) => row.saleId.equals(saleId))).get();
    return returns.fold<int>(
      0,
      (sum, saleReturn) => sum + saleReturn.refundMinor,
    );
  }

  Future<List<StatementInstallmentDetail>> _installmentsFor(
    InstallmentPlan plan,
  ) async {
    final rows =
        await (db.select(db.installmentPayments)
              ..where((row) => row.planId.equals(plan.id))
              ..orderBy([(row) => OrderingTerm.asc(row.dueDate)]))
            .get();
    var remainingPaid = plan.paidMinor;
    return rows.map((payment) {
      final paidMinor = remainingPaid <= 0
          ? 0
          : math.min(remainingPaid, payment.amountMinor);
      remainingPaid -= paidMinor;
      final remainingMinor = payment.amountMinor - paidMinor;
      final status = remainingMinor == 0
          ? 'paid'
          : paidMinor > 0
          ? 'partial'
          : 'pending';
      return StatementInstallmentDetail(
        amountMinor: payment.amountMinor,
        paidMinor: paidMinor,
        remainingMinor: remainingMinor,
        dueDate: payment.dueDate,
        status: status,
        paidAt: status == 'paid' ? payment.paidAt : null,
      );
    }).toList();
  }

  Future<SaleReceiptSnapshot> saleReceipt(int saleId) async {
    final invoice = await (db.select(
      db.saleInvoices,
    )..where((sale) => sale.id.equals(saleId))).getSingle();
    Customer? customer;
    if (invoice.customerId != null) {
      customer = await (db.select(
        db.customers,
      )..where((row) => row.id.equals(invoice.customerId!))).getSingleOrNull();
    }

    final items =
        await (db.select(db.saleItems)
              ..where((item) => item.saleId.equals(saleId))
              ..orderBy([(item) => OrderingTerm.asc(item.id)]))
            .get();
    final lines = <SaleReceiptLine>[];
    for (final item in items) {
      final product = await (db.select(
        db.products,
      )..where((product) => product.id.equals(item.productId))).getSingle();
      lines.add(
        SaleReceiptLine(
          productName: product.name,
          qty: item.qty,
          unitPriceMinor: item.unitPriceMinor,
          lineTotalMinor: item.lineTotalMinor,
          productBarcode: product.barcode,
        ),
      );
    }

    final paymentRows =
        await (db.select(db.payments)
              ..where(
                (payment) =>
                    payment.ownerType.equals('sale') &
                    payment.ownerId.equals(saleId),
              )
              ..orderBy([(payment) => OrderingTerm.asc(payment.id)]))
            .get();
    final payments = paymentRows
        .map(
          (payment) => SaleReceiptPayment(
            method: PaymentMethod.values.byName(payment.method),
            amountMinor: payment.amountMinor,
          ),
        )
        .toList();

    return SaleReceiptSnapshot(
      invoice: invoice,
      lines: lines,
      payments: payments,
      shopSettings: await shopSettings(),
      customerName: customer?.name,
    );
  }

  Future<SaleReturnPreview> saleReturnPreview(int saleId) async {
    final receipt = await saleReceipt(saleId);
    final items =
        await (db.select(db.saleItems)
              ..where((item) => item.saleId.equals(saleId))
              ..orderBy([(item) => OrderingTerm.asc(item.id)]))
            .get();
    final lines = <SaleReturnLinePreview>[];
    final netTotals = _netSaleItemTotals(receipt.invoice, items);

    for (final item in items) {
      final product = await (db.select(
        db.products,
      )..where((product) => product.id.equals(item.productId))).getSingle();
      final priorReturns = await (db.select(
        db.saleReturnItems,
      )..where((row) => row.saleItemId.equals(item.id))).get();
      final returnedQty = priorReturns.fold<int>(
        0,
        (sum, row) => sum + row.qty,
      );
      final returnableQty = item.qty - returnedQty;
      final netLineMinor = netTotals[item.id]!;
      final refundedMinor = priorReturns.fold<int>(
        0,
        (sum, row) => sum + row.qty * row.unitPriceMinor,
      );
      lines.add(
        SaleReturnLinePreview(
          saleItemId: item.id,
          productName: product.name,
          soldQty: item.qty,
          returnedQty: returnedQty,
          returnableQty: returnableQty,
          unitPriceMinor: netLineMinor ~/ item.qty,
          lineTotalMinor: _refundForQuantity(
            netLineMinor,
            item.qty,
            returnedQty,
            refundedMinor,
            returnableQty,
          ),
          netLineMinor: netLineMinor,
          refundedMinor: refundedMinor,
        ),
      );
    }

    final customerId = receipt.invoice.customerId;
    final plan = customerId == null
        ? null
        : await (db.select(db.installmentPlans)..where(
                (p) =>
                    p.ownerType.equals('sale') &
                    p.ownerId.equals(saleId) &
                    p.partyType.equals('customer') &
                    p.partyId.equals(customerId),
              ))
              .getSingleOrNull();
    return SaleReturnPreview(
      receipt: receipt,
      lines: lines,
      collectedInstallmentsMinor: plan?.paidMinor ?? 0,
      remainingDebtMinor: plan == null
          ? null
          : math.max(0, plan.totalMinor - plan.paidMinor),
    );
  }

  Future<PurchaseReturnPreview> purchaseReturnPreview(int purchaseId) async {
    final invoice = await (db.select(
      db.purchaseInvoices,
    )..where((purchase) => purchase.id.equals(purchaseId))).getSingle();
    final supplier = invoice.supplierId == null
        ? null
        : await (db.select(db.suppliers)
                ..where((row) => row.id.equals(invoice.supplierId!)))
              .getSingleOrNull();
    final items =
        await (db.select(db.purchaseItems)
              ..where((item) => item.purchaseId.equals(purchaseId))
              ..orderBy([(item) => OrderingTerm.asc(item.id)]))
            .get();
    final lines = <PurchaseReturnLinePreview>[];
    for (final item in items) {
      final product = await (db.select(
        db.products,
      )..where((product) => product.id.equals(item.productId))).getSingle();
      final priorReturns = await (db.select(
        db.purchaseReturnItems,
      )..where((row) => row.purchaseItemId.equals(item.id))).get();
      final returnedQty = priorReturns.fold<int>(
        0,
        (sum, row) => sum + row.qty,
      );
      final returnableQty = item.qty - returnedQty;
      lines.add(
        PurchaseReturnLinePreview(
          purchaseItemId: item.id,
          productName: product.name,
          purchasedQty: item.qty,
          returnedQty: returnedQty,
          returnableQty: returnableQty,
          availableStockQty: math.min(returnableQty, product.stockQty),
          unitCostMinor: item.unitCostMinor,
        ),
      );
    }
    final plan = invoice.supplierId == null
        ? null
        : await (db.select(db.installmentPlans)..where(
                (plan) =>
                    plan.ownerType.equals('purchase') &
                    plan.ownerId.equals(purchaseId) &
                    plan.partyType.equals('supplier') &
                    plan.partyId.equals(invoice.supplierId!),
              ))
              .getSingleOrNull();
    return PurchaseReturnPreview(
      invoice: invoice,
      supplierName: supplier?.name,
      lines: lines,
      remainingDebtMinor: plan == null
          ? null
          : math.max(0, plan.totalMinor - plan.paidMinor),
    );
  }

  Future<List<Product>> searchProducts(String query) async {
    final cleaned = query.trim();
    if (cleaned.isEmpty) {
      return (db.select(db.products)
            ..where((p) => p.isActive.equals(true))
            ..orderBy([(p) => OrderingTerm(expression: p.name)])
            ..limit(20))
          .get();
    }
    final pattern = '%$cleaned%';
    return (db.select(db.products)
          ..where(
            (p) =>
                p.isActive.equals(true) &
                (p.name.like(pattern) | p.barcode.like(pattern)),
          )
          ..orderBy([(p) => OrderingTerm(expression: p.name)])
          ..limit(20))
        .get();
  }

  Future<Product?> findProductByBarcode(String barcode) {
    return (db.select(
      db.products,
    )..where((p) => p.barcode.equals(barcode.trim()))).getSingleOrNull();
  }
}

part of '../v2_use_cases.dart';

/// Conservative, read-only consistency checks for a shop's existing history.
/// The audit reports problems and never rewrites financial history.
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
    final purchaseReturns = await db.select(db.purchaseReturns).get();
    final purchaseReturnItems = await db.select(db.purchaseReturnItems).get();
    final expenses = await db.select(db.expenses).get();
    final financialCorrections = await db.select(db.financialCorrections).get();
    final financialCorrectionReversals = await db
        .select(db.financialCorrectionReversals)
        .get();
    final audit = _IntegrityAuditContext(
      entries: entries,
      lines: lines,
      products: products,
      movements: movements,
      adjustments: adjustments,
      openingBalances: openingBalances,
      customers: customers,
      suppliers: suppliers,
      plans: plans,
      scheduled: scheduled,
      sales: sales,
      saleItems: saleItems,
      purchases: purchases,
      purchaseItems: purchaseItems,
      payments: payments,
      returns: returns,
      returnItems: returnItems,
      purchaseReturns: purchaseReturns,
      purchaseReturnItems: purchaseReturnItems,
      expenses: expenses,
      financialCorrections: financialCorrections,
      financialCorrectionReversals: financialCorrectionReversals,
      checkedAt: clock(),
    );
    audit
      ..auditLedgerStockAndAdjustments()
      ..auditPlansBalancesAndCorrections()
      ..auditInvoicesAndReturns()
      ..auditReferencesAndPartyBalances();
    return audit.result();
  });
}

class _IntegrityAuditContext {
  _IntegrityAuditContext({
    required this.entries,
    required this.lines,
    required this.products,
    required this.movements,
    required this.adjustments,
    required this.openingBalances,
    required this.customers,
    required this.suppliers,
    required this.plans,
    required this.scheduled,
    required this.sales,
    required this.saleItems,
    required this.purchases,
    required this.purchaseItems,
    required this.payments,
    required this.returns,
    required this.returnItems,
    required this.purchaseReturns,
    required this.purchaseReturnItems,
    required this.expenses,
    required this.financialCorrections,
    required this.financialCorrectionReversals,
    required this.checkedAt,
  });

  final List<LedgerEntry> entries;
  final List<LedgerLine> lines;
  final List<Product> products;
  final List<StockMovement> movements;
  final List<InventoryAdjustment> adjustments;
  final List<OpeningBalance> openingBalances;
  final List<Customer> customers;
  final List<Supplier> suppliers;
  final List<InstallmentPlan> plans;
  final List<InstallmentPayment> scheduled;
  final List<SaleInvoice> sales;
  final List<SaleItem> saleItems;
  final List<PurchaseInvoice> purchases;
  final List<PurchaseItem> purchaseItems;
  final List<Payment> payments;
  final List<SaleReturn> returns;
  final List<SaleReturnItem> returnItems;
  final List<PurchaseReturn> purchaseReturns;
  final List<PurchaseReturnItem> purchaseReturnItems;
  final List<Expense> expenses;
  final List<FinancialCorrection> financialCorrections;
  final List<FinancialCorrectionReversal> financialCorrectionReversals;
  final DateTime checkedAt;
  final issues = <DataIntegrityIssue>[];

  DataIntegrityAudit result() => DataIntegrityAudit(
    checkedAt: checkedAt,
    ledgerEntryCount: entries.length,
    productCount: products.length,
    installmentPlanCount: plans.length,
    issues: List.unmodifiable(issues),
  );
}

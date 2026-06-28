part of '../v2_use_cases.dart';

enum PaymentMethod { cash, wallet, installment }

class PaymentInput {
  const PaymentInput(this.method, this.amountMinor, {this.note});

  final PaymentMethod method;
  final int amountMinor;
  final String? note;
}

class NegativeBalanceImpact {
  const NegativeBalanceImpact({
    required this.accountCode,
    required this.label,
    required this.currentMinor,
    required this.deltaMinor,
    required this.newMinor,
  });

  final String accountCode;
  final String label;
  final int currentMinor;
  final int deltaMinor;
  final int newMinor;
}

class NegativeBalanceConfirmation {
  const NegativeBalanceConfirmation({required this.impacts});

  final List<NegativeBalanceImpact> impacts;
}

class SaleLineInput {
  const SaleLineInput({
    required this.productId,
    required this.qty,
    required this.unitPriceMinor,
  });

  final int productId;
  final int qty;
  final int unitPriceMinor;
}

class PurchaseLineInput {
  const PurchaseLineInput({
    required this.productId,
    required this.qty,
    required this.unitCostMinor,
  });

  final int productId;
  final int qty;
  final int unitCostMinor;
}

class InstallmentTerms {
  const InstallmentTerms({
    required this.partyId,
    required this.count,
    required this.firstDueDate,
    this.interestMinor = 0,
    this.periodDays = 30,
  });

  final int partyId;
  final int count;
  final DateTime firstDueDate;
  final int interestMinor;
  final int periodDays;
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.cashMinor,
    required this.walletMinor,
    required this.receivablesMinor,
    required this.payablesMinor,
    required this.inventoryMinor,
    required this.salesMinor,
    required this.cogsMinor,
    required this.expensesMinor,
    required this.lowStockCount,
    required this.openShift,
  });

  final int cashMinor;
  final int walletMinor;
  final int receivablesMinor;
  final int payablesMinor;
  final int inventoryMinor;
  final int salesMinor;
  final int cogsMinor;
  final int expensesMinor;
  final int lowStockCount;
  final Shift? openShift;

  int get grossProfitMinor => salesMinor - cogsMinor - expensesMinor;
}

class DailySummarySnapshot {
  const DailySummarySnapshot({
    required this.date,
    required this.salesMinor,
    required this.cogsMinor,
    required this.expensesMinor,
    required this.interestMinor,
    required this.cashNetMinor,
    required this.walletNetMinor,
    required this.purchaseMinor,
    required this.saleCount,
    required this.purchaseCount,
    required this.returnCount,
  });

  final DateTime date;
  final int salesMinor;
  final int cogsMinor;
  final int expensesMinor;
  final int interestMinor;
  final int cashNetMinor;
  final int walletNetMinor;
  final int purchaseMinor;
  final int saleCount;
  final int purchaseCount;
  final int returnCount;

  int get profitMinor => salesMinor + interestMinor - cogsMinor - expensesMinor;
}

class PeriodReportSnapshot {
  const PeriodReportSnapshot({
    required this.start,
    required this.end,
    required this.salesMinor,
    required this.cogsMinor,
    required this.expensesMinor,
    required this.interestMinor,
    required this.cashNetMinor,
    required this.walletNetMinor,
    required this.purchaseMinor,
    required this.saleCount,
    required this.purchaseCount,
    required this.returnCount,
  });

  final DateTime start;
  final DateTime end;
  final int salesMinor;
  final int cogsMinor;
  final int expensesMinor;
  final int interestMinor;
  final int cashNetMinor;
  final int walletNetMinor;
  final int purchaseMinor;
  final int saleCount;
  final int purchaseCount;
  final int returnCount;

  int get profitMinor => salesMinor + interestMinor - cogsMinor - expensesMinor;
}

class PartyBalance {
  const PartyBalance({
    required this.id,
    required this.name,
    required this.type,
    required this.balanceMinor,
    this.phone,
  });

  final int id;
  final String name;
  final String type;
  final int balanceMinor;
  final String? phone;
}

class LedgerEntryPreview {
  const LedgerEntryPreview({
    required this.entry,
    required this.debitMinor,
    required this.creditMinor,
  });

  final LedgerEntry entry;
  final int debitMinor;
  final int creditMinor;
}

class PartyStatementLine {
  const PartyStatementLine({
    required this.entry,
    required this.debitMinor,
    required this.creditMinor,
    required this.balanceMinor,
    this.invoiceDetails,
  });

  final LedgerEntry entry;
  final int debitMinor;
  final int creditMinor;
  final int balanceMinor;
  final StatementInvoiceDetails? invoiceDetails;
}

class StatementInvoiceDetails {
  const StatementInvoiceDetails({
    required this.type,
    required this.invoiceNo,
    required this.createdAt,
    required this.totalMinor,
    required this.paidMinor,
    required this.remainingMinor,
    required this.items,
    required this.payments,
    required this.installments,
    this.subtotalMinor,
    this.discountMinor = 0,
    this.interestMinor = 0,
  });

  final String type;
  final String invoiceNo;
  final DateTime createdAt;
  final int? subtotalMinor;
  final int discountMinor;
  final int interestMinor;
  final int totalMinor;
  final int paidMinor;
  final int remainingMinor;
  final List<StatementInvoiceItem> items;
  final List<StatementPaymentDetail> payments;
  final List<StatementInstallmentDetail> installments;
}

class StatementInvoiceItem {
  const StatementInvoiceItem({
    required this.productName,
    required this.qty,
    required this.unitMinor,
    required this.lineTotalMinor,
  });

  final String productName;
  final int qty;
  final int unitMinor;
  final int lineTotalMinor;
}

class StatementPaymentDetail {
  const StatementPaymentDetail({
    required this.method,
    required this.amountMinor,
    required this.createdAt,
  });

  final PaymentMethod method;
  final int amountMinor;
  final DateTime createdAt;
}

class StatementInstallmentDetail {
  const StatementInstallmentDetail({
    required this.amountMinor,
    required this.dueDate,
    required this.status,
    this.paidAt,
  });

  final int amountMinor;
  final DateTime dueDate;
  final String status;
  final DateTime? paidAt;
}

class SaleReceiptLine {
  const SaleReceiptLine({
    required this.productName,
    required this.qty,
    required this.unitPriceMinor,
    required this.lineTotalMinor,
    this.productBarcode,
  });

  final String productName;
  final int qty;
  final int unitPriceMinor;
  final int lineTotalMinor;
  final String? productBarcode;
}

class SaleReceiptPayment {
  const SaleReceiptPayment({required this.method, required this.amountMinor});

  final PaymentMethod method;
  final int amountMinor;
}

class SaleReceiptSnapshot {
  const SaleReceiptSnapshot({
    required this.invoice,
    required this.lines,
    required this.payments,
    required this.shopSettings,
    this.customerName,
  });

  final SaleInvoice invoice;
  final List<SaleReceiptLine> lines;
  final List<SaleReceiptPayment> payments;
  final ShopSettingsSnapshot shopSettings;
  final String? customerName;
}

class SaleReturnLinePreview {
  const SaleReturnLinePreview({
    required this.saleItemId,
    required this.productName,
    required this.soldQty,
    required this.returnedQty,
    required this.returnableQty,
    required this.unitPriceMinor,
    required this.lineTotalMinor,
  });

  final int saleItemId;
  final String productName;
  final int soldQty;
  final int returnedQty;
  final int returnableQty;
  final int unitPriceMinor;
  final int lineTotalMinor;
}

class SaleReturnPreview {
  const SaleReturnPreview({required this.receipt, required this.lines});

  final SaleReceiptSnapshot receipt;
  final List<SaleReturnLinePreview> lines;
}

class ShopSettingsSnapshot {
  const ShopSettingsSnapshot({
    required this.shopName,
    this.phone,
    this.address,
    this.receiptFooter,
  });

  final String shopName;
  final String? phone;
  final String? address;
  final String? receiptFooter;
}

class UiBackgroundSnapshot {
  const UiBackgroundSnapshot({required this.preset, this.imagePath});

  final String preset;
  final String? imagePath;
}

class BackupStatus {
  const BackupStatus({
    this.directory,
    this.lastDate,
    this.latestBackupPath,
    this.backupCount = 0,
    this.retentionCopies = 30,
  });

  final String? directory;
  final String? lastDate;
  final String? latestBackupPath;
  final int backupCount;
  final int retentionCopies;
}

class InstallmentDuePreview {
  const InstallmentDuePreview({
    required this.plan,
    required this.payment,
    required this.partyName,
    required this.remainingMinor,
    required this.isOverdue,
  });

  final InstallmentPlan plan;
  final InstallmentPayment payment;
  final String partyName;
  final int remainingMinor;
  final bool isOverdue;
}

class InstallmentPlanPreview {
  const InstallmentPlanPreview({
    required this.plan,
    required this.partyName,
    required this.remainingMinor,
    required this.overdueMinor,
    required this.dueSoonMinor,
    required this.nextDueMinor,
    required this.schedule,
    this.nextDueDate,
  });

  final InstallmentPlan plan;
  final String partyName;
  final int remainingMinor;
  final int overdueMinor;
  final int dueSoonMinor;
  final int nextDueMinor;
  final List<InstallmentSchedulePreview> schedule;
  final DateTime? nextDueDate;

  bool get isOverdue => overdueMinor > 0;
  bool get isDueSoon => dueSoonMinor > 0;
}

class InstallmentSchedulePreview {
  const InstallmentSchedulePreview({
    required this.payment,
    required this.paidMinor,
    required this.remainingMinor,
    required this.isOverdue,
    required this.isDueSoon,
  });

  final InstallmentPayment payment;
  final int paidMinor;
  final int remainingMinor;
  final bool isOverdue;
  final bool isDueSoon;
}

class WorkbenchSnapshot {
  const WorkbenchSnapshot({
    required this.dashboard,
    required this.dailySummary,
    required this.products,
    required this.customers,
    required this.suppliers,
    required this.customerBalances,
    required this.supplierBalances,
    required this.installmentPlans,
    required this.recentLedger,
    required this.recentSales,
    required this.recentPurchases,
    required this.dueInstallments,
    required this.installmentSummaries,
    required this.backupStatus,
    required this.shopSettings,
    required this.uiBackground,
  });

  final DashboardSnapshot dashboard;
  final DailySummarySnapshot dailySummary;
  final List<Product> products;
  final List<Customer> customers;
  final List<Supplier> suppliers;
  final List<PartyBalance> customerBalances;
  final List<PartyBalance> supplierBalances;
  final List<InstallmentPlan> installmentPlans;
  final List<LedgerEntryPreview> recentLedger;
  final List<SaleInvoice> recentSales;
  final List<PurchaseInvoice> recentPurchases;
  final List<InstallmentDuePreview> dueInstallments;
  final List<InstallmentPlanPreview> installmentSummaries;
  final BackupStatus backupStatus;
  final ShopSettingsSnapshot shopSettings;
  final UiBackgroundSnapshot uiBackground;
}

class RestoreFileOperations {
  const RestoreFileOperations();

  Future<void> copyFile(File source, File target) async {
    await source.copy(target.path);
  }

  Future<void> deleteFileIfExists(File file) async {
    if (await file.exists()) await file.delete();
  }
}

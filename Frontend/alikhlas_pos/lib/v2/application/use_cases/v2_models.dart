part of '../v2_use_cases.dart';

enum PaymentMethod { cash, wallet, installment }

enum InventoryAdjustmentReason {
  physicalCount('جرد فعلي'),
  damage('تالف'),
  loss('فقد أو سرقة'),
  found('بضاعة وُجدت'),
  dataCorrection('تصحيح إدخال');

  const InventoryAdjustmentReason(this.label);

  final String label;
}

enum OpeningBalanceType {
  customerReceivable('رصيد على عميل'),
  supplierPayable('رصيد لمورد'),
  cash('رصيد الخزينة'),
  wallet('رصيد المحفظة');

  const OpeningBalanceType(this.label);

  final String label;

  bool get requiresParty =>
      this == customerReceivable || this == supplierPayable;
}

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

/// Shown once to the shop owner after the first setup. The code itself is
/// never persisted; only a password-strength verifier is stored locally.
class InitialOwnerSetup {
  const InitialOwnerSetup({required this.owner, required this.recoveryCode});

  final User owner;
  final String recoveryCode;
}

/// A successful recovery rotates the old recovery code before returning it.
class OwnerRecovery {
  const OwnerRecovery({required this.owner, required this.recoveryCode});

  final User owner;
  final String recoveryCode;
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
    this.inventoryVarianceMinor = 0,
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
  final int inventoryVarianceMinor;
  final int lowStockCount;
  final Shift? openShift;

  int get grossProfitMinor =>
      salesMinor - cogsMinor - expensesMinor - inventoryVarianceMinor;
}

class DailySummarySnapshot {
  const DailySummarySnapshot({
    required this.date,
    required this.salesMinor,
    required this.cogsMinor,
    required this.expensesMinor,
    this.inventoryVarianceMinor = 0,
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
  final int inventoryVarianceMinor;
  final int interestMinor;
  final int cashNetMinor;
  final int walletNetMinor;
  final int purchaseMinor;
  final int saleCount;
  final int purchaseCount;
  final int returnCount;

  int get profitMinor =>
      salesMinor +
      interestMinor -
      cogsMinor -
      expensesMinor -
      inventoryVarianceMinor;
}

/// Read-only result for a consistency check; it never changes historical data.
class DataIntegrityAudit {
  const DataIntegrityAudit({
    required this.checkedAt,
    required this.ledgerEntryCount,
    required this.productCount,
    required this.installmentPlanCount,
    required this.issues,
  });

  final DateTime checkedAt;
  final int ledgerEntryCount;
  final int productCount;
  final int installmentPlanCount;
  final List<DataIntegrityIssue> issues;

  bool get isConsistent => issues.isEmpty;
}

class DataIntegrityIssue {
  const DataIntegrityIssue({
    required this.code,
    required this.record,
    required this.message,
  });

  final String code;
  final String record;
  final String message;
}

class PeriodReportSnapshot {
  const PeriodReportSnapshot({
    required this.start,
    required this.end,
    required this.salesMinor,
    required this.cogsMinor,
    required this.expensesMinor,
    this.inventoryVarianceMinor = 0,
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
  final int inventoryVarianceMinor;
  final int interestMinor;
  final int cashNetMinor;
  final int walletNetMinor;
  final int purchaseMinor;
  final int saleCount;
  final int purchaseCount;
  final int returnCount;

  int get profitMinor =>
      salesMinor +
      interestMinor -
      cogsMinor -
      expensesMinor -
      inventoryVarianceMinor;
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
    this.returnedMinor = 0,
  });

  final String type;
  final String invoiceNo;
  final DateTime createdAt;
  final int? subtotalMinor;
  final int discountMinor;
  final int interestMinor;
  final int returnedMinor;
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
    required this.paidMinor,
    required this.remainingMinor,
    required this.dueDate,
    required this.status,
    this.paidAt,
  });

  final int amountMinor;
  final int paidMinor;
  final int remainingMinor;
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
    required this.netLineMinor,
    required this.refundedMinor,
  });

  final int saleItemId;
  final String productName;
  final int soldQty;
  final int returnedQty;
  final int returnableQty;
  final int unitPriceMinor;
  final int lineTotalMinor;
  final int netLineMinor;
  final int refundedMinor;

  int refundForQuantity(int quantity) => _refundForQuantity(
    netLineMinor,
    soldQty,
    returnedQty,
    refundedMinor,
    quantity,
  );
}

int _refundForQuantity(
  int netLineMinor,
  int soldQty,
  int returnedQty,
  int refundedMinor,
  int quantity,
) {
  if (quantity < 0 || quantity > soldQty - returnedQty) {
    throw RangeError('Invalid return quantity');
  }
  if (quantity == 0) return 0;
  final cumulative =
      (BigInt.from(netLineMinor) *
              BigInt.from(returnedQty + quantity) ~/
              BigInt.from(soldQty))
          .toInt();
  // Never issue more money to compensate for an over-refund in legacy data.
  return math.max(0, cumulative - refundedMinor);
}

class SaleReturnPreview {
  const SaleReturnPreview({
    required this.receipt,
    required this.lines,
    this.remainingDebtMinor,
    this.collectedInstallmentsMinor = 0,
  });

  /// Current plan debt; null when this invoice has no installment plan.
  final int? remainingDebtMinor;
  final int collectedInstallmentsMinor;

  final SaleReceiptSnapshot receipt;
  final List<SaleReturnLinePreview> lines;
}

class PurchaseReturnLinePreview {
  const PurchaseReturnLinePreview({
    required this.purchaseItemId,
    required this.productName,
    required this.purchasedQty,
    required this.returnedQty,
    required this.returnableQty,
    required this.availableStockQty,
    required this.unitCostMinor,
  });

  final int purchaseItemId;
  final String productName;
  final int purchasedQty;
  final int returnedQty;

  /// Quantity still eligible under the original purchase document.
  final int returnableQty;

  /// Current stock caps an otherwise eligible supplier return.
  final int availableStockQty;
  final int unitCostMinor;

  int creditForQuantity(int quantity) {
    if (quantity < 0 || quantity > availableStockQty) {
      throw RangeError('Invalid purchase return quantity');
    }
    return quantity * unitCostMinor;
  }
}

class PurchaseReturnPreview {
  const PurchaseReturnPreview({
    required this.invoice,
    required this.supplierName,
    required this.lines,
    this.remainingDebtMinor,
  });

  final PurchaseInvoice invoice;
  final String? supplierName;
  final List<PurchaseReturnLinePreview> lines;

  /// Current supplier debt for this invoice; null if it was never bought on
  /// credit. A return can still be settled to cash or wallet in that case.
  final int? remainingDebtMinor;
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

class BarcodeLabelSettingsSnapshot {
  const BarcodeLabelSettingsSnapshot({
    required this.widthMm,
    required this.heightMm,
  });

  static const defaultWidthMm = 40;
  static const defaultHeightMm = 30;
  static const minWidthMm = 20;
  static const maxWidthMm = 100;
  static const minHeightMm = 15;
  static const maxHeightMm = 80;

  final int widthMm;
  final int heightMm;
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
    this.warning,
  });

  final String? directory;
  final String? lastDate;
  final String? latestBackupPath;
  final int backupCount;
  final int retentionCopies;
  final String? warning;
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
    required this.barcodeLabelSettings,
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
  final BarcodeLabelSettingsSnapshot barcodeLabelSettings;
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

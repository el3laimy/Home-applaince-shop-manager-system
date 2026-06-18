import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../accounting/account_codes.dart';
import '../core/money.dart';
import '../core/result.dart';
import '../data/app_database.dart';

enum PaymentMethod { cash, wallet, installment }

class PaymentInput {
  const PaymentInput(this.method, this.amountMinor, {this.note});

  final PaymentMethod method;
  final int amountMinor;
  final String? note;
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
  });

  final LedgerEntry entry;
  final int debitMinor;
  final int creditMinor;
  final int balanceMinor;
}

class SaleReceiptLine {
  const SaleReceiptLine({
    required this.productName,
    required this.qty,
    required this.unitPriceMinor,
    required this.lineTotalMinor,
  });

  final String productName;
  final int qty;
  final int unitPriceMinor;
  final int lineTotalMinor;
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
    this.nextDueDate,
  });

  final InstallmentPlan plan;
  final String partyName;
  final int remainingMinor;
  final int overdueMinor;
  final int dueSoonMinor;
  final int nextDueMinor;
  final DateTime? nextDueDate;

  bool get isOverdue => overdueMinor > 0;
  bool get isDueSoon => dueSoonMinor > 0;
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
}

class V2UseCases {
  V2UseCases(this.db);

  static const _passwordHashPrefix = 'pbkdf2_sha256';
  static const _passwordIterations = 120000;
  static const _passwordSaltLength = 16;
  static const _passwordKeyLength = 32;

  final AppDatabase db;

  Future<void> bootstrap() async {
    final hasOwner = await db.select(db.users).getSingleOrNull();
    if (hasOwner == null) {
      await db
          .into(db.users)
          .insert(
            UsersCompanion.insert(
              username: 'owner',
              passwordHash: _hashPassword('owner123'),
              fullName: 'مالك المحل',
              mustChangePassword: const Value(true),
            ),
          );
    }

    await _upsertSetting('backup.keepCopies', '30');
    await _upsertSetting('app.currency', 'EGP');
    await _upsertSettingIfMissing('shop.name', 'إخلاص للأجهزة المنزلية');
    await _upsertSettingIfMissing('shop.receiptFooter', 'شكرا لتعاملكم معنا');
    await runAutomaticBackupIfDue();
  }

  Future<AppResult<User>> login(String username, String password) async {
    final user = await (db.select(
      db.users,
    )..where((u) => u.username.equals(username.trim()))).getSingleOrNull();
    if (user == null) {
      return const AppFailure('اسم المستخدم أو كلمة المرور غير صحيحة');
    }
    final verification = _verifyPassword(password, user.passwordHash);
    if (!verification.isValid) {
      return const AppFailure('اسم المستخدم أو كلمة المرور غير صحيحة');
    }
    if (!verification.needsRehash) return AppSuccess(user);

    final upgradedHash = _hashPassword(password);
    await (db.update(db.users)..where((u) => u.id.equals(user.id))).write(
      UsersCompanion(passwordHash: Value(upgradedHash)),
    );
    return AppSuccess(
      await (db.select(
        db.users,
      )..where((u) => u.id.equals(user.id))).getSingle(),
    );
  }

  Future<AppResult<User>> changePassword(int userId, String newPassword) async {
    if (newPassword.length < 6) {
      return const AppFailure('كلمة المرور يجب ألا تقل عن 6 أحرف');
    }
    await (db.update(db.users)..where((u) => u.id.equals(userId))).write(
      UsersCompanion(
        passwordHash: Value(_hashPassword(newPassword)),
        mustChangePassword: const Value(false),
      ),
    );
    final updated = await (db.select(
      db.users,
    )..where((u) => u.id.equals(userId))).getSingle();
    return AppSuccess(updated);
  }

  Future<AppResult<Shift>> openShift(int openingCashMinor) async {
    final open = await currentShift();
    if (open != null) {
      return const AppFailure('توجد وردية مفتوحة بالفعل');
    }

    final id = await db
        .into(db.shifts)
        .insert(
          ShiftsCompanion.insert(
            openedAt: DateTime.now(),
            openingCashMinor: openingCashMinor,
          ),
        );
    return AppSuccess(
      await (db.select(db.shifts)..where((s) => s.id.equals(id))).getSingle(),
    );
  }

  Future<Shift?> currentShift() {
    return (db.select(
      db.shifts,
    )..where((s) => s.status.equals('open'))).getSingleOrNull();
  }

  Future<AppResult<Shift>> closeShift(int actualCashMinor) async {
    final shift = await currentShift();
    if (shift == null) {
      return const AppFailure('لا توجد وردية مفتوحة');
    }

    final cashDelta = await _accountNetSince(AccountCodes.cash, shift.openedAt);
    final expected = shift.openingCashMinor + cashDelta;
    final difference = actualCashMinor - expected;
    final closedAt = DateTime.now();

    await (db.update(db.shifts)..where((s) => s.id.equals(shift.id))).write(
      ShiftsCompanion(
        closedAt: Value(closedAt),
        expectedCashMinor: Value(expected),
        actualCashMinor: Value(actualCashMinor),
        differenceMinor: Value(difference),
        status: const Value('closed'),
      ),
    );

    return AppSuccess(
      await (db.select(
        db.shifts,
      )..where((s) => s.id.equals(shift.id))).getSingle(),
    );
  }

  Future<AppResult<Product>> createProduct({
    required String name,
    String? barcode,
    String? category,
    required int salePriceMinor,
    required int openingQty,
    required int openingCostMinor,
    int minStockQty = 1,
  }) async {
    if (name.trim().isEmpty) return const AppFailure('اسم المنتج مطلوب');
    if (salePriceMinor <= 0 || openingQty < 0 || openingCostMinor < 0) {
      return const AppFailure(
        'سعر البيع يجب أن يكون أكبر من صفر والقيم لا يمكن أن تكون سالبة',
      );
    }

    final cleanBarcode = barcode?.trim();
    if (cleanBarcode != null && cleanBarcode.isNotEmpty) {
      final duplicate = await (db.select(
        db.products,
      )..where((p) => p.barcode.equals(cleanBarcode))).getSingleOrNull();
      if (duplicate != null) return const AppFailure('الباركود مستخدم بالفعل');
    }

    final id = await db.transaction(() async {
      final productId = await db
          .into(db.products)
          .insert(
            ProductsCompanion.insert(
              name: name.trim(),
              barcode: Value(
                cleanBarcode == null || cleanBarcode.isEmpty
                    ? null
                    : cleanBarcode,
              ),
              category: Value(
                category?.trim().isEmpty == true ? null : category?.trim(),
              ),
              salePriceMinor: salePriceMinor,
              stockQty: Value(openingQty),
              avgCostMinor: Value(openingCostMinor),
              minStockQty: Value(minStockQty),
            ),
          );

      if (openingQty > 0 && openingCostMinor > 0) {
        final value = openingQty * openingCostMinor;
        await _postLedger(
          referenceType: 'opening_stock',
          referenceId: productId,
          description: 'رصيد افتتاحي للمخزون',
          lines: [
            _LedgerLineDraft(AccountCodes.inventory, debitMinor: value),
            _LedgerLineDraft(AccountCodes.capital, creditMinor: value),
          ],
        );
      }
      return productId;
    });

    return AppSuccess(
      await (db.select(db.products)..where((p) => p.id.equals(id))).getSingle(),
    );
  }

  Future<AppResult<Product>> updateProduct({
    required int id,
    required String name,
    String? barcode,
    String? category,
    required int salePriceMinor,
    required int minStockQty,
  }) async {
    if (name.trim().isEmpty) return const AppFailure('اسم المنتج مطلوب');
    if (salePriceMinor <= 0 || minStockQty < 0) {
      return const AppFailure(
        'السعر يجب أن يكون أكبر من صفر والحد الأدنى غير سالب',
      );
    }

    final cleanBarcode = barcode?.trim();
    if (cleanBarcode != null && cleanBarcode.isNotEmpty) {
      final duplicate =
          await (db.select(db.products)..where(
                (p) => p.barcode.equals(cleanBarcode) & p.id.equals(id).not(),
              ))
              .getSingleOrNull();
      if (duplicate != null) return const AppFailure('الباركود مستخدم بالفعل');
    }

    await (db.update(db.products)..where((p) => p.id.equals(id))).write(
      ProductsCompanion(
        name: Value(name.trim()),
        barcode: Value(
          cleanBarcode == null || cleanBarcode.isEmpty ? null : cleanBarcode,
        ),
        category: Value(
          category?.trim().isEmpty == true ? null : category?.trim(),
        ),
        salePriceMinor: Value(salePriceMinor),
        minStockQty: Value(minStockQty),
        updatedAt: Value(DateTime.now()),
      ),
    );

    return AppSuccess(
      await (db.select(db.products)..where((p) => p.id.equals(id))).getSingle(),
    );
  }

  Future<AppResult<void>> deactivateProduct(int id) async {
    await (db.update(db.products)..where((p) => p.id.equals(id))).write(
      ProductsCompanion(
        isActive: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return const AppSuccess(null);
  }

  Future<AppResult<Customer>> createCustomer({
    required String name,
    String? phone,
  }) async {
    if (name.trim().isEmpty) {
      return const AppFailure('اسم العميل مطلوب');
    }

    final id = await db
        .into(db.customers)
        .insert(
          CustomersCompanion.insert(
            name: name.trim(),
            phone: Value(phone?.trim().isEmpty == true ? null : phone?.trim()),
          ),
        );
    return AppSuccess(
      await (db.select(
        db.customers,
      )..where((c) => c.id.equals(id))).getSingle(),
    );
  }

  Future<AppResult<Customer>> updateCustomer({
    required int id,
    required String name,
    String? phone,
  }) async {
    if (name.trim().isEmpty) return const AppFailure('اسم العميل مطلوب');
    await (db.update(db.customers)..where((c) => c.id.equals(id))).write(
      CustomersCompanion(
        name: Value(name.trim()),
        phone: Value(phone?.trim().isEmpty == true ? null : phone?.trim()),
      ),
    );
    return AppSuccess(
      await (db.select(
        db.customers,
      )..where((c) => c.id.equals(id))).getSingle(),
    );
  }

  Future<AppResult<Supplier>> createSupplier({
    required String name,
    String? phone,
  }) async {
    if (name.trim().isEmpty) {
      return const AppFailure('اسم المورد مطلوب');
    }

    final id = await db
        .into(db.suppliers)
        .insert(
          SuppliersCompanion.insert(
            name: name.trim(),
            phone: Value(phone?.trim().isEmpty == true ? null : phone?.trim()),
          ),
        );
    return AppSuccess(
      await (db.select(
        db.suppliers,
      )..where((s) => s.id.equals(id))).getSingle(),
    );
  }

  Future<AppResult<Supplier>> updateSupplier({
    required int id,
    required String name,
    String? phone,
  }) async {
    if (name.trim().isEmpty) return const AppFailure('اسم المورد مطلوب');
    await (db.update(db.suppliers)..where((s) => s.id.equals(id))).write(
      SuppliersCompanion(
        name: Value(name.trim()),
        phone: Value(phone?.trim().isEmpty == true ? null : phone?.trim()),
      ),
    );
    return AppSuccess(
      await (db.select(
        db.suppliers,
      )..where((s) => s.id.equals(id))).getSingle(),
    );
  }

  Future<AppResult<int>> createSale({
    int? customerId,
    required List<SaleLineInput> items,
    required List<PaymentInput> payments,
    InstallmentTerms? installmentTerms,
    int discountMinor = 0,
  }) async {
    if (items.isEmpty) return const AppFailure('أضف صنفًا واحدًا على الأقل');
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
      final saleId = await db.transaction(() async {
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

  Future<AppResult<int>> createPurchase({
    int? supplierId,
    required List<PurchaseLineInput> items,
    required List<PaymentInput> payments,
  }) async {
    if (items.isEmpty) return const AppFailure('أضف صنفًا واحدًا على الأقل');
    if (payments.any((payment) => payment.amountMinor < 0)) {
      return const AppFailure('المدفوعات لا يمكن أن تكون سالبة');
    }
    final shift = await currentShift();
    if (payments.any((p) => p.method == PaymentMethod.cash) && shift == null) {
      return const AppFailure('افتح وردية قبل دفع مشتريات نقدية');
    }

    try {
      final purchaseId = await db.transaction(() async {
        var total = 0;
        final products = <int, Product>{};
        for (final item in items) {
          if (item.qty <= 0 || item.unitCostMinor < 0) {
            throw _BusinessError('تحقق من الكمية وسعر الشراء');
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
          await db
              .into(db.installmentPlans)
              .insert(
                InstallmentPlansCompanion.insert(
                  ownerType: 'purchase',
                  ownerId: purchaseId,
                  partyType: 'supplier',
                  partyId: supplierId,
                  principalMinor: remaining,
                  totalMinor: remaining,
                  installmentCount: 1,
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

        return purchaseId;
      });
      return AppSuccess(purchaseId);
    } on _BusinessError catch (e) {
      return AppFailure(e.message);
    }
  }

  Future<AppResult<int>> createSaleReturn({
    required int saleId,
    required Map<int, int> saleItemQuantities,
    required PaymentMethod refundMethod,
    PaymentMethod? overflowRefundMethod,
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
      final returnId = await db.transaction(() async {
        final sale = await (db.select(
          db.saleInvoices,
        )..where((s) => s.id.equals(saleId))).getSingleOrNull();
        if (sale == null) throw _BusinessError('فاتورة البيع غير موجودة');
        if (refundMethod == PaymentMethod.installment &&
            sale.customerId == null) {
          throw _BusinessError('مرتجع التقسيط يحتاج فاتورة مرتبطة بعميل');
        }

        var refund = 0;
        var returnedCost = 0;
        final returnNo = await _nextNumber('returnNo', prefix: 'R');
        final returnId = await db
            .into(db.saleReturns)
            .insert(
              SaleReturnsCompanion.insert(
                saleId: saleId,
                returnNo: returnNo,
                refundMinor: 0,
              ),
            );

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
          final refundUnitPrice = _netSaleItemUnitPrice(sale, saleItem);

          final product = await (db.select(
            db.products,
          )..where((p) => p.id.equals(saleItem.productId))).getSingle();
          final newQty = product.stockQty + qty;
          await (db.update(
            db.products,
          )..where((p) => p.id.equals(product.id))).write(
            ProductsCompanion(
              stockQty: Value(newQty),
              updatedAt: Value(DateTime.now()),
            ),
          );

          await db
              .into(db.saleReturnItems)
              .insert(
                SaleReturnItemsCompanion.insert(
                  returnId: returnId,
                  saleItemId: saleItem.id,
                  productId: product.id,
                  qty: qty,
                  unitPriceMinor: refundUnitPrice,
                  unitCostMinor: saleItem.unitCostMinor,
                ),
              );
          await db
              .into(db.stockMovements)
              .insert(
                StockMovementsCompanion.insert(
                  productId: product.id,
                  type: 'sale_return',
                  qtyDelta: qty,
                  balanceAfter: newQty,
                  referenceType: 'sale_return',
                  referenceId: returnId,
                ),
              );
          refund += qty * refundUnitPrice;
          // Sale returns reverse inventory at the historical sold cost; current WAC is not recalculated in v2.
          returnedCost += qty * saleItem.unitCostMinor;
        }

        await (db.update(db.saleReturns)..where((r) => r.id.equals(returnId)))
            .write(SaleReturnsCompanion(refundMinor: Value(refund)));

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

          await _reduceInstallmentPlanForReturn(
            plan: plan,
            settlementMinor: receivableSettlement,
          );
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

        await _postLedger(
          referenceType: 'sale_return',
          referenceId: returnId,
          description: 'مرتجع بيع $returnNo',
          lines: [
            _LedgerLineDraft(AccountCodes.sales, debitMinor: refund),
            ...creditLines,
          ],
        );

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

  Future<AppResult<int>> recordExpense({
    required String description,
    required int amountMinor,
    required PaymentMethod method,
  }) async {
    if (description.trim().isEmpty) {
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

    final expenseId = await db.transaction(() async {
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
        description: 'مصروف: ${description.trim()}',
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

  int _netSaleItemUnitPrice(SaleInvoice sale, SaleItem saleItem) {
    if (sale.discountMinor == 0 || sale.subtotalMinor == 0) {
      return saleItem.unitPriceMinor;
    }
    final netSubtotal = sale.subtotalMinor - sale.discountMinor;
    return (saleItem.unitPriceMinor * netSubtotal / sale.subtotalMinor).round();
  }

  Future<AppResult<int>> collectInstallment({
    required int planId,
    required int amountMinor,
    required PaymentMethod method,
  }) async {
    return _settleInstallment(
      planId: planId,
      amountMinor: amountMinor,
      method: method,
      expectedPartyType: 'customer',
      debitAccount: method == PaymentMethod.cash
          ? AccountCodes.cash
          : AccountCodes.wallet,
      creditAccount: AccountCodes.receivables,
      description: 'تحصيل قسط عميل',
    );
  }

  Future<AppResult<int>> paySupplierInstallment({
    required int planId,
    required int amountMinor,
    required PaymentMethod method,
  }) async {
    return _settleInstallment(
      planId: planId,
      amountMinor: amountMinor,
      method: method,
      expectedPartyType: 'supplier',
      debitAccount: AccountCodes.payables,
      creditAccount: method == PaymentMethod.cash
          ? AccountCodes.cash
          : AccountCodes.wallet,
      description: 'سداد قسط مورد',
    );
  }

  Future<DashboardSnapshot> dashboardSnapshot() async {
    return DashboardSnapshot(
      cashMinor: await _accountBalance(AccountCodes.cash),
      walletMinor: await _accountBalance(AccountCodes.wallet),
      receivablesMinor: await _accountBalance(AccountCodes.receivables),
      payablesMinor: await _accountBalance(AccountCodes.payables),
      inventoryMinor: await _accountBalance(AccountCodes.inventory),
      salesMinor: -(await _accountBalance(AccountCodes.sales)),
      cogsMinor: await _accountBalance(AccountCodes.cogs),
      expensesMinor: await _accountBalance(AccountCodes.expenses),
      lowStockCount:
          await (db.select(db.products)..where(
                (p) =>
                    p.isActive.equals(true) &
                    p.stockQty.isSmallerOrEqual(p.minStockQty),
              ))
              .get()
              .then((rows) => rows.length),
      openShift: await currentShift(),
    );
  }

  Future<WorkbenchSnapshot> workbenchSnapshot() async {
    final products = await (db.select(
      db.products,
    )..orderBy([(p) => OrderingTerm(expression: p.name)])).get();
    final customers = await (db.select(
      db.customers,
    )..orderBy([(c) => OrderingTerm(expression: c.name)])).get();
    final suppliers = await (db.select(
      db.suppliers,
    )..orderBy([(s) => OrderingTerm(expression: s.name)])).get();
    final plans =
        await (db.select(db.installmentPlans)
              ..where((p) => p.status.equals('open'))
              ..orderBy([
                (p) => OrderingTerm(
                  expression: p.createdAt,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();
    final recentSales =
        await (db.select(db.saleInvoices)
              ..orderBy([
                (s) => OrderingTerm(
                  expression: s.createdAt,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(8))
            .get();
    final recentPurchases =
        await (db.select(db.purchaseInvoices)
              ..orderBy([
                (p) => OrderingTerm(
                  expression: p.createdAt,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(8))
            .get();

    return WorkbenchSnapshot(
      dashboard: await dashboardSnapshot(),
      dailySummary: await _dailySummary(DateTime.now()),
      products: products,
      customers: customers,
      suppliers: suppliers,
      customerBalances: await _partyBalances(
        partyType: 'customer',
        accountCode: AccountCodes.receivables,
        names: {for (final customer in customers) customer.id: customer.name},
        phones: {for (final customer in customers) customer.id: customer.phone},
      ),
      supplierBalances: await _partyBalances(
        partyType: 'supplier',
        accountCode: AccountCodes.payables,
        names: {for (final supplier in suppliers) supplier.id: supplier.name},
        phones: {for (final supplier in suppliers) supplier.id: supplier.phone},
      ),
      installmentPlans: plans,
      recentLedger: await _recentLedgerEntries(),
      recentSales: recentSales,
      recentPurchases: recentPurchases,
      dueInstallments: await _dueInstallments(
        plans: plans,
        customers: customers,
        suppliers: suppliers,
      ),
      installmentSummaries: await _installmentSummaries(
        plans: plans,
        customers: customers,
        suppliers: suppliers,
      ),
      backupStatus: await _backupStatus(),
      shopSettings: await shopSettings(),
    );
  }

  Future<ShopSettingsSnapshot> shopSettings() async {
    return ShopSettingsSnapshot(
      shopName: await _settingValue('shop.name') ?? 'إخلاص للأجهزة المنزلية',
      phone: _blankToNull(await _settingValue('shop.phone')),
      address: _blankToNull(await _settingValue('shop.address')),
      receiptFooter: _blankToNull(await _settingValue('shop.receiptFooter')),
    );
  }

  Future<AppResult<ShopSettingsSnapshot>> updateShopSettings({
    required String shopName,
    String? phone,
    String? address,
    String? receiptFooter,
  }) async {
    if (shopName.trim().isEmpty) {
      return const AppFailure('اسم المحل مطلوب');
    }
    await _upsertSetting('shop.name', shopName.trim());
    await _upsertSetting('shop.phone', phone?.trim() ?? '');
    await _upsertSetting('shop.address', address?.trim() ?? '');
    await _upsertSetting('shop.receiptFooter', receiptFooter?.trim() ?? '');
    return AppSuccess(await shopSettings());
  }

  Future<PeriodReportSnapshot> periodReport({
    required DateTime start,
    required DateTime end,
  }) {
    return _periodReport(
      _dayStart(start),
      _dayStart(end).add(const Duration(days: 1)),
    );
  }

  Future<List<Expense>> expensesReport({
    required DateTime start,
    required DateTime end,
  }) {
    final from = _dayStart(start);
    final to = _dayStart(end).add(const Duration(days: 1));
    return (db.select(db.expenses)
          ..where(
            (expense) =>
                expense.createdAt.isBiggerOrEqualValue(from) &
                expense.createdAt.isSmallerThanValue(to),
          )
          ..orderBy([
            (expense) => OrderingTerm(
              expression: expense.createdAt,
              mode: OrderingMode.desc,
            ),
          ]))
        .get();
  }

  Future<List<PartyStatementLine>> partyStatement({
    required String partyType,
    required int partyId,
  }) async {
    final accountCode = partyType == 'supplier'
        ? AccountCodes.payables
        : AccountCodes.receivables;
    final query =
        db.select(db.ledgerLines).join([
            innerJoin(
              db.ledgerEntries,
              db.ledgerEntries.id.equalsExp(db.ledgerLines.entryId),
            ),
          ])
          ..where(
            db.ledgerLines.accountCode.equals(accountCode) &
                db.ledgerLines.partyType.equals(partyType) &
                db.ledgerLines.partyId.equals(partyId),
          )
          ..orderBy([
            OrderingTerm.asc(db.ledgerEntries.createdAt),
            OrderingTerm.asc(db.ledgerEntries.id),
          ]);
    final rows = await query.get();
    var balance = 0;
    return rows.map((row) {
      final line = row.readTable(db.ledgerLines);
      final entry = row.readTable(db.ledgerEntries);
      final delta = partyType == 'supplier'
          ? line.creditMinor - line.debitMinor
          : line.debitMinor - line.creditMinor;
      balance += delta;
      return PartyStatementLine(
        entry: entry,
        debitMinor: line.debitMinor,
        creditMinor: line.creditMinor,
        balanceMinor: balance,
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
            method: PaymentMethod.values.firstWhere(
              (method) => method.name == payment.method,
              orElse: () => PaymentMethod.cash,
            ),
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
      final refundUnitPrice = _netSaleItemUnitPrice(receipt.invoice, item);
      lines.add(
        SaleReturnLinePreview(
          saleItemId: item.id,
          productName: product.name,
          soldQty: item.qty,
          returnedQty: returnedQty,
          returnableQty: returnableQty,
          unitPriceMinor: refundUnitPrice,
          lineTotalMinor: returnableQty * refundUnitPrice,
        ),
      );
    }

    return SaleReturnPreview(receipt: receipt, lines: lines);
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

  Future<File> backupToDirectory(Directory directory) async {
    await directory.create(recursive: true);
    final keep = await _backupRetentionCopies();
    final timestamp = DateTime.now().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final target = File(p.join(directory.path, 'alikhlas-v2-$timestamp.db'));
    final escaped = target.path.replaceAll("'", "''");
    await db.customStatement("VACUUM INTO '$escaped';");
    await _pruneBackups(directory, keep: keep);
    return target;
  }

  Future<void> setBackupDirectory(String path) async {
    await _upsertSetting('backup.directory', path);
  }

  Future<File?> runAutomaticBackupIfDue() async {
    final path = await _settingValue('backup.directory');
    if (path == null || path.trim().isEmpty) return null;

    final today = _dateKey(DateTime.now());
    final lastBackup = await _settingValue('backup.lastDate');
    if (lastBackup == today) return null;

    final backup = await backupToDirectory(Directory(path));
    await _upsertSetting('backup.lastDate', today);
    return backup;
  }

  Future<void> restoreFromBackup(File backupFile) async {
    if (!await backupFile.exists()) {
      throw ArgumentError('Backup file does not exist: ${backupFile.path}');
    }
    await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE);');
    final currentDir = await db
        .customSelect('PRAGMA database_list;')
        .getSingle();
    final dbPath = currentDir.data['file'] as String?;
    if (dbPath == null || dbPath.isEmpty) {
      throw StateError('Cannot resolve current SQLite file path.');
    }
    final dbFile = File(dbPath);
    final walFile = File('$dbPath-wal');
    final shmFile = File('$dbPath-shm');
    final rollbackFile = File(
      '$dbPath.restore-${DateTime.now().microsecondsSinceEpoch}.bak',
    );
    if (await dbFile.exists()) {
      await dbFile.copy(rollbackFile.path);
    }
    await db.close();
    var restored = false;
    try {
      await _deleteFileIfExists(walFile);
      await _deleteFileIfExists(shmFile);
      await backupFile.copy(dbPath);
      restored = true;
    } catch (_) {
      if (await rollbackFile.exists()) {
        await _deleteFileIfExists(walFile);
        await _deleteFileIfExists(shmFile);
        await rollbackFile.copy(dbPath);
        await rollbackFile.delete();
      }
      rethrow;
    } finally {
      if (restored) {
        try {
          await _deleteFileIfExists(rollbackFile);
        } on FileSystemException {
          // A leftover rollback copy is safer than failing a completed restore.
        }
      }
    }
  }

  Future<void> _deleteFileIfExists(File file) async {
    if (await file.exists()) await file.delete();
  }

  Future<void> _upsertSetting(String key, String value) async {
    await db
        .into(db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: key, value: value),
        );
  }

  Future<void> _upsertSettingIfMissing(String key, String value) async {
    final existing = await _settingValue(key);
    if (existing == null) {
      await _upsertSetting(key, value);
    }
  }

  Future<String?> _settingValue(String key) async {
    final setting = await (db.select(
      db.appSettings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return setting?.value;
  }

  String? _blankToNull(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  String _dateKey(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  Future<String> _nextNumber(String key, {required String prefix}) async {
    final current = await (db.select(
      db.appSettings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    final next = int.parse(current?.value ?? '0') + 1;
    await _upsertSetting(key, next.toString());
    return '$prefix-${DateTime.now().year}-${next.toString().padLeft(5, '0')}';
  }

  Future<void> _insertPayments(
    String ownerType,
    int ownerId,
    List<PaymentInput> payments,
  ) async {
    for (final payment in payments.where((p) => p.amountMinor > 0)) {
      await db
          .into(db.payments)
          .insert(
            PaymentsCompanion.insert(
              ownerType: ownerType,
              ownerId: ownerId,
              method: payment.method.name,
              amountMinor: payment.amountMinor,
              note: Value(payment.note),
            ),
          );
    }
  }

  Future<void> _createInstallmentPlan({
    required String ownerType,
    required int ownerId,
    required String partyType,
    required int partyId,
    required int principalMinor,
    required int interestMinor,
    required InstallmentTerms terms,
  }) async {
    final total = principalMinor + interestMinor;
    final planId = await db
        .into(db.installmentPlans)
        .insert(
          InstallmentPlansCompanion.insert(
            ownerType: ownerType,
            ownerId: ownerId,
            partyType: partyType,
            partyId: partyId,
            principalMinor: principalMinor,
            interestMinor: Value(interestMinor),
            totalMinor: total,
            installmentCount: terms.count,
          ),
        );

    for (var i = 0; i < terms.count; i++) {
      await db
          .into(db.installmentPayments)
          .insert(
            InstallmentPaymentsCompanion.insert(
              planId: planId,
              amountMinor: allocateRemainderToLast(total, terms.count, i),
              dueDate: terms.firstDueDate.add(
                Duration(days: terms.periodDays * i),
              ),
            ),
          );
    }
  }

  Future<AppResult<int>> _settleInstallment({
    required int planId,
    required int amountMinor,
    required PaymentMethod method,
    required String expectedPartyType,
    required String debitAccount,
    required String creditAccount,
    required String description,
  }) async {
    if (amountMinor <= 0) {
      return const AppFailure<int>('قيمة السداد يجب أن تكون أكبر من صفر');
    }
    if (method == PaymentMethod.installment) {
      return const AppFailure<int>('سداد الأقساط يكون كاش أو محفظة فقط');
    }
    final shift = await currentShift();
    if (method == PaymentMethod.cash && shift == null) {
      return const AppFailure<int>('افتح وردية قبل أي حركة كاش');
    }

    try {
      final ledgerId = await db.transaction(() async {
        final plan = await (db.select(
          db.installmentPlans,
        )..where((p) => p.id.equals(planId))).getSingleOrNull();
        if (plan == null || plan.partyType != expectedPartyType) {
          throw _BusinessError('خطة الأقساط غير موجودة');
        }
        if (plan.status == 'closed') {
          throw _BusinessError('خطة الأقساط مغلقة بالفعل');
        }

        final remaining = plan.totalMinor - plan.paidMinor;
        if (amountMinor > remaining) {
          throw _BusinessError('قيمة السداد أكبر من المتبقي');
        }

        await _allocateInstallmentPayment(planId, amountMinor);
        final newPaid = plan.paidMinor + amountMinor;
        await (db.update(
          db.installmentPlans,
        )..where((p) => p.id.equals(planId))).write(
          InstallmentPlansCompanion(
            paidMinor: Value(newPaid),
            status: Value(newPaid == plan.totalMinor ? 'closed' : 'open'),
          ),
        );

        await _insertPayments('installment_plan', planId, [
          PaymentInput(method, amountMinor),
        ]);

        return _postLedger(
          referenceType: 'installment_payment',
          referenceId: planId,
          description: description,
          lines: [
            _LedgerLineDraft(
              debitAccount,
              debitMinor: amountMinor,
              partyType:
                  debitAccount == AccountCodes.receivables ||
                      debitAccount == AccountCodes.payables
                  ? plan.partyType
                  : null,
              partyId:
                  debitAccount == AccountCodes.receivables ||
                      debitAccount == AccountCodes.payables
                  ? plan.partyId
                  : null,
            ),
            _LedgerLineDraft(
              creditAccount,
              creditMinor: amountMinor,
              partyType:
                  creditAccount == AccountCodes.receivables ||
                      creditAccount == AccountCodes.payables
                  ? plan.partyType
                  : null,
              partyId:
                  creditAccount == AccountCodes.receivables ||
                      creditAccount == AccountCodes.payables
                  ? plan.partyId
                  : null,
            ),
          ],
        );
      });
      return AppSuccess(ledgerId);
    } on _BusinessError catch (e) {
      return AppFailure(e.message);
    }
  }

  Future<void> _allocateInstallmentPayment(int planId, int amountMinor) async {
    var remaining = amountMinor;
    final installments =
        await (db.select(db.installmentPayments)
              ..where((p) => p.planId.equals(planId))
              ..orderBy([
                (p) =>
                    OrderingTerm(expression: p.dueDate, mode: OrderingMode.asc),
              ]))
            .get();

    for (final installment in installments) {
      if (remaining == 0) break;
      if (installment.status == 'paid') continue;
      if (remaining < installment.amountMinor) {
        await (db.update(
          db.installmentPayments,
        )..where((p) => p.id.equals(installment.id))).write(
          const InstallmentPaymentsCompanion(status: Value('partial')),
        );
        break;
      }
      await (db.update(
        db.installmentPayments,
      )..where((p) => p.id.equals(installment.id))).write(
        InstallmentPaymentsCompanion(
          status: const Value('paid'),
          paidAt: Value(DateTime.now()),
        ),
      );
      remaining -= installment.amountMinor;
    }
  }

  Future<int> _postLedger({
    required String referenceType,
    required int referenceId,
    required String description,
    required List<_LedgerLineDraft> lines,
  }) async {
    final debit = lines.fold<int>(0, (sum, line) => sum + line.debitMinor);
    final credit = lines.fold<int>(0, (sum, line) => sum + line.creditMinor);
    if (debit != credit || debit == 0) {
      throw StateError('Unbalanced ledger entry: debit=$debit credit=$credit');
    }

    final entryId = await db
        .into(db.ledgerEntries)
        .insert(
          LedgerEntriesCompanion.insert(
            referenceType: referenceType,
            referenceId: referenceId,
            description: description,
          ),
        );

    for (final line in lines) {
      if (line.debitMinor < 0 || line.creditMinor < 0) {
        throw StateError('Ledger lines cannot contain negative values.');
      }
      await db
          .into(db.ledgerLines)
          .insert(
            LedgerLinesCompanion.insert(
              entryId: entryId,
              accountCode: line.accountCode,
              debitMinor: Value(line.debitMinor),
              creditMinor: Value(line.creditMinor),
              partyType: Value(line.partyType),
              partyId: Value(line.partyId),
            ),
          );
    }
    return entryId;
  }

  Future<int> _accountBalance(String accountCode) async {
    return _accountNet(accountCode: accountCode);
  }

  Future<int> _accountNetSince(String accountCode, DateTime since) async {
    return _accountNet(accountCode: accountCode, start: since);
  }

  Future<int> _accountNetBetween(
    String accountCode,
    DateTime start,
    DateTime end, {
    String? referenceType,
  }) async {
    return _accountNet(
      accountCode: accountCode,
      start: start,
      end: end,
      referenceType: referenceType,
    );
  }

  Future<int> _accountNet({
    required String accountCode,
    DateTime? start,
    DateTime? end,
    String? referenceType,
  }) async {
    final usesLedgerEntry =
        start != null || end != null || referenceType != null;
    final where = <String>['l.account_code = ?'];
    final variables = <Variable>[Variable<String>(accountCode)];
    if (start != null) {
      where.add('e.created_at >= ?');
      variables.add(Variable<DateTime>(start));
    }
    if (end != null) {
      where.add('e.created_at < ?');
      variables.add(Variable<DateTime>(end));
    }
    if (referenceType != null) {
      where.add('e.reference_type = ?');
      variables.add(Variable<String>(referenceType));
    }

    final from = usesLedgerEntry
        ? 'ledger_lines l INNER JOIN ledger_entries e ON e.id = l.entry_id'
        : 'ledger_lines l';
    final row = await db
        .customSelect(
          '''
          SELECT COALESCE(SUM(l.debit_minor - l.credit_minor), 0) AS net
          FROM $from
          WHERE ${where.join(' AND ')}
          ''',
          variables: variables,
          readsFrom: usesLedgerEntry
              ? {db.ledgerLines, db.ledgerEntries}
              : {db.ledgerLines},
        )
        .getSingle();
    return row.data['net'] as int;
  }

  Future<DailySummarySnapshot> _dailySummary(DateTime date) async {
    final start = _dayStart(date);
    final report = await _periodReport(
      start,
      start.add(const Duration(days: 1)),
    );
    return DailySummarySnapshot(
      date: start,
      salesMinor: report.salesMinor,
      cogsMinor: report.cogsMinor,
      expensesMinor: report.expensesMinor,
      interestMinor: report.interestMinor,
      cashNetMinor: report.cashNetMinor,
      walletNetMinor: report.walletNetMinor,
      purchaseMinor: report.purchaseMinor,
      saleCount: report.saleCount,
      purchaseCount: report.purchaseCount,
      returnCount: report.returnCount,
    );
  }

  Future<PeriodReportSnapshot> _periodReport(
    DateTime start,
    DateTime end,
  ) async {
    final salesMinor = -(await _accountNetBetween(
      AccountCodes.sales,
      start,
      end,
    ));
    final cogsMinor = await _accountNetBetween(AccountCodes.cogs, start, end);
    final expensesMinor = await _accountNetBetween(
      AccountCodes.expenses,
      start,
      end,
    );
    final interestMinor = -(await _accountNetBetween(
      AccountCodes.interestIncome,
      start,
      end,
    ));
    final purchaseMinor = await _accountNetBetween(
      AccountCodes.inventory,
      start,
      end,
      referenceType: 'purchase',
    );

    final saleCount =
        await (db.select(db.saleInvoices)..where(
              (sale) =>
                  sale.createdAt.isBiggerOrEqualValue(start) &
                  sale.createdAt.isSmallerThanValue(end),
            ))
            .get()
            .then((rows) => rows.length);
    final purchaseCount =
        await (db.select(db.purchaseInvoices)..where(
              (purchase) =>
                  purchase.createdAt.isBiggerOrEqualValue(start) &
                  purchase.createdAt.isSmallerThanValue(end),
            ))
            .get()
            .then((rows) => rows.length);
    final returnCount =
        await (db.select(db.saleReturns)..where(
              (saleReturn) =>
                  saleReturn.createdAt.isBiggerOrEqualValue(start) &
                  saleReturn.createdAt.isSmallerThanValue(end),
            ))
            .get()
            .then((rows) => rows.length);

    return PeriodReportSnapshot(
      start: start,
      end: end,
      salesMinor: salesMinor,
      cogsMinor: cogsMinor,
      expensesMinor: expensesMinor,
      interestMinor: interestMinor,
      cashNetMinor: await _accountNetBetween(AccountCodes.cash, start, end),
      walletNetMinor: await _accountNetBetween(AccountCodes.wallet, start, end),
      purchaseMinor: purchaseMinor,
      saleCount: saleCount,
      purchaseCount: purchaseCount,
      returnCount: returnCount,
    );
  }

  DateTime _dayStart(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  Future<List<InstallmentDuePreview>> _dueInstallments({
    required List<InstallmentPlan> plans,
    required List<Customer> customers,
    required List<Supplier> suppliers,
  }) async {
    final planById = {for (final plan in plans) plan.id: plan};
    if (planById.isEmpty) return const [];

    final customerNames = {
      for (final customer in customers) customer.id: customer.name,
    };
    final supplierNames = {
      for (final supplier in suppliers) supplier.id: supplier.name,
    };
    final now = DateTime.now();
    final horizon = now.add(const Duration(days: 7));
    final payments = await (db.select(
      db.installmentPayments,
    )..orderBy([(payment) => OrderingTerm(expression: payment.dueDate)])).get();

    return payments
        .where((payment) => payment.status != 'paid')
        .where((payment) => !payment.dueDate.isAfter(horizon))
        .where((payment) => planById.containsKey(payment.planId))
        .take(12)
        .map((payment) {
          final plan = planById[payment.planId]!;
          final names = plan.partyType == 'customer'
              ? customerNames
              : supplierNames;
          return InstallmentDuePreview(
            plan: plan,
            payment: payment,
            partyName: names[plan.partyId] ?? '#${plan.partyId}',
            remainingMinor: plan.totalMinor - plan.paidMinor,
            isOverdue: payment.dueDate.isBefore(
              DateTime(now.year, now.month, now.day),
            ),
          );
        })
        .toList();
  }

  Future<List<InstallmentPlanPreview>> _installmentSummaries({
    required List<InstallmentPlan> plans,
    required List<Customer> customers,
    required List<Supplier> suppliers,
  }) async {
    if (plans.isEmpty) return const [];

    final customerNames = {
      for (final customer in customers) customer.id: customer.name,
    };
    final supplierNames = {
      for (final supplier in suppliers) supplier.id: supplier.name,
    };
    final payments = await (db.select(
      db.installmentPayments,
    )..orderBy([(payment) => OrderingTerm.asc(payment.dueDate)])).get();
    final paymentsByPlan = <int, List<InstallmentPayment>>{};
    for (final payment in payments) {
      paymentsByPlan.putIfAbsent(payment.planId, () => []).add(payment);
    }

    final today = _dayStart(DateTime.now());
    final horizon = today.add(const Duration(days: 8));
    final previews = <InstallmentPlanPreview>[];

    for (final plan in plans) {
      final schedule = paymentsByPlan[plan.id] ?? const <InstallmentPayment>[];
      var paidRemainder = plan.paidMinor;
      var overdueMinor = 0;
      var dueSoonMinor = 0;
      var nextDueMinor = 0;
      DateTime? nextDueDate;

      for (final payment in schedule) {
        final allocated = paidRemainder <= 0
            ? 0
            : paidRemainder > payment.amountMinor
            ? payment.amountMinor
            : paidRemainder;
        final unpaid = payment.amountMinor - allocated;
        paidRemainder -= allocated;
        if (unpaid == 0) continue;

        if (payment.dueDate.isBefore(today)) {
          overdueMinor += unpaid;
        }
        if (!payment.dueDate.isBefore(today) &&
            payment.dueDate.isBefore(horizon)) {
          dueSoonMinor += unpaid;
        }
        if (nextDueDate == null || payment.dueDate.isBefore(nextDueDate)) {
          nextDueDate = payment.dueDate;
          nextDueMinor = unpaid;
        }
      }

      final names = plan.partyType == 'customer'
          ? customerNames
          : supplierNames;
      previews.add(
        InstallmentPlanPreview(
          plan: plan,
          partyName: names[plan.partyId] ?? '#${plan.partyId}',
          remainingMinor: plan.totalMinor - plan.paidMinor,
          overdueMinor: overdueMinor,
          dueSoonMinor: dueSoonMinor,
          nextDueMinor: nextDueMinor,
          nextDueDate: nextDueDate,
        ),
      );
    }

    previews.sort((a, b) {
      if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
      final aDate = a.nextDueDate ?? DateTime(9999);
      final bDate = b.nextDueDate ?? DateTime(9999);
      return aDate.compareTo(bDate);
    });
    return previews;
  }

  Future<List<PartyBalance>> _partyBalances({
    required String partyType,
    required String accountCode,
    required Map<int, String> names,
    required Map<int, String?> phones,
  }) async {
    final balances = <int, int>{};
    final rows = await db
        .customSelect(
          '''
          SELECT party_id, COALESCE(SUM(debit_minor - credit_minor), 0) AS net
          FROM ledger_lines
          WHERE account_code = ? AND party_type = ? AND party_id IS NOT NULL
          GROUP BY party_id
          ''',
          variables: [
            Variable<String>(accountCode),
            Variable<String>(partyType),
          ],
          readsFrom: {db.ledgerLines},
        )
        .get();
    for (final row in rows) {
      balances[row.data['party_id'] as int] = row.data['net'] as int;
    }
    return names.entries
        .map(
          (entry) => PartyBalance(
            id: entry.key,
            name: entry.value,
            type: partyType,
            balanceMinor: balances[entry.key] ?? 0,
            phone: phones[entry.key],
          ),
        )
        .toList()
      ..sort((a, b) => b.balanceMinor.abs().compareTo(a.balanceMinor.abs()));
  }

  Future<List<LedgerEntryPreview>> _recentLedgerEntries() async {
    final entries =
        await (db.select(db.ledgerEntries)
              ..orderBy([
                (entry) => OrderingTerm(
                  expression: entry.createdAt,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(14))
            .get();
    final previews = <LedgerEntryPreview>[];
    for (final entry in entries) {
      final lines = await (db.select(
        db.ledgerLines,
      )..where((line) => line.entryId.equals(entry.id))).get();
      previews.add(
        LedgerEntryPreview(
          entry: entry,
          debitMinor: lines.fold(0, (sum, line) => sum + line.debitMinor),
          creditMinor: lines.fold(0, (sum, line) => sum + line.creditMinor),
        ),
      );
    }
    return previews;
  }

  int _sumPayments(List<PaymentInput> payments, PaymentMethod method) {
    return payments
        .where((payment) => payment.method == method)
        .fold<int>(0, (sum, payment) => sum + payment.amountMinor);
  }

  Future<void> _pruneBackups(Directory directory, {required int keep}) async {
    final backups = await _backupFiles(directory);
    for (final backup in backups.skip(keep)) {
      await backup.delete();
    }
  }

  Future<BackupStatus> _backupStatus() async {
    final directoryPath = await _settingValue('backup.directory');
    final retentionCopies = await _backupRetentionCopies();
    if (directoryPath == null || directoryPath.trim().isEmpty) {
      return BackupStatus(
        lastDate: await _settingValue('backup.lastDate'),
        retentionCopies: retentionCopies,
      );
    }

    final directory = Directory(directoryPath);
    final backups = await _backupFiles(directory);
    return BackupStatus(
      directory: directoryPath,
      lastDate: await _settingValue('backup.lastDate'),
      latestBackupPath: backups.isEmpty ? null : backups.first.path,
      backupCount: backups.length,
      retentionCopies: retentionCopies,
    );
  }

  Future<List<File>> _backupFiles(Directory directory) async {
    if (!await directory.exists()) return [];
    final backups = await directory
        .list()
        .where(
          (entity) =>
              entity is File &&
              p.basename(entity.path).startsWith('alikhlas-v2-'),
        )
        .cast<File>()
        .toList();
    backups.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
    return backups;
  }

  Future<int> _backupRetentionCopies() async {
    final configuredCopies = int.tryParse(
      await _settingValue('backup.keepCopies') ?? '',
    );
    return configuredCopies == null || configuredCopies < 1
        ? 30
        : configuredCopies;
  }

  String _hashPassword(String password) {
    final salt = _randomBytes(_passwordSaltLength);
    final hash = _pbkdf2Sha256(
      password: password,
      salt: salt,
      iterations: _passwordIterations,
      keyLength: _passwordKeyLength,
    );
    return [
      _passwordHashPrefix,
      _passwordIterations,
      base64Encode(salt),
      base64Encode(hash),
    ].join(r'$');
  }

  String _legacyHashPassword(String password) {
    final bytes = utf8.encode('alikhlas-v2::$password');
    return sha256.convert(bytes).toString();
  }

  ({bool isValid, bool needsRehash}) _verifyPassword(
    String password,
    String storedHash,
  ) {
    final parts = storedHash.split(r'$');
    if (parts.length == 4 && parts.first == _passwordHashPrefix) {
      final iterations = int.tryParse(parts[1]);
      if (iterations == null || iterations <= 0) {
        return (isValid: false, needsRehash: false);
      }
      try {
        final salt = base64Decode(parts[2]);
        final expectedHash = base64Decode(parts[3]);
        final actualHash = _pbkdf2Sha256(
          password: password,
          salt: salt,
          iterations: iterations,
          keyLength: expectedHash.length,
        );
        return (
          isValid: _constantTimeEquals(actualHash, expectedHash),
          needsRehash:
              iterations != _passwordIterations ||
              expectedHash.length != _passwordKeyLength,
        );
      } on FormatException {
        return (isValid: false, needsRehash: false);
      }
    }

    final isLegacyValid = storedHash == _legacyHashPassword(password);
    return (isValid: isLegacyValid, needsRehash: isLegacyValid);
  }

  List<int> _randomBytes(int length) {
    final random = math.Random.secure();
    return List.generate(length, (_) => random.nextInt(256));
  }

  List<int> _pbkdf2Sha256({
    required String password,
    required List<int> salt,
    required int iterations,
    required int keyLength,
  }) {
    final hmac = Hmac(sha256, utf8.encode(password));
    final derivedKey = <int>[];
    var blockIndex = 1;

    while (derivedKey.length < keyLength) {
      var block = hmac.convert([...salt, ..._int32Bytes(blockIndex)]).bytes;
      final mixedBlock = List<int>.from(block);

      for (var i = 1; i < iterations; i++) {
        block = hmac.convert(block).bytes;
        for (var j = 0; j < mixedBlock.length; j++) {
          mixedBlock[j] ^= block[j];
        }
      }

      derivedKey.addAll(mixedBlock);
      blockIndex++;
    }

    return derivedKey.take(keyLength).toList();
  }

  List<int> _int32Bytes(int value) {
    return [
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ];
  }

  bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var diff = 0;
    for (var i = 0; i < left.length; i++) {
      diff |= left[i] ^ right[i];
    }
    return diff == 0;
  }
}

class _LedgerLineDraft {
  const _LedgerLineDraft(
    this.accountCode, {
    this.debitMinor = 0,
    this.creditMinor = 0,
    this.partyType,
    this.partyId,
  });

  final String accountCode;
  final int debitMinor;
  final int creditMinor;
  final String? partyType;
  final int? partyId;
}

class _BusinessError implements Exception {
  const _BusinessError(this.message);
  final String message;
}

import 'dart:io';

import 'restore_recovery.dart';
import 'application_lock.dart';
import 'migration_recovery.dart';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

const kAppDatabaseSchemaVersion = 11;

class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get username => text().unique()();
  TextColumn get passwordHash => text()();
  TextColumn get fullName => text()();
  BoolColumn get mustChangePassword =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get barcode => text().nullable().unique()();
  TextColumn get category => text().nullable()();
  TextColumn get imagePath => text().nullable()();
  IntColumn get stockQty => integer().withDefault(const Constant(0))();
  IntColumn get minStockQty => integer().withDefault(const Constant(1))();
  IntColumn get salePriceMinor => integer()();
  IntColumn get avgCostMinor => integer().withDefault(const Constant(0))();

  /// Exact cost basis for the units currently held. `avgCostMinor` is only a
  /// rounded display value; financial postings use this value.
  IntColumn get inventoryValueMinor =>
      integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Shifts extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get openedAt => dateTime()();
  DateTimeColumn get closedAt => dateTime().nullable()();
  IntColumn get openingCashMinor => integer()();
  IntColumn get expectedCashMinor => integer().nullable()();
  IntColumn get actualCashMinor => integer().nullable()();
  IntColumn get differenceMinor => integer().nullable()();
  TextColumn get status => text().withDefault(const Constant('open'))();
}

class SaleInvoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get invoiceNo => text().unique()();
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  IntColumn get shiftId => integer().nullable().references(Shifts, #id)();
  IntColumn get subtotalMinor => integer()();
  IntColumn get discountMinor => integer().withDefault(const Constant(0))();
  IntColumn get interestMinor => integer().withDefault(const Constant(0))();
  IntColumn get totalMinor => integer()();
  IntColumn get paidMinor => integer()();
  IntColumn get remainingMinor => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class SaleItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleId => integer().references(SaleInvoices, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get qty => integer()();
  IntColumn get unitPriceMinor => integer()();
  IntColumn get unitCostMinor => integer()();

  /// Exact allocated cost for this sale line. It may not equal qty × the
  /// rounded unit cost when a weighted-average remainder is allocated.
  IntColumn get costMinor => integer().withDefault(const Constant(0))();
  IntColumn get lineTotalMinor => integer()();
}

class PurchaseInvoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get invoiceNo => text().unique()();
  IntColumn get supplierId => integer().nullable().references(Suppliers, #id)();
  IntColumn get shiftId => integer().nullable().references(Shifts, #id)();
  IntColumn get totalMinor => integer()();
  IntColumn get paidMinor => integer()();
  IntColumn get remainingMinor => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class PurchaseItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get purchaseId => integer().references(PurchaseInvoices, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get qty => integer()();
  IntColumn get unitCostMinor => integer()();
  IntColumn get lineTotalMinor => integer()();
}

class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get ownerType => text()();
  IntColumn get ownerId => integer()();
  TextColumn get method => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get description => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get method => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class InstallmentPlans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get ownerType => text()();
  IntColumn get ownerId => integer()();
  TextColumn get partyType => text()();
  IntColumn get partyId => integer()();
  IntColumn get principalMinor => integer()();
  IntColumn get interestMinor => integer().withDefault(const Constant(0))();
  IntColumn get totalMinor => integer()();
  IntColumn get paidMinor => integer().withDefault(const Constant(0))();
  IntColumn get installmentCount => integer()();
  TextColumn get status => text().withDefault(const Constant('open'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class InstallmentPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId => integer().references(InstallmentPlans, #id)();
  IntColumn get amountMinor => integer()();
  DateTimeColumn get dueDate => dateTime()();
  DateTimeColumn get paidAt => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
}

class SaleReturns extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleId => integer().references(SaleInvoices, #id)();
  TextColumn get returnNo => text().unique()();
  IntColumn get refundMinor => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class SaleReturnItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get returnId => integer().references(SaleReturns, #id)();
  IntColumn get saleItemId => integer().references(SaleItems, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get qty => integer()();
  IntColumn get unitPriceMinor => integer()();
  IntColumn get unitCostMinor => integer()();

  /// Exact cost restored by this return row. It may differ from qty × the
  /// rounded historical unit cost when a sale-line remainder is allocated.
  IntColumn get costMinor => integer().withDefault(const Constant(0))();
}

class StockMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  TextColumn get type => text()();
  IntColumn get qtyDelta => integer()();
  IntColumn get balanceAfter => integer()();
  TextColumn get referenceType => text()();
  IntColumn get referenceId => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class InventoryAdjustments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get previousQty => integer()();
  IntColumn get countedQty => integer()();
  IntColumn get unitCostMinor => integer()();
  IntColumn get valueDeltaMinor => integer()();
  TextColumn get reason => text()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class OpeningBalances extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get balanceType => text()();
  IntColumn get partyId => integer().nullable()();
  IntColumn get amountMinor => integer()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class LedgerEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get referenceType => text()();
  IntColumn get referenceId => integer()();
  TextColumn get description => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class LedgerLines extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get entryId => integer().references(LedgerEntries, #id)();
  TextColumn get accountCode => text()();
  IntColumn get debitMinor => integer().withDefault(const Constant(0))();
  IntColumn get creditMinor => integer().withDefault(const Constant(0))();
  TextColumn get partyType => text().nullable()();
  IntColumn get partyId => integer().nullable()();
}

class PurchaseReturns extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get purchaseId => integer().references(PurchaseInvoices, #id)();
  TextColumn get returnNo => text().unique()();
  IntColumn get creditMinor => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class PurchaseReturnItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get returnId => integer().references(PurchaseReturns, #id)();
  IntColumn get purchaseItemId => integer().references(PurchaseItems, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get qty => integer()();
  IntColumn get unitCostMinor => integer()();
  IntColumn get inventoryUnitCostMinor => integer()();
}

/// A documented correction for a counted difference in a liquid account.
///
/// This deliberately has no link to an invoice, party, or stock item. Those
/// changes must retain their own documents so the audit trail stays intact.
class FinancialCorrections extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get target => text()();
  IntColumn get deltaMinor => integer()();
  TextColumn get reason => text()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// An immutable document that reverses one financial correction exactly once.
///
/// The original correction remains in place for auditability. The unique
/// source link prevents two independent operation keys from reversing it twice.
class FinancialCorrectionReversals extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get correctionId =>
      integer().references(FinancialCorrections, #id).unique()();
  TextColumn get reason => text()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

LazyDatabase openAppConnection({String fileName = 'alikhlas_v2.db'}) {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    await ApplicationLock.acquire(dir);
    final file = File(p.join(dir.path, fileName));
    await RestoreRecovery(file).recoverIfPending();
    await MigrationRecovery(
      file,
      targetVersion: kAppDatabaseSchemaVersion,
    ).prepareForOpen();
    return NativeDatabase.createInBackground(file);
  });
}

@DriftDatabase(
  tables: [
    Users,
    AppSettings,
    Products,
    Customers,
    Suppliers,
    Shifts,
    SaleInvoices,
    SaleItems,
    PurchaseInvoices,
    PurchaseItems,
    Payments,
    Expenses,
    InstallmentPlans,
    InstallmentPayments,
    SaleReturns,
    SaleReturnItems,
    StockMovements,
    InventoryAdjustments,
    OpeningBalances,
    LedgerEntries,
    LedgerLines,
    PurchaseReturns,
    PurchaseReturnItems,
    FinancialCorrections,
    FinancialCorrectionReversals,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? openAppConnection());

  @override
  int get schemaVersion => kAppDatabaseSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      await _markMigrationStarted(from: from, to: to);
      try {
        if (from < 2) {
          await migrator.addColumn(saleInvoices, saleInvoices.discountMinor);
        }
        if (from < 4) {
          await migrator.createTable(expenses);
        }
        if (from < 5) {
          await migrator.addColumn(products, products.imagePath);
        }
        if (from < 6) {
          await migrator.createTable(inventoryAdjustments);
        }
        if (from < 7) {
          await migrator.createTable(openingBalances);
        }
        if (from < 8) {
          await migrator.createTable(purchaseReturns);
          await migrator.createTable(purchaseReturnItems);
        }
        if (from < 9) {
          await migrator.createTable(financialCorrections);
        }
        if (from < 10) {
          await migrator.addColumn(products, products.inventoryValueMinor);
          await migrator.addColumn(saleItems, saleItems.costMinor);
          await migrator.addColumn(saleReturnItems, saleReturnItems.costMinor);
          // Historical rows had only an integer unit cost. Preserve their
          // recorded basis as the opening value for the new exact columns;
          // the audit will expose any legacy GL variance for explicit review.
          await customStatement(
            'UPDATE products SET inventory_value_minor = stock_qty * avg_cost_minor;',
          );
          await customStatement(
            'UPDATE sale_items SET cost_minor = qty * unit_cost_minor;',
          );
          await customStatement(
            'UPDATE sale_return_items SET cost_minor = qty * unit_cost_minor;',
          );
        }
        if (from < 11) {
          await migrator.createTable(financialCorrectionReversals);
        }
      } catch (_, stackTrace) {
        Error.throwWithStackTrace(
          DatabaseMigrationFailedDuringUpgrade(from: from, to: to),
          stackTrace,
        );
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
      await customStatement('PRAGMA journal_mode = WAL;');
      await customStatement('PRAGMA synchronous = FULL;');
      await _createPerformanceIndexes();
      await _createDataIntegrityGuards();
    },
  );

  Future<void> _createPerformanceIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_ledger_lines_entry_id ON ledger_lines(entry_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_ledger_lines_account_code ON ledger_lines(account_code);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_ledger_lines_party ON ledger_lines(party_type, party_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_ledger_entries_created_at ON ledger_entries(created_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_ledger_entries_reference ON ledger_entries(reference_type, reference_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_stock_movements_product_id ON stock_movements(product_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_stock_movements_reference ON stock_movements(reference_type, reference_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_inventory_adjustments_product_created ON inventory_adjustments(product_id, created_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_opening_balances_target ON opening_balances(balance_type, party_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_payments_owner ON payments(owner_type, owner_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_installment_payments_plan_due ON installment_payments(plan_id, due_date);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON sale_items(sale_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_purchase_returns_purchase_id ON purchase_returns(purchase_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_purchase_return_items_purchase_item_id ON purchase_return_items(purchase_item_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_financial_corrections_target_created ON financial_corrections(target, created_at);',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_financial_correction_reversals_source ON financial_correction_reversals(correction_id);',
    );
  }

  /// SQLite cannot add a CHECK constraint to an existing table without a
  /// destructive table rebuild. These triggers enforce the same invariants
  /// for every supported schema, including databases upgraded in place.
  Future<void> _createDataIntegrityGuards() async {
    const guards = [
      '''
      CREATE TRIGGER IF NOT EXISTS products_nonnegative_insert
      BEFORE INSERT ON products
      WHEN NEW.stock_qty < 0
        OR NEW.min_stock_qty < 0
        OR NEW.sale_price_minor <= 0
        OR NEW.avg_cost_minor < 0
        OR NEW.inventory_value_minor < 0
        OR (NEW.stock_qty = 0 AND NEW.inventory_value_minor != 0)
      BEGIN SELECT RAISE(ABORT, 'Invalid product inventory values'); END;
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS products_nonnegative_update
      BEFORE UPDATE OF stock_qty, min_stock_qty, sale_price_minor,
          avg_cost_minor, inventory_value_minor ON products
      WHEN NEW.stock_qty < 0
        OR NEW.min_stock_qty < 0
        OR NEW.sale_price_minor <= 0
        OR NEW.avg_cost_minor < 0
        OR NEW.inventory_value_minor < 0
        OR (NEW.stock_qty = 0 AND NEW.inventory_value_minor != 0)
      BEGIN SELECT RAISE(ABORT, 'Invalid product inventory values'); END;
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS shifts_nonnegative_insert
      BEFORE INSERT ON shifts
      WHEN NEW.opening_cash_minor < 0
        OR (NEW.actual_cash_minor IS NOT NULL AND NEW.actual_cash_minor < 0)
      BEGIN SELECT RAISE(ABORT, 'Shift cash cannot be negative'); END;
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS shifts_nonnegative_update
      BEFORE UPDATE OF opening_cash_minor, actual_cash_minor ON shifts
      WHEN NEW.opening_cash_minor < 0
        OR (NEW.actual_cash_minor IS NOT NULL AND NEW.actual_cash_minor < 0)
      BEGIN SELECT RAISE(ABORT, 'Shift cash cannot be negative'); END;
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS sale_items_positive_quantity
      BEFORE INSERT ON sale_items
      WHEN NEW.qty <= 0
      BEGIN SELECT RAISE(ABORT, 'Sale item quantity must be positive'); END;
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS purchase_items_positive_quantity
      BEFORE INSERT ON purchase_items
      WHEN NEW.qty <= 0
      BEGIN SELECT RAISE(ABORT, 'Purchase item quantity must be positive'); END;
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS sale_return_items_positive_quantity
      BEFORE INSERT ON sale_return_items
      WHEN NEW.qty <= 0
      BEGIN SELECT RAISE(ABORT, 'Sale return item quantity must be positive'); END;
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS purchase_return_items_positive_quantity
      BEFORE INSERT ON purchase_return_items
      WHEN NEW.qty <= 0
      BEGIN SELECT RAISE(ABORT, 'Purchase return item quantity must be positive'); END;
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS ledger_lines_valid_insert
      BEFORE INSERT ON ledger_lines
      WHEN NEW.debit_minor < 0
        OR NEW.credit_minor < 0
        OR (NEW.debit_minor > 0 AND NEW.credit_minor > 0)
      BEGIN SELECT RAISE(ABORT, 'Invalid ledger line values'); END;
      ''',
      '''
      CREATE TRIGGER IF NOT EXISTS ledger_lines_valid_update
      BEFORE UPDATE OF debit_minor, credit_minor ON ledger_lines
      WHEN NEW.debit_minor < 0
        OR NEW.credit_minor < 0
        OR (NEW.debit_minor > 0 AND NEW.credit_minor > 0)
      BEGIN SELECT RAISE(ABORT, 'Invalid ledger line values'); END;
      ''',
    ];
    final existingTables = (await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table';",
    ).get()).map((row) => row.read<String>('name')).toSet();
    for (final guard in guards) {
      final table = RegExp(
        r'\bON\s+([a-z_]+)',
        caseSensitive: false,
      ).firstMatch(guard)?.group(1);
      if (table == null || !existingTables.contains(table)) continue;
      await customStatement(guard);
    }
  }

  Future<void> finalizeMigrationIfReady() async {
    final file = await _openedDatabaseFile();
    if (file == null) return;
    final version =
        (await customSelect(
              'PRAGMA user_version;',
            ).getSingle()).data.values.single
            as int;
    await MigrationRecovery(
      file,
      targetVersion: schemaVersion,
    ).finalizeIfSuccessful(version);
  }

  Future<void> _markMigrationStarted({
    required int from,
    required int to,
  }) async {
    final file = await _openedDatabaseFile();
    if (file == null) return;
    await MigrationRecovery(
      file,
      targetVersion: schemaVersion,
    ).markMigrationStarted(from: from, to: to);
  }

  Future<File?> _openedDatabaseFile() async {
    final databases = await customSelect('PRAGMA database_list;').get();
    for (final database in databases) {
      if (database.data['name'] != 'main') continue;
      final path = database.data['file'] as String?;
      if (path != null && path.isNotEmpty) return File(path);
    }
    return null;
  }
}

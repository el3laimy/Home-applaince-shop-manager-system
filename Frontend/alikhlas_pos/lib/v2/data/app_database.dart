import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

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
  IntColumn get stockQty => integer().withDefault(const Constant(0))();
  IntColumn get minStockQty => integer().withDefault(const Constant(1))();
  IntColumn get salePriceMinor => integer()();
  IntColumn get avgCostMinor => integer().withDefault(const Constant(0))();
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

LazyDatabase openAppConnection({String fileName = 'alikhlas_v2.db'}) {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, fileName));
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
    InstallmentPlans,
    InstallmentPayments,
    SaleReturns,
    SaleReturnItems,
    StockMovements,
    LedgerEntries,
    LedgerLines,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? openAppConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(saleInvoices, saleInvoices.discountMinor);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
      await customStatement('PRAGMA journal_mode = WAL;');
      await customStatement('PRAGMA synchronous = NORMAL;');
    },
  );
}

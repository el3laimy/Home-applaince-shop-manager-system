import 'dart:convert';
import 'dart:io';

import 'package:alikhlas_pos/v2/accounting/account_codes.dart';
import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  group('ALIkhlasPOS v2 use-cases', () {
    late AppDatabase db;
    late V2UseCases useCases;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      useCases = V2UseCases(db);
      await useCases.bootstrap(createDefaultOwner: true);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'bootstraps owner login and requires default password change',
      () async {
        final owner = await successOf(useCases.login('owner', 'owner123'));
        final settings = await useCases.shopSettings();

        expect(owner.username, 'owner');
        expect(owner.mustChangePassword, isTrue);
        expect(owner.passwordHash, startsWith(r'pbkdf2_sha256$600000$'));
        expect(settings.shopName, 'إخلاص للأجهزة المنزلية');

        final updatedOwner = await successOf(
          useCases.changePassword(owner.id, 'new-owner-pass'),
        );
        final oldLogin = await useCases.login('owner', 'owner123');
        final newLogin = await successOf(
          useCases.login('owner', 'new-owner-pass'),
        );

        expect(updatedOwner.mustChangePassword, isFalse);
        expect(updatedOwner.passwordHash, startsWith(r'pbkdf2_sha256$600000$'));
        expect(oldLogin, isA<AppFailure<User>>());
        expect(newLogin.mustChangePassword, isFalse);
      },
    );

    test('password hashing uses a per-password salt', () async {
      final owner = await successOf(useCases.login('owner', 'owner123'));
      final firstUpdate = await successOf(
        useCases.changePassword(owner.id, 'same-owner-pass'),
      );
      final secondUpdate = await successOf(
        useCases.changePassword(owner.id, 'same-owner-pass'),
      );

      expect(firstUpdate.passwordHash, startsWith(r'pbkdf2_sha256$600000$'));
      expect(secondUpdate.passwordHash, startsWith(r'pbkdf2_sha256$600000$'));
      expect(firstUpdate.passwordHash, isNot(secondUpdate.passwordHash));
      await successOf(useCases.login('owner', 'same-owner-pass'));
    });

    test('login upgrades legacy SHA-256 password hashes', () async {
      final legacyHash = sha256
          .convert(utf8.encode('alikhlas-v2::legacy-pass'))
          .toString();
      await db
          .into(db.users)
          .insert(
            UsersCompanion.insert(
              username: 'legacy',
              passwordHash: legacyHash,
              fullName: 'مستخدم قديم',
            ),
          );

      final legacyUser = await successOf(
        useCases.login('legacy', 'legacy-pass'),
      );
      final storedUser = await (db.select(
        db.users,
      )..where((user) => user.id.equals(legacyUser.id))).getSingle();
      final wrongLogin = await useCases.login('legacy', 'wrong-pass');

      expect(storedUser.passwordHash, startsWith(r'pbkdf2_sha256$600000$'));
      expect(storedUser.passwordHash, isNot(legacyHash));
      expect(wrongLogin, isA<AppFailure<User>>());
    });

    test('database creates v2 performance indexes', () async {
      final rows = await db.customSelect('''
            SELECT name
            FROM sqlite_master
            WHERE type = 'index'
              AND name IN (
                'idx_ledger_lines_entry_id',
                'idx_ledger_lines_account_code',
                'idx_ledger_lines_party',
                'idx_ledger_entries_created_at',
                'idx_ledger_entries_reference',
                'idx_stock_movements_product_id',
                'idx_stock_movements_reference',
                'idx_inventory_adjustments_product_created',
                'idx_opening_balances_target',
                'idx_payments_owner',
                'idx_installment_payments_plan_due',
                'idx_sale_items_sale_id',
                'idx_purchase_returns_purchase_id',
                'idx_purchase_return_items_purchase_item_id',
                'idx_financial_corrections_target_created',
                'idx_financial_correction_reversals_source'
              )
            ''').get();
      final indexNames = rows.map((row) => row.data['name'] as String);

      expect(
        indexNames,
        containsAll([
          'idx_ledger_lines_entry_id',
          'idx_ledger_lines_account_code',
          'idx_ledger_lines_party',
          'idx_ledger_entries_created_at',
          'idx_ledger_entries_reference',
          'idx_stock_movements_product_id',
          'idx_stock_movements_reference',
          'idx_inventory_adjustments_product_created',
          'idx_opening_balances_target',
          'idx_payments_owner',
          'idx_installment_payments_plan_due',
          'idx_sale_items_sale_id',
          'idx_purchase_returns_purchase_id',
          'idx_purchase_return_items_purchase_item_id',
          'idx_financial_corrections_target_created',
          'idx_financial_correction_reversals_source',
        ]),
      );
    });

    test(
      'database migrates a v3 file to v11 including correction reversals and exact inventory costs',
      () async {
        await db.close();

        final tempDir = await Directory.systemTemp.createTemp(
          'alikhlas-v2-migration-',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });
        final dbFile = File('${tempDir.path}/app-v3.db');
        await createMinimalV3Database(dbFile);

        db = AppDatabase(NativeDatabase(dbFile));

        final userVersion = await db
            .customSelect('PRAGMA user_version;')
            .getSingle();
        final tables = await db.customSelect('''
            SELECT name
            FROM sqlite_master
            WHERE type = 'table'
              AND name IN (
                'expenses',
                'inventory_adjustments',
                'opening_balances',
                'purchase_returns',
                'purchase_return_items',
                'financial_corrections',
                'financial_correction_reversals'
              )
            ''').get();
        final productColumns = await db.customSelect('''
            PRAGMA table_info(products);
            ''').get();
        final saleItemColumns = await db.customSelect('''
            PRAGMA table_info(sale_items);
            ''').get();
        final saleReturnItemColumns = await db.customSelect('''
            PRAGMA table_info(sale_return_items);
            ''').get();
        final indexes = await db.customSelect('''
            SELECT name
            FROM sqlite_master
            WHERE type = 'index'
              AND name IN (
                'idx_ledger_lines_entry_id',
                'idx_ledger_lines_account_code',
                'idx_ledger_lines_party',
                'idx_ledger_entries_created_at',
                'idx_ledger_entries_reference',
                'idx_stock_movements_product_id',
                'idx_stock_movements_reference',
                'idx_inventory_adjustments_product_created',
                'idx_opening_balances_target',
                'idx_payments_owner',
                'idx_installment_payments_plan_due',
                'idx_sale_items_sale_id',
                'idx_purchase_returns_purchase_id',
                'idx_purchase_return_items_purchase_item_id',
                'idx_financial_corrections_target_created',
                'idx_financial_correction_reversals_source'
              )
            ''').get();

        expect(userVersion.data['user_version'], 11);
        expect(
          tables.map((row) => row.data['name']),
          containsAll([
            'expenses',
            'inventory_adjustments',
            'opening_balances',
            'purchase_returns',
            'purchase_return_items',
            'financial_corrections',
            'financial_correction_reversals',
          ]),
        );
        expect(
          productColumns.map((row) => row.data['name']),
          containsAll(['image_path', 'inventory_value_minor']),
        );
        expect(
          saleItemColumns.map((row) => row.data['name']),
          contains('cost_minor'),
        );
        expect(
          saleReturnItemColumns.map((row) => row.data['name']),
          contains('cost_minor'),
        );
        expect(indexes, hasLength(16));
      },
    );

    test(
      'creates products with generated barcode and optional image path',
      () async {
        final first = await successOf(
          useCases.createProduct(
            operationKey: useCases.newOpeningStockOperationKey(),
            name: 'غسالة بصورة',
            imagePath: '/tmp/washer.png',
            salePriceMinor: 10000,
            openingQty: 1,
            openingCostMinor: 7000,
          ),
        );
        final second = await successOf(
          useCases.createProduct(
            operationKey: useCases.newOpeningStockOperationKey(),
            name: 'ثلاجة بباركود تلقائي',
            salePriceMinor: 20000,
            openingQty: 1,
            openingCostMinor: 15000,
          ),
        );

        expect(first.barcode, startsWith('AK-${DateTime.now().year}-'));
        expect(second.barcode, startsWith('AK-${DateTime.now().year}-'));
        expect(first.barcode, isNot(second.barcode));
        expect(first.imagePath, '/tmp/washer.png');
      },
    );

    test(
      'barcode label settings default, save, and validate dimensions',
      () async {
        final defaults = await useCases.barcodeLabelSettings();

        expect(defaults.widthMm, 40);
        expect(defaults.heightMm, 30);

        final saved = await successOf(
          useCases.updateBarcodeLabelSettings(widthMm: 55, heightMm: 25),
        );
        final persisted = await useCases.barcodeLabelSettings();
        final rejected = await useCases.updateBarcodeLabelSettings(
          widthMm: 10,
          heightMm: 25,
        );

        expect(saved.widthMm, 55);
        expect(saved.heightMm, 25);
        expect(persisted.widthMm, 55);
        expect(persisted.heightMm, 25);
        expect(rejected, isA<AppFailure<BarcodeLabelSettingsSnapshot>>());
      },
    );

    test(
      'cash and wallet sale posts balanced ledger and historical COGS',
      () async {
        final product = await successOf(
          useCases.createProduct(
            operationKey: useCases.newOpeningStockOperationKey(),
            name: 'ثلاجة 14 قدم',
            salePriceMinor: 100000,
            openingQty: 3,
            openingCostMinor: 70000,
          ),
        );
        await successOf(
          useCases.openShift(
            50000,
            operationKey: useCases.newShiftOperationKey(),
          ),
        );
        await successOf(
          useCases.updateShopSettings(
            shopName: 'محل الإخلاص',
            phone: '01000000000',
            address: 'القاهرة',
            receiptFooter: 'نورتونا',
          ),
        );

        final saleId = await successOf(
          useCases.createSale(
            operationKey: useCases.newSaleOperationKey(),
            items: [
              SaleLineInput(
                productId: product.id,
                qty: 1,
                unitPriceMinor: 100000,
              ),
            ],
            payments: const [
              PaymentInput(PaymentMethod.cash, 50000),
              PaymentInput(PaymentMethod.wallet, 40000),
            ],
            discountMinor: 10000,
          ),
        );

        final storedProduct = await productById(db, product.id);
        final saleItem = await (db.select(
          db.saleItems,
        )..where((item) => item.saleId.equals(saleId))).getSingle();
        final receipt = await useCases.saleReceipt(saleId);
        final snapshot = await useCases.dashboardSnapshot();
        final closedShift = await successOf(
          useCases.closeShift(
            100000,
            operationKey: useCases.newShiftOperationKey(),
          ),
        );

        expect(storedProduct.stockQty, 2);
        expect(saleItem.unitCostMinor, 70000);
        expect(receipt.invoice.invoiceNo, startsWith('S-'));
        expect(receipt.shopSettings.shopName, 'محل الإخلاص');
        expect(receipt.shopSettings.phone, '01000000000');
        expect(receipt.shopSettings.address, 'القاهرة');
        expect(receipt.shopSettings.receiptFooter, 'نورتونا');
        expect(receipt.invoice.discountMinor, 10000);
        expect(receipt.invoice.totalMinor, 90000);
        expect(receipt.lines.single.productName, 'ثلاجة 14 قدم');
        expect(receipt.lines.single.lineTotalMinor, 100000);
        expect(receipt.payments.map((payment) => payment.method), [
          PaymentMethod.cash,
          PaymentMethod.wallet,
        ]);
        expect(snapshot.cashMinor, 50000);
        expect(snapshot.walletMinor, 40000);
        expect(snapshot.salesMinor, 90000);
        expect(snapshot.cogsMinor, 70000);
        expect(snapshot.grossProfitMinor, 20000);
        expect(closedShift.expectedCashMinor, 100000);
        expect(closedShift.differenceMinor, 0);
        await expectAllLedgerEntriesBalanced(db);
      },
    );

    test('purchase updates weighted average cost', () async {
      final product = await successOf(
        useCases.createProduct(
          operationKey: useCases.newOpeningStockOperationKey(),
          name: 'غسالة',
          salePriceMinor: 35000,
          openingQty: 2,
          openingCostMinor: 10000,
        ),
      );

      await successOf(
        useCases.createPurchase(
          operationKey: useCases.newPurchaseOperationKey(),
          items: [
            PurchaseLineInput(
              productId: product.id,
              qty: 2,
              unitCostMinor: 20000,
            ),
          ],
          payments: const [PaymentInput(PaymentMethod.wallet, 40000)],
          allowNegativeBalance: true,
        ),
      );

      final storedProduct = await productById(db, product.id);

      expect(storedProduct.stockQty, 4);
      expect(storedProduct.avgCostMinor, 15000);
      await expectAllLedgerEntriesBalanced(db);
    });

    test('purchase rejects zero unit cost at the use-case boundary', () async {
      final product = await successOf(
        useCases.createProduct(
          operationKey: useCases.newOpeningStockOperationKey(),
          name: 'منتج تكلفة صفر',
          salePriceMinor: 12000,
          openingQty: 0,
          openingCostMinor: 0,
        ),
      );

      final purchase = await useCases.createPurchase(
        operationKey: useCases.newPurchaseOperationKey(),
        items: [
          PurchaseLineInput(productId: product.id, qty: 1, unitCostMinor: 0),
        ],
        payments: const [],
      );
      final storedProduct = await productById(db, product.id);

      expect(purchase, isA<AppFailure<int>>());
      expect((purchase as AppFailure<int>).message, 'أدخل سعر شراء صحيح للصنف');
      expect(storedProduct.stockQty, 0);
      expect(await db.select(db.purchaseInvoices).get(), isEmpty);
      expect(await db.select(db.ledgerEntries).get(), isEmpty);
    });

    test(
      'purchase that overdrafts wallet requires approval before writing data',
      () async {
        final product = await successOf(
          useCases.createProduct(
            operationKey: useCases.newOpeningStockOperationKey(),
            name: 'خلاط',
            salePriceMinor: 15000,
            openingQty: 0,
            openingCostMinor: 0,
          ),
        );

        final warning = await confirmationOf(
          useCases.createPurchase(
            operationKey: useCases.newPurchaseOperationKey(),
            items: [
              PurchaseLineInput(
                productId: product.id,
                qty: 1,
                unitCostMinor: 9000,
              ),
            ],
            payments: const [PaymentInput(PaymentMethod.wallet, 9000)],
          ),
        );
        final payload = warning.payload as NegativeBalanceConfirmation;

        expect(warning.code, 'negative_liquid_balance');
        expect(payload.impacts, hasLength(1));
        expect(payload.impacts.single.accountCode, AccountCodes.wallet);
        expect(payload.impacts.single.currentMinor, 0);
        expect(payload.impacts.single.deltaMinor, -9000);
        expect(payload.impacts.single.newMinor, -9000);
        expect(await db.select(db.purchaseInvoices).get(), isEmpty);
        expect(await db.select(db.ledgerEntries).get(), isEmpty);

        await successOf(
          useCases.createPurchase(
            operationKey: useCases.newPurchaseOperationKey(),
            items: [
              PurchaseLineInput(
                productId: product.id,
                qty: 1,
                unitCostMinor: 9000,
              ),
            ],
            payments: const [PaymentInput(PaymentMethod.wallet, 9000)],
            allowNegativeBalance: true,
          ),
        );

        final snapshot = await useCases.dashboardSnapshot();
        expect(snapshot.walletMinor, -9000);
        expect((await productById(db, product.id)).stockQty, 1);
        await expectAllLedgerEntriesBalanced(db);
      },
    );

    test('dashboard and party balances match ledger fold totals', () async {
      final customerId = await db
          .into(db.customers)
          .insert(CustomersCompanion.insert(name: 'عميل أرصدة'));
      final product = await successOf(
        useCases.createProduct(
          operationKey: useCases.newOpeningStockOperationKey(),
          name: 'ميكروويف',
          salePriceMinor: 10000,
          openingQty: 2,
          openingCostMinor: 6000,
        ),
      );
      await successOf(
        useCases.createSale(
          operationKey: useCases.newSaleOperationKey(),
          customerId: customerId,
          items: [
            SaleLineInput(productId: product.id, qty: 1, unitPriceMinor: 10000),
          ],
          payments: const [PaymentInput(PaymentMethod.wallet, 3000)],
          installmentTerms: InstallmentTerms(
            partyId: customerId,
            count: 2,
            firstDueDate: DateTime(2026, 7),
          ),
        ),
      );

      final dashboard = await useCases.dashboardSnapshot();
      final workbench = await useCases.workbenchSnapshot();

      expect(
        dashboard.receivablesMinor,
        await accountBalance(db, AccountCodes.receivables),
      );
      expect(
        dashboard.walletMinor,
        await accountBalance(db, AccountCodes.wallet),
      );
      expect(
        workbench.customerBalances.single.balanceMinor,
        await partyBalance(
          db,
          accountCode: AccountCodes.receivables,
          partyType: 'customer',
          partyId: customerId,
        ),
      );
      await expectAllLedgerEntriesBalanced(db);
    });

    test(
      'dashboard aggregates stay correct with a larger ledger fixture',
      () async {
        for (var index = 0; index < 120; index++) {
          await insertBalancedLedgerEntry(
            db,
            referenceId: index + 1,
            description: 'قيد مبيعات مجمع ${index + 1}',
            lines: [
              LedgerLinesCompanion.insert(
                entryId: 0,
                accountCode: AccountCodes.cash,
                debitMinor: const Value(1000),
              ),
              LedgerLinesCompanion.insert(
                entryId: 0,
                accountCode: AccountCodes.sales,
                creditMinor: const Value(1000),
              ),
              LedgerLinesCompanion.insert(
                entryId: 0,
                accountCode: AccountCodes.cogs,
                debitMinor: const Value(600),
              ),
              LedgerLinesCompanion.insert(
                entryId: 0,
                accountCode: AccountCodes.inventory,
                creditMinor: const Value(600),
              ),
            ],
          );
        }

        final dashboard = await useCases.dashboardSnapshot();

        expect(dashboard.cashMinor, 120000);
        expect(dashboard.salesMinor, 120000);
        expect(dashboard.cogsMinor, 72000);
        expect(dashboard.inventoryMinor, -72000);
        await expectAllLedgerEntriesBalanced(db);
      },
    );

    test(
      'installment sale allocates flat interest and rounding remainder',
      () async {
        final customerId = await db
            .into(db.customers)
            .insert(CustomersCompanion.insert(name: 'عميل تقسيط'));
        final product = await successOf(
          useCases.createProduct(
            operationKey: useCases.newOpeningStockOperationKey(),
            name: 'بوتاجاز',
            salePriceMinor: 10000,
            openingQty: 1,
            openingCostMinor: 5000,
          ),
        );
        await successOf(
          useCases.openShift(0, operationKey: useCases.newShiftOperationKey()),
        );

        await successOf(
          useCases.createSale(
            operationKey: useCases.newSaleOperationKey(),
            customerId: customerId,
            items: [
              SaleLineInput(
                productId: product.id,
                qty: 1,
                unitPriceMinor: 10000,
              ),
            ],
            payments: const [PaymentInput(PaymentMethod.cash, 2000)],
            installmentTerms: InstallmentTerms(
              partyId: customerId,
              count: 3,
              firstDueDate: DateTime(2026, 7),
              interestMinor: 1001,
            ),
          ),
        );

        final plan = await (db.select(
          db.installmentPlans,
        )..where((plan) => plan.ownerType.equals('sale'))).getSingle();
        final payments = await db.select(db.installmentPayments).get();
        final snapshot = await useCases.dashboardSnapshot();

        expect(plan.principalMinor, 8000);
        expect(plan.interestMinor, 1001);
        expect(plan.totalMinor, 9001);
        expect(payments.map((payment) => payment.amountMinor), [
          3000,
          3000,
          3001,
        ]);
        expect(payments.map((payment) => payment.dueDate), [
          DateTime(2026, 7),
          DateTime(2026, 7, 31),
          DateTime(2026, 8, 30),
        ]);
        expect(snapshot.receivablesMinor, 9001);
        await expectAllLedgerEntriesBalanced(db);
      },
    );

    test('installment sale respects custom schedule period days', () async {
      final customerId = await db
          .into(db.customers)
          .insert(CustomersCompanion.insert(name: 'عميل مواعيد'));
      final product = await successOf(
        useCases.createProduct(
          operationKey: useCases.newOpeningStockOperationKey(),
          name: 'تكييف',
          salePriceMinor: 12000,
          openingQty: 1,
          openingCostMinor: 7000,
        ),
      );

      final invalid = await useCases.createSale(
        operationKey: useCases.newSaleOperationKey(),
        customerId: customerId,
        items: [
          SaleLineInput(productId: product.id, qty: 1, unitPriceMinor: 12000),
        ],
        payments: const [],
        installmentTerms: InstallmentTerms(
          partyId: customerId,
          count: 2,
          firstDueDate: DateTime(2026, 8, 5),
          periodDays: 0,
        ),
      );

      expect(invalid, isA<AppFailure<int>>());
      expect(await db.select(db.installmentPlans).get(), isEmpty);
      expect((await productById(db, product.id)).stockQty, 1);

      await successOf(
        useCases.createSale(
          operationKey: useCases.newSaleOperationKey(),
          customerId: customerId,
          items: [
            SaleLineInput(productId: product.id, qty: 1, unitPriceMinor: 12000),
          ],
          payments: const [],
          installmentTerms: InstallmentTerms(
            partyId: customerId,
            count: 2,
            firstDueDate: DateTime(2026, 8, 5),
            periodDays: 15,
          ),
        ),
      );
      final payments = await db.select(db.installmentPayments).get();

      expect(payments.map((payment) => payment.dueDate), [
        DateTime(2026, 8, 5),
        DateTime(2026, 8, 20),
      ]);
      expect(payments.map((payment) => payment.amountMinor), [6000, 6000]);
      await expectAllLedgerEntriesBalanced(db);
    });

    test('collects customer installment and reduces receivables', () async {
      final customerId = await db
          .into(db.customers)
          .insert(CustomersCompanion.insert(name: 'عميل تحصيل'));
      final product = await successOf(
        useCases.createProduct(
          operationKey: useCases.newOpeningStockOperationKey(),
          name: 'سخان',
          salePriceMinor: 10000,
          openingQty: 1,
          openingCostMinor: 5000,
        ),
      );
      await successOf(
        useCases.openShift(0, operationKey: useCases.newShiftOperationKey()),
      );
      await successOf(
        useCases.createSale(
          operationKey: useCases.newSaleOperationKey(),
          customerId: customerId,
          items: [
            SaleLineInput(productId: product.id, qty: 1, unitPriceMinor: 10000),
          ],
          payments: const [PaymentInput(PaymentMethod.cash, 2000)],
          installmentTerms: InstallmentTerms(
            partyId: customerId,
            count: 3,
            firstDueDate: DateTime(2026, 7),
            interestMinor: 1001,
          ),
        ),
      );
      final plan = await db.select(db.installmentPlans).getSingle();

      await successOf(
        useCases.collectInstallment(
          operationKey: useCases.newInstallmentOperationKey(),
          planId: plan.id,
          amountMinor: 1500,
          method: PaymentMethod.cash,
        ),
      );

      final updatedPlan = await db.select(db.installmentPlans).getSingle();
      final installments = await db.select(db.installmentPayments).get();
      final snapshot = await useCases.dashboardSnapshot();
      final statement = await useCases.partyStatement(
        partyType: 'customer',
        partyId: customerId,
      );
      final currentDetails = statement.last.invoiceDetails!;

      expect(updatedPlan.paidMinor, 1500);
      expect(updatedPlan.status, 'open');
      expect(installments.first.status, 'partial');
      expect(snapshot.cashMinor, 3500);
      expect(snapshot.receivablesMinor, 7501);
      expect(statement, hasLength(2));
      expect(currentDetails.paidMinor, 3500);
      expect(currentDetails.remainingMinor, 7501);
      expect(currentDetails.payments.map((payment) => payment.amountMinor), [
        2000,
        1500,
      ]);
      expect(currentDetails.installments.first.status, 'partial');
      expect(currentDetails.installments.first.paidMinor, 1500);
      expect(currentDetails.installments.first.remainingMinor, 1500);
      await expectAllLedgerEntriesBalanced(db);
    });

    test(
      'workbench snapshot includes daily report and due installments',
      () async {
        final customerId = await db
            .into(db.customers)
            .insert(CustomersCompanion.insert(name: 'عميل تقرير'));
        final product = await successOf(
          useCases.createProduct(
            operationKey: useCases.newOpeningStockOperationKey(),
            name: 'تكييف',
            salePriceMinor: 10000,
            openingQty: 3,
            openingCostMinor: 5000,
          ),
        );
        await successOf(
          useCases.openShift(0, operationKey: useCases.newShiftOperationKey()),
        );

        await successOf(
          useCases.createSale(
            operationKey: useCases.newSaleOperationKey(),
            customerId: customerId,
            items: [
              SaleLineInput(
                productId: product.id,
                qty: 1,
                unitPriceMinor: 10000,
              ),
            ],
            payments: const [PaymentInput(PaymentMethod.cash, 3000)],
            installmentTerms: InstallmentTerms(
              partyId: customerId,
              count: 2,
              firstDueDate: DateTime.now().subtract(const Duration(days: 1)),
              interestMinor: 500,
            ),
          ),
        );
        await successOf(
          useCases.recordExpense(
            operationKey: useCases.newExpenseOperationKey(),
            description: 'مصروف تشغيل',
            amountMinor: 500,
            method: PaymentMethod.cash,
          ),
        );
        await successOf(
          useCases.createPurchase(
            operationKey: useCases.newPurchaseOperationKey(),
            items: [
              PurchaseLineInput(
                productId: product.id,
                qty: 1,
                unitCostMinor: 7000,
              ),
            ],
            payments: const [PaymentInput(PaymentMethod.wallet, 7000)],
            allowNegativeBalance: true,
          ),
        );

        final snapshot = await useCases.workbenchSnapshot();
        final summary = snapshot.dailySummary;

        expect(summary.salesMinor, 10000);
        expect(summary.cogsMinor, 5000);
        expect(summary.expensesMinor, 500);
        expect(summary.interestMinor, 500);
        expect(summary.profitMinor, 5000);
        expect(summary.cashNetMinor, 2500);
        expect(summary.walletNetMinor, -7000);
        expect(summary.purchaseMinor, 7000);
        expect(summary.saleCount, 1);
        expect(summary.purchaseCount, 1);
        expect(snapshot.dueInstallments, hasLength(1));
        expect(snapshot.dueInstallments.single.partyName, 'عميل تقرير');
        expect(snapshot.dueInstallments.single.isOverdue, isTrue);
        expect(snapshot.installmentSummaries, hasLength(1));
        expect(snapshot.installmentSummaries.single.partyName, 'عميل تقرير');
        expect(snapshot.installmentSummaries.single.remainingMinor, 7500);
        expect(snapshot.installmentSummaries.single.overdueMinor, 3750);
        expect(snapshot.installmentSummaries.single.nextDueMinor, 3750);

        final today = DateTime.now();
        final period = await useCases.periodReport(start: today, end: today);
        final statement = await useCases.partyStatement(
          partyType: 'customer',
          partyId: customerId,
        );

        expect(period.salesMinor, summary.salesMinor);
        expect(period.profitMinor, summary.profitMinor);
        expect(statement, hasLength(1));
        expect(statement.single.debitMinor, 7500);
        expect(statement.single.balanceMinor, 7500);
        expect(statement.single.invoiceDetails?.type, 'sale');
        expect(statement.single.invoiceDetails?.totalMinor, 10500);
        expect(statement.single.invoiceDetails?.paidMinor, 3000);
        expect(statement.single.invoiceDetails?.remainingMinor, 7500);
        expect(
          statement.single.invoiceDetails?.items.single.productName,
          'تكييف',
        );
        expect(statement.single.invoiceDetails?.items.single.qty, 1);
        expect(
          statement.single.invoiceDetails?.payments.single.method,
          PaymentMethod.cash,
        );
        expect(
          statement.single.invoiceDetails?.payments.single.amountMinor,
          3000,
        );
        expect(statement.single.invoiceDetails?.installments, hasLength(2));
        expect(
          statement.single.invoiceDetails?.installments.map(
            (installment) => installment.amountMinor,
          ),
          [3750, 3750],
        );
        await expectAllLedgerEntriesBalanced(db);
      },
    );

    test('pays supplier installment and records daily expenses', () async {
      final supplierId = await db
          .into(db.suppliers)
          .insert(SuppliersCompanion.insert(name: 'مورد'));
      final product = await successOf(
        useCases.createProduct(
          operationKey: useCases.newOpeningStockOperationKey(),
          name: 'شفاط',
          salePriceMinor: 20000,
          openingQty: 0,
          openingCostMinor: 0,
        ),
      );

      await successOf(
        useCases.createPurchase(
          operationKey: useCases.newPurchaseOperationKey(),
          supplierId: supplierId,
          items: [
            PurchaseLineInput(
              productId: product.id,
              qty: 2,
              unitCostMinor: 10000,
            ),
          ],
          payments: const [],
        ),
      );
      final plan = await db.select(db.installmentPlans).getSingle();

      final supplierPaymentWarning = await confirmationOf(
        useCases.paySupplierInstallment(
          operationKey: useCases.newInstallmentOperationKey(),
          planId: plan.id,
          amountMinor: 20000,
          method: PaymentMethod.wallet,
        ),
      );
      expect(
        (supplierPaymentWarning.payload as NegativeBalanceConfirmation)
            .impacts
            .single
            .accountCode,
        AccountCodes.wallet,
      );
      await successOf(
        useCases.paySupplierInstallment(
          operationKey: useCases.newInstallmentOperationKey(),
          planId: plan.id,
          amountMinor: 20000,
          method: PaymentMethod.wallet,
          allowNegativeBalance: true,
        ),
      );
      final rejectedCashExpense = await useCases.recordExpense(
        operationKey: useCases.newExpenseOperationKey(),
        description: 'مصروف قبل الوردية',
        amountMinor: 500,
        method: PaymentMethod.cash,
      );
      await successOf(
        useCases.openShift(0, operationKey: useCases.newShiftOperationKey()),
      );
      final cashExpenseWarning = await confirmationOf(
        useCases.recordExpense(
          operationKey: useCases.newExpenseOperationKey(),
          description: 'نقل بضاعة',
          amountMinor: 1500,
          method: PaymentMethod.cash,
        ),
      );
      expect(
        (cashExpenseWarning.payload as NegativeBalanceConfirmation)
            .impacts
            .single
            .accountCode,
        AccountCodes.cash,
      );
      final expenseId = await successOf(
        useCases.recordExpense(
          operationKey: useCases.newExpenseOperationKey(),
          description: 'نقل بضاعة',
          amountMinor: 1500,
          method: PaymentMethod.cash,
          allowNegativeBalance: true,
        ),
      );

      final updatedPlan = await db.select(db.installmentPlans).getSingle();
      final expense = await db.select(db.expenses).getSingle();
      final expenseLedger =
          (await (db.select(
                db.ledgerEntries,
              )..where((entry) => entry.referenceType.equals('expense'))).get())
              .singleWhere((entry) => entry.referenceId == expenseId);
      final snapshot = await useCases.dashboardSnapshot();
      final supplierStatement = await useCases.partyStatement(
        partyType: 'supplier',
        partyId: supplierId,
      );

      expect(rejectedCashExpense, isA<AppFailure<int>>());
      expect(expense.id, expenseId);
      expect(expense.description, 'نقل بضاعة');
      expect(expense.amountMinor, 1500);
      expect(expense.method, PaymentMethod.cash.name);
      expect(expenseLedger.referenceId, expenseId);
      expect(updatedPlan.status, 'closed');
      expect(snapshot.payablesMinor, 0);
      expect(snapshot.walletMinor, -20000);
      expect(snapshot.expensesMinor, 1500);
      expect(snapshot.cashMinor, -1500);
      expect(supplierStatement, hasLength(2));
      expect(supplierStatement.first.invoiceDetails?.type, 'purchase');
      expect(supplierStatement.first.invoiceDetails?.totalMinor, 20000);
      expect(supplierStatement.first.invoiceDetails?.paidMinor, 20000);
      expect(supplierStatement.first.invoiceDetails?.remainingMinor, 0);
      expect(
        supplierStatement.first.invoiceDetails?.items.single.productName,
        'شفاط',
      );
      expect(supplierStatement.first.invoiceDetails?.items.single.qty, 2);
      final supplierInstallment =
          supplierStatement.first.invoiceDetails!.installments.single;
      expect(supplierInstallment.amountMinor, 20000);
      expect(supplierInstallment.paidMinor, 20000);
      expect(supplierInstallment.remainingMinor, 0);
      expect(supplierInstallment.status, 'paid');
      expect(
        supplierStatement.last.invoiceDetails?.invoiceNo,
        supplierStatement.first.invoiceDetails?.invoiceNo,
      );
      await expectAllLedgerEntriesBalanced(db);
    });

    test(
      'wallet expense records an expense row without requiring a shift',
      () async {
        final warning = await confirmationOf(
          useCases.recordExpense(
            operationKey: useCases.newExpenseOperationKey(),
            description: 'اشتراك محفظة',
            amountMinor: 700,
            method: PaymentMethod.wallet,
          ),
        );
        expect(
          (warning.payload as NegativeBalanceConfirmation)
              .impacts
              .single
              .newMinor,
          -700,
        );
        expect(await db.select(db.expenses).get(), isEmpty);

        final expenseId = await successOf(
          useCases.recordExpense(
            operationKey: useCases.newExpenseOperationKey(),
            description: 'اشتراك محفظة',
            amountMinor: 700,
            method: PaymentMethod.wallet,
            allowNegativeBalance: true,
          ),
        );

        final expense = await db.select(db.expenses).getSingle();
        final snapshot = await useCases.dashboardSnapshot();

        expect(expense.id, expenseId);
        expect(expense.description, 'اشتراك محفظة');
        expect(expense.method, PaymentMethod.wallet.name);
        expect(snapshot.walletMinor, -700);
        expect(snapshot.expensesMinor, 700);
        await expectAllLedgerEntriesBalanced(db);
      },
    );

    test(
      'expense report lists actual expense records for the period',
      () async {
        final expenseId = await successOf(
          useCases.recordExpense(
            operationKey: useCases.newExpenseOperationKey(),
            description: 'مصروف تقرير',
            amountMinor: 900,
            method: PaymentMethod.wallet,
            allowNegativeBalance: true,
          ),
        );

        final today = DateTime.now();
        final currentExpenses = await useCases.expensesReport(
          start: today,
          end: today,
        );
        final previousExpenses = await useCases.expensesReport(
          start: today.subtract(const Duration(days: 2)),
          end: today.subtract(const Duration(days: 1)),
        );

        expect(currentExpenses.map((expense) => expense.id), [expenseId]);
        expect(currentExpenses.single.description, 'مصروف تقرير');
        expect(currentExpenses.single.amountMinor, 900);
        expect(previousExpenses, isEmpty);
      },
    );

    test('sale return restores stock and reverses sales and COGS', () async {
      final product = await successOf(
        useCases.createProduct(
          operationKey: useCases.newOpeningStockOperationKey(),
          name: 'مروحة',
          salePriceMinor: 10000,
          openingQty: 2,
          openingCostMinor: 5000,
        ),
      );
      await successOf(
        useCases.openShift(0, operationKey: useCases.newShiftOperationKey()),
      );
      final saleId = await successOf(
        useCases.createSale(
          operationKey: useCases.newSaleOperationKey(),
          items: [
            SaleLineInput(productId: product.id, qty: 2, unitPriceMinor: 10000),
          ],
          payments: const [PaymentInput(PaymentMethod.cash, 20000)],
        ),
      );
      final saleItem = await (db.select(
        db.saleItems,
      )..where((item) => item.saleId.equals(saleId))).getSingle();
      final previewBeforeReturn = await useCases.saleReturnPreview(saleId);

      expect(previewBeforeReturn.lines.single.productName, 'مروحة');
      expect(previewBeforeReturn.lines.single.returnableQty, 2);
      await successOf(
        useCases.createSaleReturn(
          operationKey: useCases.newSaleReturnOperationKey(),
          saleId: saleId,
          saleItemQuantities: {saleItem.id: 1},
          refundMethod: PaymentMethod.cash,
        ),
      );
      final invalidSecondReturn = await useCases.createSaleReturn(
        operationKey: useCases.newSaleReturnOperationKey(),
        saleId: saleId,
        saleItemQuantities: {saleItem.id: 2},
        refundMethod: PaymentMethod.cash,
      );

      final storedProduct = await productById(db, product.id);
      final snapshot = await useCases.dashboardSnapshot();
      final previewAfterReturn = await useCases.saleReturnPreview(saleId);

      expect(invalidSecondReturn, isA<AppFailure<int>>());
      expect(previewAfterReturn.lines.single.returnedQty, 1);
      expect(previewAfterReturn.lines.single.returnableQty, 1);
      expect(storedProduct.stockQty, 1);
      expect(snapshot.cashMinor, 10000);
      expect(snapshot.salesMinor, 10000);
      expect(snapshot.cogsMinor, 5000);
      expect(snapshot.inventoryMinor, 5000);
      await expectAllLedgerEntriesBalanced(db);
    });

    test('cash sale return requires an open shift', () async {
      final product = await successOf(
        useCases.createProduct(
          operationKey: useCases.newOpeningStockOperationKey(),
          name: 'دفاية',
          salePriceMinor: 10000,
          openingQty: 1,
          openingCostMinor: 5000,
        ),
      );
      final saleId = await successOf(
        useCases.createSale(
          operationKey: useCases.newSaleOperationKey(),
          items: [
            SaleLineInput(productId: product.id, qty: 1, unitPriceMinor: 10000),
          ],
          payments: const [PaymentInput(PaymentMethod.wallet, 10000)],
        ),
      );
      final saleItem = await (db.select(
        db.saleItems,
      )..where((item) => item.saleId.equals(saleId))).getSingle();

      final result = await useCases.createSaleReturn(
        operationKey: useCases.newSaleReturnOperationKey(),
        saleId: saleId,
        saleItemQuantities: {saleItem.id: 1},
        refundMethod: PaymentMethod.cash,
      );

      expect(result, isA<AppFailure<int>>());
      expect((await productById(db, product.id)).stockQty, 0);
      expect(await db.select(db.saleReturns).get(), isEmpty);
      await expectAllLedgerEntriesBalanced(db);
    });

    test(
      'installment return above remaining debt settles receivables and refunds overflow',
      () async {
        final customerId = await db
            .into(db.customers)
            .insert(CustomersCompanion.insert(name: 'عميل فائض مرتجع'));
        final product = await successOf(
          useCases.createProduct(
            operationKey: useCases.newOpeningStockOperationKey(),
            name: 'مكنسة',
            salePriceMinor: 10000,
            openingQty: 1,
            openingCostMinor: 5000,
          ),
        );
        final saleId = await successOf(
          useCases.createSale(
            operationKey: useCases.newSaleOperationKey(),
            customerId: customerId,
            items: [
              SaleLineInput(
                productId: product.id,
                qty: 1,
                unitPriceMinor: 10000,
              ),
            ],
            payments: const [],
            installmentTerms: InstallmentTerms(
              partyId: customerId,
              count: 2,
              firstDueDate: DateTime(2026, 7),
            ),
          ),
        );
        final plan = await db.select(db.installmentPlans).getSingle();
        await successOf(
          useCases.collectInstallment(
            operationKey: useCases.newInstallmentOperationKey(),
            planId: plan.id,
            amountMinor: 8000,
            method: PaymentMethod.wallet,
          ),
        );
        final saleItem = await (db.select(
          db.saleItems,
        )..where((item) => item.saleId.equals(saleId))).getSingle();

        final preview = await useCases.saleReturnPreview(saleId);
        expect(preview.remainingDebtMinor, 2000);
        expect(preview.receipt.invoice.remainingMinor, 10000);

        final cashOverflowWithoutShift = await useCases.createSaleReturn(
          operationKey: useCases.newSaleReturnOperationKey(),
          saleId: saleId,
          saleItemQuantities: {saleItem.id: 1},
          refundMethod: PaymentMethod.installment,
          overflowRefundMethod: PaymentMethod.cash,
        );

        expect(cashOverflowWithoutShift, isA<AppFailure<int>>());
        expect((await productById(db, product.id)).stockQty, 0);
        expect(await db.select(db.saleReturns).get(), isEmpty);

        await successOf(
          useCases.createSaleReturn(
            operationKey: useCases.newSaleReturnOperationKey(),
            saleId: saleId,
            saleItemQuantities: {saleItem.id: 1},
            refundMethod: PaymentMethod.installment,
            overflowRefundMethod: PaymentMethod.wallet,
          ),
        );

        final updatedPlan = await db.select(db.installmentPlans).getSingle();
        final installments = (await db.select(db.installmentPayments).get())
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
        final snapshot = await useCases.dashboardSnapshot();
        final returnLines =
            await (db.select(db.ledgerLines)..where(
                  (line) => line.accountCode.isIn([
                    AccountCodes.receivables,
                    AccountCodes.wallet,
                  ]),
                ))
                .get();

        expect(updatedPlan.totalMinor, 8000);
        expect(updatedPlan.paidMinor, 8000);
        expect(updatedPlan.status, 'closed');
        expect(
          installments.every((payment) => payment.status == 'paid'),
          isTrue,
        );
        expect(installments.map((payment) => payment.amountMinor), [
          5000,
          3000,
        ]);
        expect((await productById(db, product.id)).stockQty, 1);
        expect(snapshot.receivablesMinor, 0);
        expect(snapshot.walletMinor, 0);
        expect(snapshot.salesMinor, 0);
        expect(
          returnLines
              .where((line) => line.accountCode == AccountCodes.receivables)
              .fold<int>(0, (sum, line) => sum + line.creditMinor),
          10000,
        );
        expect(
          returnLines
              .where((line) => line.accountCode == AccountCodes.wallet)
              .fold<int>(0, (sum, line) => sum + line.creditMinor),
          8000,
        );
        await expectAllLedgerEntriesBalanced(db);
      },
    );

    test('full owner operating day stays balanced and backs up', () async {
      await db.close();
      final tempDir = await Directory.systemTemp.createTemp(
        'alikhlas-v2-owner-day-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      db = AppDatabase(NativeDatabase(File('${tempDir.path}/app.db')));
      useCases = V2UseCases(db);
      await useCases.bootstrap(createDefaultOwner: true);
      final owner = await successOf(useCases.login('owner', 'owner123'));
      await successOf(useCases.changePassword(owner.id, 'new-owner-pass'));

      final customerId = await db
          .into(db.customers)
          .insert(CustomersCompanion.insert(name: 'عميل يوم كامل'));
      final supplierId = await db
          .into(db.suppliers)
          .insert(SuppliersCompanion.insert(name: 'مورد يوم كامل'));
      final product = await successOf(
        useCases.createProduct(
          operationKey: useCases.newOpeningStockOperationKey(),
          name: 'غلاية كهرباء',
          salePriceMinor: 10000,
          openingQty: 0,
          openingCostMinor: 0,
          minStockQty: 1,
        ),
      );

      await successOf(
        useCases.openShift(
          10000,
          operationKey: useCases.newShiftOperationKey(),
        ),
      );
      await successOf(
        useCases.createPurchase(
          operationKey: useCases.newPurchaseOperationKey(),
          supplierId: supplierId,
          items: [
            PurchaseLineInput(
              productId: product.id,
              qty: 3,
              unitCostMinor: 7000,
            ),
          ],
          payments: const [
            PaymentInput(PaymentMethod.cash, 5000),
            PaymentInput(PaymentMethod.wallet, 6000),
          ],
          allowNegativeBalance: true,
        ),
      );
      final saleId = await successOf(
        useCases.createSale(
          operationKey: useCases.newSaleOperationKey(),
          customerId: customerId,
          items: [
            SaleLineInput(productId: product.id, qty: 2, unitPriceMinor: 10000),
          ],
          payments: const [
            PaymentInput(PaymentMethod.cash, 5000),
            PaymentInput(PaymentMethod.wallet, 3000),
          ],
          installmentTerms: InstallmentTerms(
            partyId: customerId,
            count: 2,
            firstDueDate: DateTime(2026, 7),
            interestMinor: 1000,
          ),
          discountMinor: 2000,
        ),
      );
      final plan = await (db.select(
        db.installmentPlans,
      )..where((plan) => plan.ownerType.equals('sale'))).getSingle();
      await successOf(
        useCases.collectInstallment(
          operationKey: useCases.newInstallmentOperationKey(),
          planId: plan.id,
          amountMinor: 1000,
          method: PaymentMethod.cash,
        ),
      );
      final saleItem = await (db.select(
        db.saleItems,
      )..where((line) => line.saleId.equals(saleId))).getSingle();
      await successOf(
        useCases.createSaleReturn(
          operationKey: useCases.newSaleReturnOperationKey(),
          saleId: saleId,
          saleItemQuantities: {saleItem.id: 1},
          refundMethod: PaymentMethod.installment,
        ),
      );
      final closedShift = await successOf(
        useCases.closeShift(
          11000,
          operationKey: useCases.newShiftOperationKey(),
        ),
      );

      final storedProduct = await productById(db, product.id);
      final dashboard = await useCases.dashboardSnapshot();
      final today = DateTime.now();
      final period = await useCases.periodReport(start: today, end: today);
      final returnItem = await db.select(db.saleReturnItems).getSingle();
      final updatedPlan = await (db.select(
        db.installmentPlans,
      )..where((plan) => plan.ownerType.equals('sale'))).getSingle();
      final customerStatement = await useCases.partyStatement(
        partyType: 'customer',
        partyId: customerId,
      );
      final currentSaleDetails = customerStatement.last.invoiceDetails!;

      expect(storedProduct.stockQty, 2);
      expect(storedProduct.avgCostMinor, 7000);
      expect(returnItem.unitPriceMinor, 9000);
      expect(updatedPlan.paidMinor, 1000);
      expect(currentSaleDetails.returnedMinor, 9000);
      expect(currentSaleDetails.paidMinor, 9000);
      expect(currentSaleDetails.remainingMinor, 1000);
      expect(dashboard.salesMinor, 9000);
      expect(dashboard.cogsMinor, 7000);
      expect(period.interestMinor, 1000);
      expect(dashboard.receivablesMinor, 1000);
      expect(dashboard.payablesMinor, -10000);
      expect(dashboard.cashMinor, 1000);
      expect(dashboard.walletMinor, -3000);
      expect(dashboard.inventoryMinor, 14000);
      expect(closedShift.expectedCashMinor, 11000);
      expect(closedShift.differenceMinor, 0);
      final backup = await useCases.backupToDirectory(
        Directory('${tempDir.path}/backups'),
      );
      expect(await backup.exists(), isTrue);
      await expectAllLedgerEntriesBalanced(db);
    });

    test(
      'rejects invoice discount that consumes the full sale subtotal',
      () async {
        final product = await successOf(
          useCases.createProduct(
            operationKey: useCases.newOpeningStockOperationKey(),
            name: 'مكواة',
            salePriceMinor: 10000,
            openingQty: 1,
            openingCostMinor: 5000,
          ),
        );

        final result = await useCases.createSale(
          operationKey: useCases.newSaleOperationKey(),
          items: [
            SaleLineInput(productId: product.id, qty: 1, unitPriceMinor: 10000),
          ],
          payments: const [],
          discountMinor: 10000,
        );

        expect(result, isA<AppFailure<int>>());
        expect((await productById(db, product.id)).stockQty, 1);
        expect(await db.select(db.saleInvoices).get(), isEmpty);
      },
    );

    test('rejects selling unavailable stock atomically', () async {
      final product = await successOf(
        useCases.createProduct(
          operationKey: useCases.newOpeningStockOperationKey(),
          name: 'ديب فريزر',
          salePriceMinor: 25000,
          openingQty: 1,
          openingCostMinor: 18000,
        ),
      );

      final result = await useCases.createSale(
        operationKey: useCases.newSaleOperationKey(),
        items: [
          SaleLineInput(productId: product.id, qty: 2, unitPriceMinor: 25000),
        ],
        payments: const [PaymentInput(PaymentMethod.wallet, 50000)],
      );

      expect(result, isA<AppFailure<int>>());
      expect((await productById(db, product.id)).stockQty, 1);
      expect(await db.select(db.saleInvoices).get(), isEmpty);
      await expectAllLedgerEntriesBalanced(db);
    });

    test('backup and restore returns to the backed-up state', () async {
      await db.close();

      final tempDir = await Directory.systemTemp.createTemp(
        'alikhlas-v2-test-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final dbFile = File('${tempDir.path}/app.db');
      db = AppDatabase(NativeDatabase(dbFile));
      useCases = V2UseCases(db);
      await useCases.bootstrap(createDefaultOwner: true);
      final autoBackupBeforeDirectory = await useCases
          .runAutomaticBackupIfDue();
      expect(autoBackupBeforeDirectory, isNull);

      final backedUpProduct = await successOf(
        useCases.createProduct(
          operationKey: useCases.newOpeningStockOperationKey(),
          name: 'منتج قبل النسخة',
          salePriceMinor: 1000,
          openingQty: 1,
          openingCostMinor: 700,
        ),
      );
      await successOf(
        useCases.openShift(0, operationKey: useCases.newShiftOperationKey()),
      );
      await successOf(
        useCases.createSale(
          operationKey: useCases.newSaleOperationKey(),
          items: [
            SaleLineInput(
              productId: backedUpProduct.id,
              qty: 1,
              unitPriceMinor: 1000,
            ),
          ],
          payments: const [PaymentInput(PaymentMethod.cash, 1000)],
        ),
      );
      final backup = await useCases.backupToDirectory(
        Directory('${tempDir.path}/backups'),
      );
      await useCases.setBackupDirectory('${tempDir.path}/backups');
      final dailyBackup = await useCases.runAutomaticBackupIfDue();
      final secondDailyBackup = await useCases.runAutomaticBackupIfDue();
      await successOf(
        useCases.createProduct(
          operationKey: useCases.newOpeningStockOperationKey(),
          name: 'منتج بعد النسخة',
          salePriceMinor: 2000,
          openingQty: 1,
          openingCostMinor: 1200,
        ),
      );
      final walFile = File('${dbFile.path}-wal');
      final shmFile = File('${dbFile.path}-shm');
      expect(await walFile.exists(), isTrue);
      expect(await shmFile.exists(), isTrue);

      await useCases.restoreFromBackup(backup);

      expect(await walFile.exists(), isFalse);
      expect(await shmFile.exists(), isFalse);

      db = AppDatabase(NativeDatabase(dbFile));
      useCases = V2UseCases(db);
      final products = await db.select(db.products).get();
      final restoredProduct = products.single;
      final restoredDashboard = await useCases.dashboardSnapshot();
      final restoredPeriod = await useCases.periodReport(
        start: DateTime.now(),
        end: DateTime.now(),
      );

      expect(products.map((product) => product.name), ['منتج قبل النسخة']);
      expect(restoredProduct.stockQty, 0);
      expect(restoredDashboard.cashMinor, 1000);
      expect(restoredDashboard.salesMinor, 1000);
      expect(restoredDashboard.cogsMinor, 700);
      expect(restoredDashboard.inventoryMinor, 0);
      expect(restoredPeriod.profitMinor, 300);
      expect(dailyBackup, isNotNull);
      expect(await dailyBackup!.exists(), isTrue);
      expect(secondDailyBackup, isNull);
    });

    test('failed restore rolls back to the current usable database', () async {
      await db.close();

      final tempDir = await Directory.systemTemp.createTemp(
        'alikhlas-v2-restore-failure-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final dbFile = File('${tempDir.path}/app.db');
      db = AppDatabase(NativeDatabase(dbFile));
      useCases = V2UseCases(db);
      await useCases.bootstrap(createDefaultOwner: true);
      await successOf(
        useCases.createProduct(
          operationKey: useCases.newOpeningStockOperationKey(),
          name: 'منتج قبل النسخة',
          salePriceMinor: 1000,
          openingQty: 1,
          openingCostMinor: 700,
        ),
      );
      final backup = await useCases.backupToDirectory(
        Directory('${tempDir.path}/backups'),
      );
      await successOf(
        useCases.createProduct(
          operationKey: useCases.newOpeningStockOperationKey(),
          name: 'منتج الحالة الحالية',
          salePriceMinor: 2000,
          openingQty: 1,
          openingCostMinor: 1200,
        ),
      );

      useCases = V2UseCases(
        db,
        restoreFileOperations: _FailingRestoreFileOperations(
          backupPath: backup.path,
          targetDbPath: dbFile.path,
        ),
      );

      await expectLater(
        useCases.restoreFromBackup(backup),
        throwsA(isA<FileSystemException>()),
      );

      db = AppDatabase(NativeDatabase(dbFile));
      useCases = V2UseCases(db);
      final products = await db.select(db.products).get();

      expect(
        products.map((product) => product.name),
        unorderedEquals(['منتج قبل النسخة', 'منتج الحالة الحالية']),
      );
      await successOf(
        useCases.createProduct(
          operationKey: useCases.newOpeningStockOperationKey(),
          name: 'منتج بعد فشل الاسترجاع',
          salePriceMinor: 3000,
          openingQty: 1,
          openingCostMinor: 1500,
        ),
      );
    });

    test('backup pruning keeps the latest 30 copies', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'alikhlas-v2-backups-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      for (var i = 0; i < 32; i++) {
        final backup = File(
          '${tempDir.path}/alikhlas-v2-old-${i.toString().padLeft(2, '0')}.db',
        );
        await backup.writeAsString('old backup $i');
        await backup.setLastModified(DateTime(2026, 1, 1, 0, i));
      }

      await useCases.backupToDirectory(tempDir);
      await useCases.setBackupDirectory(tempDir.path);

      final backups = await tempDir
          .list()
          .where(
            (entity) =>
                entity is File &&
                entity.uri.pathSegments.last.startsWith('alikhlas-v2-'),
          )
          .cast<File>()
          .toList();
      final backupNames = backups.map((backup) => backup.uri.pathSegments.last);

      expect(backups, hasLength(30));
      expect(backupNames, isNot(contains('alikhlas-v2-old-00.db')));
      expect(backupNames, isNot(contains('alikhlas-v2-old-01.db')));
      expect(backupNames, isNot(contains('alikhlas-v2-old-02.db')));

      final snapshot = await useCases.workbenchSnapshot();

      expect(snapshot.backupStatus.backupCount, 30);
      expect(snapshot.backupStatus.retentionCopies, 30);
      expect(snapshot.backupStatus.latestBackupPath, isNotNull);
      expect(
        snapshot.backupStatus.latestBackupPath,
        startsWith('${tempDir.path}/alikhlas-v2-'),
      );
    });
  });
}

Future<T> successOf<T>(Future<AppResult<T>> future) async {
  final result = await future;
  if (result is AppSuccess<T>) {
    return result.value;
  }
  if (result is AppFailure<T>) {
    fail(result.message);
  }
  fail('Unexpected result type: $result');
}

Future<AppConfirmationRequired<T>> confirmationOf<T>(
  Future<AppResult<T>> future,
) async {
  final result = await future;
  if (result is AppConfirmationRequired<T>) {
    return result;
  }
  fail('Expected confirmation result, got $result');
}

Future<Product> productById(AppDatabase db, int productId) {
  return (db.select(
    db.products,
  )..where((product) => product.id.equals(productId))).getSingle();
}

Future<void> expectAllLedgerEntriesBalanced(AppDatabase db) async {
  final entries = await db.select(db.ledgerEntries).get();
  expect(entries, isNotEmpty);

  for (final entry in entries) {
    final lines = await (db.select(
      db.ledgerLines,
    )..where((line) => line.entryId.equals(entry.id))).get();
    final debit = lines.fold<int>(0, (sum, line) => sum + line.debitMinor);
    final credit = lines.fold<int>(0, (sum, line) => sum + line.creditMinor);

    expect(debit, credit, reason: 'Ledger entry ${entry.id} is unbalanced');
  }
}

Future<int> accountBalance(AppDatabase db, String accountCode) async {
  final lines = await (db.select(
    db.ledgerLines,
  )..where((line) => line.accountCode.equals(accountCode))).get();
  return lines.fold<int>(
    0,
    (sum, line) => sum + line.debitMinor - line.creditMinor,
  );
}

Future<void> expectAccountBalance(
  AppDatabase db,
  String accountCode,
  int expected,
) async {
  expect(await accountBalance(db, accountCode), expected);
}

Future<int> partyBalance(
  AppDatabase db, {
  required String accountCode,
  required String partyType,
  required int partyId,
}) async {
  final lines = await (db.select(
    db.ledgerLines,
  )..where((line) => line.accountCode.equals(accountCode))).get();
  return lines
      .where((line) => line.partyType == partyType && line.partyId == partyId)
      .fold<int>(0, (sum, line) => sum + line.debitMinor - line.creditMinor);
}

Future<void> insertBalancedLedgerEntry(
  AppDatabase db, {
  required int referenceId,
  required String description,
  required List<LedgerLinesCompanion> lines,
}) async {
  final entryId = await db
      .into(db.ledgerEntries)
      .insert(
        LedgerEntriesCompanion.insert(
          referenceType: 'large_fixture',
          referenceId: referenceId,
          description: description,
        ),
      );
  for (final ledgerLine in lines) {
    await db
        .into(db.ledgerLines)
        .insert(ledgerLine.copyWith(entryId: Value(entryId)));
  }
}

Future<void> createMinimalV3Database(File file) async {
  final rawDb = sqlite.sqlite3.open(file.path);
  try {
    rawDb
      ..execute('''
        CREATE TABLE products (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          barcode TEXT NULL UNIQUE,
          category TEXT NULL,
          stock_qty INTEGER NOT NULL DEFAULT 0,
          min_stock_qty INTEGER NOT NULL DEFAULT 1,
          sale_price_minor INTEGER NOT NULL,
          avg_cost_minor INTEGER NOT NULL DEFAULT 0,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NULL
        );
      ''')
      ..execute('''
        CREATE TABLE ledger_lines (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          entry_id INTEGER NOT NULL,
          account_code TEXT NOT NULL,
          debit_minor INTEGER NOT NULL DEFAULT 0,
          credit_minor INTEGER NOT NULL DEFAULT 0,
          party_type TEXT NULL,
          party_id INTEGER NULL
        );
      ''')
      ..execute('''
        CREATE TABLE ledger_entries (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          reference_type TEXT NOT NULL,
          reference_id INTEGER NOT NULL,
          description TEXT NOT NULL,
          created_at INTEGER NOT NULL
        );
      ''')
      ..execute('''
        CREATE TABLE stock_movements (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          type TEXT NOT NULL,
          qty_delta INTEGER NOT NULL,
          balance_after INTEGER NOT NULL,
          reference_type TEXT NOT NULL,
          reference_id INTEGER NOT NULL,
          created_at INTEGER NOT NULL
        );
      ''')
      ..execute('''
        CREATE TABLE payments (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          owner_type TEXT NOT NULL,
          owner_id INTEGER NOT NULL,
          method TEXT NOT NULL,
          amount_minor INTEGER NOT NULL,
          note TEXT NULL,
          created_at INTEGER NOT NULL
        );
      ''')
      ..execute('''
        CREATE TABLE installment_payments (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          plan_id INTEGER NOT NULL,
          amount_minor INTEGER NOT NULL,
          due_date INTEGER NOT NULL,
          paid_at INTEGER NULL,
          status TEXT NOT NULL DEFAULT 'pending'
        );
      ''')
      ..execute('''
        CREATE TABLE sale_items (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          sale_id INTEGER NOT NULL,
          product_id INTEGER NOT NULL,
          qty INTEGER NOT NULL,
          unit_price_minor INTEGER NOT NULL,
          unit_cost_minor INTEGER NOT NULL,
          line_total_minor INTEGER NOT NULL
        );
      ''')
      ..execute('''
        CREATE TABLE sale_returns (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          sale_id INTEGER NOT NULL,
          return_no TEXT NOT NULL UNIQUE,
          refund_minor INTEGER NOT NULL,
          created_at INTEGER NOT NULL
        );
      ''')
      ..execute('''
        CREATE TABLE sale_return_items (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          return_id INTEGER NOT NULL,
          sale_item_id INTEGER NOT NULL,
          product_id INTEGER NOT NULL,
          qty INTEGER NOT NULL,
          unit_price_minor INTEGER NOT NULL,
          unit_cost_minor INTEGER NOT NULL
        );
      ''')
      ..execute('PRAGMA user_version = 3;');
  } finally {
    rawDb.close();
  }
}

class _FailingRestoreFileOperations extends RestoreFileOperations {
  const _FailingRestoreFileOperations({
    required this.backupPath,
    required this.targetDbPath,
  });

  final String backupPath;
  final String targetDbPath;

  @override
  Future<void> copyFile(File source, File target) async {
    if ((source.path == backupPath ||
            source.uri.pathSegments.last == 'candidate.db') &&
        target.path == targetDbPath) {
      await target.writeAsString('partial restore write');
      throw FileSystemException('Simulated restore copy failure', target.path);
    }
    await super.copyFile(source, target);
  }
}

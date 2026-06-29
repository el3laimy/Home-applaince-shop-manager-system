import 'package:alikhlas_pos/v2/app/v2_app.dart';
import 'package:alikhlas_pos/v2/app/v2_providers.dart';
import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:alikhlas_pos/v2/printing/barcode_labels_pdf.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('login forces default password change before dashboard', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const ALIkhlasV2App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('إخلاص POS'), findsOneWidget);
    final passwordField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'كلمة المرور'),
    );
    expect(passwordField.controller?.text, isEmpty);

    await tester.enterText(
      find.widgetWithText(TextField, 'كلمة المرور'),
      'owner123',
    );
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();

    expect(find.text('تغيير كلمة المرور'), findsOneWidget);
    expect(find.text('يومية المحل'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextField, 'كلمة المرور الجديدة'),
      'new-owner-pass',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'تأكيد كلمة المرور'),
      'new-owner-pass',
    );
    await tester.tap(find.text('حفظ ومتابعة'));
    await tester.pumpAndSettle();

    expect(find.text('يومية المحل'), findsOneWidget);
  });

  testWidgets('desktop sale flow records a cash invoice from POS', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final useCases = V2UseCases(db);
    await useCases.bootstrap();
    final owner = await _success(useCases.login('owner', 'owner123'));
    await _success(useCases.changePassword(owner.id, 'new-owner-pass'));
    await _success(
      useCases.createProduct(
        name: 'غسالة اختبار',
        salePriceMinor: 10000,
        openingQty: 2,
        openingCostMinor: 7000,
      ),
    );
    await _success(useCases.openShift(0));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const ALIkhlasV2App(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'كلمة المرور'),
      'new-owner-pass',
    );
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('البيع').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('غسالة اختبار'));
    await tester.pumpAndSettle();
    expect(find.textContaining('أول قسط'), findsWidgets);
    expect(find.text('الفترة'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'كاش'), '100');
    await tester.tap(find.text('تسجيل البيع'));
    await tester.pumpAndSettle();

    expect(find.text('تم تسجيل البيع'), findsOneWidget);
    expect((await db.select(db.saleInvoices).get()).length, 1);
  });

  testWidgets('desktop sale blocks invalid money input before posting', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final useCases = V2UseCases(db);
    await useCases.bootstrap();
    final owner = await _success(useCases.login('owner', 'owner123'));
    await _success(useCases.changePassword(owner.id, 'new-owner-pass'));
    await _success(
      useCases.createProduct(
        name: 'بوتاجاز اختبار',
        salePriceMinor: 10000,
        openingQty: 1,
        openingCostMinor: 7000,
      ),
    );
    await _success(useCases.openShift(0));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const ALIkhlasV2App(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'كلمة المرور'),
      'new-owner-pass',
    );
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('البيع').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('بوتاجاز اختبار'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'كاش'), '100x');
    await tester.tap(find.text('تسجيل البيع'));
    await tester.pumpAndSettle();

    expect(find.text('كاش: استخدم أرقامًا وفاصلًا عشريًا فقط'), findsWidgets);
    expect(await db.select(db.saleInvoices).get(), isEmpty);
  });

  testWidgets('desktop purchase flow records stock intake from purchases', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final useCases = V2UseCases(db);
    await useCases.bootstrap();
    final owner = await _success(useCases.login('owner', 'owner123'));
    await _success(useCases.changePassword(owner.id, 'new-owner-pass'));
    final product = await _success(
      useCases.createProduct(
        name: 'ثلاجة شراء',
        salePriceMinor: 15000,
        openingQty: 0,
        openingCostMinor: 0,
      ),
    );
    await _success(useCases.openShift(0));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const ALIkhlasV2App(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'كلمة المرور'),
      'new-owner-pass',
    );
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('الشراء').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    final unitCostField = find.widgetWithText(TextFormField, 'تكلفة الوحدة');
    final costField = tester.widget<TextFormField>(unitCostField);
    expect(costField.initialValue, isEmpty);
    await tester.tap(find.text('تسجيل الشراء'));
    await tester.pumpAndSettle();
    expect(find.text('أدخل سعر شراء صحيح للصنف'), findsWidgets);
    expect(await db.select(db.purchaseInvoices).get(), isEmpty);

    await tester.enterText(unitCostField, '150');
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'كاش'), '150');
    await tester.tap(find.text('تسجيل الشراء'));
    await tester.pumpAndSettle();

    expect(find.text('الرصيد سيصبح سالبًا'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(await db.select(db.purchaseInvoices).get(), isEmpty);

    await tester.tap(find.text('تسجيل الشراء'));
    await tester.pumpAndSettle();
    expect(find.text('الرصيد سيصبح سالبًا'), findsOneWidget);
    await tester.tap(
      find.widgetWithText(FilledButton, 'أوافق على الرصيد السالب'),
    );
    await tester.pumpAndSettle();

    expect(find.text('طباعة باركود الوارد؟'), findsOneWidget);
    await tester.tap(find.text('تخطي'));
    await tester.pumpAndSettle();

    expect((await db.select(db.purchaseInvoices).get()).length, 1);
    final storedProduct = await (db.select(
      db.products,
    )..where((p) => p.id.equals(product.id))).getSingle();
    expect(storedProduct.stockQty, 1);
  });

  testWidgets('party statement opens invoice item details', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final useCases = V2UseCases(db);
    await useCases.bootstrap();
    final owner = await _success(useCases.login('owner', 'owner123'));
    await _success(useCases.changePassword(owner.id, 'new-owner-pass'));
    final customerId = await db
        .into(db.customers)
        .insert(CustomersCompanion.insert(name: 'عميل كشف'));
    final product = await _success(
      useCases.createProduct(
        name: 'غسالة كشف',
        salePriceMinor: 10000,
        openingQty: 1,
        openingCostMinor: 7000,
      ),
    );
    await _success(useCases.openShift(0));
    await _success(
      useCases.createSale(
        customerId: customerId,
        items: [
          SaleLineInput(productId: product.id, qty: 1, unitPriceMinor: 10000),
        ],
        payments: const [PaymentInput(PaymentMethod.cash, 3000)],
        discountMinor: 1000,
        installmentTerms: InstallmentTerms(
          partyId: customerId,
          count: 2,
          firstDueDate: DateTime(2026, 7),
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const ALIkhlasV2App(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'كلمة المرور'),
      'new-owner-pass',
    );
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الأطراف').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'كشف الحساب'));
    await tester.pumpAndSettle();

    expect(find.textContaining('إجمالي الأصناف'), findsWidgets);
    expect(find.textContaining('المدفوع'), findsWidgets);
    expect(find.textContaining('المتبقي'), findsWidgets);

    await tester.tap(find.widgetWithText(OutlinedButton, 'تفاصيل'));
    await tester.pumpAndSettle();

    expect(find.textContaining('تفاصيل فاتورة بيع'), findsOneWidget);
    expect(find.text('إجمالي الأصناف'), findsOneWidget);
    expect(find.text('خصم الفاتورة'), findsOneWidget);
    expect(find.text('صافي الفاتورة'), findsOneWidget);
    expect(find.text('غسالة كشف'), findsOneWidget);
    expect(find.text('المدفوعات'), findsOneWidget);
    expect(find.text('الأقساط'), findsWidgets);
  });

  testWidgets(
    'installments screen searches customers and prioritizes overdue',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final useCases = V2UseCases(db);
      await useCases.bootstrap();
      final owner = await _success(useCases.login('owner', 'owner123'));
      await _success(useCases.changePassword(owner.id, 'new-owner-pass'));
      final overdueCustomer = await _success(
        useCases.createCustomer(name: 'عميل متأخر'),
      );
      final futureCustomer = await _success(
        useCases.createCustomer(name: 'عميل قادم'),
      );
      final product = await _success(
        useCases.createProduct(
          name: 'مكيف أقساط',
          salePriceMinor: 5000,
          openingQty: 2,
          openingCostMinor: 3000,
        ),
      );
      await _success(useCases.openShift(0));
      await _success(
        useCases.createSale(
          customerId: overdueCustomer.id,
          items: [
            SaleLineInput(productId: product.id, qty: 1, unitPriceMinor: 5000),
          ],
          payments: const [],
          installmentTerms: InstallmentTerms(
            partyId: overdueCustomer.id,
            count: 1,
            firstDueDate: DateTime.now().subtract(const Duration(days: 2)),
          ),
        ),
      );
      await _success(
        useCases.createSale(
          customerId: futureCustomer.id,
          items: [
            SaleLineInput(productId: product.id, qty: 1, unitPriceMinor: 5000),
          ],
          payments: const [],
          installmentTerms: InstallmentTerms(
            partyId: futureCustomer.id,
            count: 1,
            firstDueDate: DateTime.now().add(const Duration(days: 12)),
          ),
        ),
      );

      await _pumpLoggedInWorkbench(tester, db);
      await tester.tap(find.text('الأقساط').first);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'بحث باسم العميل'), findsOneWidget);
      expect(find.text('تحصيل'), findsWidgets);
      expect(find.text('متأخر'), findsWidgets);

      final overdueTop = tester.getTopLeft(find.text('عميل متأخر').first).dy;
      final futureTop = tester.getTopLeft(find.text('عميل قادم').first).dy;
      expect(overdueTop, lessThan(futureTop));

      await tester.enterText(
        find.widgetWithText(TextField, 'بحث باسم العميل'),
        'قادم',
      );
      await tester.pumpAndSettle();

      expect(find.text('عميل قادم'), findsWidgets);
      expect(find.text('عميل متأخر'), findsNothing);
    },
  );

  testWidgets('installments screen shows supplier balances separately', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final useCases = V2UseCases(db);
    await useCases.bootstrap();
    final owner = await _success(useCases.login('owner', 'owner123'));
    await _success(useCases.changePassword(owner.id, 'new-owner-pass'));
    final supplier = await _success(useCases.createSupplier(name: 'مورد سريع'));
    final product = await _success(
      useCases.createProduct(
        name: 'شاشة مورد',
        salePriceMinor: 9000,
        openingQty: 0,
        openingCostMinor: 0,
      ),
    );
    await _success(
      useCases.createPurchase(
        supplierId: supplier.id,
        items: [
          PurchaseLineInput(productId: product.id, qty: 1, unitCostMinor: 7000),
        ],
        payments: const [],
      ),
    );

    await _pumpLoggedInWorkbench(tester, db);
    await tester.tap(find.text('الأقساط').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('موردين'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'بحث باسم المورد'), findsOneWidget);
    expect(find.text('مورد سريع'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'سداد'), findsWidgets);

    await tester.enterText(
      find.widgetWithText(TextField, 'بحث باسم المورد'),
      'غير موجود',
    );
    await tester.pumpAndSettle();

    expect(find.text('لا توجد أرصدة موردين مطابقة'), findsOneWidget);
  });

  testWidgets('purchase quick product adds item to cart without stock intake', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final useCases = V2UseCases(db);
    await useCases.bootstrap();
    final owner = await _success(useCases.login('owner', 'owner123'));
    await _success(useCases.changePassword(owner.id, 'new-owner-pass'));

    await _pumpLoggedInWorkbench(tester, db);
    await tester.tap(find.text('الشراء').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'منتج جديد'));
    await tester.pumpAndSettle();

    expect(find.text('منتج جديد للشراء'), findsOneWidget);
    expect(find.text('رصيد افتتاحي'), findsNothing);
    expect(find.text('تكلفة افتتاحية'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextField, 'اسم المنتج'),
      'منتج سريع شراء',
    );
    await tester.enterText(find.widgetWithText(TextField, 'سعر البيع'), '120');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(find.text('تمت إضافة المنتج للفاتورة'), findsOneWidget);
    expect(find.text('منتج سريع شراء'), findsWidgets);
    final costField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'تكلفة الوحدة'),
    );
    expect(costField.initialValue, isEmpty);
    final product = await (db.select(
      db.products,
    )..where((p) => p.name.equals('منتج سريع شراء'))).getSingle();
    expect(product.stockQty, 0);
    expect(await db.select(db.purchaseInvoices).get(), isEmpty);
  });

  testWidgets('inventory screen adds a new product with minimal fields', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final useCases = V2UseCases(db);
    await useCases.bootstrap();
    final owner = await _success(useCases.login('owner', 'owner123'));
    await _success(useCases.changePassword(owner.id, 'new-owner-pass'));

    await _pumpLoggedInWorkbench(tester, db);
    await tester.tap(find.text('المخزون').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'منتج جديد'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'اسم المنتج'),
      'مروحة جديدة',
    );
    await tester.enterText(find.widgetWithText(TextField, 'سعر البيع'), '350');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(find.text('مروحة جديدة'), findsOneWidget);
    final product = await (db.select(
      db.products,
    )..where((row) => row.name.equals('مروحة جديدة'))).getSingle();
    expect(product.salePriceMinor, 35000);
    expect(product.stockQty, 0);
  });

  testWidgets(
    'inventory screen reprints a barcode label for an existing product',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final printedItems = <BarcodeLabelItem>[];
      BarcodeLabelSettingsSnapshot? printedSettings;
      final useCases = V2UseCases(db);
      await useCases.bootstrap();
      final owner = await _success(useCases.login('owner', 'owner123'));
      await _success(useCases.changePassword(owner.id, 'new-owner-pass'));
      final product = await _success(
        useCases.createProduct(
          name: 'باركود تالف',
          salePriceMinor: 35000,
          openingQty: 4,
          openingCostMinor: 22000,
        ),
      );
      await _success(
        useCases.updateBarcodeLabelSettings(widthMm: 62, heightMm: 28),
      );

      await _pumpLoggedInWorkbench(
        tester,
        db,
        barcodeLabelPrinter: (items, settings) async {
          printedItems
            ..clear()
            ..addAll(items);
          printedSettings = settings;
        },
      );
      await tester.tap(find.text('المخزون').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('طباعة باركود بدل تالف'));
      await tester.pumpAndSettle();

      expect(find.text('طباعة باركود المنتج'), findsOneWidget);
      expect(find.text('إجمالي الملصقات: 1'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'العدد'), '3');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'طباعة الباركود'));
      await tester.pumpAndSettle();

      expect(printedItems, hasLength(1));
      expect(printedItems.single.productName, 'باركود تالف');
      expect(printedItems.single.barcode, product.barcode);
      expect(printedItems.single.quantity, 3);
      expect(printedSettings?.widthMm, 62);
      expect(printedSettings?.heightMm, 28);
      final persistedProduct = await (db.select(
        db.products,
      )..where((row) => row.id.equals(product.id))).getSingle();
      expect(persistedProduct.stockQty, 4);
    },
  );

  testWidgets('inventory product dialog keeps invalid sale price visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final useCases = V2UseCases(db);
    await useCases.bootstrap();
    final owner = await _success(useCases.login('owner', 'owner123'));
    await _success(useCases.changePassword(owner.id, 'new-owner-pass'));

    await _pumpLoggedInWorkbench(tester, db);
    await tester.tap(find.text('المخزون').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'منتج جديد'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'اسم المنتج'),
      'منتج بلا سعر',
    );
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AlertDialog, 'منتج جديد'), findsOneWidget);
    expect(find.text('سعر البيع يجب أن يكون أكبر من صفر'), findsOneWidget);
    expect(await db.select(db.products).get(), isEmpty);
  });

  testWidgets('inventory product dialog requires cost for opening stock', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final useCases = V2UseCases(db);
    await useCases.bootstrap();
    final owner = await _success(useCases.login('owner', 'owner123'));
    await _success(useCases.changePassword(owner.id, 'new-owner-pass'));

    await _pumpLoggedInWorkbench(tester, db);
    await tester.tap(find.text('المخزون').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'منتج جديد'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'اسم المنتج'),
      'منتج برصيد بلا تكلفة',
    );
    await tester.enterText(find.widgetWithText(TextField, 'سعر البيع'), '100');
    await tester.enterText(find.widgetWithText(TextField, 'رصيد افتتاحي'), '2');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AlertDialog, 'منتج جديد'), findsOneWidget);
    expect(
      find.text('تكلفة افتتاحية مطلوبة عند إدخال رصيد افتتاحي'),
      findsOneWidget,
    );
    expect(await db.select(db.products).get(), isEmpty);
  });

  testWidgets('reports screen records a new expense from the UI', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final useCases = V2UseCases(db);
    await useCases.bootstrap();
    final owner = await _success(useCases.login('owner', 'owner123'));
    await _success(useCases.changePassword(owner.id, 'new-owner-pass'));
    await _success(useCases.openShift(10000));

    await _pumpLoggedInWorkbench(tester, db);
    await tester.tap(find.text('التقارير').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'مصروف جديد'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'وصف المصروف'),
      'نقل داخلي',
    );
    await tester.enterText(find.widgetWithText(TextField, 'المبلغ'), '50');
    await tester.tap(find.widgetWithText(FilledButton, 'حفظ المصروف'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('الرصيد سيصبح سالبًا'), findsOneWidget);
    await tester.tap(
      find.widgetWithText(FilledButton, 'أوافق على الرصيد السالب'),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('نقل داخلي'), findsOneWidget);
    expect((await db.select(db.expenses).get()).single.amountMinor, 5000);
  });

  testWidgets('reports expense cash entry requires an open shift', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final useCases = V2UseCases(db);
    await useCases.bootstrap();
    final owner = await _success(useCases.login('owner', 'owner123'));
    await _success(useCases.changePassword(owner.id, 'new-owner-pass'));

    await _pumpLoggedInWorkbench(tester, db);
    await tester.tap(find.text('التقارير').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'مصروف جديد'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'وصف المصروف'),
      'مصروف بدون وردية',
    );
    await tester.enterText(find.widgetWithText(TextField, 'المبلغ'), '25');
    await tester.tap(find.widgetWithText(FilledButton, 'حفظ المصروف'));
    await tester.pumpAndSettle();

    expect(find.text('افتح وردية قبل تسجيل مصروف نقدي'), findsOneWidget);
    expect(await db.select(db.expenses).get(), isEmpty);
  });

  testWidgets('reports expense dialog rejects invalid money input', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final useCases = V2UseCases(db);
    await useCases.bootstrap();
    final owner = await _success(useCases.login('owner', 'owner123'));
    await _success(useCases.changePassword(owner.id, 'new-owner-pass'));
    await _success(useCases.openShift(10000));

    await _pumpLoggedInWorkbench(tester, db);
    await tester.tap(find.text('التقارير').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'مصروف جديد'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'وصف المصروف'),
      'مصروف خطأ',
    );
    await tester.enterText(find.widgetWithText(TextField, 'المبلغ'), 'abc');
    await tester.tap(find.widgetWithText(FilledButton, 'حفظ المصروف'));
    await tester.pumpAndSettle();

    expect(find.textContaining('المبلغ:'), findsOneWidget);
    expect(await db.select(db.expenses).get(), isEmpty);
  });

  testWidgets('settings screen saves barcode label dimensions', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final useCases = V2UseCases(db);
    await useCases.bootstrap();
    final owner = await _success(useCases.login('owner', 'owner123'));
    await _success(useCases.changePassword(owner.id, 'new-owner-pass'));

    await _pumpLoggedInWorkbench(tester, db);
    await tester.tap(find.text('الإعدادات').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'عرض الملصق mm'),
      '60',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'ارتفاع الملصق mm'),
      '35',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
    await tester.pumpAndSettle();

    final settings = await useCases.barcodeLabelSettings();
    expect(settings.widthMm, 60);
    expect(settings.heightMm, 35);
  });

  testWidgets('purchase flow prints incoming barcode labels from cart', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final printedItems = <BarcodeLabelItem>[];
    BarcodeLabelSettingsSnapshot? printedSettings;
    final useCases = V2UseCases(db);
    await useCases.bootstrap();
    final owner = await _success(useCases.login('owner', 'owner123'));
    await _success(useCases.changePassword(owner.id, 'new-owner-pass'));
    await _success(useCases.openShift(0));
    final product = await _success(
      useCases.createProduct(
        name: 'ميكروويف ملصق',
        salePriceMinor: 9000,
        openingQty: 0,
        openingCostMinor: 0,
      ),
    );
    await _success(
      useCases.updateBarcodeLabelSettings(widthMm: 55, heightMm: 25),
    );

    await _pumpLoggedInWorkbench(
      tester,
      db,
      barcodeLabelPrinter: (items, settings) async {
        printedItems
          ..clear()
          ..addAll(items);
        printedSettings = settings;
      },
    );
    await tester.tap(find.text('الشراء').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('إضافة للفاتورة').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'تكلفة الوحدة'),
      '90',
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'كاش'), '180');
    await tester.pumpAndSettle();
    await tester.tap(find.text('تسجيل الشراء'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'أوافق على الرصيد السالب'),
    );
    await tester.pumpAndSettle();

    expect(find.text('طباعة باركود الوارد؟'), findsOneWidget);
    expect(find.text('إجمالي الملصقات: 2'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'طباعة الباركود'));
    await tester.pumpAndSettle();

    expect(printedItems, hasLength(1));
    expect(printedItems.single.productName, 'ميكروويف ملصق');
    expect(printedItems.single.barcode, product.barcode);
    expect(printedItems.single.quantity, 2);
    expect(printedSettings?.widthMm, 55);
    expect(printedSettings?.heightMm, 25);
    expect((await db.select(db.purchaseInvoices).get()).length, 1);
  });
}

Future<void> _pumpLoggedInWorkbench(
  WidgetTester tester,
  AppDatabase db, {
  BarcodeLabelPrinter? barcodeLabelPrinter,
}) async {
  final overrides = [
    databaseProvider.overrideWithValue(db),
    if (barcodeLabelPrinter != null)
      barcodeLabelPrinterProvider.overrideWithValue(barcodeLabelPrinter),
  ];
  await tester.pumpWidget(
    ProviderScope(overrides: overrides, child: const ALIkhlasV2App()),
  );
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextField, 'كلمة المرور'),
    'new-owner-pass',
  );
  await tester.tap(find.text('دخول'));
  await tester.pumpAndSettle();
}

Future<T> _success<T>(Future<AppResult<T>> future) async {
  final result = await future;
  if (result is AppSuccess<T>) return result.value;
  if (result is AppFailure<T>) fail(result.message);
  fail('Unexpected result: $result');
}

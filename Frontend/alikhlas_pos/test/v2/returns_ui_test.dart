import 'package:alikhlas_pos/v2/app/v2_app.dart';
import 'package:alikhlas_pos/v2/app/v2_providers.dart';
import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<T> success<T>(Future<AppResult<T>> result) async =>
    (await result as AppSuccess<T>).value;

void main() {
  testWidgets('purchase return selects an invoice and reduces supplier debt', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final uc = V2UseCases(db);
    await uc.bootstrap();
    final owner = await success(uc.login('owner', 'owner123'));
    await success(uc.changePassword(owner.id, 'new-owner-pass'));
    final supplierId = await db
        .into(db.suppliers)
        .insert(SuppliersCompanion.insert(name: 'مورد مرتجع الواجهة'));
    final product = await success(
      uc.createProduct(
        operationKey: uc.newOpeningStockOperationKey(),
        name: 'ثلاجة مرتجع الواجهة',
        salePriceMinor: 40000,
        openingQty: 0,
        openingCostMinor: 0,
      ),
    );
    final purchaseId = await success(
      uc.createPurchase(
        operationKey: uc.newPurchaseOperationKey(),
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
    final invoice = await (db.select(
      db.purchaseInvoices,
    )..where((row) => row.id.equals(purchaseId))).getSingle();

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
    await tester.tap(find.text('المرتجعات').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('مرتجع شراء'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(
        TextField,
        'رقم فاتورة الشراء أو اسم المورد أو هاتفه',
      ),
      'مورد مرتجع الواجهة',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'بحث'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(invoice.invoiceNo), findsOneWidget);
    await tester.tap(find.text('اختيار'));
    await tester.pumpAndSettle();
    expect(find.text('ثلاجة مرتجع الواجهة'), findsOneWidget);
    await tester.tap(find.byTooltip('زيادة').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(
        DropdownButtonFormField<PaymentMethod>,
        'تسوية مرتجع المورد',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('خصم من مديونية المورد').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('تسجيل مرتجع الشراء'));
    await tester.pumpAndSettle();
    expect(find.text('تم تسجيل مرتجع الشراء'), findsOneWidget);
    expect(await db.select(db.purchaseReturns).get(), hasLength(1));
    expect((await db.select(db.products).getSingle()).stockQty, 1);
    final plan = (await db.select(db.installmentPlans).get()).singleWhere(
      (row) => row.ownerType == 'purchase' && row.ownerId == purchaseId,
    );
    expect(plan.totalMinor, 10000);
    expect(tester.takeException(), isNull);
  });

  testWidgets('old invoice search and explicit installment overflow refund', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final uc = V2UseCases(db);
    await uc.bootstrap();
    final owner = await success(uc.login('owner', 'owner123'));
    await success(uc.changePassword(owner.id, 'new-owner-pass'));
    final customer = await db
        .into(db.customers)
        .insert(CustomersCompanion.insert(name: 'عميل الفاتورة القديمة'));
    final product = await success(
      uc.createProduct(
        operationKey: uc.newOpeningStockOperationKey(),
        name: 'مكنسة اختبار',
        salePriceMinor: 10000,
        openingQty: 1,
        openingCostMinor: 5000,
      ),
    );
    final sale = await success(
      uc.createSale(
        operationKey: uc.newSaleOperationKey(),
        customerId: customer,
        items: [
          SaleLineInput(productId: product.id, qty: 1, unitPriceMinor: 10000),
        ],
        payments: const [],
        installmentTerms: InstallmentTerms(
          partyId: customer,
          count: 2,
          firstDueDate: DateTime(2026, 7),
        ),
      ),
    );
    final invoice = await (db.select(
      db.saleInvoices,
    )..where((s) => s.id.equals(sale))).getSingle();
    final plan = await db.select(db.installmentPlans).getSingle();
    await success(
      uc.collectInstallment(
        operationKey: uc.newInstallmentOperationKey(),
        planId: plan.id,
        amountMinor: 8000,
        method: PaymentMethod.wallet,
      ),
    );
    for (var i = 0; i < 25; i++) {
      await db
          .into(db.saleInvoices)
          .insert(
            SaleInvoicesCompanion.insert(
              invoiceNo: 'NEW-$i',
              subtotalMinor: 100,
              totalMinor: 100,
              paidMinor: 100,
              remainingMinor: 0,
            ),
          );
    }
    var printAttempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          saleReceiptPrinterProvider.overrideWithValue((receipt) async {
            expect(receipt.invoice.id, sale);
            printAttempts++;
            if (printAttempts == 1) throw StateError('printer disconnected');
          }),
        ],
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
    await tester.tap(find.text('المرتجعات').first);
    await tester.pumpAndSettle();
    expect(find.text(invoice.invoiceNo), findsNothing);
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    expect(find.text(invoice.invoiceNo), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'عميل الفاتورة القديمة');
    await tester.tap(find.text('بحث'));
    await tester.pumpAndSettle();
    expect(find.text('صفحة 1'), findsOneWidget);
    expect(find.text(invoice.invoiceNo), findsOneWidget);
    await tester.tap(find.text('كل التواريخ'));
    await tester.pumpAndSettle();
    final dateContext = tester.element(find.byType(DateRangePickerDialog));
    expect(Localizations.localeOf(dateContext).languageCode, 'ar');
    final formattedDate = MaterialLocalizations.of(
      dateContext,
    ).formatCompactDate(DateTime(2000, 1, 1));
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    final dateFields = find.descendant(
      of: find.byType(DateRangePickerDialog),
      matching: find.byType(TextField),
    );
    expect(dateFields, findsNWidgets(2));
    await tester.enterText(dateFields.at(0), formattedDate);
    await tester.enterText(dateFields.at(1), formattedDate);
    await tester.tap(find.text('تطبيق').last);
    await tester.pumpAndSettle();
    expect(find.text('لا توجد فواتير مطابقة'), findsOneWidget);
    await tester.tap(find.text('مسح التاريخ'));
    await tester.pumpAndSettle();
    expect(find.text(invoice.invoiceNo), findsOneWidget);
    await tester.tap(find.text('تفاصيل وطباعة').first);
    await tester.pumpAndSettle();
    expect(find.text('المديونية الحالية'), findsOneWidget);
    expect(find.text('تحصيل أقساط بعد البيع'), findsOneWidget);
    await tester.tap(find.text('طباعة'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('الفاتورة محفوظة، لكن تعذرت الطباعة'),
      findsOneWidget,
    );
    await tester.tap(find.text('طباعة'));
    await tester.pumpAndSettle();
    expect(printAttempts, 2);
    expect(await db.select(db.saleInvoices).get(), hasLength(26));
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('إنشاء مرتجع'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<PaymentMethod>, 'طريقة الرد'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('خصم من العميل').last);
    await tester.pumpAndSettle();
    expect(find.text('خصم من المديونية'), findsOneWidget);
    expect(find.text('فائض يُرد للعميل'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'تسجيل'))
          .onPressed,
      isNull,
    );
    await tester.tap(
      find.widgetWithText(
        DropdownButtonFormField<PaymentMethod>,
        'اختر طريقة رد الفائض',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('رد الفائض بالمحفظة').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('تسجيل'));
    await tester.pumpAndSettle();
    expect(find.text('تم تسجيل المرتجع'), findsOneWidget);
    expect(await db.select(db.saleReturns).get(), hasLength(1));
    final updated = await db.select(db.installmentPlans).getSingle();
    expect(updated.totalMinor - updated.paidMinor, 0);
    expect((await db.select(db.products).getSingle()).stockQty, 1);
    expect(tester.takeException(), isNull);
  });
}

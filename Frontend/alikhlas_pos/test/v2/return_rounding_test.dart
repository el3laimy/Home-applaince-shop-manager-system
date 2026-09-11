import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final quantities in [
    [1, 1, 1],
    [2, 1],
  ]) {
    for (final price in [10000, 1]) {
      test('partial returns preserve cents: $quantities at $price', () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final uc = V2UseCases(db);
        final product =
            (await uc.createProduct(
                      operationKey: uc.newOpeningStockOperationKey(),
                      name: 'rounding',
                      salePriceMinor: price,
                      openingQty: 3,
                      openingCostMinor: 1,
                    )
                    as AppSuccess<Product>)
                .value;
        final discount = price == 1 ? 2 : 1;
        final net = price * 3 - discount;
        final sale =
            (await uc.createSale(
                      operationKey: uc.newSaleOperationKey(),
                      items: [
                        SaleLineInput(
                          productId: product.id,
                          qty: 3,
                          unitPriceMinor: price,
                        ),
                      ],
                      payments: [PaymentInput(PaymentMethod.wallet, net)],
                      discountMinor: discount,
                    )
                    as AppSuccess<int>)
                .value;
        var refunded = 0;
        for (final quantity in quantities) {
          final preview = await uc.saleReturnPreview(sale);
          final line = preview.lines.single;
          final expected = line.refundForQuantity(quantity);
          expect(
            await uc.createSaleReturn(
              operationKey: uc.newSaleReturnOperationKey(),
              saleId: sale,
              saleItemQuantities: {line.saleItemId: quantity},
              refundMethod: PaymentMethod.wallet,
            ),
            isA<AppSuccess<int>>(),
          );
          final returns = await db.select(db.saleReturns).get();
          final total = returns.fold<int>(
            0,
            (sum, row) => sum + row.refundMinor,
          );
          expect(total - refunded, expected);
          refunded = total;
          expect(refunded, lessThanOrEqualTo(net));
        }
        expect(refunded, net);
        final returnItems = await db.select(db.saleReturnItems).get();
        expect(
          returnItems.fold<int>(
            0,
            (sum, row) => sum + row.qty * row.unitPriceMinor,
          ),
          net,
        );
        expect(returnItems.fold<int>(0, (sum, row) => sum + row.qty), 3);
        final snapshot = await uc.dashboardSnapshot();
        expect(snapshot.salesMinor, 0);
        expect(snapshot.walletMinor, 0);
        expect(snapshot.cogsMinor, 0);
        expect((await db.select(db.products).getSingle()).stockQty, 3);
        expect(
          (await uc.saleReturnPreview(sale)).lines.single.lineTotalMinor,
          0,
        );
      });
    }
  }

  test(
    'discount is allocated across lines regardless of return order',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final uc = V2UseCases(db);
      final products = <Product>[];
      for (var i = 0; i < 3; i++) {
        products.add(
          (await uc.createProduct(
                    operationKey: uc.newOpeningStockOperationKey(),
                    name: 'item $i',
                    salePriceMinor: 100,
                    openingQty: 1,
                    openingCostMinor: 50,
                  )
                  as AppSuccess<Product>)
              .value,
        );
      }
      final sale =
          (await uc.createSale(
                    operationKey: uc.newSaleOperationKey(),
                    items: [
                      for (final product in products)
                        SaleLineInput(
                          productId: product.id,
                          qty: 1,
                          unitPriceMinor: 100,
                        ),
                    ],
                    payments: [const PaymentInput(PaymentMethod.wallet, 299)],
                    discountMinor: 1,
                  )
                  as AppSuccess<int>)
              .value;
      final preview = await uc.saleReturnPreview(sale);
      expect(
        preview.lines.fold<int>(0, (sum, line) => sum + line.lineTotalMinor),
        299,
      );
      for (final line in preview.lines.reversed) {
        expect(
          await uc.createSaleReturn(
            operationKey: uc.newSaleReturnOperationKey(),
            saleId: sale,
            saleItemQuantities: {line.saleItemId: 1},
            refundMethod: PaymentMethod.wallet,
          ),
          isA<AppSuccess<int>>(),
        );
      }
      expect(
        (await db.select(db.saleReturns).get()).fold<int>(
          0,
          (sum, row) => sum + row.refundMinor,
        ),
        299,
      );
      expect((await uc.dashboardSnapshot()).salesMinor, 0);
    },
  );

  test('full discounted return equals invoice net', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final uc = V2UseCases(db);
    final product =
        (await uc.createProduct(
                  operationKey: uc.newOpeningStockOperationKey(),
                  name: 'audit',
                  salePriceMinor: 10000,
                  openingQty: 3,
                  openingCostMinor: 5000,
                )
                as AppSuccess<Product>)
            .value;
    final sale =
        (await uc.createSale(
                  operationKey: uc.newSaleOperationKey(),
                  items: [
                    SaleLineInput(
                      productId: product.id,
                      qty: 3,
                      unitPriceMinor: 10000,
                    ),
                  ],
                  payments: [const PaymentInput(PaymentMethod.wallet, 29999)],
                  discountMinor: 1,
                )
                as AppSuccess<int>)
            .value;
    final item = await db.select(db.saleItems).getSingle();
    expect(
      await uc.createSaleReturn(
        operationKey: uc.newSaleReturnOperationKey(),
        saleId: sale,
        saleItemQuantities: {item.id: 3},
        refundMethod: PaymentMethod.wallet,
        allowNegativeBalance: true,
      ),
      isA<AppSuccess<int>>(),
    );
    expect((await db.select(db.saleReturns).getSingle()).refundMinor, 29999);
    expect((await db.select(db.saleInvoices).getSingle()).totalMinor, 29999);
  });
}

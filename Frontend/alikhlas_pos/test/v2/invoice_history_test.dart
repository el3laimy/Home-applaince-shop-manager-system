import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'history date boundaries include start and exclude next midnight',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final uc = V2UseCases(db);
      for (final stamp in [
        DateTime(2026, 9, 8, 23, 59, 59),
        DateTime(2026, 9, 9),
        DateTime(2026, 9, 9, 23, 59, 59),
        DateTime(2026, 9, 10),
      ]) {
        await db
            .into(db.saleInvoices)
            .insert(
              SaleInvoicesCompanion.insert(
                invoiceNo: stamp.toIso8601String(),
                createdAt: Value(stamp),
                subtotalMinor: 100,
                totalMinor: 100,
                paidMinor: 100,
                remainingMinor: 0,
              ),
            );
      }
      final rows = await uc.saleInvoiceHistory(
        createdFrom: DateTime(2026, 9, 9),
        createdBefore: DateTime(2026, 9, 10),
      );
      expect(rows, hasLength(2));
      expect(rows.every((row) => row.createdAt.day == 9), isTrue);
      expect(
        await uc.saleInvoiceHistory(
          query: '23:59',
          createdFrom: DateTime(2026, 9, 9),
          createdBefore: DateTime(2026, 9, 10),
        ),
        hasLength(1),
      );
      await expectLater(
        uc.saleInvoiceHistory(
          createdFrom: DateTime(2026, 9, 10),
          createdBefore: DateTime(2026, 9, 9),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'history finds old invoices by number customer phone and pages without overlap',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final uc = V2UseCases(db);
      final customer = await db
          .into(db.customers)
          .insert(
            CustomersCompanion.insert(
              name: 'عميل قديم',
              phone: const Value('01012345'),
            ),
          );
      for (var i = 0; i < 31; i++) {
        await db
            .into(db.saleInvoices)
            .insert(
              SaleInvoicesCompanion.insert(
                invoiceNo: 'SALE-$i',
                customerId: i == 0 ? Value(customer) : const Value.absent(),
                subtotalMinor: 100,
                totalMinor: 100,
                paidMinor: 100,
                remainingMinor: 0,
              ),
            );
      }
      final first = await uc.saleInvoiceHistory(limit: 20);
      final next = await uc.saleInvoiceHistory(limit: 20, offset: 20);
      expect(first, hasLength(20));
      expect(next, hasLength(11));
      expect({
        ...first.map((s) => s.id),
        ...next.map((s) => s.id),
      }, hasLength(31));
      for (final query in ['SALE-0', 'عميل قديم', '01012345']) {
        expect(
          (await uc.saleInvoiceHistory(query: query)).single.invoiceNo,
          'SALE-0',
        );
      }
      expect(await uc.saleInvoiceHistory(query: '%'), isEmpty);
    },
  );
}

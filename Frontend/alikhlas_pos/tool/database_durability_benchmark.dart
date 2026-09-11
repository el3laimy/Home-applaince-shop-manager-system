// Opt-in measurement; not part of the regular test directory.
// Run from the Flutter project:
// DURABILITY_BENCHMARK_OUTPUT=/tmp/durability.json flutter test --no-pub \
//   --concurrency=1 tool/database_durability_benchmark.dart
import 'dart:convert';
import 'dart:io';

import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const _rounds = 3;
const _warmupCycles = 10;
const _measuredCycles = 100;
const _operations = [
  'cash_sale',
  'customer_collection',
  'supplier_payment',
  'expense',
  'sale_return',
];

void main() {
  test(
    'measure real financial commits under WAL NORMAL and FULL',
    () async {
      // Stay on the project filesystem; systemTemp may be a RAM filesystem.
      final scratch = Directory('.dart_tool/durability_benchmark');
      await scratch.create(recursive: true);
      final runs = <Map<String, Object?>>[];
      for (var round = 0; round < _rounds; round++) {
        final modes = round.isEven ? ['NORMAL', 'FULL'] : ['FULL', 'NORMAL'];
        for (final mode in modes) {
          runs.add(await _measure(scratch, mode, round + 1));
        }
      }
      final aggregate = <String, Object?>{};
      for (final mode in ['NORMAL', 'FULL']) {
        final samples = <String, List<int>>{
          for (final operation in _operations) operation: [],
        };
        for (final run in runs.where((run) => run['mode'] == mode)) {
          final raw = run['microseconds']! as Map<String, List<int>>;
          for (final operation in _operations) {
            samples[operation]!.addAll(raw[operation]!);
          }
        }
        aggregate[mode] = {
          for (final operation in _operations)
            operation: _statistics(samples[operation]!),
          'all_operations': _statistics(
            samples.values.expand((s) => s).toList(),
          ),
        };
      }
      final report = {
        'created_at_utc': DateTime.now().toUtc().toIso8601String(),
        'platform': Platform.operatingSystem,
        'os_version': Platform.operatingSystemVersion,
        'dart_version': Platform.version,
        'database_backend': 'NativeDatabase.createInBackground (real file)',
        'scratch_parent': scratch.absolute.path,
        'rounds': _rounds,
        'warmup_cycles_per_run': _warmupCycles,
        'measured_cycles_per_run': _measuredCycles,
        'measurement':
            'awaited use-case call including transaction commit and '
            'idempotency receipt; excludes setup, UI staging/ack, snapshot refresh '
            'and printing; nearest-rank percentiles in milliseconds',
        'limitations':
            'Flutter test/JIT on this device; sequential small shop '
            'workload, warm caches, no controlled disk/CPU isolation. This is a '
            'latency measurement, not a physical power-loss experiment.',
        'aggregate': aggregate,
        'runs': runs,
      };
      final json = const JsonEncoder.withIndent('  ').convert(report);
      final output = Platform.environment['DURABILITY_BENCHMARK_OUTPUT'];
      if (output != null && output.isNotEmpty) {
        await File(output).writeAsString('$json\n', flush: true);
      }
      // Compact console output; the optional JSON retains every raw observation.
      // ignore: avoid_print
      print(const JsonEncoder.withIndent('  ').convert(aggregate));
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

Future<T> _success<T>(Future<AppResult<T>> pending) async {
  final result = await pending;
  if (result is! AppSuccess<T>) {
    throw StateError('Benchmark operation did not commit: $result');
  }
  return result.value;
}

Future<Map<String, Object?>> _measure(
  Directory scratch,
  String mode,
  int round,
) async {
  final directory = await scratch.createTemp('round-$round-$mode-');
  final file = File('${directory.path}/shop.db');
  var db = AppDatabase(NativeDatabase.createInBackground(file));
  try {
    // Trigger beforeOpen first, then change only this throwaway connection.
    await db.customSelect('SELECT 1').get();
    await db.customStatement('PRAGMA synchronous = $mode;');
    final synchronous =
        (await db.customSelect('PRAGMA synchronous').getSingle())
            .data
            .values
            .single;
    final journal = (await db.customSelect('PRAGMA journal_mode').getSingle())
        .data
        .values
        .single;
    expect(synchronous, mode == 'FULL' ? 2 : 1);
    expect(journal, 'wal');
    final sqliteVersion =
        (await db.customSelect('SELECT sqlite_version()').getSingle())
            .data
            .values
            .single;
    final uc = V2UseCases(db);
    const cycles = _warmupCycles + _measuredCycles;
    await _success(uc.openShift(1000000));
    final product = await _success(
      uc.createProduct(
        name: 'منتج قياس البيع والمرتجع',
        salePriceMinor: 10000,
        openingQty: 1,
        openingCostMinor: 5000,
      ),
    );
    final creditProduct = await _success(
      uc.createProduct(
        name: 'منتج قياس الأقساط',
        salePriceMinor: cycles * 1000,
        openingQty: 1,
        openingCostMinor: cycles * 500,
      ),
    );
    final customer = await db
        .into(db.customers)
        .insert(CustomersCompanion.insert(name: 'عميل تجريبي'));
    final supplier = await db
        .into(db.suppliers)
        .insert(SuppliersCompanion.insert(name: 'مورد تجريبي'));
    await _success(
      uc.createSale(
        customerId: customer,
        items: [
          SaleLineInput(
            productId: creditProduct.id,
            qty: 1,
            unitPriceMinor: cycles * 1000,
          ),
        ],
        payments: const [],
        installmentTerms: InstallmentTerms(
          partyId: customer,
          count: 1,
          firstDueDate: DateTime(2026, 9, 11),
        ),
      ),
    );
    final customerPlan = await db.select(db.installmentPlans).getSingle();
    await _success(
      uc.createPurchase(
        supplierId: supplier,
        items: [
          PurchaseLineInput(
            productId: creditProduct.id,
            qty: 1,
            unitCostMinor: cycles * 500,
          ),
        ],
        payments: const [],
      ),
    );
    final supplierPlan = await (db.select(
      db.installmentPlans,
    )..where((row) => row.partyType.equals('supplier'))).getSingle();
    final samples = <String, List<int>>{
      for (final operation in _operations) operation: [],
    };

    Future<int> time(
      String operation,
      int cycle,
      Future<AppResult<int>> Function() action,
    ) async {
      final stopwatch = Stopwatch()..start();
      final value = await _success(action());
      stopwatch.stop();
      if (cycle >= _warmupCycles) {
        samples[operation]!.add(stopwatch.elapsedMicroseconds);
      }
      return value;
    }

    for (var cycle = 0; cycle < cycles; cycle++) {
      final saleId = await time(
        'cash_sale',
        cycle,
        () => uc.createSale(
          operationKey: 'sale-$cycle',
          items: [
            SaleLineInput(productId: product.id, qty: 1, unitPriceMinor: 10000),
          ],
          payments: const [PaymentInput(PaymentMethod.cash, 10000)],
        ),
      );
      await time(
        'customer_collection',
        cycle,
        () => uc.collectInstallment(
          operationKey: 'collection-$cycle',
          planId: customerPlan.id,
          amountMinor: 1000,
          method: PaymentMethod.cash,
        ),
      );
      await time(
        'supplier_payment',
        cycle,
        () => uc.paySupplierInstallment(
          operationKey: 'supplier-$cycle',
          planId: supplierPlan.id,
          amountMinor: 500,
          method: PaymentMethod.cash,
        ),
      );
      await time(
        'expense',
        cycle,
        () => uc.recordExpense(
          operationKey: 'expense-$cycle',
          description: 'مصروف قياس',
          amountMinor: 100,
          method: PaymentMethod.cash,
        ),
      );
      final saleItem = await (db.select(
        db.saleItems,
      )..where((row) => row.saleId.equals(saleId))).getSingle();
      await time(
        'sale_return',
        cycle,
        () => uc.createSaleReturn(
          operationKey: 'return-$cycle',
          saleId: saleId,
          saleItemQuantities: {saleItem.id: 1},
          refundMethod: PaymentMethod.cash,
        ),
      );
    }

    // Verify committed data from a new connection, outside measured intervals.
    await db.close();
    db = AppDatabase(NativeDatabase.createInBackground(file));
    expect((await db.select(db.saleInvoices).get()).length, cycles + 1);
    expect((await db.select(db.saleReturns).get()).length, cycles);
    expect((await db.select(db.expenses).get()).length, cycles);
    for (final plan in await db.select(db.installmentPlans).get()) {
      expect(plan.paidMinor, plan.totalMinor);
    }
    expect(
      (await (db.select(
        db.products,
      )..where((row) => row.id.equals(product.id))).getSingle()).stockQty,
      1,
    );
    expect(
      (await db.customSelect('PRAGMA integrity_check').getSingle())
          .data
          .values
          .single,
      'ok',
    );
    final unbalanced = await db
        .customSelect(
          'SELECT entry_id FROM ledger_lines GROUP BY entry_id '
          'HAVING SUM(debit_minor) != SUM(credit_minor)',
        )
        .get();
    expect(unbalanced, isEmpty);
    return {
      'round': round,
      'mode': mode,
      'synchronous_during_measurement': synchronous,
      'journal_mode': journal,
      'sqlite_version': sqliteVersion,
      'post_reopen_validation':
          'invoice/return/expense counts, plans paid, stock, '
          'integrity_check and per-entry ledger balance passed',
      'statistics': {
        for (final operation in _operations)
          operation: _statistics(samples[operation]!),
      },
      'microseconds': samples,
    };
  } finally {
    await db.close();
    await directory.delete(recursive: true);
  }
}

Map<String, Object> _statistics(List<int> samples) {
  final sorted = samples.toList()..sort();
  double percentile(double fraction) =>
      sorted[(sorted.length * fraction).ceil() - 1] / 1000;
  return {
    'n': sorted.length,
    'p50_ms': percentile(0.50),
    'p95_ms': percentile(0.95),
    'max_ms': sorted.last / 1000,
  };
}

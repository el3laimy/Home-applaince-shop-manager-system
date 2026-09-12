// Opt-in production-scale measurement; it is intentionally outside test/.
// Run from the Flutter project:
// SCALE_BENCHMARK_OUTPUT=/tmp/alikhlas-scale.json flutter test --no-pub \
//   --concurrency=1 tool/production_scale_benchmark.dart
import 'dart:convert';
import 'dart:io';

import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const _productCount = 10000;
const _invoiceCount = 50000;
const _openingQuantity = 1000;
const _unitPriceMinor = 10000;
const _unitCostMinor = 6000;
const _warmupSamples = 3;
const _measuredSamples = 20;
const _baseTimestamp = 1767225600; // 2026-01-01T00:00:00Z.

void main() {
  test(
    'measure 10k products and 50k balanced invoices',
    () async {
      final scratch = Directory('.dart_tool/production_scale_benchmark');
      await scratch.create(recursive: true);
      final runDirectory = await scratch.createTemp('run-');
      final databaseFile = File('${runDirectory.path}/shop.db');
      late AppDatabase db;
      addTearDown(() async {
        await db.close();
        if (await runDirectory.exists()) {
          await runDirectory.delete(recursive: true);
        }
      });

      db = AppDatabase(NativeDatabase(databaseFile));
      await db.customSelect('SELECT 1;').getSingle();
      final seedWatch = Stopwatch()..start();
      await _seed(db);
      seedWatch.stop();
      await db.close();

      final openWatch = Stopwatch()..start();
      db = AppDatabase(NativeDatabase.createInBackground(databaseFile));
      await db.customSelect('SELECT 1;').getSingle();
      openWatch.stop();

      final useCases = V2UseCases(
        db,
        clock: () => DateTime.utc(2026, 1, 1, 12),
      );
      final workbenchSamples = await _measure(
        () async => useCases.workbenchSnapshot(),
        measured: 5,
        warmup: 1,
      );
      final targetInvoice = 'SCALE-${_invoiceCount.toString().padLeft(6, '0')}';
      final searchSamples = await _measure(() async {
        final rows = await useCases.saleInvoiceHistory(
          query: targetInvoice,
          limit: 21,
        );
        expect(rows, hasLength(1));
        expect(rows.single.invoiceNo, targetInvoice);
      });
      final reportSamples = await _measure(() async {
        final report = await useCases.periodReport(
          start: DateTime.utc(2026, 1, 1),
          end: DateTime.utc(2026, 1, 2),
        );
        expect(report.saleCount, greaterThanOrEqualTo(_invoiceCount));
      }, measured: 8);

      await _success(
        useCases.openShift(0, operationKey: useCases.newShiftOperationKey()),
      );
      var saleSequence = 0;
      final saveSamples = await _measure(() async {
        saleSequence += 1;
        await _success(
          useCases.createSale(
            operationKey: 'scale-measured-sale-$saleSequence',
            items: const [
              SaleLineInput(
                productId: 1,
                qty: 1,
                unitPriceMinor: _unitPriceMinor,
              ),
            ],
            payments: const [PaymentInput(PaymentMethod.cash, _unitPriceMinor)],
          ),
        );
      });

      final auditWatch = Stopwatch()..start();
      final audit = await useCases.dataIntegrityAudit();
      auditWatch.stop();
      if (audit.issues.isNotEmpty) {
        // Keep benchmark failures diagnosable without retaining the large
        // temporary database after the test process exits.
        // ignore: avoid_print
        print(
          const JsonEncoder.withIndent(' ').convert(
            audit.issues
                .take(25)
                .map(
                  (issue) => {
                    'code': issue.code,
                    'record': issue.record,
                    'message': issue.message,
                  },
                )
                .toList(growable: false),
          ),
        );
      }
      expect(audit.issues, isEmpty);
      expect(audit.productCount, _productCount);
      expect(
        (await db.customSelect('PRAGMA quick_check;').getSingle())
            .data
            .values
            .single,
        'ok',
      );

      final metrics = <String, Object?>{
        'database_open_ms': openWatch.elapsedMicroseconds / 1000,
        'workbench_snapshot': _statistics(workbenchSamples),
        'exact_invoice_search': _statistics(searchSamples),
        'period_report': _statistics(reportSamples),
        'cash_sale_commit': _statistics(saveSamples),
        'full_integrity_audit_ms': auditWatch.elapsedMicroseconds / 1000,
      };
      final workbenchP95 = _percentile(workbenchSamples, 0.95) / 1000;
      final searchP95 = _percentile(searchSamples, 0.95) / 1000;
      final reportP95 = _percentile(reportSamples, 0.95) / 1000;
      final saveP95 = _percentile(saveSamples, 0.95) / 1000;
      expect(openWatch.elapsedMilliseconds, lessThan(5000));
      expect(workbenchP95, lessThan(2500));
      expect(searchP95, lessThan(300));
      expect(reportP95, lessThan(2000));
      expect(saveP95, lessThan(1000));
      final report = <String, Object?>{
        'created_at_utc': DateTime.now().toUtc().toIso8601String(),
        'platform': Platform.operatingSystem,
        'os_version': Platform.operatingSystemVersion,
        'dart_version': Platform.version,
        'logical_processors': Platform.numberOfProcessors,
        'cpu_model': await _cpuModel(),
        'database_backend': 'SQLite file via NativeDatabase',
        'products': _productCount,
        'seeded_invoices': _invoiceCount,
        'measured_sale_commits': _warmupSamples + _measuredSamples,
        'database_size_bytes': await databaseFile.length(),
        'seed_duration_ms': seedWatch.elapsedMicroseconds / 1000,
        'metrics_ms': metrics,
        'initial_targets': {
          'database_open_under_5000_ms': openWatch.elapsedMilliseconds < 5000,
          'workbench_p95_under_2500_ms': workbenchP95 < 2500,
          'exact_search_p95_under_300_ms': searchP95 < 300,
          'period_report_p95_under_2000_ms': reportP95 < 2000,
          'sale_commit_p95_under_1000_ms': saveP95 < 1000,
        },
        'integrity': {
          'issues': audit.issues.length,
          'ledger_entries': audit.ledgerEntryCount,
          'products': audit.productCount,
        },
        'limitations':
            'Measures the SQLite/application layer in Flutter test JIT with warm '
            'query caches. Database open excludes Flutter engine and window '
            'rendering. Synthetic invoices use one item and cash payment. Results '
            'must be repeated on the declared customer hardware before release.',
      };
      final encoded = const JsonEncoder.withIndent(' ').convert(report);
      final output = Platform.environment['SCALE_BENCHMARK_OUTPUT'];
      if (output != null && output.isNotEmpty) {
        await File(output).writeAsString('$encoded\n', flush: true);
      }
      // ignore: avoid_print
      print(encoded);
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}

Future<void> _seed(AppDatabase db) async {
  const productUses =
      '(CASE WHEN id <= $_invoiceCount THEN '
      '((($_invoiceCount - id) / $_productCount) + 1) ELSE 0 END)';
  await db.transaction(() async {
    await db.customStatement('''
      WITH RECURSIVE sequence(id) AS (
        VALUES(1) UNION ALL SELECT id + 1 FROM sequence WHERE id < $_productCount
      )
      INSERT INTO products (
        id, name, barcode, stock_qty, min_stock_qty, sale_price_minor,
        avg_cost_minor, inventory_value_minor, is_active, created_at
      )
      SELECT id, 'منتج قياس ' || printf('%05d', id),
        'SCALE-P-' || printf('%05d', id),
        $_openingQuantity - $productUses, 10, $_unitPriceMinor,
        $_unitCostMinor, ($_openingQuantity - $productUses) * $_unitCostMinor,
        1, $_baseTimestamp
      FROM sequence;
    ''');
    await db.customStatement('''
      INSERT INTO stock_movements (
        product_id, type, qty_delta, balance_after, reference_type,
        reference_id, created_at
      )
      SELECT id, 'opening_stock', $_openingQuantity, $_openingQuantity,
        'opening_stock', id, $_baseTimestamp FROM products ORDER BY id;
    ''');
    await db.customStatement('''
      INSERT INTO ledger_entries (
        id, reference_type, reference_id, description, created_at
      )
      SELECT id, 'opening_stock', id, 'رصيد افتتاحي لعينة الأداء',
        $_baseTimestamp FROM products;
    ''');
    await db.customStatement('''
      INSERT INTO ledger_lines (entry_id, account_code, debit_minor, credit_minor)
      SELECT id, 'inventory', $_openingQuantity * $_unitCostMinor, 0
      FROM products;
    ''');
    await db.customStatement('''
      INSERT INTO ledger_lines (entry_id, account_code, debit_minor, credit_minor)
      SELECT id, 'capital', 0, $_openingQuantity * $_unitCostMinor
      FROM products;
    ''');
    await db.customStatement('''
      WITH RECURSIVE sequence(id) AS (
        VALUES(1) UNION ALL SELECT id + 1 FROM sequence WHERE id < $_invoiceCount
      )
      INSERT INTO sale_invoices (
        id, invoice_no, subtotal_minor, discount_minor, interest_minor,
        total_minor, paid_minor, remaining_minor, created_at
      )
      SELECT id, 'SCALE-' || printf('%06d', id), $_unitPriceMinor, 0, 0,
        $_unitPriceMinor, $_unitPriceMinor, 0, $_baseTimestamp + id
      FROM sequence;
    ''');
    await db.customStatement('''
      INSERT INTO sale_items (
        id, sale_id, product_id, qty, unit_price_minor, unit_cost_minor,
        cost_minor, line_total_minor
      )
      SELECT id, id, ((id - 1) % $_productCount) + 1, 1,
        $_unitPriceMinor, $_unitCostMinor, $_unitCostMinor, $_unitPriceMinor
      FROM sale_invoices;
    ''');
    await db.customStatement('''
      INSERT INTO payments (owner_type, owner_id, method, amount_minor, created_at)
      SELECT 'sale', id, 'cash', $_unitPriceMinor, created_at
      FROM sale_invoices;
    ''');
    await db.customStatement('''
      INSERT INTO stock_movements (
        product_id, type, qty_delta, balance_after, reference_type,
        reference_id, created_at
      )
      SELECT ((id - 1) % $_productCount) + 1, 'sale', -1,
        $_openingQuantity - (((id - 1) / $_productCount) + 1),
        'sale', id, created_at
      FROM sale_invoices
      ORDER BY id;
    ''');
    await db.customStatement('''
      INSERT INTO ledger_entries (
        id, reference_type, reference_id, description, created_at
      )
      SELECT $_productCount + id, 'sale', id, 'بيع عينة الأداء', created_at
      FROM sale_invoices;
    ''');
    for (final line in const [
      ('cash', _unitPriceMinor, 0),
      ('sales', 0, _unitPriceMinor),
      ('cogs', _unitCostMinor, 0),
      ('inventory', 0, _unitCostMinor),
    ]) {
      await db.customStatement('''
        INSERT INTO ledger_lines (
          entry_id, account_code, debit_minor, credit_minor
        )
        SELECT $_productCount + id, '${line.$1}', ${line.$2}, ${line.$3}
        FROM sale_invoices;
      ''');
    }
  });
}

Future<List<int>> _measure(
  Future<void> Function() action, {
  int warmup = _warmupSamples,
  int measured = _measuredSamples,
}) async {
  final samples = <int>[];
  for (var index = 0; index < warmup + measured; index += 1) {
    final watch = Stopwatch()..start();
    await action();
    watch.stop();
    if (index >= warmup) samples.add(watch.elapsedMicroseconds);
  }
  return samples;
}

Map<String, Object> _statistics(List<int> microseconds) {
  final sorted = [...microseconds]..sort();
  return {
    'samples': sorted.length,
    'min': sorted.first / 1000,
    'median': _percentile(sorted, 0.50) / 1000,
    'p95': _percentile(sorted, 0.95) / 1000,
    'max': sorted.last / 1000,
  };
}

int _percentile(List<int> values, double percentile) {
  final sorted = [...values]..sort();
  final index = (percentile * sorted.length).ceil().clamp(1, sorted.length) - 1;
  return sorted[index];
}

Future<T> _success<T>(Future<AppResult<T>> pending) async {
  final result = await pending;
  if (result is AppSuccess<T>) return result.value;
  throw StateError('Benchmark operation failed: $result');
}

Future<String> _cpuModel() async {
  if (!Platform.isLinux) return 'not collected';
  try {
    final line = await File('/proc/cpuinfo').readAsLines().then(
      (lines) => lines.firstWhere((line) => line.startsWith('model name')),
    );
    return line.split(':').skip(1).join(':').trim();
  } on Object {
    return 'unavailable';
  }
}

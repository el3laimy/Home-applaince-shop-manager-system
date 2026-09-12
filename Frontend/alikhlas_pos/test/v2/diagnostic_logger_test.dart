import 'dart:convert';
import 'dart:io';

import 'package:alikhlas_pos/v2/application/v2_diagnostic_logger.dart';
import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'diagnostic log omits messages, paths, and raw operation keys',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'alikhlas-diagnostics-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/errors.jsonl');
      final logger = V2DiagnosticLogger.forFile(
        file,
        clock: () => DateTime.utc(2026, 9, 12, 12),
      );

      await logger.recordError(
        module: 'sale checkout',
        event: 'database write',
        error: FileSystemException(
          'customer 01012345678 failed',
          '/home/private/customer.db',
        ),
        stackTrace: StackTrace.fromString('/home/private/source.dart:44'),
        operationId: 'secret-operation-key',
      );

      final source = await file.readAsString();
      final record = jsonDecode(source.trim()) as Map<String, dynamic>;
      expect(record['timestampUtc'], '2026-09-12T12:00:00.000Z');
      expect(record['module'], 'sale_checkout');
      expect(record['event'], 'database_write');
      expect(record['errorType'], 'FileSystemException');
      expect(record['operationHash'], hasLength(16));
      expect(record['stackHash'], hasLength(16));
      expect(source, isNot(contains('01012345678')));
      expect(source, isNot(contains('/home/private')));
      expect(source, isNot(contains('secret-operation-key')));
    },
  );

  test('diagnostic log rotates and reports bounded history', () async {
    final directory = await Directory.systemTemp.createTemp(
      'alikhlas-diagnostics-rotation-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final logger = V2DiagnosticLogger.forFile(
      File('${directory.path}/errors.jsonl'),
      maximumBytes: 260,
      clock: () => DateTime.utc(2026, 9, 12, 13),
    );

    for (var index = 0; index < 6; index++) {
      await logger.recordError(
        module: 'database',
        event: 'write_$index',
        error: StateError('private message $index'),
      );
    }

    final summary = await logger.summary();
    expect(summary.hasRotatedLog, isTrue);
    expect(summary.recordCount, greaterThan(0));
    expect(summary.lastRecordedAt, DateTime.utc(2026, 9, 12, 13));
    expect(await logger.file.length(), lessThanOrEqualTo(520));
    expect(await logger.rotatedFile.length(), lessThanOrEqualTo(520));
  });

  test(
    'unexpected financial failure carries module and operation id',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final events = <({String module, String event, String? operationId})>[];
      final useCases = V2UseCases(
        database,
        writeBarrier: _FailingWriteBarrier(),
        diagnosticSink:
            ({
              required module,
              required event,
              required error,
              stackTrace,
              operationId,
            }) => events.add((
              module: module,
              event: event,
              operationId: operationId,
            )),
      );

      await expectLater(
        useCases.createSale(
          operationKey: 'sale-attempt-42',
          items: const [],
          payments: const [],
        ),
        throwsA(isA<Object>()),
      );
      expect(events, [
        (
          module: 'financial_operation',
          event: 'sale',
          operationId: 'sale-attempt-42',
        ),
      ]);
    },
  );
}

class _FailingWriteBarrier extends V2WriteBarrier {
  @override
  Future<T> write<T>(Future<T> Function() action) =>
      Future<T>.error(StateError('simulated write failure'));
}

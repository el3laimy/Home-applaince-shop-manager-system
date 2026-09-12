import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:archive/archive_io.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../accounting/account_codes.dart';
import '../core/money.dart';
import '../core/result.dart';
import '../data/app_database.dart';
import '../data/restore_recovery.dart';
import 'backup_file_operations.dart';
import 'v2_diagnostic_logger.dart';

part 'use_cases/v2_models.dart';
part 'use_cases/v2_invoice_draft_use_cases.dart';
part 'use_cases/v2_pending_sale_use_cases.dart';
part 'use_cases/v2_pending_purchase_use_cases.dart';
part 'use_cases/v2_pending_financial_operation_use_cases.dart';
part 'use_cases/v2_integrity_audit_use_cases.dart';
part 'use_cases/v2_integrity_ledger_stock_audit.dart';
part 'use_cases/v2_integrity_plans_corrections_audit.dart';
part 'use_cases/v2_integrity_documents_audit.dart';
part 'use_cases/v2_integrity_reference_audit.dart';
part 'use_cases/v2_integrity_audit_helpers.dart';
part 'use_cases/v2_auth_shift_use_cases.dart';
part 'use_cases/v2_catalog_party_use_cases.dart';
part 'use_cases/v2_inventory_adjustment_use_cases.dart';
part 'use_cases/v2_opening_balance_use_cases.dart';
part 'use_cases/v2_financial_correction_use_cases.dart';
part 'use_cases/v2_product_csv_import_use_cases.dart';
part 'use_cases/v2_sale_use_cases.dart';
part 'use_cases/v2_purchase_use_cases.dart';
part 'use_cases/v2_purchase_return_use_cases.dart';
part 'use_cases/v2_sale_return_use_cases.dart';
part 'use_cases/v2_expense_use_cases.dart';
part 'use_cases/v2_installment_use_cases.dart';
part 'use_cases/v2_snapshot_report_use_cases.dart';
part 'use_cases/v2_statement_receipt_use_cases.dart';
part 'use_cases/v2_backup_settings_use_cases.dart';
part 'use_cases/v2_portable_backup_use_cases.dart';
part 'use_cases/v2_core_helpers.dart';
part 'use_cases/v2_operation_receipt_helpers.dart';
part 'use_cases/v2_report_helpers.dart';
part 'use_cases/v2_support_types.dart';

/// Coordinates application writes with a destructive database restore.
///
/// A restore first closes admissions, lets writes already in progress complete,
/// then receives exclusive access. This avoids closing the SQLite connection
/// under a transaction or admitting a new mutation after its rollback copy has
/// been prepared.
class V2WriteBarrier {
  var _restoreRequested = false;
  var _activeWrites = 0;
  Completer<void>? _writesDrained;

  Future<T> write<T>(Future<T> Function() action) async {
    if (_restoreRequested) {
      throw StateError('الاسترجاع جارٍ. لا يمكن حفظ بيانات جديدة الآن.');
    }
    _activeWrites += 1;
    try {
      return await action();
    } finally {
      _activeWrites -= 1;
      if (_activeWrites == 0) {
        _writesDrained?.complete();
        _writesDrained = null;
      }
    }
  }

  Future<T> restore<T>(Future<T> Function() action) async {
    if (_restoreRequested) {
      throw StateError('يوجد استرجاع جارٍ بالفعل.');
    }
    _restoreRequested = true;
    try {
      while (_activeWrites > 0) {
        final drained = _writesDrained ??= Completer<void>();
        await drained.future;
      }
      return await action();
    } finally {
      _restoreRequested = false;
    }
  }
}

class V2UseCases {
  V2UseCases(
    this.db, {
    RestoreFileOperations? restoreFileOperations,
    BackupFileOperations? backupFileOperations,
    DateTime Function()? clock,
    V2WriteBarrier? writeBarrier,
    V2DiagnosticEventSink? diagnosticSink,
  }) : clock = clock ?? DateTime.now,
       _restoreFiles = restoreFileOperations ?? const RestoreFileOperations(),
       _backupFileOperations =
           backupFileOperations ?? const BackupFileOperations(),
       _writeBarrier = writeBarrier ?? V2WriteBarrier(),
       _diagnosticSink = diagnosticSink;

  static const _passwordHashPrefix = 'pbkdf2_sha256';
  static const _passwordIterations = 600000;
  static const _passwordSaltLength = 16;
  static const _passwordKeyLength = 32;

  final DateTime Function() clock;
  bool _automaticBackupRunning = false;
  bool _backupRunning = false;
  bool _restoreRunning = false;
  String? backupWarning;
  bool databaseClosedForRestore = false;

  final AppDatabase db;
  final RestoreFileOperations _restoreFiles;
  final BackupFileOperations _backupFileOperations;
  final V2WriteBarrier _writeBarrier;
  final V2DiagnosticEventSink? _diagnosticSink;

  void _recordUnexpectedError({
    required String module,
    required String event,
    required Object error,
    required StackTrace stackTrace,
    String? operationId,
  }) => _diagnosticSink?.call(
    module: module,
    event: event,
    error: error,
    stackTrace: stackTrace,
    operationId: operationId,
  );

  Future<T> _write<T>(Future<T> Function() action) {
    if (databaseClosedForRestore) {
      return Future<T>.error(
        StateError('أعد فتح التطبيق بعد اكتمال الاسترجاع.'),
      );
    }
    return _writeBarrier.write(action);
  }

  Future<T> _writeTransaction<T>(Future<T> Function() action) =>
      _write(() => db.transaction(action));

  Future<T> _withRestoreWriteBarrier<T>(Future<T> Function() action) =>
      _writeBarrier.restore(action);

  String _hashPassword(String password) {
    final salt = _randomBytes(_passwordSaltLength);
    final hash = _pbkdf2Sha256(
      password: password,
      salt: salt,
      iterations: _passwordIterations,
      keyLength: _passwordKeyLength,
    );
    return [
      _passwordHashPrefix,
      _passwordIterations,
      base64Encode(salt),
      base64Encode(hash),
    ].join(r'$');
  }

  String _legacyHashPassword(String password) {
    final bytes = utf8.encode('alikhlas-v2::$password');
    return sha256.convert(bytes).toString();
  }

  ({bool isValid, bool needsRehash}) _verifyPassword(
    String password,
    String storedHash,
  ) {
    final parts = storedHash.split(r'$');
    if (parts.length == 4 && parts.first == _passwordHashPrefix) {
      final iterations = int.tryParse(parts[1]);
      if (iterations == null || iterations <= 0) {
        return (isValid: false, needsRehash: false);
      }
      try {
        final salt = base64Decode(parts[2]);
        final expectedHash = base64Decode(parts[3]);
        final actualHash = _pbkdf2Sha256(
          password: password,
          salt: salt,
          iterations: iterations,
          keyLength: expectedHash.length,
        );
        return (
          isValid: _constantTimeEquals(actualHash, expectedHash),
          needsRehash:
              iterations != _passwordIterations ||
              expectedHash.length != _passwordKeyLength,
        );
      } on FormatException {
        return (isValid: false, needsRehash: false);
      }
    }

    final isLegacyValid = storedHash == _legacyHashPassword(password);
    return (isValid: isLegacyValid, needsRehash: isLegacyValid);
  }

  List<int> _randomBytes(int length) {
    final random = math.Random.secure();
    return List.generate(length, (_) => random.nextInt(256));
  }

  List<int> _pbkdf2Sha256({
    required String password,
    required List<int> salt,
    required int iterations,
    required int keyLength,
  }) {
    final hmac = Hmac(sha256, utf8.encode(password));
    final derivedKey = <int>[];
    var blockIndex = 1;

    while (derivedKey.length < keyLength) {
      var block = hmac.convert([...salt, ..._int32Bytes(blockIndex)]).bytes;
      final mixedBlock = List<int>.from(block);

      for (var i = 1; i < iterations; i++) {
        block = hmac.convert(block).bytes;
        for (var j = 0; j < mixedBlock.length; j++) {
          mixedBlock[j] ^= block[j];
        }
      }

      derivedKey.addAll(mixedBlock);
      blockIndex++;
    }

    return derivedKey.take(keyLength).toList();
  }

  List<int> _int32Bytes(int value) {
    return [
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ];
  }

  bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var diff = 0;
    for (var i = 0; i < left.length; i++) {
      diff |= left[i] ^ right[i];
    }
    return diff == 0;
  }
}

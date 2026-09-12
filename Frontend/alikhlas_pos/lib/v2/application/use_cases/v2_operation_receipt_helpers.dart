part of '../v2_use_cases.dart';

/// Durable receipt helpers for financial mutations that return an integer id.
///
/// A receipt is written in the same transaction as the mutation. Replaying the
/// same operation key and payload returns its original id, while a different
/// payload is rejected before any financial state changes.
extension V2OperationReceiptHelpers on V2UseCases {
  String newFinancialOperationKey() =>
      base64UrlEncode(_randomBytes(16)).replaceAll('=', '');

  static const _unreadableReceiptMessage =
      'تعذر التحقق من إيصال عملية محفوظة. لا تعِد تسجيلها؛ راجع الدعم.';

  Future<AppResult<int>> _runIdempotentFinancialOperation({
    required String namespace,
    required String operationKey,
    required Object fingerprintPayload,
    required String conflictMessage,
    required Future<AppResult<int>> Function() execute,
    List<String> legacyIdFields = const [],
    Object? legacyFingerprintPayload,
  }) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,100}$').hasMatch(operationKey)) {
      return const AppFailure<int>('معرّف عملية غير صالح');
    }
    final fingerprint = sha256
        .convert(utf8.encode(jsonEncode(fingerprintPayload)))
        .toString();
    final legacyFingerprint = legacyFingerprintPayload == null
        ? null
        : sha256
              .convert(utf8.encode(jsonEncode(legacyFingerprintPayload)))
              .toString();
    final key = 'operation.$namespace.$operationKey';

    try {
      return await _writeTransaction(() async {
        final prior = await (db.select(
          db.appSettings,
        )..where((row) => row.key.equals(key))).getSingleOrNull();
        if (prior != null) {
          final saved = _decodeOperationReceipt(
            prior.value,
            legacyIdFields: legacyIdFields,
          );
          if (saved == null) {
            return const AppFailure<int>(_unreadableReceiptMessage);
          }
          if (saved['fingerprint'] != fingerprint &&
              saved['fingerprint'] != legacyFingerprint) {
            return AppFailure<int>(conflictMessage);
          }
          return AppSuccess<int>(saved['id'] as int);
        }

        final result = await execute();
        if (result is AppSuccess<int>) {
          await _upsertSetting(
            key,
            jsonEncode({'fingerprint': fingerprint, 'id': result.value}),
          );
        }
        return result;
      });
    } on Object catch (error, stackTrace) {
      _recordUnexpectedError(
        module: 'financial_operation',
        event: namespace,
        error: error,
        stackTrace: stackTrace,
        operationId: operationKey,
      );
      rethrow;
    }
  }

  /// The opening stock operation creates a product, a stock movement, and
  /// potentially a capital/inventory ledger entry. Its receipt must therefore
  /// replay the original product rather than create another opening balance.
  Future<AppResult<Product>> _runIdempotentProductOperation({
    required String namespace,
    required String operationKey,
    required Object fingerprintPayload,
    required String conflictMessage,
    required Future<AppResult<Product>> Function() execute,
  }) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,100}$').hasMatch(operationKey)) {
      return const AppFailure<Product>('معرّف عملية غير صالح');
    }
    final fingerprint = sha256
        .convert(utf8.encode(jsonEncode(fingerprintPayload)))
        .toString();
    final key = 'operation.$namespace.$operationKey';

    try {
      return await _writeTransaction(() async {
        final prior = await (db.select(
          db.appSettings,
        )..where((row) => row.key.equals(key))).getSingleOrNull();
        if (prior != null) {
          final saved = _decodeOperationReceipt(prior.value);
          if (saved == null) {
            return const AppFailure<Product>(_unreadableReceiptMessage);
          }
          if (saved['fingerprint'] != fingerprint) {
            return AppFailure<Product>(conflictMessage);
          }
          final product =
              await (db.select(db.products)
                    ..where((row) => row.id.equals(saved['id'] as int)))
                  .getSingleOrNull();
          if (product == null) {
            return const AppFailure<Product>(_unreadableReceiptMessage);
          }
          return AppSuccess<Product>(product);
        }

        final result = await execute();
        if (result is AppSuccess<Product>) {
          await _upsertSetting(
            key,
            jsonEncode({'fingerprint': fingerprint, 'id': result.value.id}),
          );
        }
        return result;
      });
    } on Object catch (error, stackTrace) {
      _recordUnexpectedError(
        module: 'product_operation',
        event: namespace,
        error: error,
        stackTrace: stackTrace,
        operationId: operationKey,
      );
      rethrow;
    }
  }

  Future<AppResult<Shift>> _runIdempotentShiftOperation({
    required String namespace,
    required String operationKey,
    required Object fingerprintPayload,
    required String conflictMessage,
    required Future<AppResult<Shift>> Function() execute,
  }) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,100}$').hasMatch(operationKey)) {
      return const AppFailure<Shift>('معرّف عملية غير صالح');
    }
    final fingerprint = sha256
        .convert(utf8.encode(jsonEncode(fingerprintPayload)))
        .toString();
    final key = 'operation.$namespace.$operationKey';

    try {
      return await _writeTransaction(() async {
        final prior = await (db.select(
          db.appSettings,
        )..where((row) => row.key.equals(key))).getSingleOrNull();
        if (prior != null) {
          final saved = _decodeOperationReceipt(prior.value);
          if (saved == null) {
            return const AppFailure<Shift>(_unreadableReceiptMessage);
          }
          if (saved['fingerprint'] != fingerprint) {
            return AppFailure<Shift>(conflictMessage);
          }
          final shift =
              await (db.select(db.shifts)
                    ..where((row) => row.id.equals(saved['id'] as int)))
                  .getSingleOrNull();
          if (shift == null) {
            return const AppFailure<Shift>(_unreadableReceiptMessage);
          }
          return AppSuccess<Shift>(shift);
        }

        final result = await execute();
        if (result is AppSuccess<Shift>) {
          await _upsertSetting(
            key,
            jsonEncode({'fingerprint': fingerprint, 'id': result.value.id}),
          );
        }
        return result;
      });
    } on Object catch (error, stackTrace) {
      _recordUnexpectedError(
        module: 'shift_operation',
        event: namespace,
        error: error,
        stackTrace: stackTrace,
        operationId: operationKey,
      );
      rethrow;
    }
  }

  Map<String, dynamic>? _decodeOperationReceipt(
    String source, {
    List<String> legacyIdFields = const [],
  }) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map) return null;
      final receipt = Map<String, dynamic>.from(decoded);
      final fingerprint = receipt['fingerprint'];
      var id = receipt['id'];
      for (final field in legacyIdFields) {
        id ??= receipt[field];
      }
      if (fingerprint is! String || id is! int || id < 1) return null;
      return {'fingerprint': fingerprint, 'id': id};
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}

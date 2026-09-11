part of '../v2_use_cases.dart';

/// A persisted purchase request; negative-balance consent is never persisted.
class PendingPurchase {
  PendingPurchase({
    required this.operationKey,
    this.supplierId,
    required List<PurchaseLineInput> items,
    required List<PaymentInput> payments,
  }) : items = List.unmodifiable(items),
       payments = List.unmodifiable(payments) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,100}$').hasMatch(operationKey)) {
      throw const FormatException('Invalid pending purchase key');
    }
  }
  final String operationKey;
  final int? supplierId;
  final List<PurchaseLineInput> items;
  final List<PaymentInput> payments;

  String encode() => jsonEncode({
    'version': 1,
    'operationKey': operationKey,
    'supplierId': supplierId,
    'items': [
      for (final item in items) [item.productId, item.qty, item.unitCostMinor],
    ],
    'payments': [
      for (final payment in payments)
        [payment.method.name, payment.amountMinor, payment.note],
    ],
  });
  factory PendingPurchase.decode(String source) {
    final data = jsonDecode(source) as Map<String, dynamic>;
    if (data['version'] != 1) {
      throw const FormatException('Unknown pending purchase version');
    }
    return PendingPurchase(
      operationKey: data['operationKey'] as String,
      supplierId: data['supplierId'] as int?,
      items: [
        for (final row in data['items'] as List<dynamic>)
          PurchaseLineInput(
            productId: row[0] as int,
            qty: row[1] as int,
            unitCostMinor: row[2] as int,
          ),
      ],
      payments: [
        for (final row in data['payments'] as List<dynamic>)
          PaymentInput(
            PaymentMethod.values.byName(row[0] as String),
            row[1] as int,
            note: row[2] as String?,
          ),
      ],
    );
  }
}

extension V2PendingPurchaseUseCases on V2UseCases {
  static const _pendingKey = 'pending.purchase.v1';

  Future<PendingPurchase?> pendingPurchase() async {
    final row = await (db.select(
      db.appSettings,
    )..where((row) => row.key.equals(_pendingKey))).getSingleOrNull();
    return row == null ? null : PendingPurchase.decode(row.value);
  }

  /// Never replace an unresolved request, including after navigation/restart.
  Future<PendingPurchase> stagePendingPurchase(PendingPurchase request) =>
      _writeTransaction(() async {
        final existing = await pendingPurchase();
        if (existing != null) return existing;
        await _upsertSetting(_pendingKey, request.encode());
        await (db.delete(
          db.appSettings,
        )..where((row) => row.key.equals(_purchaseDraftKey))).go();
        return request;
      });

  Future<AppResult<int>> submitPendingPurchase(
    PendingPurchase request, {
    bool allowNegativeBalance = false,
  }) => _writeTransaction(() async {
    final active = await pendingPurchase();
    if (active == null || active.encode() != request.encode()) {
      return const AppFailure<int>(
        'طلب الشراء المعلّق تغير أو أُلغي. أعد فتح شاشة الشراء.',
      );
    }
    return createPurchase(
      operationKey: request.operationKey,
      supplierId: request.supplierId,
      items: request.items,
      payments: request.payments,
      allowNegativeBalance: allowNegativeBalance,
    );
  });

  /// Only an already committed operation may be acknowledged as completed.
  Future<bool> acknowledgePendingPurchase(String operationKey) =>
      _writeTransaction(() async {
        final request = await pendingPurchase();
        if (request == null || request.operationKey != operationKey) {
          return false;
        }
        final saved =
            await (db.select(db.appSettings)..where(
                  (row) => row.key.equals('operation.purchase.$operationKey'),
                ))
                .getSingleOrNull();
        if (saved == null) return false;
        await (db.delete(
          db.appSettings,
        )..where((row) => row.key.equals(_pendingKey))).go();
        return true;
      });

  /// The check and removal share a transaction with competing purchase commits.
  Future<bool> discardUncommittedPendingPurchase(String operationKey) =>
      _writeTransaction(() async {
        final request = await pendingPurchase();
        if (request == null || request.operationKey != operationKey) {
          return false;
        }
        final saved =
            await (db.select(db.appSettings)..where(
                  (row) => row.key.equals('operation.purchase.$operationKey'),
                ))
                .getSingleOrNull();
        if (saved != null) return false;
        await (db.delete(
          db.appSettings,
        )..where((row) => row.key.equals(_pendingKey))).go();
        return true;
      });

  /// Converts an uncommitted request back to an editable, non-posting draft.
  /// A newer draft is never replaced by an older pending request.
  Future<bool> restoreUncommittedPendingPurchaseAsDraft(String operationKey) =>
      _writeTransaction(() async {
        final request = await pendingPurchase();
        if (request == null || request.operationKey != operationKey) {
          return false;
        }
        final saved =
            await (db.select(db.appSettings)..where(
                  (row) => row.key.equals('operation.purchase.$operationKey'),
                ))
                .getSingleOrNull();
        if (saved != null || await purchaseDraft() != null) return false;
        int paymentAmount(PaymentMethod method) => request.payments
            .where((payment) => payment.method == method)
            .fold(0, (total, payment) => total + payment.amountMinor);
        await _upsertSetting(
          _purchaseDraftKey,
          PurchaseDraft(
            supplierId: request.supplierId,
            items: request.items,
            cashMinor: paymentAmount(PaymentMethod.cash),
            walletMinor: paymentAmount(PaymentMethod.wallet),
            savedAt: clock(),
          ).encode(),
        );
        await (db.delete(
          db.appSettings,
        )..where((row) => row.key.equals(_pendingKey))).go();
        return true;
      });
}
